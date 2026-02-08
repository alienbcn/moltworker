#!/bin/bash
# Sistema de Reportes Automáticos para Jasper
# Envía reporte de salud del sistema cada hora a carriertrafic@gmail.com
# Recolecta: CPU, memoria, sesiones activas, y últimos errores

set -e

LOG_FILE="/root/system-report.log"
HEARTBEAT_FILE="/root/heartbeat.log"
STARTUP_LOG="/root/openclaw-startup.log"

EMAIL_TO="${SYSTEM_REPORT_EMAIL:-carriertrafic@gmail.com}"
EMAIL_FROM="jasper@openclaw.local"
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")
TIMESTAMP_FILE=$(date -u +"%Y%m%d_%H%M%S")

# Crear directorio de logs si no existe
mkdir -p "$(dirname "$LOG_FILE")"

# ============================================================
# RECOLECTAR MÉTRICAS DEL SISTEMA
# ============================================================

# CPU y Memoria
CPU_USAGE=$(top -bn1 | grep "Cpu(s)" | awk '{print 100 - $8}' | sed 's/,.*//' || echo "N/A")
MEMORY_FREE=$(free -h | grep Mem | awk '{print $3 " / " $2}')
MEMORY_PERCENT=$(free | grep Mem | awk '{printf "%.0f", $3/$2*100}' || echo "N/A")
SWAP_USAGE=$(free -h | grep Swap | awk '{print $3 " / " $2}')

# Uptime y procesos
UPTIME=$(uptime -p 2>/dev/null || uptime | sed 's/.*up //;s/,.*//')
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}')
PROCESS_COUNT=$(ps aux | wc -l)
TCP_CONNECTIONS=$(netstat -an 2>/dev/null | grep ESTABLISHED | wc -l || echo "N/A")

