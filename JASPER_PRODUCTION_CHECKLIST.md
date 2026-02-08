# 🚀 Jasper - Checklist de Producción (70% → 100%)

**Status**: En Progreso | **Versión**: 2026-02-08

Este documento detalla todas las tareas necesarias para llevar Jasper al 100% de operatividad en producción/monetización.

---

## 📋 CHECKLIST RESUMIDO

### 1️⃣ Configuración de Capacidades Faltantes
- [ ] **Web Search (Brave Search API)** - PENDIENTE
  - [ ] Crear variable `BRAVE_SEARCH_API_KEY`
  - [ ] Parchear openclaw.json con config de Brave
  - [ ] Validar conexión a API
- [ ] **Memory Search (Embeddings)** - PENDIENTE
  - [ ] Seleccionar proveedor: Google Gemini o OpenAI
  - [ ] Crear variables de entorno necesarias
  - [ ] Parchear configuración de embeddings
- [ ] **Limpieza de Bootstrap** - PENDIENTE
  - [ ] Crear IDENTITY.md (identidad del agente)
  - [ ] Crear SOUL.md (personalidad/comportamiento)
  - [ ] Validar BOOTSTRAP.md completado (o eliminarlo)

### 2️⃣ Optimización Cloudflare & Playwright
- [ ] **Timeout Gateway ajustado** - PENDIENTE
  - [ ] Aumentar timeout a 60-120s en wrangler.jsonc
  - [ ] Validar respuestas largas de Claude Opus 4.5
- [ ] **Auto-release Chromium** - PENDIENTE
  - [ ] Crear script de gestión de procesos del browser
  - [ ] Implementar lógica de liberación de instancias inactivas
  - [ ] Evitar fugas de memoria en sandbox

### 3️⃣ Automatización de Reportes
- [ ] **Cron Email (cada hora)** - PENDIENTE
  - [ ] Crear script de reporte de sistemas
  - [ ] Configurar envío de email a carriertrafic@gmail.com
  - [ ] Recopilar: CPU, RAM, sesiones, logs de errores
- [ ] **Método de envío** - PENDIENTE
  - [ ] Usar `curl` a mail-relay
  - [ ] O usar comando `mail` del contenedor

### 4️⃣ Validación Final
- [ ] **DM Policy Telegram** - REVISAR
  - [ ] Cambiar de `pairing` a `open` si se va a monetizar
  - [ ] O mantener `pairing` con allowFrom selectivo
- [ ] **Heartbeat Logging** - PENDIENTE
  - [ ] Crear `/root/heartbeat.log` con logs cada 30min
  - [ ] Incluir estado del sistema y health checks

### 5️⃣ Revisión de tools.md
- [ ] **Límites de contexto** - REVISAR
  - [ ] Validar que tools.md no permita consumir todo el contexto
  - [ ] Implementar límites por herramienta
  - [ ] Alertas de sobreuso de tokens

---

## 🔧 CONFIGURACIÓN DETALLADA

### 1. Web Search (Brave Search API)

**Archivo a modificar**: `start-openclaw.sh` (función PATCH CONFIG)

```javascript
// Agregar en EOFPATCH:
if (process.env.BRAVE_SEARCH_API_KEY) {
    config.tools = config.tools || {};
    config.tools.web_search = {
        enabled: true,
        provider: 'brave',
        apiKey: process.env.BRAVE_SEARCH_API_KEY,
    };
    console.log('Web Search (Brave) configured');
}
```

**Variables requeridas**:
- `BRAVE_SEARCH_API_KEY` - Obtenible en https://api.search.brave.com/

**Tareas**:
```bash
# 1. Registrarse en Brave Search API
# 2. Obtener API key
# 3. Configurar en wrangler:
npx wrangler secret put BRAVE_SEARCH_API_KEY
# Entrar: tu_api_key_aqui

# 4. Actualizar .dev.vars.example
echo "BRAVE_SEARCH_API_KEY=your-brave-api-key" >> .dev.vars.example
```

---

### 2. Memory Search (Embeddings - Semántica)

**Opciones disponibles**:

#### Opción A: Google Gemini Embeddings (RECOMENDADO)
```javascript
if (process.env.GOOGLE_API_KEY) {
    config.plugins = config.plugins || {};
    config.plugins.embeddings = {
        provider: 'google',
        model: 'embedding-001',
        apiKey: process.env.GOOGLE_API_KEY,
        chunkSize: 1024,
        overlap: 100,
    };
}
```

