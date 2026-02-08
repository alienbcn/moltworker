#!/bin/bash
# Telegram Bot Diagnostic Script
# Este script ayuda a diagnosticar problemas con la configuración de Telegram

set -e

echo "==============================================="
echo "Bot de Telegram - Diagnóstico"
echo "==============================================="
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_status() {
    local description="$1"
    local condition="$2"
    
    if [ "$condition" = "true" ]; then
        echo -e "${GREEN}✓${NC} $description"
    else
        echo -e "${RED}✗${NC} $description"
    fi
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Detectar el URL del worker
echo "1. Detectando configuración del worker..."
if [ -n "$WORKER_URL" ]; then
    WORKER_URL="$WORKER_URL"
    echo "   URL del worker: $WORKER_URL"
else
    # Intentar obtenerlo desde el archivo local
    if grep -q "WORKER_URL" .dev.vars 2>/dev/null; then
        WORKER_URL=$(grep "WORKER_URL" .dev.vars | cut -d'=' -f2)
        echo "   URL del worker: $WORKER_URL"
    else
        warning "No se encontró WORKER_URL. Por favor proporciona:"
        echo "   export WORKER_URL=https://tunombredelworker.workers.dev"
        exit 1
    fi
fi
echo ""

# 2. Verificar que el token de Telegram está configurado
echo "2. Verificando token de Telegram..."
if grep -q "TELEGRAM_BOT_TOKEN" .dev.vars 2>/dev/null; then
    TOKEN=$(grep "TELEGRAM_BOT_TOKEN" .dev.vars | cut -d'=' -f2)
    if [ -z "$TOKEN" ]; then
        check_status "Token de Telegram configurado" false
        warning "TELEGRAM_BOT_TOKEN está vacío"
    else
        # Validar formato del token (numeroS:LETRAS_NUMEROS)
        if [[ $TOKEN =~ ^[0-9]+:[A-Za-z0-9_-]+$ ]]; then
            check_status "Token de Telegram configurado con formato válido" true
        else
            check_status "Token de Telegram configurado" true
            warning "Formato de token podría ser inválido (esperado: NUMEROS:ALFANUMÉRICOS)"
        fi
    fi
else
    check_status "Token de Telegram configurado" false
    warning "TELEGRAM_BOT_TOKEN no encontrado en .dev.vars"
fi
echo ""

# 3. Verificar salud del gateway
echo "3. Verificando salud del gateway..."
HEALTH_RESPONSE=$(curl -s "$WORKER_URL/debug/health" 2>/dev/null || echo '{"healthy":false}')

GATEWAY_STATUS=$(echo "$HEALTH_RESPONSE" | grep -o '"gateway":{[^}]*}' | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
GATEWAY_RESPONSIVE=$(echo "$HEALTH_RESPONSE" | grep -o '"responsive":[^,}]*' | cut -d':' -f2 || echo "unknown")

if [ "$GATEWAY_STATUS" = "running" ]; then
    check_status "Gateway en ejecución" true
    if [ "$GATEWAY_RESPONSIVE" = "true" ]; then
        check_status "Gateway respondiendo a requests" true
    else
        check_status "Gateway respondiendo a requests" false
        warning "El gateway está corriendo pero no responde. Podría estar iniciando."
    fi
else
    check_status "Gateway en ejecución" false
    warning "El gateway no está corriendo. Status: $GATEWAY_STATUS"
fi
echo ""

# 4. Verificar configuración de Telegram en OpenClaw
echo "4. Verificando configuración de Telegram en OpenClaw..."
TELEGRAM_STATUS=$(echo "$HEALTH_RESPONSE" | grep -o '"telegram":{[^}]*}' | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
TELEGRAM_ENABLED=$(echo "$HEALTH_RESPONSE" | grep -o '"enabled":[^,}]*' | cut -d':' -f2)

if [ "$TELEGRAM_STATUS" = "configured" ]; then
    check_status "Telegram configurado en OpenClaw" true
    if [ "$TELEGRAM_ENABLED" = "true" ]; then
        check_status "Telegram habilitado" true
    else
        check_status "Telegram habilitado" false
        warning "Telegram está configurado pero deshabilitado"
    fi
elif [ "$TELEGRAM_STATUS" = "not_configured" ]; then
    check_status "Telegram configurado en OpenClaw" false
    warning "Telegram no está configurado. Verifica que TELEGRAM_BOT_TOKEN está en las variables secretas."
else
    check_status "Telegram configurado en OpenClaw" false
    warning "No se pudo determinar status de Telegram: $TELEGRAM_STATUS"
fi
echo ""

# 5. Verificar memoria/persistencia
echo "5. Verificando persistencia de datos..."
MEMORY_STATUS=$(echo "$HEALTH_RESPONSE" | grep -o '"memory":{[^}]*}' | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
MEMORY_FILES=$(echo "$HEALTH_RESPONSE" | grep -o '"files":[^,}]*' | cut -d':' -f2)
IDENTITY_FILE=$(echo "$HEALTH_RESPONSE" | grep -o '"identity_file":"[^"]*"' | cut -d'"' -f4)

if [ "$MEMORY_STATUS" = "has_data" ]; then
    check_status "Memoria del bot guardada" true
    echo "   Archivos: $MEMORY_FILES"
    echo "   Archivo de identidad: $IDENTITY_FILE"
elif [ "$MEMORY_STATUS" = "empty" ]; then
    check_status "Memoria del bot guardada" false
    warning "No hay datos de memoria aún. El bot conversará y guardará datos la próxima vez."
else
    check_status "Memoria del bot guardada" false
    warning "No se pudo verificar memoria: $MEMORY_STATUS"
fi
echo ""

# 6. Verificar procesos activos
echo "6. Verificando procesos activos..."
PROCESSES=$(curl -s "$WORKER_URL/debug/processes?logs=false" 2>/dev/null || echo '{"processes":[]}')
RUNNING_PROCESSES=$(echo "$PROCESSES" | grep -o '"status":"running"' | wc -l)
TOTAL_PROCESSES=$(echo "$PROCESSES" | grep -o '"status"' | wc -l)

if [ "$RUNNING_PROCESSES" -gt 0 ]; then
    check_status "Procesos en ejecución" true
    echo "   $RUNNING_PROCESSES de $TOTAL_PROCESSES procesos activos"
else
    check_status "Procesos en ejecución" false
    warning "No hay procesos en ejecución"
fi
echo ""

# 7. Resumen y recomendaciones
echo "==============================================="
echo "Resumen y Recomendaciones"
echo "==============================================="
echo ""

if [ "$GATEWAY_STATUS" = "running" ] && [ "$GATEWAY_RESPONSIVE" = "true" ] && [ "$TELEGRAM_STATUS" = "configured" ]; then
    echo -e "${GREEN}✓ El bot parece estar configurado correctamente.${NC}"
    echo ""
    echo "Próximos pasos:"
    echo "1. Envía un mensaje a tu bot en Telegram"
    echo "2. El bot debería responder con opciones de emparejamiento"
    echo "3. Sigue las instrucciones de emparejamiento"
    echo "4. Una vez emparejado, el bot responderá a tus preguntas"
else
    echo -e "${RED}✗ Se detectaron problemas.${NC}"
    echo ""
    echo "Acciones recomendadas:"
    
    if [ "$GATEWAY_STATUS" != "running" ]; then
        echo "1. El gateway no está corriendo:"
        echo "   - Verifica los logs: curl $WORKER_URL/debug/logs"
        echo "   - Asegúrate de que el servidor tiene conexión a internet"
        echo "   - Revisa si las variables de AI están configuradas (ANTHROPIC_API_KEY, etc.)"
    fi
    
    if [ "$TELEGRAM_STATUS" != "configured" ]; then
        echo "2. Telegram no está configurado:"
        echo "   - Verifica que TELEGRAM_BOT_TOKEN está en las variables secretas"
        echo "   - Usa: wrangler secret put TELEGRAM_BOT_TOKEN"
        echo "   - Pega el token obtenido de BotFather"
    fi
    
    if [ "$RUNNING_PROCESSES" -eq 0 ]; then
        echo "3. No hay procesos en ejecución:"
        echo "   - Reinicia el worker: wrangler deploy"
        echo "   - O accede a cualquier endpoint para iniciar la gateway"
    fi
fi

echo ""
echo "Para más ayuda, revisa:"
echo "- Logs detallados: curl $WORKER_URL/debug/logs?logs=true"
echo "- Salud completa: curl $WORKER_URL/debug/health | jq"
echo "- Documentación: cat TELEGRAM_SETUP.md"
