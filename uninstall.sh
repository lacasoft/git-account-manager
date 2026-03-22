#!/usr/bin/env bash

# Desinstalador de Git Account Manager

set -e

# Colores
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}    Git Account Manager - Desinstalador ${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verificar si está instalado
INSTALL_DIR="/usr/local/bin"
SCRIPT_NAME="gam"

if [ ! -f "$INSTALL_DIR/$SCRIPT_NAME" ]; then
    echo -e "${YELLOW}GAM no está instalado en $INSTALL_DIR/$SCRIPT_NAME${NC}"
else
    echo -e "${YELLOW}Se eliminará GAM del sistema${NC}"
    if [ -w "$INSTALL_DIR" ]; then
        rm "$INSTALL_DIR/$SCRIPT_NAME"
    else
        sudo rm "$INSTALL_DIR/$SCRIPT_NAME"
    fi
    echo -e "${GREEN}✓ GAM eliminado de $INSTALL_DIR${NC}"
fi

# Preguntar si quiere eliminar configuraciones
echo ""
echo -e "${YELLOW}¿Deseas eliminar también las configuraciones de cuentas?${NC}"
echo -e "${YELLOW}Esto eliminará:${NC}"
echo "  - Claves SSH (~/.ssh/id_ed25519_*)"
echo "  - Configuración SSH (~/.ssh/config)"
echo "  - Configuraciones de Git (~/.gitconfig-*)"
echo "  - Directorio ~/.gam"
echo ""
read -p "¿Eliminar todas las configuraciones? (s/n): " remove_configs

if [[ "$remove_configs" =~ ^[sS] ]]; then
    echo ""
    echo -e "${BLUE}Eliminando configuraciones...${NC}"
    
    # Eliminar claves SSH de GAM
    if [ -d "$HOME/.ssh" ]; then
        echo "Eliminando claves SSH..."
        rm -f "$HOME/.ssh/id_ed25519_"* 2>/dev/null || true
        
        # Hacer backup del config original
        if [ -f "$HOME/.ssh/config" ]; then
            cp "$HOME/.ssh/config" "$HOME/.ssh/config.backup.$(date +%Y%m%d_%H%M%S)"
            echo "Backup de SSH config guardado en ~/.ssh/config.backup.*"
            
            # Eliminar solo las líneas de GAM
            sed -i '/# Cuenta:/,+9d' "$HOME/.ssh/config" 2>/dev/null || true
            
            # Si el archivo quedó vacío, eliminarlo
            if [ ! -s "$HOME/.ssh/config" ]; then
                rm "$HOME/.ssh/config"
            fi
        fi
        echo -e "${GREEN}✓ Configuración SSH limpiada${NC}"
    fi
    
    # Eliminar configuraciones de Git de GAM
    echo "Eliminando configuraciones de Git..."
    rm -f "$HOME/.gitconfig-"* 2>/dev/null || true
    
    # Limpiar includes de .gitconfig
    if [ -f "$HOME/.gitconfig" ]; then
        # Hacer backup
        cp "$HOME/.gitconfig" "$HOME/.gitconfig.backup.$(date +%Y%m%d_%H%M%S)"
        
        # Eliminar líneas de includeIf de GAM
        sed -i '/includeIf.*gitdir:/d' "$HOME/.gitconfig" 2>/dev/null || true
        sed -i '\|path = .*/.gitconfig-|d' "$HOME/.gitconfig" 2>/dev/null || true
        
        echo -e "${GREEN}✓ Configuración Git limpiada${NC}"
    fi
    
    # Eliminar directorio .gam
    if [ -d "$HOME/.gam" ]; then
        rm -rf "$HOME/.gam"
        echo -e "${GREEN}✓ Directorio ~/.gam eliminado${NC}"
    fi
    
    echo ""
    echo -e "${GREEN}✓ Todas las configuraciones han sido eliminadas${NC}"
else
    echo ""
    echo -e "${YELLOW}Configuraciones conservadas. Puedes eliminarlas manualmente después.${NC}"
fi

# Eliminar autocompletado de .bashrc
if [ -f "$HOME/.bashrc" ]; then
    if grep -q "gam-completion.bash" "$HOME/.bashrc" 2>/dev/null; then
        sed -i '/# Git Account Manager completion/d' "$HOME/.bashrc"
        sed -i '/gam-completion.bash/d' "$HOME/.bashrc"
        echo -e "${GREEN}✓ Autocompletado eliminado de .bashrc${NC}"
    fi
fi

# Preguntar si quiere eliminar el repositorio
echo ""
echo -e "${YELLOW}¿Deseas eliminar el repositorio de GAM?${NC}"
echo -e "${YELLOW}(Esto eliminará el directorio actual)${NC}"
read -p "¿Eliminar repositorio? (s/n): " remove_repo

if [[ "$remove_repo" =~ ^[sS] ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    cd ..
    rm -rf "$SCRIPT_DIR"
    echo -e "${GREEN}✓ Repositorio de GAM eliminado${NC}"
fi

echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Desinstalación completada${NC}"
echo -e "${BLUE}========================================${NC}"