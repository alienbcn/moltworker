# Diagnóstico de Pruebas: Bot de Telegram

## 📊 Resumen Ejecutivo

Se han creado pruebas de integración para diagnosticar por qué el bot de Telegram no responde aunque el deploy está en verde.

## 🔍 Hallazgos Clave

### 1. OpenClaw usa POLLING, NO webhooks

**Importante**: A diferencia de muchos bots de Telegram, OpenClaw **no usa webhooks**. Usa **polling**.

```
┌─────────────┐
│  Telegram   │
│  API Server │
└──────┬──────┘
       │
       │ ← OpenClaw hace polling cada ~1 segundo
       │
┌──────┴──────────────────────────┐
│   OpenClaw Gateway              │
│   (dentro del contenedor)       │
│   Puerto 18789                  │
└─────────────────────────────────┘
```

**Esto significa:**
- ❌ No hay ruta `/webhook` o `/telegram`
- ❌ No necesitas configurar webhook en Telegram
- ✅ El worker solo hace proxy al gateway
- ✅ El gateway maneja todo el polling internamente

### 2. Rutas del Worker

El worker tiene estas rutas principales:

```typescript
/                    → Proxy al gateway (catch-all)
/api/*              → API protegida con CF Access
/_admin/*           → Admin UI protegida con CF Access
/debug/*            → Debug routes (si DEBUG_ROUTES=true)
/sandbox-health     → Health check público
```

**Cualquier ruta que no coincida** con las rutas específicas se envía al gateway en el puerto 18789.

### 3. Variables de Entorno Críticas

Para que Telegram funcione necesitas:

| Variable | ¿Obligatoria? | Propósito |
|----------|---------------|-----------|
| `TELEGRAM_BOT_TOKEN` | ✅ Sí | Token del bot de Telegram |
| `ANTHROPIC_API_KEY` o `OPENAI_API_KEY` | ✅ Sí | Para que la IA responda |
| `MOLTBOT_GATEWAY_TOKEN` | ✅ Sí | Token de acceso al gateway |
| `CF_ACCESS_TEAM_DOMAIN` | ⚠️ Prod | Para Cloudflare Access (no en DEV_MODE) |
| `CF_ACCESS_AUD` | ⚠️ Prod | Para Cloudflare Access (no en DEV_MODE) |

### 4. ¿Por qué el Bot No Responde?

Si el deploy está en verde pero el bot no responde, las causas probables son:

#### A. Gateway no está corriendo
```bash
# Verificar
curl https://tu-worker.workers.dev/debug/health | jq '.gateway.status'

# Debería responder: "running"
```

#### B. TELEGRAM_BOT_TOKEN no está configurado
```bash
# Verificar en logs del worker
wrangler tail | grep TELEGRAM

# Debería mostrar: "Has TELEGRAM_BOT_TOKEN: true"
```

#### C. Gateway arrancó pero falló al configurar Telegram
```bash
# Ver logs de inicio del contenedor
curl https://tu-worker.workers.dev/debug/health | jq '.telegram'

# Debería responder:
# {
#   "status": "configured",
#   "enabled": true,
#   "has_token": true
# }
```

#### D. AI API Keys no están configuradas
El gateway puede arrancar sin API keys, pero la IA no responderá:
```bash
curl https://tu-worker.workers.dev/debug/health | jq '.ai'

# Debería tener alguna de estas:
# "anthropic": { "configured": true } o
# "openai": { "configured": true }
```

## 🧪 Pruebas de Integración Añadidas

Se ha creado `src/index.test.ts` con las siguientes pruebas:

### Validación de Variables de Entorno
- ✅ Advierte si falta `TELEGRAM_BOT_TOKEN` en logs
- ✅ Verifica que el worker detecta la presencia del token
- ✅ Acepta configuración válida con TELEGRAM_BOT_TOKEN

### Integración con Gateway
- ✅ Maneja arranque del gateway en DEV_MODE
- ✅ Maneja errores de arranque del gateway gracefully
- ✅ Retorna error 503 si el gateway falla

### Verificación de Telegram
- ✅ Documenta que OpenClaw usa polling
- ✅ Verifica que todas las rutas se proxyan al gateway
- ✅ Valida formato del token de Telegram

### Logging y Diagnóstico
- ✅ Registra todas las requests con método y path
- ✅ Registra estado de DEV_MODE
- ✅ Maneja eventos programados (cron) para backup R2

## 🚀 CI/CD Mejorado

El workflow `.github/workflows/deploy.yml` ahora incluye:

```yaml
- name: Run Tests
  run: npm test
  env:
    DEV_MODE: "true"
```

