#!/usr/bin/env bash

# Instalador de Git Account Manager

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="/usr/local/bin"
GAM_HOME="$HOME/.gam"
SCRIPT_NAME="gam"

# Colores
GREEN=$'\033[0;32m'
BLUE=$'\033[0;34m'
YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'
NC=$'\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    Git Account Manager - Instalador    ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verificar dependencias
echo -e "${BLUE}Verificando dependencias...${NC}"
MISSING_DEPS=()

if ! command -v git &> /dev/null; then
    MISSING_DEPS+=("git")
fi

if ! command -v ssh &> /dev/null; then
    MISSING_DEPS+=("ssh")
fi

if [ ${#MISSING_DEPS[@]} -gt 0 ]; then
    echo -e "${RED}Faltan dependencias: ${MISSING_DEPS[*]}${NC}"
    echo "Instálalas con: sudo apt install ${MISSING_DEPS[*]}"
    exit 1
fi
echo -e "${GREEN}✓ Todas las dependencias están instaladas${NC}"
echo ""

# Verificar si tiene permisos de sudo
if [ ! -w "$INSTALL_DIR" ]; then
    echo -e "${YELLOW}Se necesitan permisos para instalar en $INSTALL_DIR${NC}"
    SUDO="sudo"
else
    SUDO=""
fi

# Copiar script principal
echo -e "${BLUE}Instalando $SCRIPT_NAME...${NC}"
$SUDO cp "$SCRIPT_DIR/gam" "$INSTALL_DIR/$SCRIPT_NAME"
$SUDO chmod +x "$INSTALL_DIR/$SCRIPT_NAME"
echo -e "${GREEN}✓ $SCRIPT_NAME instalado en $INSTALL_DIR${NC}"

# Instalar librerías, templates y completions en ~/.gam
echo -e "${BLUE}Instalando archivos de soporte en $GAM_HOME...${NC}"
mkdir -p "$GAM_HOME/lib" "$GAM_HOME/templates" "$GAM_HOME/completions"
cp "$SCRIPT_DIR/lib/"*.sh "$GAM_HOME/lib/"
cp "$SCRIPT_DIR/templates/"* "$GAM_HOME/templates/"
cp "$SCRIPT_DIR/completions/"* "$GAM_HOME/completions/"
echo -e "${GREEN}✓ Archivos instalados en $GAM_HOME${NC}"

# Configurar autocompletado
echo ""
echo -e "${BLUE}Configurando autocompletado...${NC}"
COMPLETION_FILE="$HOME/.bashrc"
COMPLETION_SOURCE="source $GAM_HOME/completions/gam-completion.bash"

if [ -f "$GAM_HOME/completions/gam-completion.bash" ]; then
    if ! grep -q "gam-completion.bash" "$COMPLETION_FILE" 2>/dev/null; then
        echo "" >> "$COMPLETION_FILE"
        echo "# Git Account Manager completion" >> "$COMPLETION_FILE"
        echo "$COMPLETION_SOURCE" >> "$COMPLETION_FILE"
        echo -e "${GREEN}✓ Autocompletado agregado a $COMPLETION_FILE${NC}"
        echo -e "${YELLOW}  Para usar autocompletado, ejecuta: source $COMPLETION_FILE${NC}"
    else
        echo -e "${GREEN}✓ Autocompletado ya configurado${NC}"
    fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}    Instalación completada exitosamente  ${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Para comenzar, ejecuta:${NC}"
echo "  gam add          # Agregar tu primera cuenta"
echo "  gam list         # Listar cuentas configuradas"
echo "  gam help         # Ver todos los comandos"
echo ""
echo -e "${BLUE}Para autocompletado inmediato:${NC}"
echo "  source ~/.bashrc"
echo ""