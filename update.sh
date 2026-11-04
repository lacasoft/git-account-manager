#!/usr/bin/env bash

# Actualizador de Git Account Manager (desde un clon del repositorio)
#
# Trae los últimos cambios de la rama actual y reinstala.
# Si instalaste con el one-liner (sin clon), usa: gam upgrade

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
if ! git -C "$SCRIPT_DIR" rev-parse --is-inside-work-tree &> /dev/null; then
    echo -e "${RED}Error: $SCRIPT_DIR no es un clon del repositorio de GAM.${NC}"
    echo "Si instalaste con el one-liner, actualiza con: gam upgrade"
    exit 1
fi

BRANCH=$(git -C "$SCRIPT_DIR" rev-parse --abbrev-ref HEAD)

# Verificar conexión con el remoto
if ! git -C "$SCRIPT_DIR" ls-remote --exit-code origin "$BRANCH" &> /dev/null; then
    echo -e "${RED}Error: no se pudo acceder a la rama '$BRANCH' en el remoto origin${NC}"
    exit 1
fi

# Guardar cambios locales si existen
STASHED=false
if ! git -C "$SCRIPT_DIR" diff --quiet || ! git -C "$SCRIPT_DIR" diff --cached --quiet; then
    echo -e "${YELLOW}Hay cambios locales en el repositorio.${NC}"
    read -p "¿Quieres guardarlos (git stash) antes de actualizar? (s/n): " save_changes

    if [[ "$save_changes" =~ ^[sS] ]]; then
        git -C "$SCRIPT_DIR" stash push -m "gam-update-$(date +%Y%m%d_%H%M%S)"
        STASHED=true
        echo -e "${GREEN}✓ Cambios guardados temporalmente${NC}"
    fi
fi

# Versión actual
CURRENT_VERSION=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD)
echo -e "${BLUE}Versión actual: ${CURRENT_VERSION} (${BRANCH})${NC}"

# Actualizar repositorio (solo fast-forward: nunca crea merges)
echo -e "${BLUE}Actualizando repositorio...${NC}"
git -C "$SCRIPT_DIR" pull --ff-only origin "$BRANCH"

NEW_VERSION=$(git -C "$SCRIPT_DIR" rev-parse --short HEAD)
if [ "$NEW_VERSION" = "$CURRENT_VERSION" ]; then
    echo -e "${GREEN}✓ El repositorio ya estaba al día${NC}"
else
    echo -e "${GREEN}Nueva versión: ${NEW_VERSION}${NC}"
fi

# Reinstalar (también si ya estaba al día: sincroniza ~/.gam con el repo)
echo -e "${BLUE}Reinstalando GAM...${NC}"
bash "$SCRIPT_DIR/install.sh"

if [ "$STASHED" = true ]; then
    echo -e "${YELLOW}Tus cambios locales están en el stash. Recupéralos con:${NC}"
    echo "  git -C \"$SCRIPT_DIR\" stash pop"
fi

echo ""
echo -e "${GREEN}✓ Actualización completada${NC}"
