#!/usr/bin/env bash

_gam_completion() {
    local cur prev words cword
    _init_completion || return

    local commands="add list update remove check test clone switch use export import upgrade help"
    
    if [[ "$cur" == -* ]]; then
        case "${words[1]}" in
            add)    COMPREPLY=($(compgen -W "--name --email --username" -- "$cur")) ;;
            update) COMPREPLY=($(compgen -W "--email --username --folder --new-key" -- "$cur")) ;;
            check)  COMPREPLY=($(compgen -W "--fix" -- "$cur")) ;;
            *)      COMPREPLY=($(compgen -W "--help" -- "$cur")) ;;
        esac
        return 0
    fi

    case "$prev" in
        --folder)
            COMPREPLY=($(compgen -d -- "$cur"))
            return 0
            ;;
        update|remove|check|test|switch)
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
        
    COMPREPLY=($(compgen -W "$commands" -- "$cur"))
}

complete -F _gam_completion gam