# Estado del gateway
GATEWAY_RESPONSE=$(curl -s -m 5 http://localhost:18789/health 2>/dev/null || echo '{}')
GATEWAY_STATUS=$(echo "$GATEWAY_RESPONSE" | jq -r '.healthy // .status // "unknown"' 2>/dev/null || echo "ERROR")
GATEWAY_HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 http://localhost:18789/health 2>/dev/null || echo "000")

# Sesiones activas (si hay endpoint)
SESSION_COUNT=$(echo "$GATEWAY_RESPONSE" | jq -r '.sessions // "N/A"' 2>/dev/null || echo "N/A")

# Últimas líneas de log
ERROR_COUNT=$(grep -c "ERROR\|FAIL" "$STARTUP_LOG" 2>/dev/null || echo "0")
ERROR_SAMPLE=$(grep "ERROR\|FAIL" "$STARTUP_LOG" 2>/dev/null | tail -5 | sed 's/^/    /' || echo "    (ninguno)")

# Número de heartbeats en las últimas 24 horas
HEARTBEAT_24H=$(grep HEARTBEAT "$HEARTBEAT_FILE" 2>/dev/null | grep "$(date -u -d '1 day ago' +%Y-%m-%d)" | wc -l || echo "0")

# Disponibilidad (porcentaje aproximado)
if [ "$HEARTBEAT_24H" -gt 0 ]; then
  AVAILABILITY=$(( (HEARTBEAT_24H * 30) / 1440 * 100 ))
else
  AVAILABILITY="N/A"
fi

# ============================================================
# CONSTRUIR REPORTE
# ============================================================

REPORT="
╔════════════════════════════════════════════════════════════╗
║          REPORTE DE SALUD DEL SISTEMA - JASPER            ║
╚════════════════════════════════════════════════════════════╝

📅 FECHA/HORA: $TIMESTAMP
🆔 IDENTIFICADOR: $TIMESTAMP_FILE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 RECURSOS DEL SISTEMA
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CPU (uso actual):         $CPU_USAGE%
Memoria física:           $MEMORY_FREE ($MEMORY_PERCENT%)
Memoria de intercambio:   $SWAP_USAGE
Carga promedio:          $LOAD_AVG
Procesos activos:        $PROCESS_COUNT
Conexiones TCP:          $TCP_CONNECTIONS

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🤖 ESTADO DEL GATEWAY
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Status:                   $GATEWAY_STATUS (HTTP: $GATEWAY_HTTP_CODE)
Sesiones activas:        $SESSION_COUNT
Uptime del contenedor:   $UPTIME

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📈 DISPONIBILIDAD (últimas 24h)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Heartbeats registrados:  $HEARTBEAT_24H
Disponibilidad estimada: $AVAILABILITY%

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
⚠️  ERRORES E INCIDENTES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Total de errores (histórico): $ERROR_COUNT
Últimos 5 errores:
$ERROR_SAMPLE

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📌 ACCIONES RECOMENDADAS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

$(if [ "$GATEWAY_STATUS" != "running" ] && [ "$GATEWAY_STATUS" != "healthy" ]; then echo "🔴 CRÍTICO: Gateway no está operativo. Revisar logs."; fi)
$(if [ "${MEMORY_PERCENT%.*}" -gt 80 ]; then echo "🟡 ADVERTENCIA: Uso de memoria >80%. Considerar reinicio."; fi)
$(if [ "${CPU_USAGE%.*}" -gt 80 ]; then echo "🟡 ADVERTENCIA: CPU >80%. Posible sobrecarga."; fi)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Reportes anteriores: https://moltbot.workers.dev/?tab=reports
Dashboard en vivo: https://moltbot.workers.dev/debug/health
Soporte: carriertrafic@gmail.com

🤖 Reporte automático generado por Jasper OpenClaw Gateway
"

# ============================================================
# GUARDAR REPORTE LOCALMENTE
# ============================================================

echo "$REPORT" >> "$LOG_FILE"

# ============================================================
# ENVIAR POR EMAIL VÍA MAILERSEND
# ============================================================

if [ -z "$MAILER_SEND_API_KEY" ]; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ⚠️ MAILER_SEND_API_KEY no configurada. Reporte guardado en $LOG_FILE"
    echo "$REPORT" >> "$LOG_FILE"
    exit 0
fi

# Enviar vía MailerSend
REPORT_HTML=$(cat <<'EOFHTML'
<html><head><meta charset="UTF-8"><style>
  body { font-family: monospace; background: #f5f5f5; color: #333; }
  .container { max-width: 800px; margin: 0 auto; background: white; padding: 20px; }
  pre { background: #f9f9f9; padding: 15px; border-radius: 5px; overflow-x: auto; }
  h1 { color: #2c3e50; border-bottom: 2px solid #3498db; }
</style></head><body>
  <div class="container">
    <h1>🤖 Jasper System Health Report</h1>
    <pre>REPORT_PLACEHOLDER</pre>
  </div>
</body></html>
EOFHTML
)

REPORT_HTML="${REPORT_HTML//REPORT_PLACEHOLDER/$REPORT}"

# Cuerpo JSON para MailerSend
PAYLOAD=$(cat <<EOF
{
  "from": {
    "email": "${EMAIL_FROM}",
    "name": "Jasper Health Monitor"
  },
  "to": [
    {
      "email": "${EMAIL_TO}",
      "name": "System Operator"
    }
  ],
  "subject": "Jasper Health Report - ${TIMESTAMP}",
  "html": $(echo "$REPORT_HTML" | jq -Rs .)
}
EOF
)

RESPONSE=$(curl -s -X POST "https://api.mailersend.com/v1/email" \
  -H "Content-Type: application/json" \
  -H "X-Mailersend-API-Key: $MAILER_SEND_API_KEY" \
  -d "$PAYLOAD" 2>&1)

if echo "$RESPONSE" | grep -q '"message_id"'; then
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ✅ Email enviado a $EMAIL_TO vía MailerSend" >> "$LOG_FILE"
else
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] ❌ Fallo en envío de email:" >> "$LOG_FILE"
    echo "$RESPONSE" >> "$LOG_FILE"
fi

# Log de ejecución
echo "[$(date +'%Y-%m-%d %H:%M:%S')] Reporte completado (ID: $TIMESTAMP_FILE)" >> "$LOG_FILE"
