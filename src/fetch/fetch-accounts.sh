#!/usr/bin/env bash
#
# Fetch Accounts Data from Finicity
#
# This script fetches all accounts for a customer from Finicity and saves them as JSON.
#
# Required Environment Variables:
#   FINICITY_APP_KEY          - Finicity app key
#   FINICITY_TOKEN            - Finicity authentication token
#   FINICITY_CUSTOMER_ID      - Finicity customer ID
#
# Required Arguments:
#   $1 - Output file path for accounts.json
#
# Output:
#   Creates a JSON file with an array of accounts: [...]
#

set -euo pipefail

# Source common utilities
_FETCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_FETCH_DIR/../lib/common.sh"

# Validate arguments
if [[ $# -lt 1 ]]; then
    log_error "Usage: $0 <output_file>"
    log_error "Example: $0 /tmp/accounts.json"
    exit 1
fi

OUTPUT_FILE="$1"

# Validate required environment variables
validate_required_vars FINICITY_APP_KEY FINICITY_TOKEN FINICITY_CUSTOMER_ID || exit 1

# Fetch accounts data and keep the full response with {"accounts": [...]} wrapper
log_info "Fetching all accounts for customer: $FINICITY_CUSTOMER_ID"
curl -s -X GET "https://api.finicity.com/aggregation/v1/customers/$FINICITY_CUSTOMER_ID/accounts" \
    -H "Finicity-App-Key: $FINICITY_APP_KEY" \
    -H "Finicity-App-Token: $FINICITY_TOKEN" \
    -H "Accept: application/json" \
    | jq '.' > "$OUTPUT_FILE"

# Validate output file
validate_json "$OUTPUT_FILE" || exit 1

# Count accounts
ACCOUNT_COUNT=$(jq '.accounts | length' "$OUTPUT_FILE")
log_info "✓ Accounts data saved to: $OUTPUT_FILE ($ACCOUNT_COUNT account(s))"

