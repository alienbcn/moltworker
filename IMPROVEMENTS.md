# Mejoras de Robustez para OpenClaw Telegram Bot

## Resumen de Cambios

Se han realizado mejoras significativas para asegurar que el bot de Telegram permanezca siempre activo, maneje errores de forma robusta, y conserve la memoria incluso después de reinicios. 

## Cambios Implementados

### 1. Script de Inicio Mejorado (`start-openclaw.sh`)

**Mejoras:**
- ✅ Validación de formato de token de Telegram antes de iniciar
- ✅ Logging detallado de cada paso del proceso
- ✅ Supervisor automático con reintentos (máximo 5 intentos)
- ✅ Delay de 10 segundos entre reintentos fallidos
- ✅ Health check para verificar si el gateway está ya corriendo
- ✅ Manejo mejorado de errors con mensajes claros

**Ubicación:** `/workspaces/moltworker/start-openclaw.sh`

**Ejemplo de log mejorado:**
```
[2026-02-08 14:30:15] INFO: === OpenClaw Startup ===
[2026-02-08 14:30:15] INFO: Gateway startup attempt 1/5...
[2026-02-08 14:30:15] INFO: Telegram configured with dmPolicy: pairing
[2026-02-08 14:30:18] INFO: Gateway is ready!
```

### 2. Supervisor de Procesos (`process.ts`)

**Mejoras:**
- ✅ Nueva función `isGatewayHealthy()` que verifica respuesta del gateway
- ✅ Health checks adicionales después del inicio (5 intentos, 2 segundos entre intentos)
- ✅ Detección mejorada de procesos atascados
- ✅ Killing y reinicio automático de procesos no responsivos
- ✅ Logging mejorado con prefijo `[Gateway]` para claridad

**Ubicación:** `/workspaces/moltworker/src/gateway/process.ts`

**Cambios clave:**
```typescript
// Nuevo health check después del startup
let isHealthy = await isGatewayHealthy(sandbox);
if (!isHealthy) {
  console.log('[Gateway] Process exists but not responsive, restarting...');
  await existingProcess.kill();
}
```

### 3. Sincronización R2 Mejorada (`sync.ts`)

**Mejoras:**
- ✅ Sincronización explícita de carpeta de memoria (`/root/clawd/memory/`)
- ✅ Exclusión de archivos temporales y locks para evitar conflictos
- ✅ Verificación de integridad después de sync (con ls para confirmar)
- ✅ Mensajes informativos sobre qué se sincronizó
- ✅ Logging detallado de errores de sincronización

**Ubicación:** `/workspaces/moltworker/src/gateway/sync.ts`

**Cambios clave:**
```bash
# Ahora incluye explícitamente /root/clawd/memory en la sincronización
rsync -r --no-times --delete --exclude='*.lock' \
  /root/clawd/ ${R2_MOUNT_PATH}/workspace/
```

### 4. Endpoint de Health Check (`debug.ts`)

**Nuevo Endpoint:** `GET /debug/health`

Proporciona información completa sobre:
- Estado del gateway (running, responsive)
- Configuración de Telegram (enabled, has_token, dm_policy)
- Estado de la memoria (has_data, files, identity_file)
- Procesos activos en el contenedor

**Ejemplo de respuesta:**
```json
{
  "healthy": true,
  "health": {
    "timestamp": "2026-02-08T14:30:00Z",
    "gateway": {
      "status": "running",
      "responsive": true,
      "http_status": 200
    },
    "telegram": {
      "enabled": true,
      "status": "configured",
      "has_token": true,
      "dm_policy": "pairing"
    },
    "memory": {
      "status": "has_data",
      "files": 15,
      "identity_file": "present"
    }
  }
}
```

## Cómo Funciona Ahora

### Flujo de Inicio

1. **Validación Pre-inicio**
   - Verifica token de Telegram (formato `NUMEROS:ALFANUMÉRICOS`)
   - Comprueba si el gateway ya está corriendo

