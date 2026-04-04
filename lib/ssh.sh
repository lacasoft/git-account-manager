#!/usr/bin/env bash

# Generar clave SSH
generate_ssh_key() {
    local account_name="$1"
    local email="$2"
    local ssh_key_file="$HOME/.ssh/id_ed25519_$account_name"
    
    log_info "Generando clave SSH para $account_name..."
    
    if [ -f "$ssh_key_file" ]; then
        log_warning "La clave ya existe: $ssh_key_file"
        if ! confirm "¿Deseas sobrescribirla?"; then
            return 1
        fi
    fi
    
    # Crear directorio .ssh si no existe
    ensure_dir "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    
    ssh-keygen -t ed25519 -C "$email" -f "$ssh_key_file" -N "" -q
    chmod 600 "$ssh_key_file"
    chmod 644 "$ssh_key_file.pub"
    log_success "Clave generada: $ssh_key_file"
    
    # Agregar al agente SSH (iniciar uno si no hay ninguno activo)
    if [ -z "$SSH_AUTH_SOCK" ]; then
        eval "$(ssh-agent -s)" > /dev/null 2>&1
    fi

    if [ "$GAM_OS" = "macos" ]; then
        ssh-add --apple-use-keychain "$ssh_key_file" 2>/dev/null
        log_success "Clave agregada al agente SSH (keychain de macOS)"
    else
        ssh-add "$ssh_key_file" 2>/dev/null
        log_success "Clave agregada al agente SSH"
    fi

    echo "$ssh_key_file"
}

# Usar template para SSH config
use_ssh_template() {
    local account_name="$1"
    local ssh_key_file="$2"
    local template_file="${TEMPLATES_DIR:-$SCRIPT_DIR/templates}/ssh-config.template"
    
    local keychain_line=""
    if [ "$GAM_OS" = "macos" ]; then
        keychain_line="    UseKeychain yes
    AddKeysToAgent yes"
    fi

    if [ -f "$template_file" ]; then
        local output
        output=$(sed -e "s/{{ACCOUNT_NAME}}/$account_name/g" \
            -e "s|{{SSH_KEY_PATH}}|$ssh_key_file|g" \
            "$template_file")
        echo "$output"
        if [ -n "$keychain_line" ]; then
            echo "$keychain_line"
        fi
    else
        # Fallback si no existe template
        cat << EOF

# Cuenta: $account_name
Host github.com-$account_name
    HostName github.com
    User git
    IdentityFile $ssh_key_file
    IdentitiesOnly yes${keychain_line:+
$keychain_line}
    ServerAliveInterval 60
    ServerAliveCountMax 3
    Compression yes
    ForwardAgent no
EOF
    fi
}

# Configurar SSH config
configure_ssh() {
    local account_name="$1"
    local ssh_host="github.com-$account_name"
    local ssh_key_file="$HOME/.ssh/id_ed25519_$account_name"
    
    log_info "Configurando SSH..."
    
    # Backup
    if [ -f "$HOME/.ssh/config" ]; then
        cp "$HOME/.ssh/config" "$HOME/.ssh/config.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    fi
    
    # Agregar configuración usando template
    use_ssh_template "$account_name" "$ssh_key_file" >> "$HOME/.ssh/config"
    
    chmod 600 "$HOME/.ssh/config"
    log_success "SSH configurado: $ssh_host"
    
    echo "$ssh_host"
}

# Probar conexión SSH
test_ssh_connection() {
    local ssh_host="$1"
    local account_name="$2"
    
    log_info "Probando conexión para $account_name..."
    
    local output
    output=$(ssh -T "$ssh_host" 2>&1) || true
    if echo "$output" | grep -q "successfully authenticated"; then
        log_success "Conexión exitosa para $account_name"
        return 0
    fi
    
    # Verificar si es por huella digital no conocida
    if echo "$output" | grep -q "authenticity of host"; then
        log_warning "Es la primera vez que te conectas a GitHub"
        echo -e "${YELLOW}¿Quieres aceptar la huella digital de GitHub? (yes/no)${NC}"
        read -r response
        if [ "$response" = "yes" ]; then
            ssh-keyscan github.com >> ~/.ssh/known_hosts 2>/dev/null
            log_success "GitHub agregado a known_hosts"
            # Reintentar
            if ssh -T "$ssh_host" 2>&1 | grep -q "successfully authenticated"; then
                log_success "Conexión exitosa para $account_name"
                return 0
            fi
        fi
    fi
    
    log_error "No se pudo conectar para $account_name"
    return 1
}

# Obtener lista de cuentas SSH
get_ssh_accounts() {
    local accounts=()
    while IFS= read -r line; do
        if [[ $line =~ ^#\ Cuenta:\ (.+)$ ]]; then
            accounts+=("${BASH_REMATCH[1]}")
        fi
    done < "$HOME/.ssh/config" 2>/dev/null
    echo "${accounts[@]}"
}