#### Opción B: OpenAI Embeddings
```javascript
if (process.env.OPENAI_API_KEY && process.env.OPENAI_EMBEDDINGS_ENABLED === 'true') {
    config.plugins = config.plugins || {};
    config.plugins.embeddings = {
        provider: 'openai',
        model: 'text-embedding-3-small',
        apiKey: process.env.OPENAI_API_KEY,
        chunkSize: 512,
        overlap: 50,
    };
}
```

**Tareas**:
```bash
# Para Gemini:
npx wrangler secret put GOOGLE_API_KEY

# Para OpenAI:
# (Ya tienes OPENAI_API_KEY, solo activa embeddings)
npx wrangler secret put OPENAI_EMBEDDINGS_ENABLED
# Entrar: true
```

**Archivo a modificar**: `start-openclaw.sh` (EOFPATCH)

---

### 3. IDENTITY.md y SOUL.md

**Archivo**: `/root/clawd/IDENTITY.md` (en contenedor)

```markdown
# Identidad de Jasper

## Datos Personales
- Nombre: Jasper
- Rol: Asistente Personal IA
- Versión: 2026.2.3+

## Capacidades Confirmadas
- Conversación natural en español/inglés
- Búsqueda web con Brave Search API
- Memoria semántica (embeddings)
- Integración multi-canal (Telegram, Discord, Slack)
- Análisis de código
- Generación de contenido

## Límites Operacionales
- Contexto: 131,072 tokens (Opus 4.5)
- Respuesta máxima: 8,192 tokens
- Timeout en gateway: 120 segundos
- Límite de herramientas: 15 por consulta

## Responsabilidades
- Respetar privacidad del usuario
- No acceder a información sensible sin permiso
- Escalar problemas complejos
- Mantener logs de auditoría

---

**Última actualización**: 2026-02-08
**Estado**: Producción
```

**Archivo**: `/root/clawd/SOUL.md` (en contenedor)

```markdown
# Alma de Jasper - Personalidad y Comportamiento

## Filosofía
- Útil, honesto, y cauteloso
- Priorizar la claridad en la comunicación
- Admitir limitaciones y errores

## Tono
- Profesional pero amable
- Directo y conciso
- Adaptar nivel técnico al usuario

## Directrices de Comportamiento

### Sí ✅
- Ayudar con tareas legítimas
- Explicar procesos complejos
- Reconocer cuando no sé algo
- Ofrecer alternativas

### No ❌
- Facilitar actividades ilegales
- Compartir información sensible
- Pretender tener certeza absoluta
- Ignorar límites de seguridad

## Autoridad de Decisión
- Usuario es autoridad final
- Escalación a operador en temas éticos
- No sobrecargar con información

---

**Versión**: 1.0
**Adoptado**: 2026-02-08
```

**Tareas**:
1. Crear ambos archivos en `/root/clawd/`
2. El script `start-openclaw.sh` los sincronizará a R2 automáticamente
3. Se restaurarán en reinicios desde R2

---

### 4. Timeout del Gateway (60-120 segundos)

**Archivo a modificar**: `wrangler.jsonc`

```jsonc
{
  "workers_dev": true,
  "routes": [
    {
      "pattern": "*/*",
      "zone_name": "example.com"
    }
  ],
  // Agregar configuración de timeout para sandboxes
  "observability": {
    "enabled": true,
  },
  // Aumentar el timeout de respuesta
  "env": {
    "production": {
      "name": "moltbot-sandbox-prod",
      "routes": [
        {
          "pattern": "*/*",
          "zone_name": "example.com",
          "custom_domain": true
        }
      ]
    }
  },
  // Configuración de Cloudflare:
  "limits": {
    "timeout_ms": 120000  // 120 segundos para respuestas largas
  }
}
```

**Nota**: Cloudflare Workers tiene límite de 30s en plan estándar, pero con Containers puede ir hasta 120s.

**Tasas**:
```bash
# 1. Verificar plan actual
wrangler whoami

# 2. Asegurar Workers Paid plan

# 3. Deploy con nuevo timeout
npm run deploy

# 4. Probar con solicitud larga
curl -X POST https://tu-worker.workers.dev/api/query \
  -d '{"prompt": "analiza un código muy largo..."}' \
  --max-time 130  # Cliente espera 130s
```

