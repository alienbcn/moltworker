# Guía: Cómo Verificar ANTHROPIC_API_KEY en Cloudflare

**Objetivo:** Verificar que la API key de Anthropic está configurada correctamente en Cloudflare Workers.

---

## 🔑 Paso 1: Acceder al Panel de Cloudflare

1. Abre tu navegador
2. Ve a: https://dash.cloudflare.com/
3. Inicia sesión con tu cuenta

---

## 📂 Paso 2: Ir a Workers & Pages

1. En el menú lateral izquierdo, busca **"Workers & Pages"**
2. Haz clic para abrir la lista de workers

---

## 🤖 Paso 3: Seleccionar tu Worker

1. En la lista, busca **"moltbot-sandbox"** (o el nombre de tu worker)
2. Haz clic en el nombre para abrir la configuración

---

## ⚙️ Paso 4: Abrir Settings

1. En la página del worker, busca las pestañas superiores
2. Haz clic en **"Settings"**

---

## 🔐 Paso 5: Ver Variables y Secrets

1. En Settings, busca la sección **"Variables and Secrets"**
2. Deberías ver dos subsecciones:
   - **Environment Variables** (variables no encriptadas)
   - **Secrets** (variables encriptadas)

---

## ✅ Paso 6: Verificar ANTHROPIC_API_KEY

En la sección **Secrets**, busca:

```
ANTHROPIC_API_KEY
```

### ✅ Si EXISTE:

```
✅ ANTHROPIC_API_KEY
   Value: •••••••••••••••••••
   [Edit] [Delete]
```

**¡Perfecto!** La key está configurada.

**Siguiente paso:** Verificar que es válida:
1. Copia la key (haz clic en Edit para ver el valor)
2. Pruébala con:
```bash
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: TU_KEY_AQUI" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":10,"messages":[{"role":"user","content":"Hi"}]}'
```

Si responde con JSON → ✅ Key válida  
Si responde 401/403 → ❌ Key inválida

---

### ❌ Si NO EXISTE:

**Problema encontrado:** Falta la API key.

**Solución:**

#### A. Obtener una API Key de Anthropic

1. Ve a: https://console.anthropic.com/
2. Inicia sesión (o crea cuenta si no tienes)
3. En el dashboard, busca **"API Keys"**
4. Haz clic en **"Create Key"**
5. Dale un nombre (ej: "Cloudflare Worker")
6. Copia la key (formato: `sk-ant-api03-...`)
7. **⚠️ GUÁRDALA AHORA** - No podrás verla después

#### B. Agregar la Key en Cloudflare

1. En Cloudflare Worker Settings > Variables and Secrets
2. Scroll hasta la sección **"Secrets"**
3. Haz clic en **"Add Variable"**
4. Selecciona **"Encrypt"** (para que sea un secret)
5. Llena el formulario:
   ```
   Variable name: ANTHROPIC_API_KEY
   Value: sk-ant-api03-...  (pega tu key aquí)
   ```
6. Haz clic en **"Deploy"** o **"Save"**

---

## 🔄 Paso 7: Esperar el Reinicio

Después de agregar o editar un secret:

1. ⏱️ Espera **2-3 minutos**
2. El Worker se reiniciará automáticamente
3. El container arrancará con la nueva key

---

## ✅ Paso 8: Probar el Bot

1. Abre Telegram
2. Busca tu bot (ej: @your_bot)
3. Envía un mensaje: "Hola"
4. El bot debería responder en 5-10 segundos

---

## 🔍 Troubleshooting

### El bot sigue sin responder

**Verifica logs en tiempo real:**

```bash
# Desde tu terminal local:
npx wrangler tail --format pretty

# Luego envía un mensaje al bot
# Observa los logs
```

**Busca estos errores:**

❌ `Error: Missing API key`
→ ANTHROPIC_API_KEY no está set o no llegó al container

❌ `Error: Invalid API key`
→ La key es incorrecta o expiró

❌ `Error: Telegram polling failed`
→ Problema con TELEGRAM_BOT_TOKEN o conectividad

❌ `Error: 429 Rate limit`
→ Has excedido el límite de requests

---

## 🎯 Checklist Final

Verifica que tienes estos secrets configurados:

```
✅ ANTHROPIC_API_KEY = sk-ant-api03-...
✅ TELEGRAM_BOT_TOKEN = 1234567890:ABCdefGHI...
✅ MOLTBOT_GATEWAY_TOKEN = (opcional, auto-generado)
```

Variables de ambiente (no secretas):

```
✅ TELEGRAM_DM_POLICY = allow_all
✅ CF_AI_GATEWAY_MODEL = anthropic/claude-sonnet-4-5 (opcional)
```

---

## 📞 Soporte Adicional

**Si el problema persiste:**

1. Lee `DEPLOY_ANALYSIS_2026-02-09.md` - Análisis completo
2. Lee `TELEGRAM_DIAGNOSIS.md` - Diagnóstico de Telegram
3. Ejecuta `./scripts/verify-deployment.sh`
4. Habilita debug routes: `DEBUG_ROUTES=true`
5. Visita: `https://your-worker.workers.dev/debug/health`

---

**Generado por:** GitHub Copilot Agent  
**PR:** #15  
**Fecha:** 2026-02-09
