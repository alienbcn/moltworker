#!/bin/bash
# Script de reparación rápida para bot de Telegram
# Este script intenta arreglar los problemas más comunes

set -e

echo "========================================="
echo "REPARACIÓN RÁPIDA - BOT TELEGRAM"
echo "========================================="
echo ""

# 1. Verificar token
echo "1. Verificando token..."
TOKEN=$(grep "TELEGRAM_BOT_TOKEN" .dev.vars 2>/dev/null | cut -d'=' -f2 | tr -d ' ')
if [ -z "$TOKEN" ]; then
    echo "❌ Token no encontrado en .dev.vars"
    exit 1
fi
echo "✅ Token encontrado"

# 2. Verificar y arreglar configuración
echo ""
echo "2. Verificando configuración de OpenClaw..."
CONFIG_FILE="/root/.openclaw/openclaw.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "⚠️  Configuración no existe, creando desde cero..."
    mkdir -p /root/.openclaw
    cat > "$CONFIG_FILE" << 'JSONEOF'
{
  "gateway": {
    "port": 18789,
    "mode": "local",
    "trustedProxies": ["10.1.0.0"]
  },
  "channels": {
    "telegram": {
      "botToken": "PLACEHOLDER_TOKEN",
      "enabled": true,
      "dmPolicy": "pairing"
    }
  }
}
JSONEOF
    # Reemplazar token placeholder
    sed -i "s|PLACEHOLDER_TOKEN|$TOKEN|g" "$CONFIG_FILE"
    echo "✅ Configuración creada"
else
    echo "✅ Configuración existe"
    
    # Verificar que Telegram está en la config
    if ! grep -q '"telegram"' "$CONFIG_FILE"; then
        echo "⚠️  Telegram no está en la configuración, agregando..."
        
        # Usar jq si está disponible, sino usar sed
        if command -v jq &> /dev/null; then
            jq '.channels.telegram = {
              "botToken": "'$TOKEN'",
              "enabled": true,
              "dmPolicy": "pairing"
            }' "$CONFIG_FILE" > /tmp/config.json && mv /tmp/config.json "$CONFIG_FILE"
        else
            # Fallback a sed (más frágil pero funciona)
            cat >> "$CONFIG_FILE" << JSONEOF2
,
  "channels": {
    "telegram": {
      "botToken": "$TOKEN",
      "enabled": true,
      "dmPolicy": "pairing"
    }
  }
JSONEOF2
        fi
        echo "✅ Telegram agregado a configuración"
    fi
    
    # Verificar que dmPolicy es correcto
    if grep -q '"dmPolicy": "pairing"' "$CONFIG_FILE"; then
        echo "ℹ️  Modo de emparejamiento activo (pairing)"
    else
        echo "ℹ️  Modo abierto activo (open)"
    fi
fi

# 3. Verificar que el gateway está corriendo
echo ""
echo "3. Verificando gateway..."
if pgrep -f "openclaw gateway" > /dev/null; then
    echo "✅ Gateway está corriendo"
    
    # Intentar contactarlo
    if curl -s http://localhost:18789/health > /dev/null 2>&1; then
        echo "✅ Gateway responde"
    else
        echo "⚠️  Gateway no responde en puerto 18789"
        echo "   Matando y reiniciando..."
        pkill -9 -f "openclaw gateway" || true
        sleep 2
        /usr/local/bin/start-openclaw.sh &
        sleep 5
        echo "✅ Gateway reiniciado"
    fi
else
    echo "⚠️  Gateway NO está corriendo"
    echo "   Iniciando..."
    /usr/local/bin/start-openclaw.sh &
    sleep 5
    echo "✅ Gateway iniciado"
fi

# 4. Verificar memoria
echo ""
echo "4. Verificando persistencia de memoria..."
if [ -d /root/clawd/memory ]; then
    MEMORY_FILES=$(ls /root/clawd/memory 2>/dev/null | wc -l)
    echo "✅ Carpeta de memoria existe ($MEMORY_FILES archivos)"
else
    echo "⚠️  Creando carpeta de memoria..."
    mkdir -p /root/clawd/memory
    echo "✅ Carpeta creada"
fi

# 5. Verificar logs
echo ""
echo "5. Últimos eventos de logs..."
if [ -f /root/openclaw-startup.log ]; then
    tail -5 /root/openclaw-startup.log
else
    echo "⚠️  No hay logs aún"
fi

echo ""
echo "========================================="
echo "REPARACIÓN COMPLETADA"
echo "========================================="
echo ""
echo "Próximos pasos:"
echo "1. Envia un mensaje de prueba a @japsper_bcn_bot"
echo "2. Si responde con 'pairing required', completa el emparejamiento"
echo "3. Si no responde en 10 segundos, revisa:"
echo "   tail -20 /root/openclaw-startup.log"
echo ""
echo "Para diagnóstico detallado:"
echo "   curl http://localhost:18789/health | jq '.health'"
echo ""
