#!/usr/bin/env bash
#
# Common utility functions for Finicity-Ocrolus POC scripts
#
# This library provides shared functionality including:
# - Colored logging (log_info, log_warn, log_error)
# - Environment variable validation
# - .env file loading
# - Temporary directory management
# - JSON validation
#

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Load .env file from the project root directory
# Usage: load_env_file
load_env_file() {
    # Get the directory of the lib file (src/lib)
    local lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    # Get project root (two levels up from src/lib)
    local project_dir="$(cd "$lib_dir/../.." && pwd)"
    local env_file="$project_dir/.env"

    if [[ -f "$env_file" ]]; then
        log_info "Loading environment variables from $env_file"
        set -a
        source "$env_file"
        set +a
        return 0
    else
        log_warn "No .env file found at $env_file"
        return 1
    fi
}

# Validate that required environment variables are set
# Usage: validate_required_vars VAR1 VAR2 VAR3 ...
validate_required_vars() {
    local missing_vars=()

    for var in "$@"; do
        if [[ -z "${!var:-}" ]]; then
            missing_vars+=("$var")
        fi
    done

    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        log_error "Missing required environment variables:"
        for var in "${missing_vars[@]}"; do
            log_error "  - $var"
        done
        return 1
    fi

    return 0
}

# Set up a temporary directory with automatic cleanup
# Usage: TEMP_DIR=$(setup_temp_dir)
setup_temp_dir() {
    local temp_dir=$(mktemp -d)

    # Set up trap to clean up on exit
    trap "rm -rf $temp_dir" EXIT

    echo "$temp_dir"
}

# Validate that a file contains valid JSON
# Usage: validate_json /path/to/file.json
validate_json() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        return 1
    fi

    if ! jq empty "$file" 2>/dev/null; then
        log_error "Invalid JSON in file: $file"
        return 1
    fi

    return 0
}

# Set default value for a variable if not already set
# Usage: set_default VAR_NAME "default value"
set_default() {
    local var_name="$1"
    local default_value="$2"

    if [[ -z "${!var_name:-}" ]]; then
        eval "$var_name='$default_value'"
    fi
}

# Get the directory where the calling script is located
# Usage: SCRIPT_DIR=$(get_script_dir)
get_script_dir() {
    echo "$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
}

# Export functions so they're available to scripts that source this file
export -f log_info
export -f log_warn
export -f log_error
export -f validate_required_vars
export -f validate_json
export -f set_default
export -f get_script_dir

