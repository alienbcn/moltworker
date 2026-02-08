# Bot Telegram No Responde - Checklist Rápido

## ✅ YA VERIFICADO
- Token es **VÁLIDO**: `123456789:ABCDefGhIjKlMnOpqRsTuVwXyZ`
- Bot @your_bot existe en Telegram

## 🔍 PRÓXIMAS VERIFICACIONES

### Paso 1: Verificar Gateway (2 minutos)
```bash
# ¿Está corriendo?
ps aux | grep "openclaw gateway"

# ¿Responde?
curl -v http://localhost:18789/health

# Si no responde, reiniciar:
pkill -9 "openclaw gateway"
/usr/local/bin/start-openclaw.sh
sleep 10
curl http://localhost:18789/health | jq '.health.telegram'
```

**Resultado esperado para Telegram:**
```json
{
  "enabled": true,
  "status": "configured",
  "has_token": true,
  "dm_policy": "pairing"
}
```

### Paso 2: Verificar Config de OpenClaw (2 minutos)
```bash
# ¿Existe el archivo?
ls -la /root/.openclaw/openclaw.json

# ¿Tiene Telegram?
cat /root/.openclaw/openclaw.json | jq '.channels.telegram'

# Resultado esperado:
# {
#   "botToken": "123456789:ABCDefGhIjKl...",
#   "enabled": true,
#   "dmPolicy": "pairing"
# }
```

### Paso 3: Ver Logs (5 minutos)
```bash
# Últimos 50 líneas de startup
tail -50 /root/openclaw-startup.log

# Buscar específicamente Telegram
grep -i telegram /root/openclaw-startup.log

# Buscar errores
grep -i "error\|fail" /root/openclaw-startup.log
```

**Qué buscar en logs:**
- ✅ "Telegram configured with dmPolicy"
- ✅ "Gateway startup attempt"
- ✅ "Executing: openclaw gateway"
- ❌ "ERROR" o "FAILED"

### Paso 4: Probar Bot (1 minuto)
1. Abre Telegram
2. Busca @your_bot
3. Envía un mensaje simple como: "Hola"
4. El bot debería responder en 2-5 segundos

**Posibles respuestas:**
- "Pairing required" → ✅ Telegram SÍ funciona, solo necesitas emparejar
- Sin respuesta → ❌ Problema en configuración o gateway
- Error message → ❌ Token o configuración incorrecta

## 🚀 SOLUCIÓN RÁPIDA

Si todo lo anterior falla, ejecuta:
```bash
chmod +x /workspaces/moltworker/scripts/fix-telegram-quick.sh
/workspaces/moltworker/scripts/fix-telegram-quick.sh
```

Este script:
1. Verifica el token
2. Crea/arregla la configuración
3. Reinicia el gateway
4. Muestra estado final

## 📋 VARIABLES NECESARIAS

En `.dev.vars` debe haber:
```bash
TELEGRAM_BOT_TOKEN=123456789:ABCDefGhIjKlMnOpqRsTuVwXyZ   ✅ VERIFICADO
ANTHROPIC_API_KEY=sk-ant-...                                        ❓ NECESARIO
DEV_MODE=true                                                        (opcional)
MOLTBOT_GATEWAY_TOKEN=xxxxx                                         (opcional)
```

## 🐛 PROBLEMAS COMUNES

### Gateway no inicia
- Revisar: `tail -50 /root/openclaw-startup.log`
- Verificar ANTHROPIC_API_KEY está configurado
- Check disk space: `df -h /root`

### Gateway inicia pero Telegram no funciona
- No hay polling habilitado
- dmPolicy está mal configurado
- Token no se aplicó correctamente
- Solución: `./scripts/fix-telegram-quick.sh`

### Bot responde "Pairing required" pero no funciona después
- Problema con ANTHROPIC_API_KEY
- Revisar: `cat /root/.openclaw/openclaw.json | jq '.agents.defaults.model'`
- Debe tener una referencia a anthropic o similar

## 📊 DIAGRAMA DE FLUJO

```
Mensaje Telegram
      ↓
Telegram API (polling)
      ↓
OpenClaw Gateway (puerto 18789)
      ↓
Agent Engine (usa ANTHROPIC_API_KEY)
      ↓
Respuesta → Telegram
```

Si falla en cualquier paso:
1. Verificar logs en `/root/openclaw-startup.log`
2. Revisar configuración en `/root/.openclaw/openclaw.json`
3. Reiniciar gateway
4. Ejecutar script de reparación

## 💡 TIPS

- Los logs son tu mejor amigo: `tail -f /root/openclaw-startup.log`
- Health check rápido: `curl http://localhost:18789/health | jq`
- Token más importante: ANTHROPIC_API_KEY (sin él no puede responder)
- El bot puede tardar 5-10 segundos en responder (normal)

## ❓ SIGUIENTES PASOS

1. **Ahora mismo:**
   - Ejecuta `curl http://localhost:18789/health | jq` 
   - Comparte el resultado

2. **Si eso falla:**
   - Ejecuta `tail -50 /root/openclaw-startup.log`
   - Comparte los últimos 20 líneas

3. **Si los logs están al día:**
   - Ejecuta `./scripts/fix-telegram-quick.sh`
   - Reinicia el gateway
      - Intenta enviar un mensaje a @your_bot
