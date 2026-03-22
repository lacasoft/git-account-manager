#!/usr/bin/env bash

# Agregar cuenta
add_account() {
    local account_name=""
    local email=""
    local username=""
    
    # Parsear argumentos
    while [[ $# -gt 0 ]]; do
        case $1 in
            --name)
                account_name="$2"
                shift 2
                ;;
            --email)
                email="$2"
                shift 2
                ;;
            --username)
                username="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done
    
    # Si no hay argumentos, modo interactivo
    if [ -z "$account_name" ]; then
        echo ""
        echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║${NC}   ➕  ${CYAN}Agregar nueva cuenta de GitHub${NC}   ${BLUE}║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
        echo ""

        read -p "  📛  Nombre de la cuenta (ej: trabajo, freelance): " account_name
        read -p "  📧  Email asociado a la cuenta: " email
        read -p "  🐙  Usuario en GitHub: " username
        echo ""
    fi
    
    # Validar
    validate_not_empty "$account_name" "Nombre de cuenta" || return 1
    validate_not_empty "$email" "Email" || return 1
    validate_not_empty "$username" "Usuario de GitHub" || return 1
    
    # Verificar que no exista
    if grep -q "# Cuenta: $account_name" "$HOME/.ssh/config" 2>/dev/null; then
        log_error "La cuenta '$account_name' ya existe"
        return 1
    fi
    
    # Generar clave SSH
    local ssh_key_file
    ssh_key_file=$(generate_ssh_key "$account_name" "$email") || return 1
    
    # Configurar SSH
    local ssh_host
    ssh_host=$(configure_ssh "$account_name") || return 1
    
    # Mostrar clave pública
    echo ""
    log_info "=== CLAVE PÚBLICA (agrega a GitHub) ==="
    cat "${ssh_key_file}.pub"
    echo "========================================="
    echo ""
    
    log_info "Pasos a seguir:"
    echo "1. Ve a https://github.com/settings/keys"
    echo "2. Inicia sesión como: $username"
    echo "3. Haz clic en 'New SSH key'"
    echo "4. Título: $account_name"
    echo "5. Tipo: Authentication Key"
    echo "6. Pega la clave pública mostrada arriba"
    echo "7. Haz clic en 'Add SSH key'"
    echo ""
    
    read -p "¿Ya agregaste la clave en GitHub? (s/n): " key_added
    
    if [[ "$key_added" =~ ^[sS] ]]; then
        test_ssh_connection "$ssh_host" "$account_name"
        
        # Preguntar si quiere configurar Git
        echo ""
        read -p "¿Quieres configurar Git para esta cuenta? (s/n): " setup_git
        if [[ "$setup_git" =~ ^[sS] ]]; then
            read -p "¿En qué carpeta estarán los proyectos? (ej: /code/$account_name): " project_folder
            if [ -n "$project_folder" ]; then
                create_git_config "$account_name" "$email" "$username" "$project_folder"
            fi
        fi
    else
        log_info "Cuando agregues la clave, prueba con: gam test $account_name"
    fi
    
    log_success "Cuenta $account_name agregada exitosamente"
    echo ""
    echo "Para clonar repositorios:"
    echo "  git clone git@$ssh_host:$username/repo.git"
    echo ""
    echo "O usa:"
    echo "  gam clone $account_name $username/repo"
}

