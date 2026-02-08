#!/bin/bash
# Script de diagnóstico detallado para Telegram

echo "====================================="
echo "DIAGNÓSTICO COMPLETO DE TELEGRAM BOT"
echo "====================================="
echo ""

# 1. Validar token
echo "1. VALIDACIÓN DEL TOKEN"
echo "======================"
if [ -f .dev.vars ]; then
    TOKEN=$(grep "TELEGRAM_BOT_TOKEN" .dev.vars | cut -d'=' -f2 | tr -d ' ')
    if [ -z "$TOKEN" ]; then
        echo "❌ Token vacío"
    else
        echo "✓ Token configurado: ${TOKEN:0:10}..."
        
        # Validar con BotFather
        echo ""
        echo "2. VERIFICACIÓN CON TELEGRAM API"
        echo "================================="
        echo "Consultando información del bot..."
        
        RESULT=$(curl -s "https://api.telegram.org/bot${TOKEN}/getMe" 2>/dev/null)
        
        if echo "$RESULT" | grep -q '"ok":true'; then
            echo "✓ Token es válido y responde"
            BOT_ID=$(echo "$RESULT" | grep -o '"id":[0-9]*' | head -1 | cut -d':' -f2)
            BOT_NAME=$(echo "$RESULT" | grep -o '"first_name":"[^"]*"' | cut -d'"' -f4)
            BOT_USERNAME=$(echo "$RESULT" | grep -o '"username":"[^"]*"' | cut -d'"' -f4)
            
            echo "  Bot ID: $BOT_ID"
            echo "  Bot Name: $BOT_NAME"
            echo "  Bot Username: @$BOT_USERNAME"
        elif echo "$RESULT" | grep -q '"ok":false'; then
            ERROR=$(echo "$RESULT" | grep -o '"description":"[^"]*"' | cut -d'"' -f4)
            echo "❌ Token inválido: $ERROR"
            echo ""
            echo "Solución:"
            echo "1. Ve a @BotFather en Telegram"
            echo "2. Envía /start"
            echo "3. Envía /newbot o /mybots"
            echo "4. Copia el token correctamente"
            echo "5. Ejecuta: wrangler secret put TELEGRAM_BOT_TOKEN"
        else
            echo "❌ Error conectando con Telegram API"
            echo "Respuesta: $RESULT"
        fi
    fi
else
    echo "❌ .dev.vars no encontrado"
fi

echo ""
echo "3. VERIFICACIÓN DE CONFIGURACIÓN LOCAL"
echo "====================================="

# Verificar logs
if [ -f /root/openclaw-startup.log ]; then
    echo "Últimas líneas de logs de startup:"
    tail -20 /root/openclaw-startup.log 2>/dev/null | grep -i telegram
else
    echo "⚠ No hay logs de startup"
fi

echo ""
echo "4. VERIFICACIÓN DEL ARCHIVO CONFIG"
echo "=================================="
if [ -f /root/.openclaw/openclaw.json ]; then
    echo "Config encontrado. Verificando Telegram..."
    if grep -q '"telegram"' /root/.openclaw/openclaw.json; then
        echo "✓ Telegram está en la configuración"
        grep -A 3 '"telegram"' /root/.openclaw/openclaw.json | head -5
    else
        echo "❌ Telegram NO está en la configuración"
    fi
elif [ -f /root/.clawdbot/clawdbot.json ]; then
    echo "Config legacy encontrado. Verificando Telegram..."
    if grep -q '"telegram"' /root/.clawdbot/clawdbot.json; then
        echo "✓ Telegram está en la configuración (legacy)"
        grep -A 3 '"telegram"' /root/.clawdbot/clawdbot.json | head -5
    else
        echo "❌ Telegram NO está en la configuración"
    fi
else
    echo "⚠ No hay archivo de configuración aún"
fi

echo ""
echo "5. VERIFICACIÓN DEL GATEWAY"
echo "==========================="
if pgrep -f "openclaw gateway" > /dev/null; then
    echo "✓ Gateway está corriendo"
    GATEWAY_PID=$(pgrep -f "openclaw gateway" | head -1)
    echo "  PID: $GATEWAY_PID"
    
    if curl -s http://localhost:18789/health > /dev/null 2>&1; then
        echo "✓ Gateway responde en puerto 18789"
    else
        echo "⚠ Gateway no responde (aún iniciando?)"
    fi
else
    echo "❌ Gateway NO está corriendo"
fi

echo ""
echo "6. VERIFICACIÓN DE MEMORIA"
echo "=========================="
if [ -d /root/clawd/memory ]; then
    COUNT=$(ls /root/clawd/memory 2>/dev/null | wc -l)
    echo "✓ Carpeta de memoria existe con $COUNT archivos"
else
    echo "⚠ Carpeta de memoria no existe aún"
fi

echo ""
echo "====================================="
echo "RESUMEN"
echo "====================================="
echo ""
echo "Pasos para diagnosticar:"
echo "1. Si el token es inválido → Obtener nuevo token de BotFather"
echo "2. Si el gateway no corre → Revisar logs con: tail -f /root/openclaw-startup.log"
echo "3. Si Telegram no está en config → Verificar que TELEGRAM_BOT_TOKEN está en .dev.vars"
echo "4. Si todo OK, enviar mensaje normal al bot en Telegram"
echo ""
