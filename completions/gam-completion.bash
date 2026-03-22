#!/usr/bin/env bash

_gam_completion() {
    local cur prev words cword
    _init_completion || return

    local commands="add list remove test clone switch use export import help"
    
    case "$prev" in
        remove|test|switch)
            # Completar con nombres de cuentas
            local accounts=$(grep "^# Cuenta:" ~/.ssh/config 2>/dev/null | sed 's/# Cuenta: //')
            COMPREPLY=($(compgen -W "$accounts" -- "$cur"))
            return 0
            ;;
        clone)
            if [ ${#words[@]} -eq 3 ]; then
                # Completar con nombres de cuentas
                local accounts=$(grep "^# Cuenta:" ~/.ssh/config 2>/dev/null | sed 's/# Cuenta: //')
                COMPREPLY=($(compgen -W "$accounts" -- "$cur"))
            elif [ ${#words[@]} -eq 4 ]; then
                # Completar con repositorios (si se puede obtener)
                local account="${words[2]}"
                # Aquí se podría hacer una llamada a GitHub API para listar repos
                # Por simplicidad, no se implementa
                COMPREPLY=()
            fi
            return 0
            ;;
        use)
            # Completar con rutas
            COMPREPLY=($(compgen -d -- "$cur"))
            return 0
            ;;
        import)
            # Completar con archivos
            COMPREPLY=($(compgen -f -- "$cur"))
            return 0
            ;;
    esac
    
    if [[ "$cur" == -* ]]; then
        COMPREPLY=($(compgen -W "--help --name --email --username" -- "$cur"))
        return 0
    fi
    
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
}

complete -F _gam_completion gam