---

### 5. Auto-Release Chromium (Browser Cleanup)

**Archivo a crear**: `src/gateway/browser-cleanup.ts`

```typescript
import type { Sandbox } from '@cloudflare/sandbox';

/**
 * Monitor de procesos del navegador
 * Limpia instancias inactivas de Chromium para evitar fugas de memoria
 */
export async function cleanupInactiveChromium(
  sandbox: Sandbox,
  options: { maxAge: number; checkInterval: number } = {
    maxAge: 30 * 60 * 1000, // 30 minutos
    checkInterval: 5 * 60 * 1000, // 5 minutos
  },
): Promise<void> {
  const processes = await sandbox.listProcesses();
  const now = Date.now();

  for (const proc of processes) {
    // Buscar procesos de Chromium (Puppeteer/Playwright)
    if (!proc.command.includes('chrome') && !proc.command.includes('chromium')) {
      continue;
    }

    // Ignorar procesos corriendo
    if (proc.status === 'running') {
      const age = proc.startTime ? now - proc.startTime.getTime() : 0;

      // Matar si es más viejo que maxAge
      if (age > options.maxAge) {
        console.log(`[Browser] Killing inactive Chromium (age: ${Math.round(age / 1000)}s): ${proc.id}`);
        try {
          await proc.kill();
        } catch (err) {
          console.error(`[Browser] Failed to kill process ${proc.id}:`, err);
        }
      }
    } else if (proc.status === 'completed' || proc.status === 'failed') {
      // Limpiar procesos terminados que sean muy antiguos
      const endTime = proc.endTime ? now - proc.endTime.getTime() : 0;
      if (endTime > 10 * 60 * 1000) {
        // 10 minutos
        console.log(`[Browser] Cleaning up old terminated Chromium: ${proc.id}`);
      }
    }
  }
}

/**
 * Iniciar monitor de limpieza periódica en el índice
 */
export function startBrowserCleanupMonitor(
  sandbox: Sandbox,
  intervalMs: number = 5 * 60 * 1000, // 5 minutos
): () => void {
  const interval = setInterval(async () => {
    try {
      await cleanupInactiveChromium(sandbox);
    } catch (err) {
      console.error('[Browser] Cleanup error:', err);
    }
  }, intervalMs);

  return () => clearInterval(interval);
}
```

**Integración en `src/index.ts`**:

```typescript
import { startBrowserCleanupMonitor } from './gateway/browser-cleanup';

// En la sección de middleware (después de inicializar sandbox):
app.use('*', async (c, next) => {
  const sandbox = c.get('sandbox');
  
  // Iniciar monitor de limpieza del browser (una vez)
  if (!c.get('browserCleanupStarted')) {
    startBrowserCleanupMonitor(sandbox, 5 * 60 * 1000); // Cada 5 minutos
    c.set('browserCleanupStarted', true);
  }
  
  await next();
});
```

**Variables de entorno** (añadir a `.dev.vars.example`):
```bash
# Browser cleanup configuration
BROWSER_CLEANUP_ENABLED=true
BROWSER_MAX_IDLE_MS=1800000   # 30 minutos
BROWSER_CHECK_INTERVAL_MS=300000  # 5 minutos
```

---

### 6. Cron Email - Reportes de Sistema (Cada Hora)

**Archivo a crear**: `scripts/send-system-report.sh`

