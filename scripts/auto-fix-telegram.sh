#!/bin/bash
# Script de arreglo automático para problemas comunes del bot de Telegram

set -e

echo "=================================================="
echo "🔧 ARREGLO AUTOMÁTICO - BOT DE TELEGRAM"
echo "=================================================="
echo ""

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

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

# 1. Verificar y eliminar webhook si existe
echo "1️⃣  VERIFICANDO WEBHOOK DE TELEGRAM"
echo "===================================="

if [ -f ".dev.vars" ]; then
    TOKEN=$(grep "TELEGRAM_BOT_TOKEN" .dev.vars 2>/dev/null | cut -d'=' -f2 | tr -d ' ' || echo "")
    
    if [ -n "$TOKEN" ]; then
        log_success "Token encontrado"
        
        WEBHOOK_INFO=$(curl -s "https://api.telegram.org/bot${TOKEN}/getWebhookInfo" 2>/dev/null)
        WEBHOOK_URL=$(echo "$WEBHOOK_INFO" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
        
        if [ -n "$WEBHOOK_URL" ]; then
            log_warning "Webhook detectado: $WEBHOOK_URL"
            log_info "OpenClaw usa polling, eliminando webhook..."
            
            DELETE_RESULT=$(curl -s -X POST "https://api.telegram.org/bot${TOKEN}/deleteWebhook")
            
            if echo "$DELETE_RESULT" | grep -q '"ok":true'; then
                log_success "Webhook eliminado exitosamente"
            else
                log_error "Error al eliminar webhook"
                echo "$DELETE_RESULT"
            fi
        else
            log_success "No hay webhook configurado (correcto)"
        fi
    else
        log_warning "Token no encontrado en .dev.vars"
    fi
else
    log_warning ".dev.vars no encontrado"
fi

echo ""
echo "2️⃣  VERIFICANDO CONFIGURACIÓN DE SECRETS"
echo "========================================="

if command -v wrangler &> /dev/null; then
    log_info "Verificando secrets en Cloudflare..."
    
    SECRETS=$(wrangler secret list 2>&1 || echo "")
    
    if ! echo "$SECRETS" | grep -q "TELEGRAM_BOT_TOKEN"; then
        log_warning "TELEGRAM_BOT_TOKEN no configurado en Cloudflare"
        
        if [ -f ".dev.vars" ] && [ -n "$TOKEN" ]; then
            log_info "¿Deseas configurarlo ahora? (y/n)"
            read -r RESPONSE
            
            if [ "$RESPONSE" = "y" ]; then
                echo "$TOKEN" | wrangler secret put TELEGRAM_BOT_TOKEN
                log_success "Secret configurado"
            fi
        else
            log_info "Configura el secret manualmente:"
            echo "  wrangler secret put TELEGRAM_BOT_TOKEN"
        fi
    else
        log_success "TELEGRAM_BOT_TOKEN ya configurado"
    fi
    
    # Verificar otros secrets importantes
    if ! echo "$SECRETS" | grep -q "ANTHROPIC_API_KEY"; then
        log_warning "ANTHROPIC_API_KEY no configurado"
        log_info "Para configurarlo:"
        echo "  wrangler secret put ANTHROPIC_API_KEY"
    else
        log_success "ANTHROPIC_API_KEY configurado"
    fi
else
    log_error "Wrangler no instalado"
    log_info "Instala con: npm install -g wrangler"
    exit 1
fi

echo ""
echo "3️⃣  VERIFICANDO ESTADO DEL DEPLOYMENT"
echo "======================================"

# Verificar que el workflow está OK
if command -v gh &> /dev/null; then
    log_info "Verificando último deployment..."
    
    LAST_RUN=$(gh run list --workflow=deploy.yml --limit 1 --json conclusion,status --jq '.[0]')
    CONCLUSION=$(echo "$LAST_RUN" | jq -r '.conclusion')
    
    if [ "$CONCLUSION" != "success" ]; then
        log_warning "Último deployment no fue exitoso: $CONCLUSION"
        log_info "¿Deseas hacer un nuevo deployment? (y/n)"
        read -r RESPONSE
        
        if [ "$RESPONSE" = "y" ]; then
            log_info "Haciendo deployment..."
            npm run deploy
            log_success "Deployment iniciado"
        fi
    else
        log_success "Último deployment exitoso"
    fi
else
    log_warning "GitHub CLI no disponible"
fi

echo ""
echo "4️⃣  REINICIANDO WORKER (si es necesario)"
echo "========================================="

log_info "Para reiniciar el worker, redespliega:"
echo "  npm run deploy"
echo ""
log_info "O usa el botón de restart en el dashboard de Cloudflare"

echo ""
echo "=================================================="
echo "📋 RESUMEN DE ACCIONES REALIZADAS"
echo "=================================================="
echo ""

echo "✅ Verificaciones completadas:"
echo "  • Webhook de Telegram verificado/eliminado"
echo "  • Secrets de Cloudflare verificados"
echo "  • Estado del deployment revisado"
echo ""

echo "🔄 Próximos pasos:"
echo "  1. Espera 1-2 minutos para que el worker se actualice"
echo "  2. Prueba enviando un mensaje al bot en Telegram"
echo "  3. Si no responde, verifica logs: wrangler tail"
echo "  4. Para diagnóstico detallado: ./scripts/diagnose-production.sh"
echo ""

log_success "Arreglo automático completado"
echo "=================================================="
