#!/usr/bin/env bash

# Diagnóstico de cuentas: gam check [cuenta] [--fix]
#
# Revisa todo lo que necesita una cuenta para funcionar (config SSH, claves,
# registro en GitHub, perfil Git y carpetas) e indica cómo resolver cada
# problema. Con --fix repara lo que es seguro reparar automáticamente.

CHECK_ERRORS=0
CHECK_WARNINGS=0
CHECK_SSH_BROKEN=false

_check_ok()     { echo -e "    ${GREEN}✓${NC}  $1"; }
_check_warn()   { echo -e "    ${YELLOW}!${NC}  $1"; CHECK_WARNINGS=$((CHECK_WARNINGS + 1)); }
_check_fail()   { echo -e "    ${RED}✗${NC}  $1"; CHECK_ERRORS=$((CHECK_ERRORS + 1)); }
_check_detail() { echo -e "       $1"; }
_check_hint()   { echo -e "       ${CYAN}→ $1${NC}"; }
_check_title()  { echo ""; echo -e "    ${MAGENTA}$1${NC}"; }

check_account() {
    local account=""
    local fix=false

    while [[ $# -gt 0 ]]; do
        case $1 in
            --fix) fix=true; shift ;;
            -*)
                log_error "Opción desconocida: $1"
                echo "Uso: gam check [cuenta] [--fix]"
                return 1
                ;;
            *) account="$1"; shift ;;
        esac
    done

    CHECK_ERRORS=0
    CHECK_WARNINGS=0
    CHECK_SSH_BROKEN=false

    echo ""
    echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║${NC}   🩺  ${CYAN}Diagnóstico de cuentas GitHub${NC}      ${BLUE}║${NC}"
    echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"

    echo ""
    echo -e "  ${GREEN}⚙️  General${NC}"
    _check_ssh_config "$fix"

    local accounts=()
    if [ -n "$account" ]; then
        accounts=("$account")
    else
        read -ra accounts <<< "$(get_ssh_accounts)"
        if [ ${#accounts[@]} -eq 0 ]; then
            _check_warn "No hay cuentas configuradas"
            _check_hint "gam add"
        fi
    fi

    local acc
    for acc in "${accounts[@]}"; do
        _check_one_account "$acc" "$fix"
    done

    echo ""
    echo -e "  ${BLUE}──────────────────────────────────────────${NC}"
    if [ "$CHECK_ERRORS" -eq 0 ] && [ "$CHECK_WARNINGS" -eq 0 ]; then
        echo -e "  ${GREEN}✓ Todo en orden${NC}"
    else
        echo -e "  ${RED}$CHECK_ERRORS problema(s)${NC} · ${YELLOW}$CHECK_WARNINGS aviso(s)${NC}"
    fi
    echo ""

    [ "$CHECK_ERRORS" -eq 0 ]
}

# Comprobaciones de ~/.ssh/config que afectan a todas las cuentas
_check_ssh_config() {
    local fix="$1"
    local config="$HOME/.ssh/config"

    if [ ! -f "$config" ]; then
        _check_warn "No existe ~/.ssh/config"
        _check_hint "gam add"
        return 0
    fi

    # Permisos: ssh rechaza el archivo si otros pueden escribirlo
    local mode
    mode=$(file_mode "$config" || true)
    if [ -n "$mode" ] && [ $((8#$mode & 8#022)) -ne 0 ]; then
        if [ "$fix" = true ]; then
            chmod 600 "$config"
            _check_ok "Permisos de ~/.ssh/config corregidos ($mode → 600)"
        else
            _check_fail "~/.ssh/config tiene permisos $mode: ssh lo rechazará"
            _check_hint "gam check --fix"
        fi
    fi

    # Líneas pegadas por versiones anteriores de GAM
    local glued
    glued=$(ssh_config_glued_lines || true)
    if [ -n "$glued" ] && [ "$fix" = true ]; then
        repair_ssh_config
        glued=""
    fi

    local err
    if err=$(ssh_config_error); then
        _check_ok "~/.ssh/config se lee correctamente"
        return 0
    fi

    CHECK_SSH_BROKEN=true
    _check_fail "~/.ssh/config tiene errores: ssh no puede usar NINGUNA cuenta"
    _check_detail "$(tilde_path "$err")"
    if [ -n "$glued" ]; then
        _check_detail "Líneas pegadas por una versión anterior de GAM:"
        local line
        while IFS= read -r line; do
            _check_detail "  línea ${line%%:*}: ${line#*:}"
        done <<< "$glued"
        _check_hint "gam check --fix   (repara el archivo y guarda un backup)"
    else
        _check_hint "Corrige la línea indicada en ~/.ssh/config"
    fi
}

# Comprobaciones de una cuenta
_check_one_account() {
    local account="$1"
    local fix="$2"
    local host="github.com-$account"
    local key_file="$HOME/.ssh/id_ed25519_$account"
    local profile="$HOME/.gitconfig-$account"

    echo ""
    echo -e "  ${GREEN}📁 $account${NC}"

    if ! account_exists "$account" && [ ! -f "$key_file" ] && [ ! -f "$profile" ]; then
        _check_fail "La cuenta '$account' no existe (sin bloque SSH, clave ni perfil Git)"
        _check_hint "gam list para ver las cuentas · gam add para crearla"
        return 0
    fi

    local prof_name="" prof_email=""
    if [ -f "$profile" ]; then
        prof_name=$(git config --file "$profile" user.name 2>/dev/null || true)
        prof_email=$(git config --file "$profile" user.email 2>/dev/null || true)
    fi

    # ── SSH ──────────────────────────────────────────────
    _check_title "🔐 SSH"

    local has_block=false
    if account_exists "$account" && grep -qxF "Host $host" "$HOME/.ssh/config"; then
        has_block=true
        _check_ok "Host $host en ~/.ssh/config"
    elif account_exists "$account"; then
        _check_fail "Falta la línea 'Host $host' bajo '# Cuenta: $account' en ~/.ssh/config"
        _check_hint "gam remove $account y vuelve a crearla con gam add"
    else
        _check_fail "No hay bloque para '$account' en ~/.ssh/config"
        _check_hint "gam add --name $account ...   (vuelve a crear la cuenta)"
    fi

    # Qué clave usa realmente ssh para este host
    if [ "$has_block" = true ] && [ "$CHECK_SSH_BROKEN" = false ]; then
        local resolved resolved_host identity
        resolved=$(ssh -G "$host" 2>/dev/null || true)
        resolved_host=$(echo "$resolved" | awk '$1 == "hostname" { print $2; exit }')
        identity=$(echo "$resolved" | awk '$1 == "identityfile" { print $2; exit }')
        identity="${identity/#\~/$HOME}"

        if [ "$resolved_host" != "github.com" ]; then
            _check_fail "HostName de $host apunta a '$resolved_host', no a github.com"
        fi
        if [ -n "$identity" ] && [ "$identity" != "$key_file" ]; then
            _check_warn "IdentityFile apunta a $(tilde_path "$identity") (lo habitual es $(tilde_path "$key_file"))"
            key_file="$identity"
        fi
    fi

    # Clave privada
    if [ -f "$key_file" ]; then
        local mode
        mode=$(file_mode "$key_file" || true)
        if [ -n "$mode" ] && [ $((8#$mode & 8#077)) -ne 0 ]; then
            if [ "$fix" = true ]; then
                chmod 600 "$key_file"
                _check_ok "Clave privada $(tilde_path "$key_file") (permisos corregidos $mode → 600)"
            else
                _check_fail "Clave privada con permisos $mode: ssh la ignorará"
                _check_hint "gam check $account --fix"
            fi
        else
            _check_ok "Clave privada $(tilde_path "$key_file")"
        fi
    else
        _check_fail "No existe la clave privada $(tilde_path "$key_file")"
        _check_hint "gam update $account --new-key"
    fi

    # Clave pública
    if [ ! -f "${key_file}.pub" ] && [ -f "$key_file" ] && [ "$fix" = true ]; then
        if ssh-keygen -y -P "" -f "$key_file" > "${key_file}.pub" 2>/dev/null; then
            chmod 644 "${key_file}.pub"
            log_success "Clave pública regenerada a partir de la privada"
        else
            rm -f "${key_file}.pub"
        fi
    fi

    if [ -f "${key_file}.pub" ]; then
        local fingerprint comment
        fingerprint=$(ssh-keygen -lf "${key_file}.pub" 2>/dev/null | awk '{ print $2 }')
        comment=$(awk '{ print $3 }' "${key_file}.pub")
        _check_ok "Clave pública ${fingerprint}${comment:+ ($comment)}"

        # Que la pública corresponda a la privada (solo claves sin passphrase)
        if [ -f "$key_file" ]; then
            local derived stored
            derived=$(ssh-keygen -y -P "" -f "$key_file" 2>/dev/null | awk '{ print $1" "$2 }')
            stored=$(awk '{ print $1" "$2 }' "${key_file}.pub")
            if [ -n "$derived" ] && [ "$derived" != "$stored" ]; then
                _check_fail "La clave pública no corresponde a la privada"
                _check_hint "gam update $account --new-key"
            fi
        fi
    elif [ -f "$key_file" ]; then
        _check_fail "Falta la clave pública $(tilde_path "${key_file}.pub")"
        _check_hint "gam check $account --fix   (la regenera a partir de la privada)"
    fi

    # Conexión con GitHub
    local show_key=false
    if [ "$CHECK_SSH_BROKEN" = true ]; then
        _check_warn "Conexión con GitHub sin verificar: primero repara ~/.ssh/config"
    elif [ "$has_block" = true ] && [ -f "$key_file" ]; then
        local output gh_user
        output=$(ssh -T -o BatchMode=yes -o ConnectTimeout=10 "$host" 2>&1 || true)
        case "$output" in
            *"successfully authenticated"*)
                gh_user=$(echo "$output" | sed -n 's/^Hi \([^!]*\)!.*/\1/p' | head -1)
                _check_ok "GitHub reconoce la clave como ${CYAN}@$gh_user${NC}"
                # user.name con aspecto de usuario (sin espacios) distinto: clave en otra cuenta
                if [ -n "$prof_name" ] && [[ "$prof_name" != *" "* ]] && [ "$prof_name" != "$gh_user" ]; then
                    _check_warn "La clave está en la cuenta @$gh_user pero el perfil Git usa '$prof_name'"
                    _check_hint "Si es un error, quita la clave de @$gh_user y agrégala en la cuenta correcta"
                fi
                ;;
            *"Permission denied"*)
                _check_fail "GitHub rechaza la clave: todavía no está registrada en GitHub"
                _check_hint "Agrégala en https://github.com/settings/keys (clave y pasos abajo)"
                show_key=true
                ;;
            *"Host key verification failed"*)
                _check_fail "github.com no está en ~/.ssh/known_hosts"
                _check_hint "gam test $account   (te pedirá aceptar la huella de GitHub)"
                ;;
            *"Could not resolve"*|*"timed out"*|*"unreachable"*|*"Connection refused"*)
                _check_warn "Sin conexión con GitHub: no se pudo verificar la clave"
                ;;
            *)
                _check_fail "No se pudo conectar con GitHub"
                _check_detail "$(echo "$output" | head -1)"
                ;;
        esac
    fi

    # ── Git ──────────────────────────────────────────────
    _check_title "👤 Git"

    if [ ! -f "$profile" ]; then
        _check_warn "Sin perfil Git ($(tilde_path "$profile")): los commits usarán tu identidad global"
        _check_hint "gam update $account   (crea el perfil y asigna una carpeta)"
    else
        if [ -n "$prof_name" ] && [ -n "$prof_email" ]; then
            _check_ok "Perfil $(tilde_path "$profile"): $prof_name <$prof_email>"
        else
            _check_fail "El perfil $(tilde_path "$profile") no tiene user.name o user.email"
            _check_hint "gam update $account"
        fi

        local includes
        includes=$(get_profile_includes "$profile")
        if [ -z "$includes" ]; then
            _check_warn "Ninguna carpeta usa este perfil"
            _check_hint "gam update $account --folder <carpeta>"
        else
            local cond dir
            while IFS= read -r cond; do
                case "$cond" in
                    gitdir:*|gitdir/i:*) dir="${cond#*:}" ;;
                    *) _check_ok "includeIf \"$cond\""; continue ;;
                esac
                case "$dir" in
                    /*|"~/"*)
                        local real="${dir/#\~/$HOME}"
                        real="${real%\*\*}"
                        if [ -d "$real" ]; then
                            _check_ok "Carpeta $dir"
                        else
                            _check_warn "La carpeta $dir no existe"
                        fi
                        ;;
                    *)
                        _check_warn "Carpeta relativa '$dir': Git la aplica a CUALQUIER carpeta llamada así"
                        _check_hint "git config --global --unset 'includeIf.$cond.path'"
                        _check_hint "gam update $account --folder <ruta absoluta>"
                        ;;
                esac
            done <<< "$includes"
        fi
    fi

    if [ "$show_key" = true ]; then
        show_key_instructions "$account" "$prof_name" "$key_file"
        log_info "Después vuelve a ejecutar: gam check $account"
    fi
}
