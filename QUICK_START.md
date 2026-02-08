# 🚀 GUÍA RÁPIDA DE IMPLEMENTACIÓN - Jasper 100% (70% → 100%)

**Fecha**: 2026-02-08  
**Tiempo Estimado**: 2-4 horas  
**Dificultad**: Media  

---

## ✅ PASOS INMEDIATOS (AHORA)

### 1. Copiar archivos de identidad al contenedor

```bash
# Los archivos ya están creados en el repo:
# - /IDENTITY.md
# - /SOUL.md  
# - /TOOLS.md

# El Dockerfile debe copiarlos al contenedor. Actualizar Dockerfile:

# Agregar después de "COPY skills/ /root/clawd/skills/":
COPY IDENTITY.md /root/clawd/IDENTITY.md
COPY SOUL.md /root/clawd/SOUL.md
COPY TOOLS.md /root/clawd/TOOLS.md

# Y el script de reportes:
COPY scripts/send-system-report.sh /usr/local/bin/send-system-report.sh
RUN chmod +x /usr/local/bin/send-system-report.sh
```

### 2. Agregar variables a wrangler

```bash
# Web Search
npx wrangler secret put BRAVE_SEARCH_API_KEY

# Memory/Embeddings (elegir uno)
npx wrangler secret put GOOGLE_API_KEY
# O
npx wrangler secret put OPENAI_EMBEDDINGS_ENABLED

# Email Reporting (elegir uno)
npx wrangler secret put MAILER_SEND_API_KEY
# O
npx wrangler secret put SENDGRID_API_KEY

# Email destino
npx wrangler secret put SYSTEM_REPORT_EMAIL
# Entrar: carriertrafic@gmail.com

# Telegram policy
npx wrangler secret put TELEGRAM_DM_POLICY
# Entrar: pairing (o "open" si monetizas)

# Browser settings
npx wrangler secret put BROWSER_CLEANUP_ENABLED
# Entrar: true
```

### 3. Actualizar start-openclaw.sh

Parchear las nuevas herramientas en la sección `EOFPATCH`:

```javascript
// Agregar en start-openclaw.sh alrededor de línea 300 (dentro del EOFPATCH):

// Web Search (Brave Search API)
if (process.env.BRAVE_SEARCH_API_KEY) {
    config.tools = config.tools || {};
    config.tools.web = {
        provider: 'brave',
        enabled: true,
        apiKey: process.env.BRAVE_SEARCH_API_KEY,
        search_timeout: 10000,
        max_results: 10
    };
    console.log('Web Search (Brave) configured');
}

// Memory/Embeddings - Google Gemini
if (process.env.GOOGLE_API_KEY) {
    config.plugins = config.plugins || {};
    config.plugins.embeddings = {
        provider: 'google',
        model: 'embedding-001',
        apiKey: process.env.GOOGLE_API_KEY,
        chunkSize: 1024,
        overlap: 100
    };
    console.log('Memory search (Google Gemini) configured');
}

// Memory/Embeddings - OpenAI (alternativa)
if (process.env.OPENAI_API_KEY && process.env.OPENAI_EMBEDDINGS_ENABLED === 'true') {
    config.plugins = config.plugins || {};
    config.plugins.embeddings = {
        provider: 'openai',
        model: 'text-embedding-3-small',
        apiKey: process.env.OPENAI_API_KEY,
        chunkSize: 512,
        overlap: 50
    };
    console.log('Memory search (OpenAI) configured');
}
```

### 4. Configurar Cron Jobs

Agregar al final de `start-openclaw.sh` (después de start_gateway_with_supervisor):

```bash
# ============================================================
# SETUP CRON JOBS
# ============================================================

log_info "Setting up cron jobs for system reporting..."

if command -v crontab &> /dev/null; then
    # Reporte de sistema cada hora (en puntos: 0, 1, 2, ..., 23)
    (crontab -l 2>/dev/null | grep -v "send-system-report" || true; \
     echo "0 * * * * /usr/local/bin/send-system-report.sh >> /root/system-report.log 2>&1") | \
    crontab - 2>/dev/null && log_info "Cron: System report every hour - OK" || log_error "Failed to setup report cron"

    # Heartbeat cada 30 minutos
    (crontab -l 2>/dev/null | grep -v "heartbeat" || true; \
     echo "*/30 * * * * bash -c 'echo \"[$(date -u +\"%Y-%m-%d %H:%M:%S\")] HEARTBEAT OK\" >> /root/heartbeat.log'" ) | \
    crontab - 2>/dev/null && log_info "Cron: Heartbeat every 30min - OK" || log_error "Failed to setup heartbeat cron"

    log_info "Cron jobs configured"
else
    log_error "Cron not available, reporting will be manual"
fi
```

### 5. Build y Deploy

```bash
# Test local
npm run build
npm run test

# Deploy a producción
npm run deploy

# Ver logs en vivo
npx wrangler tail
```

---

## 📋 CHECKLIST DE VALIDACIÓN

### Antes de Deploy

