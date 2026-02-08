import type { Sandbox } from '@cloudflare/sandbox';

/**
 * Browser Process Cleanup
 *
 * Monitorea y limpia instancias inactivas de Chromium para evitar fugas de memoria
 * en el ecosistema de Cloudflare Sandbox.
 */

export interface BrowserCleanupOptions {
  /** Edad máxima permitida para un proceso inactivo de browser (ms) */
  maxIdleMs?: number;
  /** Intervalo entre checks (ms) */
  checkIntervalMs?: number;
  /** Registrar en logs */
  verbose?: boolean;
}

/**
 * Limpiar procesos inactivos de Chromium/Puppeteer
 * Busca procesos viejos y los elimina para liberar memoria
 */
export async function cleanupInactiveChromium(
  sandbox: Sandbox,
  options: BrowserCleanupOptions = {},
): Promise<{ killed: number; failed: number }> {
  const {
    maxIdleMs = 30 * 60 * 1000, // 30 minutos por defecto
    checkIntervalMs = 5 * 60 * 1000, // Check cada 5 minutos
    verbose = false,
  } = options;

  let killed = 0;
  let failed = 0;

  try {
    const processes = await sandbox.listProcesses();
    const now = Date.now();

    for (const proc of processes) {
      // Buscar procesos del navegador
      const isChromium =
        proc.command.includes('chrome') ||
        proc.command.includes('chromium') ||
        proc.command.includes('puppeteer') ||
        proc.command.includes('playwright') ||
        proc.command.includes('cdp');

      if (!isChromium) {
        continue;
      }

      // Procesos en ejecución: verificar edad
      if (proc.status === 'running' && proc.startTime) {
        const age = now - proc.startTime.getTime();

        if (age > maxIdleMs) {
          if (verbose) {
            const ageMin = Math.round(age / 1000 / 60);
            console.log(
              `[Browser] Matando Chromium inactivo después de ${ageMin}min: ${proc.id}`,
            );
          }

          try {
            await proc.kill();
            killed++;
          } catch (err) {
            if (verbose) {
              console.error(
                `[Browser] Error al matar proceso ${proc.id}:`,
                err instanceof Error ? err.message : String(err),
              );
            }
            failed++;
          }
        }
      }
      // Procesos completados: que estén en el historial, OK
      // No necesario limpiarlos activamente
    }
  } catch (err) {
    if (verbose) {
      console.error(
        '[Browser] Error en cleanup:',
        err instanceof Error ? err.message : String(err),
      );
    }
  }

  return { killed, failed };
}

/**
 * Iniciar monitor automático de limpieza de browser
 * Retorna una función para detener el monitor
 */
export function startBrowserCleanupMonitor(
  sandbox: Sandbox,
  options: BrowserCleanupOptions = {},
): () => void {
  const checkIntervalMs = options.checkIntervalMs || 5 * 60 * 1000;
  const verbose = options.verbose ?? false;

  const interval = setInterval(async () => {
    try {
      const result = await cleanupInactiveChromium(sandbox, options);

      if (verbose || result.killed > 0) {
        console.log(
          `[Browser] Cleanup tick: ${result.killed} killed, ${result.failed} failed`,
        );
      }
    } catch (err) {
      console.error(
        '[Browser] Monitor error:',
        err instanceof Error ? err.message : String(err),
      );
    }
  }, checkIntervalMs);

  // Retornar función para detener el monitor
  return () => {
    clearInterval(interval);
    if (verbose) {
      console.log('[Browser] Monitor dettenido');
    }
  };
}
