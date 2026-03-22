#!/usr/bin/env bash

# Actualizador de Git Account Manager

set -e

GREEN=$'\033[0;32m'
BLUE=$'\033[0;34m'
YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'
NC=$'\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    Git Account Manager - Actualizador  ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Obtener directorio del script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Verificar que es un repositorio git
if [ ! -d "$SCRIPT_DIR/.git" ]; then
    echo -e "${RED}Error: No se encontró el repositorio git.${NC}"
    echo "Este script solo funciona si GAM fue instalado desde el repositorio."
    exit 1
fi

# Verificar conexión a internet
if ! git ls-remote --exit-code origin HEAD &> /dev/null; then
    echo -e "${RED}Error: No hay conexión al repositorio remoto${NC}"
    exit 1
fi

# Guardar cambios locales si existen
if ! git -C "$SCRIPT_DIR" diff --quiet; then
    echo -e "${YELLOW}Hay cambios locales en el repositorio.${NC}"
    read -p "¿Quieres guardarlos antes de actualizar? (s/n): " save_changes
    
    if [[ "$save_changes" =~ ^[sS] ]]; then
        timestamp=$(date +%Y%m%d_%H%M%S)
        git -C "$SCRIPT_DIR" stash push -m "backup_$timestamp"
        echo -e "${GREEN}✓ Cambios guardados temporalmente${NC}"
    fi
fi

# Obtener versión actual
CURRENT_VERSION=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo "unknown")
echo -e "${BLUE}Versión actual: ${CURRENT_VERSION}${NC}"

# Actualizar repositorio
echo -e "${BLUE}Actualizando repositorio...${NC}"
git -C "$SCRIPT_DIR" pull origin main

# Obtener nueva versión
NEW_VERSION=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD)
echo -e "${GREEN}Nueva versión: ${NEW_VERSION}${NC}"

# Reinstalar
echo -e "${BLUE}Reinstalando GAM...${NC}"
"$SCRIPT_DIR/install.sh"

echo ""
echo -e "${GREEN}✓ Actualización completada${NC}"