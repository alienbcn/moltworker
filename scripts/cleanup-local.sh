#!/bin/bash
# Script de Limpieza Completa - Moltworker
# Este script elimina LOCALMENTE build artifacts, node_modules, etc.
# NO elimina el repositorio de GitHub ni el Worker de Cloudflare

set -e

echo "🗑️  Script de Limpieza Completa - Moltworker"
echo "=============================================="
echo ""
echo "⚠️  ADVERTENCIA: Este script eliminará:"
echo "  - node_modules/"
echo "  - dist/"
echo "  - package-lock.json"
echo "  - .dev.vars (si existe)"
echo "  - Archivos temporales"
echo "  - Build artifacts"
echo ""
echo "Este script NO eliminará:"
echo "  ❌ El código fuente (src/)"
echo "  ❌ El repositorio Git"
echo "  ❌ El Worker de Cloudflare"
echo "  ❌ Los datos de R2"
echo ""
read -p "¿Deseas continuar? (escribe 'SI' para confirmar): " CONFIRM

if [ "$CONFIRM" != "SI" ]; then
    echo "❌ Cancelado por el usuario"
    exit 1
fi

echo ""
echo "🧹 Iniciando limpieza..."
echo ""

# Guardar directorio actual
ORIGINAL_DIR=$(pwd)

# Función para limpiar un directorio
cleanup() {
    local dir="$1"
    if [ -d "$dir" ]; then
        echo "🗑️  Eliminando: $dir"
        rm -rf "$dir"
        echo "   ✅ Eliminado"
    else
        echo "   ⏭️  No existe: $dir"
    fi
}

# Función para eliminar un archivo
delete_file() {
    local file="$1"
    if [ -f "$file" ]; then
        echo "🗑️  Eliminando: $file"
        rm -f "$file"
        echo "   ✅ Eliminado"
    else
        echo "   ⏭️  No existe: $file"
    fi
}

# 1. Eliminar node_modules
echo ""
echo "1️⃣  Eliminando dependencias de Node.js..."
cleanup "node_modules"

# 2. Eliminar build artifacts
echo ""
echo "2️⃣  Eliminando build artifacts..."
cleanup "dist"
cleanup ".vite"
cleanup ".wrangler"

# 3. Eliminar lock files
echo ""
echo "3️⃣  Eliminando lock files..."
delete_file "package-lock.json"
delete_file "pnpm-lock.yaml"
delete_file "yarn.lock"

# 4. Eliminar archivos de configuración locales
echo ""
echo "4️⃣  Eliminando configuración local..."
delete_file ".dev.vars"
delete_file ".env"
delete_file ".env.local"

# 5. Eliminar archivos temporales
echo ""
echo "5️⃣  Eliminando archivos temporales..."
find . -type f -name "*.log" -delete 2>/dev/null || true
find . -type f -name "*.tmp" -delete 2>/dev/null || true
find . -type f -name ".DS_Store" -delete 2>/dev/null || true
cleanup ".cache"
cleanup "tmp"
cleanup "/tmp/moltworker*" 2>/dev/null || true

# 6. Limpiar Git (opcional)
echo ""
echo "6️⃣  Limpiando Git..."
if [ -d ".git" ]; then
    echo "   Limpiando Git cache..."
    git gc --prune=now --aggressive 2>/dev/null || true
    echo "   ✅ Git limpiado"
else
    echo "   ⏭️  No es un repositorio Git"
fi

# 7. Mostrar espacio liberado
echo ""
echo "📊 Calculando espacio liberado..."
DU_AFTER=$(du -sh . 2>/dev/null | cut -f1)
echo "   Tamaño actual: $DU_AFTER"

echo ""
echo "✅ Limpieza completada!"
echo ""
echo "📝 Siguiente pasos:"
echo "   1. Si quieres reinstalar dependencias: npm install"
echo "   2. Si quieres eliminar TODO (repo, worker, etc): lee GUIA_ELIMINACION_COMPLETA.md"
echo "   3. Si quieres empezar de cero: elimina este directorio y clona de nuevo"
echo ""
