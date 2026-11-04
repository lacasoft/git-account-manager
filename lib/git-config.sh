#!/usr/bin/env bash

# Usar template para Git config
use_git_template() {
    local username="$1"
    local email="$2"
    local template_file="${TEMPLATES_DIR:-$SCRIPT_DIR/templates}/gitconfig.template"
    
    if [ -f "$template_file" ]; then
        sed -e "s/{{USERNAME}}/$username/g" \
            -e "s/{{EMAIL}}/$email/g" \
            "$template_file"
    else
        # Fallback si no existe template
        cat << EOF
[user]
    name = $username
    email = $email

[init]
    defaultBranch = main

[core]
    autocrlf = input
    editor = nano

[color]
    ui = auto

[alias]
    co = checkout
    br = branch
    st = status
    ci = commit
    lg = log --oneline --graph --all
    unstage = reset HEAD --
    last = log -1 HEAD
    tree = log --graph --oneline --all

[push]
    default = simple
    autoSetupRemote = true

[fetch]
    prune = true

[merge]
    conflictstyle = diff3
EOF
    fi
}

# Crear configuración de Git para cuenta
create_git_config() {
    local account_name="$1"
    local email="$2"
    local username="$3"
    local project_folder="$4"
    
    local git_config_file="$HOME/.gitconfig-$account_name"
    
    # Crear configuración usando template
    use_git_template "$username" "$email" > "$git_config_file"
    
    chmod 644 "$git_config_file"
    log_success "Configuración Git creada: $git_config_file"
    
    # Agregar includeIf si se especificó carpeta
    if [ -n "$project_folder" ]; then
        add_include_if "$project_folder" "$git_config_file" || true
    fi
}

# Asociar una carpeta a un perfil Git con includeIf en ~/.gitconfig
add_include_if() {
    local folder
    folder=$(abs_path "$1")
    local git_config_file="$2"

    # Crear la carpeta solo si el usuario lo confirma: así se detectan
    # respuestas por error (p.ej. "s") antes de escribir un includeIf inútil
    if [ ! -d "$folder" ]; then
        if confirm "La carpeta '$folder' no existe. ¿Crearla?"; then
            mkdir -p "$folder"
            log_success "Carpeta creada: $folder"
        else
            log_warning "No se configuró la carpeta $folder"
            return 1
        fi
    fi

    local key="includeIf.gitdir:$folder/.path"
    local current
    current=$(git config --global --get "$key" 2>/dev/null || true)

    if [ -z "$current" ]; then
        git config --global "$key" "$git_config_file"
        log_success "Configuración automática para $folder/"
    elif [ "${current/#\~/$HOME}" = "$git_config_file" ]; then
        log_info "La carpeta $folder/ ya usa este perfil"
    else
        log_warning "La carpeta $folder/ ya está asignada a otro perfil: $current"
        return 1
    fi
}

# Listar las condiciones includeIf (p.ej. "gitdir:/code/x/") que usan un perfil
get_profile_includes() {
    local profile="$1"
    local entry key value

    git config --global --null --get-regexp '^includeif\..*\.path$' 2>/dev/null |
    while IFS= read -r -d '' entry; do
        key="${entry%%$'\n'*}"
        value="${entry#*$'\n'}"
        [ "${value/#\~/$HOME}" = "$profile" ] || continue
        key="${key#includeif.}"
        echo "${key%.path}"
    done
}

# Cambiar configuración Git global
switch_git_config() {
    local account_name="$1"
    local git_config_file="$HOME/.gitconfig-$account_name"
    
    if [ ! -f "$git_config_file" ]; then
        log_error "No existe configuración para la cuenta '$account_name'"
        echo "Ejecuta 'gam add' para crear la configuración"
        return 1
    fi
    
    # Guardar configuración actual como backup
    if [ -f "$HOME/.gitconfig" ]; then
        cp "$HOME/.gitconfig" "$HOME/.gitconfig.backup.$(date +%Y%m%d_%H%M%S)"
        log_info "Backup de configuración actual creado"
    fi

    # Leer nombre y email del archivo de configuración de la cuenta
    local user_name user_email
    user_name=$(git config --file "$git_config_file" user.name 2>/dev/null)
    user_email=$(git config --file "$git_config_file" user.email 2>/dev/null)

    if [ -z "$user_name" ] || [ -z "$user_email" ]; then
        log_error "No se pudo leer el nombre/email de $git_config_file"
        return 1
    fi

    # Actualizar solo la sección [user] sin tocar los includeIf existentes
    git config --global user.name "$user_name"
    git config --global user.email "$user_email"

    log_success "Configuración Git cambiada a $account_name"
    log_info "Usuario: $user_name"
    log_info "Email: $user_email"
}

# Configurar Git automático por carpeta
setup_auto_git_config() {
    local folder="$1"
    
    if [ -z "$folder" ]; then
        log_error "Uso: gam use <carpeta>"
        echo "Ejemplo: gam use /code/personal"
        return 1
    fi
    
    # Ruta absoluta (una relativa como "s/" haría que Git la aplique a
    # cualquier carpeta con ese nombre)
    folder=$(abs_path "$folder")
    
    # Verificar que la carpeta existe o crearla
    if [ ! -d "$folder" ]; then
        read -p "La carpeta '$folder' no existe. ¿Crearla? (s/n): " create_folder
        if [[ "$create_folder" =~ ^[sS] ]]; then
            mkdir -p "$folder"
            log_success "Carpeta creada: $folder"
        else
            return 1
        fi
    fi
    
    # Listar cuentas disponibles
    local accounts=($(get_ssh_accounts))
    
    if [ ${#accounts[@]} -eq 0 ]; then
        log_error "No hay cuentas configuradas. Ejecuta 'gam add' primero."
        return 1
    fi
    
    echo -e "${BLUE}Cuentas disponibles:${NC}"
    for i in "${!accounts[@]}"; do
        echo "$((i+1))) ${accounts[$i]}"
    done
    
    echo ""
    read -p "Selecciona el número de cuenta: " account_num
    
    if [[ "$account_num" =~ ^[0-9]+$ ]] && [ "$account_num" -ge 1 ] && [ "$account_num" -le ${#accounts[@]} ]; then
        local selected_account="${accounts[$((account_num-1))]}"
        local git_config_file="$HOME/.gitconfig-$selected_account"
        
        if [ ! -f "$git_config_file" ]; then
            log_warning "No hay configuración Git para $selected_account"
            read -p "¿Quieres crearla ahora? (s/n): " create_it
            if [[ "$create_it" =~ ^[sS] ]]; then
                read -p "Email: " email
                read -p "Username: " username
                create_git_config "$selected_account" "$email" "$username" ""
            else
                return 1
            fi
        fi
        
        add_include_if "$folder" "$git_config_file"
    else
        log_error "Selección inválida"
    fi
}