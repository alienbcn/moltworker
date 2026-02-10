#!/bin/bash
# Script de diagnóstico completo para el bot de Telegram en producción
# Este script verifica el estado del deployment, webhook, y configuración

set -e

echo "=================================================="
echo "🔍 DIAGNÓSTICO COMPLETO DEL BOT DE TELEGRAM"
echo "=================================================="
echo ""

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_info() {
    echo -e "ℹ $1"
}

# 1. Verificar que tenemos el worker URL
echo "1️⃣  VERIFICACIÓN DE CONFIGURACIÓN LOCAL"
echo "=========================================="

if [ ! -f "wrangler.jsonc" ]; then
    log_error "wrangler.jsonc no encontrado"
    exit 1
fi

WORKER_NAME=$(grep '"name"' wrangler.jsonc | head -1 | cut -d'"' -f4)
log_info "Worker name: $WORKER_NAME"

# Intentar obtener el URL del worker
if command -v wrangler &> /dev/null; then
    log_success "Wrangler CLI instalado"
    
    # Obtener account ID
    if [ -n "$CLOUDFLARE_ACCOUNT_ID" ]; then
        ACCOUNT_ID="$CLOUDFLARE_ACCOUNT_ID"
        log_success "Account ID encontrado en variable de entorno"
    else
        log_warning "CLOUDFLARE_ACCOUNT_ID no configurado, intentando desde wrangler..."
        ACCOUNT_ID=$(wrangler whoami 2>/dev/null | grep "Account ID" | cut -d':' -f2 | tr -d ' ' || echo "")
    fi
    
    if [ -n "$ACCOUNT_ID" ]; then
        WORKER_URL="https://$WORKER_NAME.${ACCOUNT_ID}.workers.dev"
        log_info "Worker URL estimado: $WORKER_URL"
    else
        log_warning "No se pudo determinar el URL del worker automáticamente"
        log_info "Por favor, ingresa el URL de tu worker (ej: https://moltbot-sandbox.xxxxx.workers.dev):"
        read -r WORKER_URL
    fi
else
    log_warning "Wrangler no instalado, usando URL manual"
    log_info "Por favor, ingresa el URL de tu worker:"
    read -r WORKER_URL
fi

echo ""
echo "2️⃣  VERIFICACIÓN DE CONECTIVIDAD DEL WORKER"
echo "============================================"

# Verificar que el worker responde
log_info "Verificando conectividad con $WORKER_URL..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$WORKER_URL" --max-time 10 || echo "000")

if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "302" ] || [ "$HTTP_CODE" = "401" ]; then
    log_success "Worker responde (HTTP $HTTP_CODE)"
else
    log_error "Worker no responde correctamente (HTTP $HTTP_CODE)"
    log_warning "Verifica que el deployment fue exitoso"
    exit 1
fi

echo ""
echo "3️⃣  VERIFICACIÓN DE HEALTH ENDPOINT"
echo "===================================="

# Intentar acceder al health endpoint (si está habilitado)
if curl -s "$WORKER_URL/debug/health" --max-time 5 > /tmp/health_check.json 2>/dev/null; then
    log_success "Debug endpoint accesible"
    
    # Verificar estado del gateway
    GATEWAY_STATUS=$(cat /tmp/health_check.json | grep -o '"gateway":{[^}]*}' || echo "")
    if [ -n "$GATEWAY_STATUS" ]; then
        log_info "Estado del Gateway:"
        echo "$GATEWAY_STATUS" | sed 's/,/\n  /g'
    fi
    
    # Verificar estado de Telegram
    TELEGRAM_STATUS=$(cat /tmp/health_check.json | grep -o '"telegram":{[^}]*}' || echo "")
    if [ -n "$TELEGRAM_STATUS" ]; then
        log_info "Estado de Telegram:"
        echo "$TELEGRAM_STATUS" | sed 's/,/\n  /g'
    fi
else
    log_warning "Debug endpoint no accesible (puede estar deshabilitado en producción)"
fi

echo ""
echo "4️⃣  VERIFICACIÓN DEL TOKEN DE TELEGRAM"
echo "======================================="

# Verificar que el token está configurado
if [ -f ".dev.vars" ]; then
    TOKEN=$(grep "TELEGRAM_BOT_TOKEN" .dev.vars 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "")
    if [ -n "$TOKEN" ]; then
        log_success "Token encontrado en .dev.vars"
    else
        log_warning "Token no encontrado en .dev.vars"
    fi
else
    log_warning ".dev.vars no encontrado (normal en producción)"
fi

