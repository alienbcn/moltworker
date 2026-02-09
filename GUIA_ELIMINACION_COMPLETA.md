# 🗑️ Guía Completa: Eliminar Proyecto Moltworker

**Objetivo:** Eliminar completamente el proyecto moltworker y todas sus conexiones para empezar de cero.

**⚠️ ADVERTENCIA: Esta acción es IRREVERSIBLE. Perderás TODO el código, configuración, datos y despliegues.**

---

## 📋 Checklist de Eliminación

Marca cada paso a medida que lo completes:

- [ ] 1. Hacer backup (si necesitas guardar algo)
- [ ] 2. Eliminar Worker de Cloudflare
- [ ] 3. Eliminar R2 Bucket y datos
- [ ] 4. Eliminar Secrets de Cloudflare
- [ ] 5. Eliminar configuración de AI Gateway (si existe)
- [ ] 6. Eliminar configuración de Cloudflare Access (si existe)
- [ ] 7. Eliminar GitHub Actions secrets
- [ ] 8. Eliminar el repositorio de GitHub
- [ ] 9. Eliminar clon local
- [ ] 10. Verificar eliminación completa

---

## 1️⃣ Hacer Backup (Opcional)

**Si quieres guardar algo antes de eliminar:**

```bash
# Backup del código
cd ~
git clone https://github.com/alienbcn/moltworker moltworker-backup-$(date +%Y%m%d)

# Backup de configuración local (si existe)
cp -r /ruta/a/moltworker/.dev.vars ~/moltworker-backup-config-$(date +%Y%m%d) 2>/dev/null || true
```

---

## 2️⃣ Eliminar Worker de Cloudflare

### Opción A: Usar Wrangler CLI

```bash
# Listar workers
npx wrangler deployments list

# Eliminar el worker
npx wrangler delete moltbot-sandbox

# Confirmar eliminación cuando pregunte
```

### Opción B: Dashboard de Cloudflare

1. Ve a: https://dash.cloudflare.com/
2. Navega a: **Workers & Pages**
3. Busca: **moltbot-sandbox**
4. Haz clic en el worker
5. Ve a: **Settings** (pestaña)
6. Scroll hasta el final
7. Haz clic en: **Delete** (botón rojo)
8. Confirma: Escribe el nombre del worker
9. Haz clic en: **Delete**

---

## 3️⃣ Eliminar R2 Bucket y Datos

**⚠️ Esto eliminará TODOS tus datos, conversaciones y configuración de OpenClaw.**

### Usando Wrangler:

```bash
# Listar buckets
npx wrangler r2 bucket list

# Eliminar el bucket (esto borrará TODO el contenido)
npx wrangler r2 bucket delete moltbot-data

# Confirmar cuando pregunte
```

### Usando Dashboard:

1. Ve a: https://dash.cloudflare.com/
2. Navega a: **R2**
3. Busca: **moltbot-data**
4. Haz clic en el bucket
5. **Primero, vacía el bucket:**
   - Settings > Management
   - Delete all objects
6. **Luego, elimina el bucket:**
   - Settings > Delete bucket
7. Confirma la eliminación

---

## 4️⃣ Eliminar Secrets de Cloudflare

```bash
# Listar secrets
npx wrangler secret list

# Eliminar cada secret (reemplaza SECRET_NAME con el nombre real)
npx wrangler secret delete ANTHROPIC_API_KEY
npx wrangler secret delete OPENAI_API_KEY
npx wrangler secret delete TELEGRAM_BOT_TOKEN
npx wrangler secret delete DISCORD_BOT_TOKEN
npx wrangler secret delete SLACK_BOT_TOKEN
npx wrangler secret delete SLACK_APP_TOKEN
npx wrangler secret delete MOLTBOT_GATEWAY_TOKEN
npx wrangler secret delete CLOUDFLARE_AI_GATEWAY_API_KEY
npx wrangler secret delete AI_GATEWAY_API_KEY
npx wrangler secret delete R2_ACCESS_KEY_ID
npx wrangler secret delete R2_SECRET_ACCESS_KEY
npx wrangler secret delete CF_ACCOUNT_ID
npx wrangler secret delete CDP_SECRET
npx wrangler secret delete BRAVE_SEARCH_API_KEY
npx wrangler secret delete GOOGLE_API_KEY
npx wrangler secret delete MAILER_SEND_API_KEY
npx wrangler secret delete SENDGRID_API_KEY

# O eliminar todos a la vez
for secret in ANTHROPIC_API_KEY OPENAI_API_KEY TELEGRAM_BOT_TOKEN DISCORD_BOT_TOKEN SLACK_BOT_TOKEN SLACK_APP_TOKEN MOLTBOT_GATEWAY_TOKEN; do
  npx wrangler secret delete $secret --force 2>/dev/null || true
done
```

---

## 5️⃣ Eliminar AI Gateway (si existe)

1. Ve a: https://dash.cloudflare.com/
2. Navega a: **AI Gateway**
3. Si tienes un gateway configurado:
   - Selecciona el gateway
   - Settings
   - Delete Gateway
4. Confirma la eliminación

---

## 6️⃣ Eliminar Cloudflare Access (si existe)

1. Ve a: https://dash.cloudflare.com/
2. Navega a: **Zero Trust** > **Access** > **Applications**
3. Busca aplicaciones relacionadas con moltbot
4. Elimina cada aplicación:
   - Haz clic en la aplicación
   - Edit
   - Scroll hasta el final
   - Delete Application

---

## 7️⃣ Eliminar GitHub Actions Secrets

1. Ve a: https://github.com/alienbcn/moltworker
2. Navega a: **Settings** > **Secrets and variables** > **Actions**
3. Elimina cada secret:
   - `CLOUDFLARE_API_TOKEN`
   - `CLOUDFLARE_ACCOUNT_ID`
   - Cualquier otro secret relacionado
