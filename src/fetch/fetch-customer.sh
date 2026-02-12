#!/usr/bin/env bash
#
# Fetch Customer Data from Finicity
#
# This script fetches customer data from Finicity and saves it as JSON.
#
# Required Environment Variables:
#   FINICITY_APP_KEY          - Finicity app key
#   FINICITY_TOKEN            - Finicity authentication token
#   FINICITY_CUSTOMER_ID      - Finicity customer ID to fetch
#
# Required Arguments:
#   $1 - Output file path for customers.json
#
# Output:
#   Creates a JSON file with structure: {"customer": {...}}
#

set -euo pipefail

# Source common utilities
_FETCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_FETCH_DIR/../lib/common.sh"

# Validate arguments
if [[ $# -lt 1 ]]; then
    log_error "Usage: $0 <output_file>"
    log_error "Example: $0 /tmp/customers.json"
    exit 1
fi

OUTPUT_FILE="$1"

# Validate required environment variables
validate_required_vars FINICITY_APP_KEY FINICITY_TOKEN FINICITY_CUSTOMER_ID || exit 1

log_info "Fetching customer data for customer ID: $FINICITY_CUSTOMER_ID"

# Fetch customer data from Finicity
CUSTOMER_RESPONSE=$(curl -s -X GET "https://api.finicity.com/aggregation/v1/customers/$FINICITY_CUSTOMER_ID" \
    -H "Finicity-App-Key: $FINICITY_APP_KEY" \
    -H "Finicity-App-Token: $FINICITY_TOKEN" \
    -H "Accept: application/json")

# Validate JSON response
if ! echo "$CUSTOMER_RESPONSE" | jq empty 2>/dev/null; then
    log_error "Invalid JSON received for customer data"
    log_error "Response: $CUSTOMER_RESPONSE"
    exit 1
fi

# Save the customer data directly without wrapping (per Ocrolus requirements)
echo "$CUSTOMER_RESPONSE" | jq '.' > "$OUTPUT_FILE"

# Validate output file
validate_json "$OUTPUT_FILE" || exit 1

log_info "✓ Customer data saved to: $OUTPUT_FILE"