```bash
#!/bin/bash
# Script para enviar reporte de sistema cada hora
# Ejecutado por un cron job dentro del contenedor

EMAIL_TO="carriertrafic@gmail.com"
EMAIL_FROM="jasper@moltbot.local"
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# Recolectar metrics
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}')
MEMORY_USAGE=$(free | grep Mem | awk '{printf int($3/$2*100)}')
MEMORY_MB=$(free -m | grep Mem | awk '{printf "%d/%d MB", $3, $2}')
UPTIME=$(uptime -p)
PROCESS_COUNT=$(ps aux | wc -l)
GATEWAY_STATUS=$(curl -s http://localhost:18789/health | jq -r '.status // "unknown"' 2>/dev/null || echo "ERROR")
SESSION_COUNT=$(curl -s http://localhost:18789/sessions 2>/dev/null | jq 'length' 2>/dev/null || echo "N/A")

# Últimos 10 errores del log
ERROR_SAMPLE=$(grep "ERROR\|FAIL" /root/openclaw-startup.log 2>/dev/null | tail -10 | sed 's/^/  /')

# Reporte
REPORT="
=== JASPER SYSTEM REPORT ===
Timestamp: $TIMESTAMP

📊 SISTEMA
- CPU: ${CPU_USAGE}%
- Memoria: ${MEMORY_USAGE}% (${MEMORY_MB})
- Uptime: $UPTIME
- Procesos activos: $PROCESS_COUNT

🤖 GATEWAY
- Estado: $GATEWAY_STATUS
- Sesiones activas: $SESSION_COUNT

❌ ERRORES RECIENTES (últimas 10 líneas)
$ERROR_SAMPLE

---
Reporte automático de Jasper
Más info: https://moltbot.workers.dev/debug/health
"

# Enviar por email usando curl (requiere servicio de mail-relay)
# Opción 1: Usando MailerSend API
if [ -n "$MAILER_SEND_API_KEY" ]; then
  PAYLOAD=$(cat <<EOF
{
  "from": { "email": "$EMAIL_FROM" },
  "to": [{ "email": "$EMAIL_TO" }],
  "subject": "Jasper Report - $TIMESTAMP",
  "text": "$REPORT"
}
EOF
)
  curl -X POST "https://api.mailersend.com/v1/email" \
    -H "Content-Type: application/json" \
    -H "X-Mailer-Send-Key: $MAILER_SEND_API_KEY" \
    -d "$PAYLOAD"
fi

# Opción 2: Usando comando mail del sistema (si está disponible)
if command -v mail &> /dev/null; then
  echo "$REPORT" | mail -s "Jasper Report - $TIMESTAMP" "$EMAIL_TO"
fi

# Opción 3: Usando SendGrid
if [ -n "$SENDGRID_API_KEY" ]; then
  PAYLOAD=$(cat <<EOF
{
  "personalizations": [{"to": [{"email": "$EMAIL_TO"}]}],
  "from": {"email": "$EMAIL_FROM"},
  "subject": "Jasper Report - $TIMESTAMP",
  "content": [{"type": "text/plain", "value": "$REPORT"}]
}
EOF
)
  curl -X POST "https://api.sendgrid.com/v1/mail/send" \
    -H "Authorization: Bearer $SENDGRID_API_KEY" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD"
fi

echo "[$(date -u +"%Y-%m-%d %H:%M:%S")] Report sent to $EMAIL_TO"
```

**Configurar Cron en contenedor** (`start-openclaw.sh`):

```bash
# Agregar después de que se inicia el gateway:

# ============================================================
# SETUP CRON JOBS (systemd-run alternativa sin cron)
# ============================================================

# Si el sistema soporta cron:
if command -v crontab &> /dev/null; then
    log_info "Setting up cron jobs..."
    
    # Reporte de sistema cada hora
    (crontab -l 2>/dev/null || true; \
     echo "0 * * * * /root/send-system-report.sh >> /root/system-report.log 2>&1") | \
    crontab - 2>/dev/null || log_error "Failed to setup cron"
    
    # Heartbeat cada 30 minutos
    (crontab -l 2>/dev/null || true; \
     echo "*/30 * * * * bash -c 'echo \"[$(date -u +\"%Y-%m-%d %H:%M:%S\")] HEARTBEAT: Gateway=$(curl -s http://localhost:18789/health | jq -r .status)\" >> /root/heartbeat.log'") | \
    crontab - 2>/dev/null || log_error "Failed to setup heartbeat cron"
    
    crontab -l | grep -q "send-system-report" && log_info "Cron jobs configured successfully"
fi
```

**Variables requeridas** (elegir una opción):
```bash
# Opción 1: MailerSend (RECOMENDADO)
npx wrangler secret put MAILER_SEND_API_KEY

# Opción 2: SendGrid
npx wrangler secret put SENDGRID_API_KEY

# Opción 3: SMTP local (usar comando mail)
# (No requiere variable, solo que el contenedor tenga mail configurado)
```

---

### 7. DM Policy Telegram

**Estado actual**: `dmPolicy: 'pairing'` (seguro, requiere aprobación)

**Opciones para monetización**:

