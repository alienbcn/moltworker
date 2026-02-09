import type { Sandbox } from '@cloudflare/sandbox';
import type { MoltbotEnv } from '../types';
import { R2_MOUNT_PATH } from '../config';
import { mountR2Storage } from './r2';
import { waitForProcess } from './utils';

export interface SyncResult {
  success: boolean;
  lastSync?: string;
  error?: string;
  details?: string;
}

/**
 * Sync OpenClaw config and workspace from container to R2 for persistence.
 *
 * This function:
 * 1. Mounts R2 if not already mounted
 * 2. Verifies source has critical files (prevents overwriting good backup with empty data)
 * 3. Runs rsync to copy config, workspace, and skills to R2
 * 4. Writes a timestamp file for tracking
 *
 * Syncs three directories:
 * - Config: /root/.openclaw/ (or /root/.clawdbot/) → R2:/openclaw/
 * - Workspace: /root/clawd/ → R2:/workspace/ (IDENTITY.md, MEMORY.md, memory/, assets/)
 * - Skills: /root/clawd/skills/ → R2:/skills/
 *
 * @param sandbox - The sandbox instance
 * @param env - Worker environment bindings
 * @returns SyncResult with success status and optional error details
 */
export async function syncToR2(sandbox: Sandbox, env: MoltbotEnv): Promise<SyncResult> {
  // Check if R2 is configured
  if (!env.R2_ACCESS_KEY_ID || !env.R2_SECRET_ACCESS_KEY || !env.CF_ACCOUNT_ID) {
    console.log('[R2 Sync] R2 storage is not configured - skipping backup');
    return { success: false, error: 'R2 storage is not configured' };
  }

  console.log('[R2 Sync] Starting backup sync to R2...');

  // Mount R2 if not already mounted
  const mounted = await mountR2Storage(sandbox, env);
  if (!mounted) {
    console.error('[R2 Sync] Failed to mount R2 storage - cannot backup');
    return { success: false, error: 'Failed to mount R2 storage' };
  }

  // Determine which config directory exists
  // Check new path first, fall back to legacy
  let configDir = '/root/.openclaw';
  try {
    const checkNew = await sandbox.startProcess(
      'test -f /root/.openclaw/openclaw.json && echo "ok"',
    );
    await waitForProcess(checkNew, 5000);
    const newLogs = await checkNew.getLogs();
    if (!newLogs.stdout?.includes('ok')) {
      // Try legacy path
      const checkLegacy = await sandbox.startProcess(
        'test -f /root/.clawdbot/clawdbot.json && echo "ok"',
      );
      await waitForProcess(checkLegacy, 5000);
      const legacyLogs = await checkLegacy.getLogs();
      if (legacyLogs.stdout?.includes('ok')) {
        configDir = '/root/.clawdbot';
      } else {
        console.error('[R2 Sync] Config verification failed: no openclaw.json or clawdbot.json found');
        return {
          success: false,
          error: 'Sync aborted: no config file found',
          details: 'Neither openclaw.json nor clawdbot.json found in config directory.',
        };
      }
    }
  } catch (err) {
    console.error('[R2 Sync] Failed to verify source files:', err);
    return {
      success: false,
      error: 'Failed to verify source files',
      details: err instanceof Error ? err.message : 'Unknown error',
    };
  }

  // Sync to the new openclaw/ R2 prefix (even if source is legacy .clawdbot)
  // Also sync workspace directory with memory, identity, and assets
  // This ensures that conversation memory, user identity, and skills are preserved
  console.log('[R2 Sync] Syncing config from', configDir, 'to R2');
  const syncCmd = `rsync -r --no-times --delete --exclude='*.lock' --exclude='*.log' --exclude='*.tmp' --exclude='node_modules' ${configDir}/ ${R2_MOUNT_PATH}/openclaw/ 2>&1 && rsync -r --no-times --delete --exclude='skills' --exclude='node_modules' /root/clawd/ ${R2_MOUNT_PATH}/workspace/ 2>&1 && rsync -r --no-times --delete /root/clawd/skills/ ${R2_MOUNT_PATH}/skills/ 2>&1 && date -Iseconds > ${R2_MOUNT_PATH}/.last-sync && echo "Sync completed successfully"`;

  try {
    const proc = await sandbox.startProcess(syncCmd);
    await waitForProcess(proc, 30000); // 30 second timeout for sync

    const syncLogs = await proc.getLogs();
    const stdout = syncLogs.stdout || '';
    const stderr = syncLogs.stderr || '';
    
    console.log('[R2 Sync] Command output:', stdout.slice(0, 200));
    if (stderr) {
      console.warn('[R2 Sync] Command stderr:', stderr.slice(0, 200));
    }

    // Check for success by reading the timestamp file
    const timestampProc = await sandbox.startProcess(`cat ${R2_MOUNT_PATH}/.last-sync`);
    await waitForProcess(timestampProc, 5000);
    const timestampLogs = await timestampProc.getLogs();
    const lastSync = timestampLogs.stdout?.trim();

    if (lastSync && lastSync.match(/^\d{4}-\d{2}-\d{2}/)) {
      // Verify that key directories exist in R2
      const verifyProc = await sandbox.startProcess(`
        echo "Config:" && ls -la ${R2_MOUNT_PATH}/openclaw/ 2>&1 | head -5 &&
        echo "Workspace:" && ls -la ${R2_MOUNT_PATH}/workspace/ 2>&1 | head -5 &&
        echo "Memory:" && ls -la ${R2_MOUNT_PATH}/workspace/memory/ 2>&1 | head -5
      `);
      await waitForProcess(verifyProc, 10000);
      const verifyLogs = await verifyProc.getLogs();
      
      console.log('[R2 Sync] Sync completed successfully at', lastSync);
      return { 
        success: true, 
        lastSync,
        details: `Synced config, workspace (including memory), and skills. Verification:\n${verifyLogs.stdout || ''}`,
      };
    } else {
      console.error('[R2 Sync] Sync failed: No valid timestamp file created');
      return {
        success: false,
        error: 'Sync failed: No timestamp file created',
        details: `stdout: ${stdout}\nstderr: ${stderr}`,
      };
    }
  } catch (err) {
    console.error('[R2 Sync] Sync error:', err);
    return {
      success: false,
      error: 'Sync error',
      details: err instanceof Error ? err.message : 'Unknown error',
    };
  }
}
