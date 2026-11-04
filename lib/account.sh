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
    if account_exists "$account_name"; then
        log_error "La cuenta '$account_name' ya existe"
        echo ""
        echo "  Si el alta quedó a medias o quieres cambiar algo:"
        echo -e "    ${YELLOW}gam check $account_name${NC}    ver qué le falta"
        echo -e "    ${YELLOW}gam update $account_name${NC}   cambiar email, usuario, carpeta o clave"
        echo -e "    ${YELLOW}gam remove $account_name${NC}   eliminarla y empezar de nuevo"
        echo ""
        return 1
    fi
    
    # Generar clave SSH
    local ssh_key_file
    ssh_key_file=$(generate_ssh_key "$account_name" "$email") || return 1
    
    # Configurar SSH
    local ssh_host
    ssh_host=$(configure_ssh "$account_name") || return 1
    
    # Mostrar clave pública e instrucciones
    show_key_instructions "$account_name" "$username" "$ssh_key_file"
    log_info "Si interrumpes este paso, retómalo luego con: gam check $account_name"
    
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
        log_info "Cuando agregues la clave, verifica con: gam check $account_name"
    fi
    
    log_success "Cuenta $account_name agregada exitosamente"
    echo ""
    echo "Para clonar repositorios:"
    echo "  git clone git@$ssh_host:$username/repo.git"
    echo ""
    echo "O usa:"
    echo "  gam clone $account_name $username/repo"
}