4. Haz clic en **Remove** para cada uno

---

## 8️⃣ Eliminar el Repositorio de GitHub

**⚠️ ESTO ES PERMANENTE. No podrás recuperar el código después.**

### Pasos:

1. Ve a: https://github.com/alienbcn/moltworker
2. Navega a: **Settings** (pestaña superior)
3. Scroll hasta el final de la página
4. Busca la sección: **Danger Zone**
5. Haz clic en: **Delete this repository**
6. Lee las advertencias
7. Escribe: `alienbcn/moltworker` para confirmar
8. Haz clic en: **I understand the consequences, delete this repository**
9. Ingresa tu contraseña de GitHub si te la pide

---

## 9️⃣ Eliminar Clon Local

```bash
# Si estás FUERA del directorio
cd ~
rm -rf /ruta/a/moltworker

# Ejemplo común:
rm -rf ~/moltworker
rm -rf ~/projects/moltworker
rm -rf ~/dev/moltworker

# Verificar que se eliminó
ls -la ~/moltworker  # Debería dar error "No such file or directory"
```

**⚠️ SI ESTÁS DENTRO del directorio moltworker:**

```bash
# Salir del directorio primero
cd ~

# LUEGO eliminar
rm -rf /home/runner/work/moltworker/moltworker
```

---

## 🔟 Verificar Eliminación Completa

### Cloudflare:

```bash
# Verificar workers (no debería aparecer moltbot-sandbox)
npx wrangler deployments list

# Verificar R2 buckets (no debería aparecer moltbot-data)
npx wrangler r2 bucket list

# Verificar secrets (no debería haber ninguno para moltbot-sandbox)
npx wrangler secret list
```

### GitHub:

```bash
# Intentar acceder al repo (debería dar 404)
curl -I https://github.com/alienbcn/moltworker
# Debería decir: 404 Not Found
```

### Local:

```bash
# Verificar que no existe
ls ~/moltworker  # Error: No such file or directory
ls /home/runner/work/moltworker  # Error: No such file or directory
```

---

## 🔄 Empezar de Cero

Una vez eliminado todo, si quieres empezar de nuevo:

### 1. Crear Nuevo Repositorio

```bash
# Opción A: Desde GitHub UI
# Ve a: https://github.com/new
# Nombre: moltworker (o el que quieras)
# Descripción: (opcional)
# Público o Privado
# Create repository

# Opción B: Desde CLI
gh repo create alienbcn/moltworker --public --clone
```

### 2. Clonar el Template Original (si existe)

```bash
# Si hay un template oficial de moltworker/openclaw
git clone https://github.com/original/moltworker-template nuevo-moltworker
cd nuevo-moltworker

# Cambiar remote a tu nuevo repo
git remote remove origin
git remote add origin https://github.com/alienbcn/moltworker
git push -u origin main
```

### 3. O Empezar desde Cero

```bash
mkdir moltworker-nuevo
cd moltworker-nuevo
git init
echo "# Moltworker - Nuevo Proyecto" > README.md
git add README.md
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/alienbcn/moltworker
git push -u origin main
```

---

## 📝 Notas Importantes

### Lo que SE ELIMINA:

- ✅ Todo el código fuente
- ✅ Todo el historial de Git
- ✅ Todos los commits
- ✅ Todas las ramas
- ✅ Todos los Pull Requests
- ✅ Todos los Issues
- ✅ Todas las GitHub Actions runs
- ✅ Todos los deployments en Cloudflare
- ✅ Todos los datos en R2
- ✅ Todas las conversaciones de OpenClaw
- ✅ Todas las configuraciones

### Lo que NO se elimina automáticamente:

- ❌ Tokens de bots de Telegram (debes revocarlos en @BotFather)
- ❌ Tokens de Discord (debes revocarlos en Discord Developer Portal)
- ❌ Tokens de Slack (debes revocarlos en Slack API)
- ❌ API Keys de Anthropic (debes revocarlas en Anthropic Console)
- ❌ API Keys de OpenAI (debes revocarlas en OpenAI Platform)

### Para revocar tokens de terceros:

**Telegram:**
1. Abre Telegram
2. Busca: @BotFather
3. Envía: `/mybots`
4. Selecciona tu bot
5. Delete Bot

**Anthropic:**
1. Ve a: https://console.anthropic.com/
2. Settings > API Keys
3. Encuentra la key
4. Delete

**OpenAI:**
1. Ve a: https://platform.openai.com/api-keys
2. Encuentra la key
3. Delete

---

## 🆘 Recuperación (Si te arrepientes)

**Si eliminaste por error:**

1. **GitHub:** Los repositorios se pueden recuperar en 90 días:
   - Ve a: https://github.com/settings/repositories
   - Busca repositorios eliminados
   - Restore

2. **Cloudflare Worker:** NO se puede recuperar. Perdido para siempre.

3. **R2 Data:** NO se puede recuperar. Perdido para siempre.

4. **Código local:** Puedes recuperar de:
   - Backup que hiciste en el paso 1
   - Git reflog (si todavía tienes el clon)
   - GitHub cache (en los primeros días)

---

## ✅ Checklist Final

Antes de cerrar esta guía, confirma que:

- [ ] Cloudflare Worker eliminado
- [ ] R2 Bucket eliminado
- [ ] Secrets eliminados
- [ ] GitHub repo eliminado
- [ ] Clon local eliminado
- [ ] Tokens de terceros revocados (opcional pero recomendado)
- [ ] Verificación completada

---

**Estado:** Todo eliminado ✅  
**Siguiente paso:** Empezar proyecto nuevo desde cero  

**¡Buena suerte con el nuevo proyecto!** 🚀