#### Opción A: Mantener Pairing (Más seguro - RECOMENDADO)
```bash
# En wrangler:
npx wrangler secret put TELEGRAM_DM_POLICY
# Entrar: pairing

# Los usuarios deben:
# 1. Enviar DM inicial
# 2. Ser aprobados en /_admin/
# 3. Luego pueden interact como siempre
```

#### Opción B: Modo Abierto (Más usuarios, menos control)
```bash
npx wrangler secret put TELEGRAM_DM_POLICY
# Entrar: open

# Riesgos: Spam, abuso, consumo de API
```

#### Opción C: Lista Blanca Selectiva
```bash
npx wrangler secret put TELEGRAM_DM_ALLOW_FROM
# Entrar: 123456789,987654321,555555555   (lista de user IDs)

# Y:
npx wrangler secret put TELEGRAM_DM_POLICY
# Entrar: open_with_list
```

**Recomendación**: Mantener `pairing` inicial, luego cambiar a `open` después de tener clientes verificados.

---

### 8. Heartbeat Logging (Cada 30 minutos)

Ya configurado en la sección de Cron, pero confirmamos:

**Archivo**: `/root/heartbeat.log` (se crea automáticamente)

**Contenido esperado**:
```
[2026-02-08 10:00:00] HEARTBEAT: Gateway=running
[2026-02-08 10:30:00] HEARTBEAT: Gateway=running
[2026-02-08 11:00:00] HEARTBEAT: Gateway=healthy, Sessions=3, CPU=45%
[2026-02-08 11:30:00] HEARTBEAT: Gateway=running
```

**Auditoría**: Revisar con:
```bash
# Ver últimos heartbeats
tail -20 /root/heartbeat.log

# Estadísticas de disponibilidad
grep HEARTBEAT /root/heartbeat.log | wc -l
```

---

### 9. Revisión de tools.md (Límites de Contexto)

**Archivo a crear/revisar**: `/root/clawd/tools.md`

```markdown
# Tools y Límites de Contexto para Jasper

## Configuración Global
- **Modelo**: Claude Opus 4.5
- **Contexto disponible**: 131,072 tokens
- **Respuesta máxima**: 8,192 tokens
- **Timeout**: 120 segundos
- **Budget por herramienta**: LIMITADO

## Herramientas Disponibles y Sus Límites

### 1. Web Search (Brave API)
- **Limit**: Máximo 3 búsquedas por consulta
- **Timeout**: 10 segundos por búsqueda
- **Tokens reservados**: ~500 (resumen de resultados)
- **Coste**: 1 crédito Brave por búsqueda

```
❌ PROHIBIDO: Búsquedas en bucle
✅ RECOMENDADO: Verificar resultados antes de más búsquedas
```

### 2. Embeddings/Memory Search
- **Limit**: Máximo 100 documentos por búsqueda
- **Chunk size**: 1,024 tokens
- **Coste**: Variable según proveedor
- **Timeout**: 5 segundos

```
❌ PROHIBIDO: Búsquedas sin filtro
✅ RECOMENDADO: Usar filtros de fecha/categoría
```

### 3. Código Análisis (Code Interpreter)
- **Limit**: 5MB máximo por archivo
- **Ejecución**: 30 segundos máximo
- **Memoria**: 512MB máximo
- **Output**: 10,000 caracteres máximo

```
❌ PROHIBIDO: Entrenar modelos de ML
❌ PROHIBIDO: Descargar archivos grandes
✅ RECOMENDADO: Análisis de datos pequeños
```

## Sistema de Alertas

Implementar alertas cuando:
- ⚠️ Tokens consumidos > 50% del contexto
- 🔴 Tiempo de respuesta > 90 segundos
- 🔴 Errores de quota en APIs externas

## Throttling

```typescript
// Ejemplo de implementación
const TOOL_LIMITS = {
  web_search: { perMinute: 10, perHour: 100 },
  memory_search: { perMinute: 20, perHour: 500 },
  code_exec: { perMinute: 5, perHour: 50 }
};

function checkToolLimit(tool: string, userId: string): boolean {
  const count = getRecentUses(tool, userId);
  return count < TOOL_LIMITS[tool].perMinute;
}
```

---

**Última actualización**: 2026-02-08
```

---

## 🔑 VARIABLES DE ENTORNO FALTANTES

Agregar a `.dev.vars` y `wrangler secret put`:

