#!/usr/bin/env bash
#
# Finicity Authentication Library
#
# This library handles authentication with the Finicity API.
# It exports the FINICITY_TOKEN environment variable for use by other scripts.
#
# Required Environment Variables:
#   FINICITY_PARTNER_ID       - Finicity partner ID
#   FINICITY_PARTNER_SECRET   - Finicity partner secret
#   FINICITY_APP_KEY          - Finicity app key
#

# Source common utilities
_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_LIB_DIR/common.sh"

# Authenticate with Finicity and export the token
# Usage: finicity_authenticate
# Exports: FINICITY_TOKEN
finicity_authenticate() {
    log_info "Authenticating with Finicity..."

    # Validate required variables
    validate_required_vars FINICITY_PARTNER_ID FINICITY_PARTNER_SECRET FINICITY_APP_KEY || return 1

    # Make authentication request
    local auth_response=$(curl -s -w "\n%{http_code}" -X POST "https://api.finicity.com/aggregation/v2/partners/authentication" \
        -H "Finicity-App-Key: $FINICITY_APP_KEY" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "{\"partnerId\":\"$FINICITY_PARTNER_ID\",\"partnerSecret\":\"$FINICITY_PARTNER_SECRET\"}")

    local http_code=$(echo "$auth_response" | tail -n1)
    local response_body=$(echo "$auth_response" | sed '$d')

    # Check HTTP status
    if [[ "$http_code" != "200" ]]; then
        log_error "Finicity authentication failed with HTTP $http_code"
        log_error "Response: $response_body"
        return 1
    fi

    # Extract token from JSON response
    FINICITY_TOKEN=$(echo "$response_body" | jq -r '.token // empty' 2>/dev/null)

    if [[ -z "$FINICITY_TOKEN" ]]; then
        log_error "Failed to extract token from Finicity response"
        log_error "Response: $response_body"
        return 1
    fi

    # Export token for use by other scripts
    export FINICITY_TOKEN

    log_info "✓ Finicity authentication successful"
    return 0
}

# Export the function
export -f finicity_authenticate