# Listar cuentas
list_accounts() {
    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}   🔑  ${CYAN}Cuentas de GitHub configuradas${NC}   ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
    echo ""

    local count=0
    local account_name=""

    while IFS= read -r line; do
        if [[ $line =~ ^#\ Cuenta:\ (.+)$ ]]; then
            account_name="${BASH_REMATCH[1]}"
            count=$((count + 1))
        elif [[ $line =~ ^Host\ github.com-(.+)$ ]]; then
            local host="${BASH_REMATCH[1]}"
            local git_config="$HOME/.gitconfig-$host"

            echo -e "  ${GREEN}📁 ${account_name}${NC}"
            echo -e "  ${BLUE}├─${NC} 🔑  ${YELLOW}github.com-$host${NC}"

            if [ -f "$git_config" ]; then
                local user_name user_email
                user_name=$(git config --file "$git_config" user.name 2>/dev/null)
                user_email=$(git config --file "$git_config" user.email 2>/dev/null)
                echo -e "  ${BLUE}└─${NC} 👤  ${CYAN}$user_name${NC} <$user_email>"
            else
                echo -e "  ${BLUE}└─${NC} ⚠️   ${YELLOW}sin perfil Git — ejecuta: gam use <carpeta>${NC}"
            fi
            echo ""
        fi
    done < "$HOME/.ssh/config" 2>/dev/null

    if [ $count -eq 0 ]; then
        echo -e "  ${YELLOW}⚠️  No hay cuentas configuradas${NC}"
        echo -e "  Ejecuta ${GREEN}gam add${NC} para agregar tu primera cuenta"
        echo ""
    else
        echo -e "  ${BLUE}──────────────────────────────────────────${NC}"
        echo -e "  ${CYAN}Total: $count cuenta(s)${NC}"
        echo ""
    fi
}

# Eliminar cuenta
remove_account() {
    local account_name="$1"
    
    if [ -z "$account_name" ]; then
        echo -e "${RED}Error: Especifica el nombre de la cuenta${NC}"
        echo "Uso: gam remove <nombre>"
        return 1
    fi
    
    # Verificar que existe
    if ! grep -q "# Cuenta: $account_name" "$HOME/.ssh/config" 2>/dev/null; then
        log_error "La cuenta '$account_name' no existe"
        return 1
    fi
    
    echo -e "${YELLOW}¿Estás seguro de eliminar la cuenta '$account_name'?${NC}"
    if ! confirm; then
        return 0
    fi
    
    # Eliminar clave SSH
    local ssh_key="$HOME/.ssh/id_ed25519_$account_name"
    local ssh_key_pub="${ssh_key}.pub"
    
    if [ -f "$ssh_key" ]; then
        rm -f "$ssh_key" "$ssh_key_pub"
        log_success "Clave SSH eliminada"
    fi
    
    # Eliminar de SSH config
    if [ -f "$HOME/.ssh/config" ]; then
        sed -i "/# Cuenta: $account_name/,+9d" "$HOME/.ssh/config"
        log_success "Configuración SSH eliminada"
    fi
    
    # Eliminar configuración de Git
    local git_config="$HOME/.gitconfig-$account_name"
    if [ -f "$git_config" ]; then
        rm -f "$git_config"
        log_success "Configuración Git eliminada"
        
        # Eliminar includeIf de .gitconfig
        if [ -f "$HOME/.gitconfig" ]; then
            sed -i "\|path = $git_config|d" "$HOME/.gitconfig" 2>/dev/null
        fi
    fi
    
    log_success "Cuenta $account_name eliminada"
}

# Probar conexión
test_connection() {
    local account_name="$1"
    
    if [ -z "$account_name" ]; then
        # Probar todas
        log_info "Probando todas las cuentas..."
        local accounts=($(get_ssh_accounts))
        if [ ${#accounts[@]} -eq 0 ]; then
            log_warning "No hay cuentas configuradas"
            return 1
        fi
        for acc in "${accounts[@]}"; do
            test_ssh_connection "github.com-$acc" "$acc"
        done
    else
        test_ssh_connection "github.com-$account_name" "$account_name"
    fi
}

# Clonar repositorio
clone_repo() {
    local account_name="$1"
    local repo="$2"
    local destination="${3:-}"
    
    if [ -z "$account_name" ] || [ -z "$repo" ]; then
        log_error "Uso: gam clone <cuenta> <repo> [destino]"
        echo "Ejemplo: gam clone personal lacasoft/evvaApi"
        return 1
    fi
    
    # Verificar que la cuenta existe
    if ! grep -q "# Cuenta: $account_name" "$HOME/.ssh/config" 2>/dev/null; then
        log_error "La cuenta '$account_name' no existe"
        echo "Ejecuta 'gam list' para ver las cuentas disponibles"
        return 1
    fi
    
    local git_url="git@github.com-$account_name:$repo.git"
    
    log_info "Clonando $repo con cuenta $account_name..."
    
    if [ -n "$destination" ]; then
        git clone "$git_url" "$destination"
    else
        git clone "$git_url"
    fi
    
    log_success "Repositorio clonado exitosamente"
}

# Exportar configuración
export_config() {
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    echo "# Git Account Manager - Export $timestamp"
    echo "# ========================================"
    echo ""
    
    # Exportar SSH config
    if [ -f "$HOME/.ssh/config" ]; then
        echo "# SSH Config"
        echo "### SSH_CONFIG_START ###"
        cat "$HOME/.ssh/config"
        echo "### SSH_CONFIG_END ###"
        echo ""
    fi
    
    # Exportar Git configs
    for config in "$HOME"/.gitconfig-*; do
        if [ -f "$config" ]; then
            local account="${config##*/.gitconfig-}"
            echo "# Git Config: .gitconfig-$account"
            echo "### GIT_CONFIG_${account}###"
            cat "$config"
            echo "### GIT_CONFIG_END ###"
            echo ""
        fi
    done
    
    # Exportar includes de .gitconfig
    if [ -f "$HOME/.gitconfig" ]; then
        echo "# Git Global Includes"
        echo "### GIT_INCLUDES_START ###"
        grep "includeIf" "$HOME/.gitconfig" 2>/dev/null || true
        echo "### GIT_INCLUDES_END ###"
        echo ""
    fi
    
    log_success "Configuración exportada" >&2
}

# Importar configuración
import_config() {
    local file="$1"

    if [ -z "$file" ] || [ ! -f "$file" ]; then
        log_error "Archivo no encontrado: $file"
        echo "Uso: gam import <archivo>"
        return 1
    fi

    log_warning "Esto sobrescribirá configuraciones existentes"
    if ! confirm "¿Continuar?"; then
        return 0
    fi

    # Extraer SSH config
    if grep -q "### SSH_CONFIG_START ###" "$file"; then
        sed -n '/### SSH_CONFIG_START ###/,/### SSH_CONFIG_END ###/p' "$file" | \
            grep -v "### SSH_CONFIG" > "$HOME/.ssh/config.tmp"

        if [ -s "$HOME/.ssh/config.tmp" ]; then
            mv "$HOME/.ssh/config.tmp" "$HOME/.ssh/config"
            chmod 600 "$HOME/.ssh/config"
            log_success "SSH config importada"
        fi
    fi

    # Extraer Git configs — parsear marcadores línea a línea
    local config_name=""
    while IFS= read -r line; do
        if [[ $line =~ ^###\ GIT_CONFIG_(.+)###$ ]]; then
            config_name="${BASH_REMATCH[1]}"
            > "$HOME/.gitconfig-$config_name"
        elif [ "$line" = "### GIT_CONFIG_END ###" ]; then
            if [ -n "$config_name" ]; then
                chmod 644 "$HOME/.gitconfig-$config_name"
                log_success "Config Git importada: .gitconfig-$config_name"
            fi
            config_name=""
        elif [ -n "$config_name" ]; then
            echo "$line" >> "$HOME/.gitconfig-$config_name"
        fi
    done < "$file"

    log_success "Configuración importada"
    log_info "Revisa las configuraciones con: gam list"
}