import type { Sandbox, Process } from '@cloudflare/sandbox';
import type { MoltbotEnv } from '../types';
import { MOLTBOT_PORT, STARTUP_TIMEOUT_MS } from '../config';
import { buildEnvVars } from './env';
import { mountR2Storage } from './r2';

/**
 * Check if the gateway is actually responding to requests
 * 
 * @param sandbox - The sandbox instance
 * @param timeoutMs - Timeout in milliseconds
 * @returns true if gateway is responding, false otherwise
 */
async function isGatewayHealthy(sandbox: Sandbox, timeoutMs: number = 5000): Promise<boolean> {
  try {
    const response = await Promise.race([
      sandbox.containerFetch(new Request('http://localhost:18789/'), 18789),
      new Promise<Response>((_, reject) =>
        setTimeout(() => reject(new Error('Gateway health check timeout')), timeoutMs),
      ),
    ]);
    return response.status >= 200 && response.status < 500;
  } catch {
    return false;
  }
}
export async function findExistingMoltbotProcess(sandbox: Sandbox): Promise<Process | null> {
  try {
    const processes = await sandbox.listProcesses();
    for (const proc of processes) {
      // Match gateway process (openclaw gateway or legacy clawdbot gateway)
      // Don't match CLI commands like "openclaw devices list"
      const isGatewayProcess =
        proc.command.includes('start-openclaw.sh') ||
        proc.command.includes('openclaw gateway') ||
        // Legacy: match old startup script during transition
        proc.command.includes('start-moltbot.sh') ||
        proc.command.includes('clawdbot gateway');
      const isCliCommand =
        proc.command.includes('openclaw devices') ||
        proc.command.includes('openclaw --version') ||
        proc.command.includes('openclaw onboard') ||
        proc.command.includes('clawdbot devices') ||
        proc.command.includes('clawdbot --version');

      if (isGatewayProcess && !isCliCommand) {
        if (proc.status === 'starting' || proc.status === 'running') {
          return proc;
        }
      }
    }
  } catch (e) {
    console.log('Could not list processes:', e);
  }
  return null;
}

/**
 * Ensure the OpenClaw gateway is running
 *
 * This will:
 * 1. Mount R2 storage if configured
 * 2. Check for an existing gateway process
 * 3. Verify it's healthy (responsive to requests)
 * 4. Wait for it to be ready, or start a new one
 * 5. Do health check to ensure the gateway is actually working
 *
 * @param sandbox - The sandbox instance
 * @param env - Worker environment bindings
 * @returns The running gateway process
 */
export async function ensureMoltbotGateway(sandbox: Sandbox, env: MoltbotEnv): Promise<Process> {
  // Mount R2 storage for persistent data (non-blocking if not configured)
  // R2 is used as a backup - the startup script will restore from it on boot
  console.log('[Gateway] Mounting R2 storage...');
  await mountR2Storage(sandbox, env);

  // Check if gateway is already running or starting
  const existingProcess = await findExistingMoltbotProcess(sandbox);
  if (existingProcess) {
    console.log(
      '[Gateway] Found existing gateway process:',
      existingProcess.id,
      'status:',
      existingProcess.status,
    );

    // Check if gateway is actually healthy (responding to requests)
    const isHealthy = await isGatewayHealthy(sandbox);
    if (isHealthy) {
      console.log('[Gateway] Process is running and responsive');
      return existingProcess;
    } else {
      console.log('[Gateway] Process exists but not responsive, checking port accessibility...');
      // Try waiting for port one more time
      try {
        await existingProcess.waitForPort(MOLTBOT_PORT, { mode: 'tcp', timeout: 10000 });
        console.log('[Gateway] Port is now accessible');
        return existingProcess;
      } catch (_e) {
        console.log(
          '[Gateway] Process not responsive after timeout, killing and restarting...',
        );
        try {
          await existingProcess.kill();
        } catch (killError) {
          console.log('[Gateway] Failed to kill process:', killError);
        }
      }
    }
  }

  // Start a new OpenClaw gateway
  console.log('[Gateway] Starting new OpenClaw gateway...');
  const envVars = buildEnvVars(env);
  const command = '/usr/local/bin/start-openclaw.sh';

  console.log('[Gateway] Starting process with command:', command);
  console.log('[Gateway] Environment vars being passed:', Object.keys(envVars));
  console.log('[Gateway] Has ANTHROPIC_API_KEY:', !!env.ANTHROPIC_API_KEY);
  console.log('[Gateway] Has OPENAI_API_KEY:', !!env.OPENAI_API_KEY);
  console.log('[Gateway] Has TELEGRAM_BOT_TOKEN:', !!env.TELEGRAM_BOT_TOKEN);
  console.log('[Gateway] Has R2 configured:', !!(env.R2_ACCESS_KEY_ID && env.R2_SECRET_ACCESS_KEY));

  let process: Process;
  try {
    process = await sandbox.startProcess(command, {
      env: Object.keys(envVars).length > 0 ? envVars : undefined,
    });
    console.log('[Gateway] Process started with id:', process.id, 'status:', process.status);
  } catch (startErr) {
    console.error('[Gateway] Failed to start process:', startErr);
    throw startErr;
  }

  // Wait for the gateway to be ready
  try {
    console.log('[Gateway] Waiting for OpenClaw gateway to be ready on port', MOLTBOT_PORT);
    await process.waitForPort(MOLTBOT_PORT, { mode: 'tcp', timeout: STARTUP_TIMEOUT_MS });
    console.log('[Gateway] OpenClaw gateway port is now accessible');

    // Do a health check to verify it's actually working
    let healthCheckAttempts = 0;
    let isHealthy = false;
    
    while (healthCheckAttempts < 5 && !isHealthy) {
      await new Promise((r) => setTimeout(r, 2000)); // Wait 2 seconds between attempts
      isHealthy = await isGatewayHealthy(sandbox, 5000);
      healthCheckAttempts++;
      console.log(`[Gateway] Health check attempt ${healthCheckAttempts}/5: ${isHealthy ? 'OK' : 'failed'}`);
    }

    if (!isHealthy) {
      console.warn('[Gateway] Gateway port is open but not responding to health checks');
    }

    const logs = await process.getLogs();
    if (logs.stdout) console.log('[Gateway] startup stdout:', logs.stdout.substring(0, 500));
    if (logs.stderr) console.log('[Gateway] startup stderr:', logs.stderr.substring(0, 500));
  } catch (e) {
    console.error('[Gateway] waitForPort failed:', e);
    try {
      const logs = await process.getLogs();
      console.error('[Gateway] startup failed. Stderr:', logs.stderr?.substring(0, 1000));
      console.error('[Gateway] startup failed. Stdout:', logs.stdout?.substring(0, 1000));
      throw new Error(`OpenClaw gateway failed to start. Stderr: ${logs.stderr || '(empty)'}`, {
        cause: e,
      });
    } catch (logErr) {
      console.error('[Gateway] Failed to get logs:', logErr);
      throw e;
    }
  }

  console.log('[Gateway] OpenClaw gateway is ready!');
  return process;
}