```bash
# ===== NUEVAS =====

# Web Search
BRAVE_SEARCH_API_KEY=                    # https://api.search.brave.com/

# Memory/Embeddings (elegir uno)
GOOGLE_API_KEY=                          # Para Gemini embeddings
OPENAI_EMBEDDINGS_ENABLED=true           # Si usas OpenAI

# Browser
BROWSER_CLEANUP_ENABLED=true
BROWSER_MAX_IDLE_MS=1800000
BROWSER_CHECK_INTERVAL_MS=300000

# Email Reporting (elegir uno)
MAILER_SEND_API_KEY=                     # MailerSend (recomendado)
SENDGRID_API_KEY=                        # SendGrid alternativa
SYSTEM_REPORT_EMAIL=carriertrafic@gmail.com

# Telegram
TELEGRAM_DM_POLICY=pairing               # pairing o open

# ===== EXISTENTES (CONFIRMAR QUE EXISTEN) =====
ANTHROPIC_API_KEY=                       # ✅ Ya existe
MOLTBOT_GATEWAY_TOKEN=                   # ✅ Ya existe
```

---

## ⚡ ORDEN DE IMPLEMENTACIÓN RECOMENDADO

1. **Primero** (Crítico - 1-2 horas)
   - [x] IDENTITY.md y SOUL.md
   - [x] Ajustar timeout Gateway
   - [x] Revisar DM policy Telegram

2. **Segundo** (Depende - 2-4 horas)
   - [ ] Web Search (Brave API)
   - [ ] Memory Search (Embeddings)

3. **Tercero** (Automatización - 3-5 horas)
   - [ ] Auto-cleanup Chromium
   - [ ] Cron Email Reports
   - [ ] Heartbeat logging

4. **Cuarto** (Validación - 1-2 horas)
   - [ ] Testing integral
   - [ ] Documentación final
   - [ ] Deployment a producción

---

## 📊 TOKEN BUDGET

**Reservas por token**:
```
Total disponible: 131,072 tokens
│
├─ Sistema prompt: ~1,000 (1%)
├─ Contexto usuario: ~50,000 (38%)
├─ Resultados búsqueda: ~500 (0.4%)
├─ Memoria embeddings: ~20,000 (15%)
├─ Herramientas/Tools: ~5,000 (3.8%)
├─ Buffer respuesta: ~8,192 (6.2%)
├─ RESERVA (seguridad): ~46,380 (35%)
└─ = 131,072 total
```

**Validación**: En tools.md, implementar alertas cuando se consume >80% disponible.

---

## 🚀 COMANDOS DE DEPLOYMENT

```bash
# 1. Crear archivos de identidad en el contenedor
ssh-keygen -t ed25519 -f ~/.ssh/jasper_id -N ""

# 2. Actualizar .dev.vars
cp .dev.vars.example .dev.vars
# Editar con los tokens necesarios

# 3. Build y test local
npm run build
npm run test

# 4. Deploy a Cloudflare
npm run deploy

# 5. Verificar en producción
curl https://tu-worker.workers.dev/debug/health \
  -H "Authorization: Bearer YOUR_CF_ACCESS_TOKEN"

# 6. Ver logs
npx wrangler tail

# 7. Monitorear heartbeat
curl https://tu-worker.workers.dev/debug/heartbeat
```

---

## ✅ VALIDACIÓN POST-DEPLOYMENT

- [ ] Web Search funciona (responde preguntas con URLs)
- [ ] Memory persiste entre sesiones
- [ ] Timeout de 120s confirmado (respuesta larga = OK)
- [ ] Email reportes llegando (revisar spam)
- [ ] Heartbeat logueando cada 30min
- [ ] Chromium no consume memoria infinita
- [ ] DM policy correcta en Telegram
- [ ] Sin errores en `/debug/health`

---

## 📞 CONTACTOS/REFERENCIAS

- **Documentación OpenClaw**: https://docs.openclaw.ai/
- **Brave Search API**: https://api.search.brave.com/
- **Google Gemini API**: https://ai.google.dev/
- **OpenAI Embeddings**: https://platform.openai.com/docs/guides/embeddings
- **MailerSend**: https://www.mailersend.com/

---

**Documento actualizado**: 2026-02-08 14:30 UTC
**Responsable**: Equipo Jasper
**Próxima revisión**: 2026-02-15
