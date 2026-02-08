# Diagnóstico y Solución: Bot de Telegram No Responde

## Estado Actual ✅
- ✅ Token de Telegram es **VÁLIDO** (`your_bot`)
- ✅ Bot existe en Telegram: `@your_bot` 
- ✅ API responde correctamente

## Posibles Problemas y Soluciones

### 1. El Gateway No Está Corriendo

```bash
# Verificar si está corriendo
ps aux | grep "openclaw gateway"

# Si no está corriendo, iniciar:
/usr/local/bin/start-openclaw.sh

# Ver logs de startup
tail -50 /root/openclaw-startup.log
```

**Buscar en logs:**
- "Telegram configured with dmPolicy"
- "Gateway startup attempt"
- Cualquier error de "process exit"

### 2. Gateway Corriendo Pero No Responde

```bash
# Verificar puerto 18789
curl -v http://localhost:18789/

# Ver health del gateway
curl http://localhost:18789/health | jq '.channels.telegram'

# Resultado esperado:
# {
#   "status": "configured",
#   "enabled": true,
#   "has_token": true,
#   "dm_policy": "pairing"
# }
```

**Si falla:**
- El gateway podría estar stuck
- Matar y reiniciar
- Ver logs en `/root/openclaw-startup.log`

### 3. Telegram Configurado Pero No Recibe Mensajes

Esto significa:
1. ✅ Token es válido
2. ✅ Gateway está corriendo
3. ❌ Pero OpenClaw no recibe mensajes de Telegram

**Causas posibles:**
- Bot no está configurado correctamente en Telegram (no tiene botones/comandos)
- Polling está deshabilitado
- Firewall bloqueando api.telegram.org
- OpenClaw no está leyendo correctamente openclaw.json

**Soluciones:**

```bash
# A. Verificar que la config tiene Telegram
cat /root/.openclaw/openclaw.json | jq '.channels.telegram'

# Resultado esperado:
{
  "botToken": "123456789:ABCDefGhIjKlMnOpqRsTuVwXyZ",
  "enabled": true,
  "dmPolicy": "pairing"
}

# B. Cambiar dmPolicy a 'open' para permitir a cualquiera
# (por ahora, para testing)
sed -i 's/"dmPolicy": "pairing"/"dmPolicy": "open"/' /root/.openclaw/openclaw.json

# C. Reiniciar gateway
pkill -9 "openclaw gateway"
/usr/local/bin/start-openclaw.sh

# D. Esperar 5 segundos y enviar mensaje a @your_bot
# El bot debería responder con "pairing required" o empezar conversación
```

### 4. El Bot Pidiendo Emparejamiento Pero No Funciona Después

Esto significa:
- ✅ El bot SÍ está recibiendo mensajes
- ✅ Telegra está funcionando
- ❌ Pero OpenClaw/IA no responde después del emparejamiento

**Solución:**
```bash
# Verificar que API de IA está configurada
cat /root/.openclaw/openclaw.json | jq '.agents.defaults.model'

# Debe salir algo como:
# {
#   "primary": "anthropic/claude-3-5-sonnet-20241022"
# }

# Si no, verificar que ANTHROPIC_API_KEY está configurado:
grep -i anthropic /root/openclaw-startup.log | tail -5
```

## Pasos Recomendados de Debugging

### Paso 1: Verificar Estado General
```bash
curl https://tudominio.com/debug/health | jq
```

### Paso 2: Revisar Logs de Inicio
```bash
tail -100 /root/openclaw-startup.log | grep -i -E "telegram|error|failed"
```

### Paso 3: Verificar Configuración
```bash
cat /root/.openclaw/openclaw.json | jq '.channels'
```

### Paso 4: Probar Conectividad Telegram
```bash
# Desde dentro del contenedor
curl -X POST "https://api.telegram.org/bot123456789:ABCDefGhIjKlMnOpqRsTuVwXyZ/getMe" \
  -H "Content-Type: application/json"
```

### Paso 5: Si Todo Lo Anterior Falla
```bash
# Iniciar desde cero con máxima verbosidad
rm -f /root/.openclaw/openclaw.json
DEV_MODE=true /usr/local/bin/start-openclaw.sh

# Cambiar a open para permitir a cualquiera
echo '{"dmPolicy": "open"}' | jq \
  '.channels.telegram.dmPolicy = "open"' \
  /root/.openclaw/openclaw.json > /tmp/config.json && \
  mv /tmp/config.json /root/.openclaw/openclaw.json

# Reiniciar gateway
pkill -9 "openclaw gateway"
/usr/local/bin/start-openclaw.sh
```

## Checklist de Verificación Final

- [ ] Token es válido (✅ YA VERIFICADO)
- [ ] Bot @your_bot existe en Telegram
- [ ] Gateway está corriendo: `ps aux | grep "openclaw gateway"`
- [ ] Gateway responde: `curl http://localhost:18789/health`
- [ ] Archivo config existe: `ls /root/.openclaw/openclaw.json`
- [ ] Telegram está en config: `jq '.channels.telegram' /root/.openclaw/openclaw.json`
- [ ] API Key (ANTHROPIC_API_KEY) está configurada
- [ ] Logs no muestran errores: `tail /root/openclaw-startup.log`

## Próximos Pasos

1. **Ejecutar:** `curl https://tudominio.com/debug/health | jq`
2. **Revisar telegram.status** - debe ser "configured"
3. **Revisar gateway.status** - debe ser "running"
4. **Enviar mensaje test** a @your_bot
5. **Si no responde:** Ejecutar `tail -50 /root/openclaw-startup.log`

## Mejoras Implementadas

Para hacer el sistema más robusto:
- ✅ Validación de token mejorada (warnings en lugar de errores fatales)
- ✅ Health checks automáticos
- ✅ Supervisor de procesos con reintentos
- ✅ Logging detallado de cada paso
- ✅ Script de diagnóstico: `./scripts/check-telegram-detailed.sh`
