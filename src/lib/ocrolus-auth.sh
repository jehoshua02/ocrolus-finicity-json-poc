#!/usr/bin/env bash
#
# Ocrolus Authentication Library
#
# This library handles OAuth2 authentication with the Ocrolus API.
# It exports the OCROLUS_TOKEN environment variable for use by other scripts.
#
# Required Environment Variables:
#   OCROLUS_CLIENT_ID         - Ocrolus OAuth2 client ID
#   OCROLUS_CLIENT_SECRET     - Ocrolus OAuth2 client secret
#

# Source common utilities
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/common.sh"

# Authenticate with Ocrolus and export the access token
# Usage: ocrolus_authenticate
# Exports: OCROLUS_TOKEN
ocrolus_authenticate() {
    log_info "Authenticating with Ocrolus..."

    # Validate required variables
    validate_required_vars OCROLUS_CLIENT_ID OCROLUS_CLIENT_SECRET || return 1

    # Make OAuth2 token request
    OCROLUS_TOKEN=$(curl -s -X POST "https://auth.ocrolus.com/oauth/token" \
        -H "Content-Type: application/json" \
        -d "{\"client_id\":\"$OCROLUS_CLIENT_ID\",\"client_secret\":\"$OCROLUS_CLIENT_SECRET\",\"audience\":\"https://api.ocrolus.com/\",\"grant_type\":\"client_credentials\"}" \
        | jq -r '.access_token')

    if [[ -z "$OCROLUS_TOKEN" || "$OCROLUS_TOKEN" == "null" ]]; then
        log_error "Failed to authenticate with Ocrolus"
        return 1
    fi

    # Export token for use by other scripts
    export OCROLUS_TOKEN

    log_info "✓ Ocrolus authentication successful"
    return 0
}

# Export the function
export -f ocrolus_authenticate