**Esto significa:**
- ✅ Los tests deben pasar ANTES de deployar
- ✅ Si falta configuración crítica, el deploy fallará
- ✅ Evita deployar código roto

## 📋 Checklist de Diagnóstico

Si el bot no responde después de un deploy verde, ejecuta estos pasos:

### 1. Verificar Worker
```bash
# ¿El worker está respondiendo?
curl https://tu-worker.workers.dev/sandbox-health

# Debería responder: 200 OK
```

### 2. Verificar Gateway
```bash
# ¿El gateway está corriendo?
curl https://tu-worker.workers.dev/debug/health | jq '.gateway.status'

# Debería responder: "running"
```

### 3. Verificar Telegram
```bash
# ¿Telegram está configurado?
curl https://tu-worker.workers.dev/debug/health | jq '.telegram'

# Debería responder:
# {
#   "status": "configured",
#   "enabled": true,
#   "has_token": true
# }
```

### 4. Verificar AI
```bash
# ¿Hay AI API key configurada?
curl https://tu-worker.workers.dev/debug/health | jq '.ai'

# Debería tener alguna key configurada
```

### 5. Verificar Secrets
```bash
# Listar secrets configurados
wrangler secret list

# Deberías ver:
# - ANTHROPIC_API_KEY (o OPENAI_API_KEY)
# - TELEGRAM_BOT_TOKEN
# - MOLTBOT_GATEWAY_TOKEN
```

### 6. Ver Logs en Vivo
```bash
# Monitorear logs del worker
wrangler tail

# Enviar mensaje al bot en Telegram
# Deberías ver logs de:
# [REQ] GET /...
# [PROXY] Handling request: ...
```

## 🔧 Comandos Útiles

### Ejecutar Tests Localmente
```bash
npm test                  # Ejecutar todos los tests
npm run test:watch       # Modo watch para desarrollo
npm run test:coverage    # Ver cobertura de tests
```

### Ejecutar Tests en Modo DEV
```bash
DEV_MODE=true npm test   # Tests con DEV_MODE (como CI)
```

### Verificar Solo Tests de Telegram
```bash
npm test -- src/index.test.ts
```

## 📚 Recursos Adicionales

- [TELEGRAM_DIAGNOSIS.md](./TELEGRAM_DIAGNOSIS.md) - Diagnóstico detallado de Telegram
- [TELEGRAM_SETUP.md](./TELEGRAM_SETUP.md) - Guía de configuración inicial
- [AGENTS.md](./AGENTS.md) - Arquitectura y patrones del proyecto

## 🎯 Próximos Pasos

Si los tests pasan pero el bot no responde:

1. **Verificar que el secret TELEGRAM_BOT_TOKEN está configurado en producción:**
   ```bash
   wrangler secret list | grep TELEGRAM
   ```

2. **Añadir el secret si falta:**
   ```bash
   wrangler secret put TELEGRAM_BOT_TOKEN
   # Pegar el token cuando se solicite
   ```

3. **Hacer un nuevo deploy:**
   ```bash
   npm run deploy
   ```

4. **Esperar 30 segundos** para que el contenedor arranque

5. **Verificar health:**
   ```bash
   curl https://tu-worker.workers.dev/debug/health | jq
   ```

6. **Enviar mensaje de prueba** al bot en Telegram

7. **Ver logs en tiempo real:**
   ```bash
   wrangler tail
   ```

## ⚠️ Notas Importantes

1. **Cold Starts**: El contenedor tarda ~30 segundos en arrancar la primera vez
2. **Polling Delay**: OpenClaw puede tardar 1-2 segundos en detectar mensajes nuevos (es normal)
3. **DEV_MODE**: En modo desarrollo se salta la autenticación de CF Access
4. **Debug Routes**: Solo están habilitadas si `DEBUG_ROUTES=true`
5. **R2 Backup**: El contenedor sincroniza la configuración a R2 cada cierto tiempo

## 🐛 Problemas Conocidos

### "Bot no responde después del primer mensaje"
- **Causa**: El bot requiere emparejamiento (`dmPolicy: "pairing"`)
- **Solución**: El usuario debe seguir las instrucciones de emparejamiento que da el bot

### "Gateway arranca pero se cae después de unos segundos"
- **Causa**: Falta ANTHROPIC_API_KEY o hay un error en la configuración
- **Solución**: Verificar logs con `wrangler tail` y revisar `openclaw-startup.log` en el contenedor

### "Tests pasan localmente pero fallan en CI"
- **Causa**: Mocks pueden comportarse diferente en CI
- **Solución**: Asegurarse de que `DEV_MODE=true` esté configurado en el workflow

---

**Creado**: 2026-02-09  
**Última actualización**: 2026-02-09  
**Versión**: 1.0