# Actualizar cuenta existente
update_account() {
    local account_name=""
    local email=""
    local username=""
    local folder=""
    local new_key=false
    local interactive=true

    while [[ $# -gt 0 ]]; do
        case $1 in
            --email)    email="$2";    interactive=false; shift 2 ;;
            --username) username="$2"; interactive=false; shift 2 ;;
            --folder)   folder="$2";   interactive=false; shift 2 ;;
            --new-key)  new_key=true;  interactive=false; shift ;;
            -*)
                log_error "Opción desconocida: $1"
                return 1
                ;;
            *)
                account_name="$1"
                shift
                ;;
        esac
    done

    if [ -z "$account_name" ]; then
        log_error "Uso: gam update <cuenta> [--email X] [--username X] [--folder X] [--new-key]"
        return 1
    fi

    if ! account_exists "$account_name"; then
        log_error "La cuenta '$account_name' no existe"
        echo "Ejecuta 'gam list' para ver las cuentas disponibles"
        return 1
    fi

    local git_config_file="$HOME/.gitconfig-$account_name"
    local ssh_key_file="$HOME/.ssh/id_ed25519_$account_name"

    # Valores actuales: perfil Git y, como respaldo, el comentario de la clave
    local cur_name="" cur_email="" key_email=""
    if [ -f "$git_config_file" ]; then
        cur_name=$(git config --file "$git_config_file" user.name 2>/dev/null || true)
        cur_email=$(git config --file "$git_config_file" user.email 2>/dev/null || true)
    fi
    if [ -f "${ssh_key_file}.pub" ]; then
        key_email=$(awk '{print $3}' "${ssh_key_file}.pub")
    fi

    if [ "$interactive" = true ]; then
        echo ""
        echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║${NC}   ✏️   ${CYAN}Actualizar cuenta de GitHub${NC}       ${BLUE}║${NC}"
        echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "  ${GREEN}📁 $account_name${NC}"
        echo -e "  ${CYAN}Deja vacío para mantener el valor actual.${NC}"
        if [ ! -f "$git_config_file" ]; then
            echo -e "  ${YELLOW}⚠️  Aún no tiene perfil Git: indica email y usuario para crearlo.${NC}"
        fi
        echo ""

        read -p "  📧  Email [${cur_email:-$key_email}]: " email
        read -p "  🐙  Usuario en GitHub [${cur_name}]: " username

        local includes
        includes=$(get_profile_includes "$git_config_file")
        if [ -n "$includes" ]; then
            echo "  📂  Carpetas actuales:"
            echo "$includes" | sed 's/^/        /'
        fi
        read -p "  📂  Agregar carpeta de proyectos (vacío para omitir): " folder
        echo ""

        log_warning "Regenerar la clave invalida la actual: tendrás que registrar la nueva en GitHub"
        if confirm "  🔑  ¿Regenerar la clave SSH?"; then
            new_key=true
        fi
        echo ""
    elif [ "$new_key" = true ]; then
        log_warning "Regenerar la clave invalida la actual: tendrás que registrar la nueva en GitHub"
        if ! confirm "¿Regenerar la clave SSH de '$account_name'?"; then
            new_key=false
        fi
    fi

    local email_input="$email"
    email="${email:-${cur_email:-$key_email}}"
    username="${username:-$cur_name}"

    local changes=0

    # 1) Perfil Git
    if [ ! -f "$git_config_file" ]; then
        if [ -n "$email" ] && [ -n "$username" ]; then
            create_git_config "$account_name" "$email" "$username" ""
            changes=$((changes + 1))
        elif [ -n "$folder" ]; then
            log_error "Para asignar una carpeta primero hace falta un perfil Git: indica email y usuario"
            return 1
        fi
    else
        if [ "$username" != "$cur_name" ]; then
            git config --file "$git_config_file" user.name "$username"
            log_success "Usuario actualizado: $username"
            changes=$((changes + 1))
        fi
        if [ "$email" != "$cur_email" ]; then
            git config --file "$git_config_file" user.email "$email"
            log_success "Email actualizado: $email"
            changes=$((changes + 1))
        fi
    fi

    # Si cambió el email, actualizar también el comentario de la clave pública
    # (la clave es la misma, GitHub la sigue reconociendo)
    if [ "$new_key" = false ] && [ -n "$email_input" ] && [ -f "$ssh_key_file" ] && [ "$email_input" != "$key_email" ]; then
        if ssh-keygen -c -C "$email" -P "" -f "$ssh_key_file" >/dev/null 2>&1; then
            log_success "Comentario de la clave SSH actualizado"
        fi
    fi

    # 2) Carpeta de proyectos
    if [ -n "$folder" ]; then
        if add_include_if "$folder" "$git_config_file"; then
            changes=$((changes + 1))
        fi
    fi

    # 3) Nueva clave SSH
    if [ "$new_key" = true ]; then
        validate_not_empty "$email" "Email" || return 1

        if [ -f "$ssh_key_file" ]; then
            local backup_suffix
            backup_suffix="bak.$(date +%Y%m%d_%H%M%S)"
            ssh-add -d "$ssh_key_file" >/dev/null 2>&1 || true
            mv "$ssh_key_file" "$ssh_key_file.$backup_suffix"
            [ -f "${ssh_key_file}.pub" ] && mv "${ssh_key_file}.pub" "${ssh_key_file}.pub.$backup_suffix"
            log_info "Clave anterior respaldada en ${ssh_key_file}.$backup_suffix"
        fi

        generate_ssh_key "$account_name" "$email" >/dev/null || return 1
        changes=$((changes + 1))

        show_key_instructions "$account_name" "$username" "$ssh_key_file"
        log_info "Elimina también la clave anterior de GitHub (mismo título: $account_name)"
        echo ""

        read -p "¿Ya agregaste la clave en GitHub? (s/n): " key_added
        if [[ "$key_added" =~ ^[sS] ]]; then
            test_ssh_connection "github.com-$account_name" "$account_name" || true
        else
            log_info "Cuando agregues la clave, verifica con: gam check $account_name"
        fi
    fi

    echo ""
    if [ "$changes" -eq 0 ]; then
        log_info "No hubo cambios en '$account_name'"
    else
        log_success "Cuenta $account_name actualizada"
        log_info "Revisa su estado con: gam check $account_name"
    fi
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
    if ! account_exists "$account_name"; then
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
        cp "$HOME/.ssh/config" "$HOME/.ssh/config.backup.$(date +%Y%m%d_%H%M%S)"
        remove_ssh_block "$account_name"
        log_success "Configuración SSH eliminada"
    fi
    
    # Eliminar configuración de Git
    local git_config="$HOME/.gitconfig-$account_name"
    if [ -f "$git_config" ]; then
        rm -f "$git_config"
        log_success "Configuración Git eliminada"
        
        # Eliminar includeIf de .gitconfig
        if [ -f "$HOME/.gitconfig" ]; then
            sed_inplace "\|path = $git_config|d" "$HOME/.gitconfig" 2>/dev/null
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
    if ! account_exists "$account_name"; then
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