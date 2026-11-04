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
        # Solo desde "# Cuenta:" en adelante: los comentarios de cabecera del
        # template documentan el archivo, no deben copiarse a ~/.ssh/config
        local output
        output=$(sed -e "s/{{ACCOUNT_NAME}}/$account_name/g" \
            -e "s|{{SSH_KEY_PATH}}|$ssh_key_file|g" \
            "$template_file" | sed -n '/^# Cuenta:/,$p')
        echo ""
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
    
    # Si el archivo no termina en salto de línea, el nuevo bloque quedaría
    # pegado a la última línea y ssh dejaría de poder leer el config
    ensure_trailing_newline "$HOME/.ssh/config"

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

    # ~/.ssh/config con errores: ssh ni siquiera intenta conectar
    if echo "$output" | grep -q "bad configuration option\|terminating"; then
        log_error "~/.ssh/config tiene errores de sintaxis:"
        echo "$output" | head -1 >&2
        log_info "Diagnostica y repara con: gam check --fix"
        return 1
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

# ¿Existe la cuenta en ~/.ssh/config? (coincidencia exacta del marcador)
account_exists() {
    grep -qxF "# Cuenta: $1" "$HOME/.ssh/config" 2>/dev/null
}

# Mostrar la clave pública e instrucciones para registrarla en GitHub
show_key_instructions() {
    local account_name="$1"
    local username="$2"
    local ssh_key_file="$3"

    echo ""
    log_info "=== CLAVE PÚBLICA (agrega a GitHub) ==="
    cat "${ssh_key_file}.pub"
    echo "========================================="

    # Intentar copiar al portapapeles
    if copy_to_clipboard "$(cat "${ssh_key_file}.pub")"; then
        log_success "Clave copiada al portapapeles"
    fi
    echo ""

    log_info "Pasos a seguir:"
    echo "1. Ve a https://github.com/settings/keys"
    echo "2. Inicia sesión como: ${username:-<tu usuario de GitHub>}"
    echo "3. Haz clic en 'New SSH key'"
    echo "4. Título: $account_name"
    echo "5. Tipo: Authentication Key"
    echo "6. Pega la clave pública mostrada arriba"
    echo "7. Haz clic en 'Add SSH key'"
    echo ""
}

# Validar la sintaxis de ~/.ssh/config. Imprime el error si lo hay.
ssh_config_error() {
    [ -f "$HOME/.ssh/config" ] || return 0
    local err
    if ! err=$(ssh -G github.com 2>&1 >/dev/null); then
        echo "$err" | head -1
        return 1
    fi
    return 0
}

# Líneas dañadas por versiones anteriores de GAM: el bloque nuevo se pegaba a
# la última línea del archivo (p.ej. "ForwardAgent no# Template para ...")
ssh_config_glued_lines() {
    grep -nE '[^[:space:]]# (Template para configuraci|Cuenta: )' "$HOME/.ssh/config" 2>/dev/null
}

# Reparar ~/.ssh/config: separa líneas pegadas, quita la cabecera del template
# y asegura el salto de línea final. Hace backup antes de tocar nada.
repair_ssh_config() {
    local config="$HOME/.ssh/config"
    [ -f "$config" ] || return 0

    local backup
    backup="$config.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$config" "$backup"

    awk '
        {
            line = $0
            if (match(line, /[^[:space:]]# (Template para configuraci|Cuenta: )/)) {
                print substr(line, 1, RSTART)
                line = substr(line, RSTART + 1)
            }
            if (line == "# Template para configuración SSH de GitHub") next
            if (line == "# Este archivo se usa como base para nuevas cuentas") next
            print line
        }
    ' "$backup" > "$config.tmp" && mv "$config.tmp" "$config"
    chmod 600 "$config"

    log_success "~/.ssh/config reparado (backup: $(tilde_path "$backup"))"
}

# Eliminar de ~/.ssh/config el bloque de una cuenta: el marcador "# Cuenta: X",
# su línea "Host github.com-X" y todas las opciones indentadas que la siguen
remove_ssh_block() {
    local account_name="$1"
    local config="$HOME/.ssh/config"
    [ -f "$config" ] || return 0

    awk -v acct="# Cuenta: $account_name" -v host="Host github.com-$account_name" '
        $0 == acct { skip = 1; next }
        skip == 1 && $0 == host { skip = 2; next }
        skip == 2 && /^[[:space:]]+[^[:space:]]/ { next }
        { skip = 0; print }
    ' "$config" > "$config.tmp" && mv "$config.tmp" "$config"
    chmod 600 "$config"
}