# Si tenemos el token, verificar con Telegram API
if [ -n "$TOKEN" ]; then
    log_info "Verificando token con Telegram API..."
    
    TELEGRAM_RESPONSE=$(curl -s "https://api.telegram.org/bot${TOKEN}/getMe" 2>/dev/null)
    
    if echo "$TELEGRAM_RESPONSE" | grep -q '"ok":true'; then
        log_success "Token es válido"
        
        BOT_USERNAME=$(echo "$TELEGRAM_RESPONSE" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
        BOT_NAME=$(echo "$TELEGRAM_RESPONSE" | grep -o '"first_name":"[^"]*"' | cut -d'"' -f4)
        
        log_info "Bot: @$BOT_USERNAME ($BOT_NAME)"
        
        # Verificar webhook
        echo ""
        log_info "Verificando configuración de webhook..."
        WEBHOOK_INFO=$(curl -s "https://api.telegram.org/bot${TOKEN}/getWebhookInfo" 2>/dev/null)
        
        WEBHOOK_URL=$(echo "$WEBHOOK_INFO" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
        PENDING_UPDATES=$(echo "$WEBHOOK_INFO" | grep -o '"pending_update_count":[0-9]*' | cut -d':' -f2)
        LAST_ERROR=$(echo "$WEBHOOK_INFO" | grep -o '"last_error_message":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$WEBHOOK_URL" ]; then
            log_warning "Webhook configurado: $WEBHOOK_URL"
            log_warning "OpenClaw usa POLLING, no webhooks. Esto puede causar problemas."
            log_info "Para desactivar webhook, ejecuta:"
            echo "  curl -X POST https://api.telegram.org/bot${TOKEN}/deleteWebhook"
        else
            log_success "No hay webhook configurado (correcto para polling)"
        fi
        
        if [ -n "$PENDING_UPDATES" ] && [ "$PENDING_UPDATES" != "0" ]; then
            log_warning "Hay $PENDING_UPDATES actualizaciones pendientes"
        fi
        
        if [ -n "$LAST_ERROR" ]; then
            log_error "Último error de webhook: $LAST_ERROR"
        fi
    else
        log_error "Token inválido o error de API"
        echo "$TELEGRAM_RESPONSE"
    fi
else
    log_warning "No se puede verificar token (no disponible localmente)"
    log_info "Verifica que TELEGRAM_BOT_TOKEN esté configurado en Cloudflare:"
    echo "  wrangler secret list"
fi

echo ""
echo "5️⃣  VERIFICACIÓN DE SECRETS EN CLOUDFLARE"
echo "=========================================="

if command -v wrangler &> /dev/null; then
    log_info "Listando secrets configurados..."
    
    SECRETS=$(wrangler secret list 2>&1 || echo "ERROR")
    
    if echo "$SECRETS" | grep -q "TELEGRAM_BOT_TOKEN"; then
        log_success "TELEGRAM_BOT_TOKEN configurado en Cloudflare"
    else
        log_error "TELEGRAM_BOT_TOKEN NO está configurado en Cloudflare"
        log_info "Para configurarlo, ejecuta:"
        echo "  wrangler secret put TELEGRAM_BOT_TOKEN"
    fi
    
    if echo "$SECRETS" | grep -q "ANTHROPIC_API_KEY"; then
        log_success "ANTHROPIC_API_KEY configurado"
    else
        log_warning "ANTHROPIC_API_KEY no configurado"
    fi
    
    if echo "$SECRETS" | grep -q "ERROR"; then
        log_warning "No se pudo listar secrets (puede requerir autenticación)"
        log_info "Ejecuta: wrangler login"
    fi
else
    log_warning "Wrangler no disponible, no se pueden verificar secrets"
fi

echo ""
echo "6️⃣  ÚLTIMOS LOGS DE DEPLOYMENT"
echo "==============================="

if command -v gh &> /dev/null; then
    log_info "Verificando último workflow de GitHub Actions..."
    
    LAST_RUN=$(gh run list --workflow=deploy.yml --limit 1 --json conclusion,status,databaseId --jq '.[0]')
    
    if [ -n "$LAST_RUN" ]; then
        CONCLUSION=$(echo "$LAST_RUN" | jq -r '.conclusion')
        STATUS=$(echo "$LAST_RUN" | jq -r '.status')
        RUN_ID=$(echo "$LAST_RUN" | jq -r '.databaseId')
        
        if [ "$CONCLUSION" = "success" ]; then
            log_success "Último deployment: EXITOSO"
        elif [ "$CONCLUSION" = "failure" ]; then
            log_error "Último deployment: FALLIDO"
            log_info "Ver logs: gh run view $RUN_ID"
        else
            log_warning "Último deployment: $STATUS ($CONCLUSION)"
        fi
    fi
else
    log_warning "GitHub CLI no disponible, no se pueden verificar workflows"
fi

echo ""
echo "=================================================="
echo "📋 RESUMEN Y PRÓXIMOS PASOS"
echo "=================================================="
echo ""

if [ -n "$BOT_USERNAME" ]; then
    log_info "Para probar el bot, envía un mensaje a: @$BOT_USERNAME"
fi

echo ""
log_info "CHECKLIST DE VERIFICACIÓN:"
echo "  1. ✓ Worker desplegado y accesible"
echo "  2. ? Token de Telegram configurado en Cloudflare"
echo "  3. ? API Key de Anthropic configurada"
echo "  4. ? Webhook de Telegram desactivado (debe usar polling)"
echo "  5. ? Gateway corriendo dentro del container"
echo ""

log_info "Si el bot no responde, verifica:"
echo "  • Logs en tiempo real: wrangler tail"
echo "  • Secrets configurados: wrangler secret list"
echo "  • Estado del worker: curl $WORKER_URL/debug/health"
echo ""

log_warning "IMPORTANTE: OpenClaw usa POLLING, no webhooks"
log_info "Si hay un webhook configurado, elimínalo con:"
echo "  curl -X POST https://api.telegram.org/bot<TOKEN>/deleteWebhook"
echo ""

echo "=================================================="
log_success "Diagnóstico completado"
echo "=================================================="