- [ ] IDENTITY.md creado ✓
- [ ] SOUL.md creado ✓
- [ ] TOOLS.md creado ✓
- [ ] browser-cleanup.ts creado ✓
- [ ] send-system-report.sh creado ✓
- [ ] .dev.vars.example actualizado ✓
- [ ] env.ts actualizado ✓
- [ ] types.ts actualizado ✓
- [ ] start-openclaw.sh parcheado (Brave + embeddings)
- [ ] start-openclaw.sh parcheado (cron jobs)
- [ ] Dockerfile actualizado (copiar archivos)
- [ ] Compilado sin errores `npm run build`

### Después de Deploy

```bash
# 1. Verificar Gateway está operativo
curl https://tu-worker.workers.dev/debug/health

# 2. Verificar Web Search funciona
curl -X POST https://tu-worker.workers.dev/api/test-search \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -d '{"query": "noticias de hoy"}'

# 3. Verificar Memory/Embeddings disponible
curl https://tu-worker.workers.dev/debug/memory-status

# 4. Ver reportes de sistema
tail -50 /root/system-report.log

# 5. Ver heartbeat
tail -20 /root/heartbeat.log

# 6. Verificar cron jobs están corriendo
crontab -l | grep -E "(report|heartbeat)"
```

---

## 🎯 FEATURES PRINCIPALES AHORA ACTIVOS

### ✅ Web Search (Brave API)
- Usuario pregunta: "¿Qué pasó hoy?"
- Jasper: Busca con Brave, retorna links + resumen

### ✅ Memory Search (Embeddings)
- Conversación continúa de sesiones anteriores
- Usuario: "¿Recuerdas el documento que
 me pasaste?"
- Jasper: Busca en embeddings, recupera contexto

### ✅ Auto-cleanup Chromium
- Procesos inactivos se matan automáticamente
- Libera memoria antes de fugas
- Check cada 5 minutos

### ✅ Email Reports (Cada hora)
- Reporte de CPU, RAM, sesiones, errores
- Enviado automáticamente a carriertrafic@gmail.com
- 3 métodos disponibles: MailerSend, SendGrid, mail local

### ✅ Heartbeat Logging (Cada 30min)
- Log de estado en /root/heartbeat.log
- Auditoría de disponibilidad
- Incluido en reportes

### ✅ Context Limits (Tools.md)
- Límites documentados por herramienta
- Alertas en 50%, 75%, 90% de contexto
- Prevención de sobreuso

---

## 🔧 CONFIGURACIÓN POR ESCENARIO

### Escenario 1: Usar solo Brave Search (sin embeddings)

```bash
# Wrangler
npx wrangler secret put BRAVE_SEARCH_API_KEY

# En start-openclaw.sh, comentar la sección de embeddings:
# if (process.env.GOOGLE_API_KEY) { ... }  # COMENTAR
# if (process.env.OPENAI_API_KEY...) { ... } # COMENTAR
```

### Escenario 2: Usar Google Gemini embeddings

```bash
npx wrangler secret put GOOGLE_API_KEY
# No necesita BRAVE_SEARCH_API_KEY
```

### Escenario 3: Monetizar con DM abierto

```bash
npx wrangler secret put TELEGRAM_DM_POLICY
# Entrar: open

# Riesgos: Spam, abuso
# Mitiga: Implementar rate limiting en /api/telegram
```

### Escenario 4: Email reports via SendGrid

```bash
npx wrangler secret put SENDGRID_API_KEY
# Comentar MailerSend en send-system-report.sh
```

---

## 🐛 TROUBLESHOOTING COMÚN

### "Brave Search no funciona"
```bash
# 1. Verificar API key
curl "https://api.search.brave.com/res/v1/web/search?q=test" \
  -H "Accept: application/json" \
  -H "X-Subscription-Token: YOUR_KEY"

# 2. Check en logs
npx wrangler tail | grep -i brave

# 3. Verificar límites de quota (50k búsquedas/mes)
```

### "Email reports no se envían"
```bash
# 1. Verificar API key
echo $MAILER_SEND_API_KEY  # No debe estar vacío

# 2. Ver log de ejecución
tail -30 /root/system-report.log

# 3. Verificar cron está corriendo
ps aux | grep cron

# 4. Test manual
bash /usr/local/bin/send-system-report.sh
```

### "Memory search muy lenta"
```bash
# 1. Verificar tamaño de vector DB
ls -lh /root/.openclaw/embeddings.db

# 2. Reducir chunk size en start-openclaw.sh
# chunkSize: 512 (en lugar de 1024)

# 3. Verificar Google API quota
```

---

## 📚 REFERENCIAS RÁPIDAS

| Archivo | Propósito |
|---------|-----------|
| JASPER_PRODUCTION_CHECKLIST.md | Checklist completo (70% → 100%) |
| IDENTITY.md | Quién es Jasper (identidad) |
| SOUL.md | Personalidad y comportamiento |
| TOOLS.md | Límites de contexto y herramientas |
| src/gateway/browser-cleanup.ts | Auto-cleanup de Chromium |
| scripts/send-system-report.sh | Script de reportes |
| .dev.vars.example | Variables de entorno |

---

## 📞 SOPORTE

- **Documentación OpenClaw**: https://docs.openclaw.ai/
- **Brave Search**: https://api.search.brave.com/
- **MailerSend**: https://www.mailersend.com/
- **SendGrid**: https://sendgrid.com/

---

**Próxima revisión**: 2026-02-15  
**Responsable**: Equipo Jasper  
**Estado**: Listo para implementación
