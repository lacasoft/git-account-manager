#!/usr/bin/env bash

# Colores (definidos nuevamente para scripts independientes)
export RED=$'\033[0;31m'
export GREEN=$'\033[0;32m'
export YELLOW=$'\033[1;33m'
export BLUE=$'\033[0;34m'
export MAGENTA=$'\033[0;35m'
export CYAN=$'\033[0;36m'
export NC=$'\033[0m'

# Detección de sistema operativo
detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "macos" ;;
        *)       echo "unknown" ;;
    esac
}
export GAM_OS
GAM_OS="$(detect_os)"

# sed -i portable (macOS necesita sed -i '', Linux usa sed -i)
sed_inplace() {
    if [ "$GAM_OS" = "macos" ]; then
        sed -i '' "$@"
    else
        sed -i "$@"
    fi
}

# Copiar al portapapeles
copy_to_clipboard() {
    local text="$1"
    if [ "$GAM_OS" = "macos" ]; then
        echo "$text" | pbcopy && return 0
    elif command -v xclip &> /dev/null; then
        echo "$text" | xclip -selection clipboard && return 0
    elif command -v xsel &> /dev/null; then
        echo "$text" | xsel --clipboard && return 0
    fi
    return 1
}

# Logging
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[✗]${NC} $1" >&2
}

# Validar inputs
validate_not_empty() {
    local value="$1"
    local name="$2"
    
    if [ -z "$value" ]; then
        log_error "$name no puede estar vacío"
        return 1
    fi
    return 0
}

# Confirmar acción
confirm() {
    local message="${1:-¿Estás seguro?}"
    echo -e "${YELLOW}$message (s/n)${NC}"
    read -r response
    case "$response" in
        [sS]|[sS][iI]|[sS][íÍ]) return 0 ;;
        *) return 1 ;;
    esac
}

# Mostrar spinner
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while ps -p "$pid" > /dev/null 2>&1; do
        local temp=${spinstr#?}
        printf " [%c]  " "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

# Verificar si está instalado
check_installed() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd no está instalado"
        return 1
    fi
    return 0
}

# Crear directorio si no existe
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        log_success "Directorio creado: $dir"
    fi
}