2. **Restauración de Datos**
   - Restaura configuración desde R2 si es más reciente
   - Restaura memoria/workspace desde R2
   - Restaura skills desde R2

3. **Configuración**
   - Parcheha openclaw.json con token de Telegram validado
   - Configura gateway auth, proxy settings, etc.

4. **Inicio con Supervisor**
   - Intenta iniciar el gateway (máximo 5 veces)
   - Si falla, espera 10 segundos y reintenta
   - Verifica health (respuesta HTTP) después de cada inicio

5. **Sincronización Automática**
   - Cada 5 minutos, sincroniza todos los datos a R2
   - Incluye: configuración, memoria, identidad, skills, assets

### Persistencia de Memoria

```
┌─────────────────────────────────────┐
│  Contenedor (epímero)               │
├─────────────────────────────────────┤
│ /root/clawd/                        │
│  ├── IDENTITY.md      ─────────┐   │
│  ├── MEMORY.md                  │   │
│  ├── memory/          ──────────┼──→ R2 Bucket
│  │   └── [archivos]             │   │ (persistente)
│  ├── assets/          ──────────┤   │
│  └── skills/                    │   │
│                                  │   │
│ Sincronización automática        │   │
│ cada 5 minutos (cron) ───────────┘   │
└─────────────────────────────────────┘
```

## Comandos Útiles para Diagnóstico

### Verificar Salud del Bot
```bash
curl https://tudominio.com/debug/health | jq
```

### Ver Logs del Gateway
```bash
curl https://tudominio.com/debug/logs
```

### Ver Procesos Activos
```bash
curl https://tudominio.com/debug/processes?logs=true
```

### Sincronizar Manualmente
```bash
curl -X POST https://tudominio.com/api/admin/storage/sync
```

### Ejecutar Script de Diagnóstico
```bash
./scripts/diagnose-telegram.sh
```

## Archivos Nuevos

1. **TELEGRAM_SETUP.md**
   - Guía completa de configuración de Telegram
   - Instrucciones para obtener token de BotFather
   - Solución de problemas comunes
   - Mejores prácticas

2. **scripts/diagnose-telegram.sh**
   - Script de diagnóstico automático
   - Verifica todas las configuraciones
   - Proporciona recomendaciones actionables

## Mejoras Futuras Posibles

1. Endpoint `/api/admin/restart-gateway` para reinicio forzado
2. Alertas automáticas si el bot se cae
3. Dashboard en tiempo real con métricas
4. Respaldos automáticos a Telegram/Discord
5. Multi-lenguaje para mensajes de error

## Variables de Entorno Relacionadas

```bash
# Token de Telegram (REQUERIDO)
TELEGRAM_BOT_TOKEN=123456789:ABCDefGhIjKlMnOpqRsTuVwXyZ

# Política de DM (OPCIONAL, default: pairing)
TELEGRAM_DM_POLICY=pairing  # o 'open'

# IDs de usuario permitidos (OPCIONAL)
TELEGRAM_DM_ALLOW_FROM=12345,67890

# R2 Storage (para persistencia automática)
R2_ACCESS_KEY_ID=xxxxx
R2_SECRET_ACCESS_KEY=xxxxx
CF_ACCOUNT_ID=xxxxx
```

## Monitoreo Recomendado

Para asegurar que el bot permanezca siempre activo:

1. **Daily**: Revisa `/debug/health` para alertas
2. **Weekly**: Ejecuta `./scripts/diagnose-telegram.sh`
3. **Monthly**: Verifica logs en Cloudflare Dashboard
4. **Always**: Sincronización automática cada 5 minutos

## Soporte

Si el bot se queda atascado después de estos cambios:

1. Revisa `/debug/logs` para el mensaje de error específico
2. Ejecuta `./scripts/diagnose-telegram.sh`
3. Verifica TELEGRAM_BOT_TOKEN es válido (con BotFather `/start`)
4. Asegúrate de que AI provider (Anthropic) está configurado
5. Comprueba conectividad a internet desde el servidor
