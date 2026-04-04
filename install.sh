#!/usr/bin/env bash

# Instalador de Git Account Manager
# Funciona local (bash install.sh) y remoto (curl ... | bash)

set -e

REPO_URL="https://github.com/lacasoft/git-account-manager"
INSTALL_DIR="/usr/local/bin"
GAM_HOME="$HOME/.gam"
SCRIPT_NAME="gam"

# Colores
GREEN=$'\033[0;32m'
BLUE=$'\033[0;34m'
YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

# Detección de OS
GAM_OS="linux"
case "$(uname -s)" in Darwin*) GAM_OS="macos" ;; esac

echo ""
echo -e "${BLUE}  ██████╗  █████╗ ███╗   ███╗${NC}"
echo -e "${BLUE} ██╔════╝ ██╔══██╗████╗ ████║${NC}"
echo -e "${BLUE} ██║  ███╗███████║██╔████╔██║${NC}"
echo -e "${BLUE} ██║   ██║██╔══██║██║╚██╔╝██║${NC}"
echo -e "${BLUE} ╚██████╔╝██║  ██║██║ ╚═╝ ██║${NC}"
echo -e "${BLUE}  ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝${NC}"
echo -e "${CYAN}  Instalador — v1.0.0${NC}"
echo ""

# Detectar si estamos en modo local o remoto
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" 2>/dev/null && pwd 2>/dev/null)" || SCRIPT_DIR=""
IS_REMOTE=false

if [ -z "$SCRIPT_DIR" ] || [ ! -f "$SCRIPT_DIR/gam" ]; then
    IS_REMOTE=true
fi

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
    if [ "$GAM_OS" = "macos" ]; then
        echo "Instálalas con: brew install ${MISSING_DEPS[*]}"
    else
        echo "Instálalas con: sudo apt install ${MISSING_DEPS[*]}"
    fi
    exit 1
fi
echo -e "${GREEN}✓ Todas las dependencias están instaladas${NC}"

# Detectar sistema operativo
if [ "$GAM_OS" = "macos" ]; then
    echo -e "${GREEN}✓ Sistema detectado: macOS${NC}"
else
    echo -e "${GREEN}✓ Sistema detectado: Linux${NC}"
fi
echo ""

# Si es instalación remota, clonar el repo primero
if [ "$IS_REMOTE" = true ]; then
    echo -e "${BLUE}Descargando GAM...${NC}"
    TMPDIR=$(mktemp -d)
    git clone --depth 1 "$REPO_URL.git" "$TMPDIR" 2>/dev/null
    SCRIPT_DIR="$TMPDIR"
    echo -e "${GREEN}✓ Descargado${NC}"
fi

# Verificar permisos de sudo
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

# Detectar shell del usuario
SHELL_RC=""
if [ -n "$ZSH_VERSION" ] || [[ "$SHELL" == */zsh ]]; then
    SHELL_RC="$HOME/.zshrc"
elif [ -f "$HOME/.bashrc" ]; then
    SHELL_RC="$HOME/.bashrc"
fi

if [ -n "$SHELL_RC" ] && [ -f "$GAM_HOME/completions/gam-completion.bash" ]; then
    COMPLETION_SOURCE="source $GAM_HOME/completions/gam-completion.bash"
    if ! grep -q "gam-completion.bash" "$SHELL_RC" 2>/dev/null; then
        echo "" >> "$SHELL_RC"
        echo "# Git Account Manager completion" >> "$SHELL_RC"
        echo "$COMPLETION_SOURCE" >> "$SHELL_RC"
        echo -e "${GREEN}✓ Autocompletado agregado a $SHELL_RC${NC}"
    else
        echo -e "${GREEN}✓ Autocompletado ya configurado${NC}"
    fi
fi

# Limpiar si fue instalación remota
if [ "$IS_REMOTE" = true ] && [ -n "$TMPDIR" ]; then
    rm -rf "$TMPDIR"
fi

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║${NC}   ✅  ${CYAN}Instalación completada${NC}              ${GREEN}║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo -e "  Para comenzar:"
echo -e "    ${YELLOW}gam add${NC}          Agregar tu primera cuenta"
echo -e "    ${YELLOW}gam list${NC}         Listar cuentas configuradas"
echo -e "    ${YELLOW}gam help${NC}         Ver todos los comandos"
echo ""
echo -e "  Para autocompletado inmediato:"
echo -e "    ${YELLOW}source ${SHELL_RC:-~/.bashrc}${NC}"
echo ""
