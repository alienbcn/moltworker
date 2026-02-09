# 🗑️ Referencia Rápida: Cómo Eliminar Todo

**Solicitud:** Eliminar moltworker completamente y empezar de cero

---

## ⚡ TL;DR (10 segundos)

```bash
# 1. Eliminar Worker
wrangler delete moltbot-sandbox

# 2. Eliminar R2
wrangler r2 bucket delete moltbot-data

# 3. Eliminar repo GitHub
# → https://github.com/alienbcn/moltworker/settings
# → Danger Zone → Delete this repository

# 4. Eliminar local
cd ~ && rm -rf /path/to/moltworker
```

---

## 📚 Documentación Completa

| Archivo | Para Qué |
|---------|----------|
| **GUIA_ELIMINACION_COMPLETA.md** | Guía detallada paso a paso |
| **scripts/cleanup-local.sh** | Script de limpieza local |
| **DELETION_REQUEST.md** | Resumen de la solicitud |

---

## 🎯 Opciones

### Opción A: Solo Limpiar Local (Rápido)

```bash
./scripts/cleanup-local.sh
```

**Elimina:**
- node_modules/
- dist/
- Build artifacts
- Archivos temporales

**NO elimina:**
- Código fuente
- Repositorio Git
- Worker de Cloudflare

---

### Opción B: Eliminación Parcial

**Eliminar solo Worker:**
```bash
wrangler delete moltbot-sandbox
```

**Eliminar solo R2:**
```bash
wrangler r2 bucket delete moltbot-data
```

**Eliminar solo repo:**
- https://github.com/alienbcn/moltworker/settings
- Danger Zone → Delete

---

### Opción C: Eliminación TOTAL

**Lee:** `GUIA_ELIMINACION_COMPLETA.md`

**Sigue checklist:**
1. Backup (opcional)
2. Worker
3. R2
4. Secrets
5. GitHub repo
6. Local
7. Verificar

**Tiempo:** 15-20 minutos

---

## ⚠️ ADVERTENCIA

**Antes de eliminar:**
- 🔴 Es PERMANENTE
- 🔴 NO hay "undo"
- 🔴 Perderás TODO
- 🔴 GitHub: 90 días recuperación
- 🔴 Cloudflare: NO recuperación

**Haz backup si:**
- Hay código importante
- Hay datos en R2
- Quieres guardar configuración

---

## 🔄 Empezar de Cero

**Después de eliminar todo:**

```bash
# Nuevo repo
gh repo create alienbcn/moltworker --public --clone
cd moltworker

# Inicializar
npm init -y
npm install --save-dev wrangler typescript

# O clonar template
git clone https://template-url moltworker-nuevo
```

---

## 📞 Ayuda

**Si tienes dudas:**
1. Lee GUIA_ELIMINACION_COMPLETA.md primero
2. Pregunta ANTES de eliminar
3. Verifica cada paso

**Si cometiste error:**
- GitHub: Repos se recuperan en 90 días
- Cloudflare: NO hay recuperación
- Local: Usa backup

---

## ✅ Verificación

**Después de eliminar:**

```bash
# Worker eliminado?
wrangler deployments list
# No debería aparecer moltbot-sandbox

# R2 eliminado?
wrangler r2 bucket list
# No debería aparecer moltbot-data

# Repo eliminado?
curl -I https://github.com/alienbcn/moltworker
# Debería dar 404

# Local eliminado?
ls ~/moltworker
# Debería dar error "No such file"
```

---

## 🎯 Estado

- [x] Documentación creada
- [x] Scripts creados
- [ ] Usuario debe eliminar manualmente

**Siguiente:** Lee `GUIA_ELIMINACION_COMPLETA.md`

---

**¡Buena suerte!** 🚀
