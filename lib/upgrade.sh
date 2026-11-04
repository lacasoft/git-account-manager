#!/usr/bin/env bash

# Actualizar GAM a la última versión: gam upgrade
#
# Funciona con cualquier tipo de instalación (one-liner o desde un clon):
# descarga la última versión a un directorio temporal y ejecuta su install.sh.

GAM_REPO_URL="${GAM_REPO_URL:-https://github.com/lacasoft/git-account-manager}"

upgrade_gam() {
    # En modo dev el código que corre es el del propio repositorio
    if [ "$GAM_HOME" = "$SCRIPT_DIR" ]; then
        log_info "Estás ejecutando GAM desde el repositorio ($SCRIPT_DIR)"
        echo "Para actualizarlo usa: bash update.sh"
        return 0
    fi

    check_installed git || return 1

    local installed=""
    if [ -f "$GAM_HOME/version" ]; then
        installed=$(cat "$GAM_HOME/version")
    fi

    log_info "Buscando la última versión..."
    local latest
    latest=$(git ls-remote "$GAM_REPO_URL.git" HEAD 2>/dev/null | awk '{ print $1 }')
    if [ -z "$latest" ]; then
        log_error "No se pudo contactar con $GAM_REPO_URL"
        return 1
    fi

    if [ "$installed" = "$latest" ]; then
        log_success "Ya tienes la última versión (${latest:0:7})"
        return 0
    fi

    local from="${installed:0:7}"
    log_info "Actualizando GAM: ${from:-versión desconocida} → ${latest:0:7}"

    local tmp
    tmp=$(mktemp -d)
    if ! git clone --depth 1 -q "$GAM_REPO_URL.git" "$tmp" 2>/dev/null; then
        rm -rf "$tmp"
        log_error "No se pudo descargar GAM"
        return 1
    fi

    # Reinstalar en el mismo directorio donde está este gam
    local status=0
    GAM_INSTALL_DIR="$SCRIPT_DIR" bash "$tmp/install.sh" || status=$?
    rm -rf "$tmp"

    # install.sh acaba de reemplazar este mismo script: salir ya, sin que bash
    # siga leyendo el archivo nuevo desde la posición del viejo
    exit "$status"
}
