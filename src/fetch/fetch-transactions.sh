#!/usr/bin/env bash
#
# Fetch Transactions Data from Finicity
#
# This script fetches transaction data from Finicity using the account transactions endpoint
# with pagination support. It saves one JSON file per page of transactions for each account.
#
# Required Environment Variables:
#   FINICITY_APP_KEY          - Finicity app key
#   FINICITY_TOKEN            - Finicity authentication token
#   FINICITY_CUSTOMER_ID      - Finicity customer ID
#   TXN_FROM_DATE             - Unix timestamp for transaction start date
#   TXN_TO_DATE               - Unix timestamp for transaction end date
#
# Optional Environment Variables:
#   TXN_LIMIT                 - Number of transactions per page (default: 20)
#
# Required Arguments:
#   $1 - Output directory path for transaction JSON files
#   $2 - Accounts JSON file path (to get list of account IDs)
#
# Output:
#   Creates JSON files in the output directory with naming pattern:
#   transactions_<accountId>_page_<pageNum>.json
#
#   Each file contains the complete Finicity response structure with dailyBalances:
#   {
#     "found": 57,
#     "displaying": 20,
#     "moreAvailable": "true",
#     "fromDate": "...",
#     "toDate": "...",
#     "sort": "desc",
#     "transactions": [...],
#     "dailyBalances": [...]
#   }
#
#   Note: Uses showDailyBalance=true query parameter to request daily balances
#

set -euo pipefail

# Source common utilities
_FETCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_FETCH_DIR/../lib/common.sh"

# Validate arguments
if [[ $# -lt 2 ]]; then
    log_error "Usage: $0 <output_dir> <accounts_file>"
    log_error "Example: $0 /tmp/transactions /tmp/accounts.json"
    exit 1
fi

OUTPUT_DIR="$1"
ACCOUNTS_FILE="$2"

# Validate required environment variables
validate_required_vars FINICITY_APP_KEY FINICITY_TOKEN FINICITY_CUSTOMER_ID TXN_FROM_DATE TXN_TO_DATE || exit 1

# Set default limit for pagination (20 for testing, 1000 for production)
TXN_LIMIT="${TXN_LIMIT:-20}"

# Validate accounts file exists
if [[ ! -f "$ACCOUNTS_FILE" ]]; then
    log_error "Accounts file not found: $ACCOUNTS_FILE"
    exit 1
fi

validate_json "$ACCOUNTS_FILE" || exit 1

# Create output directory
mkdir -p "$OUTPUT_DIR"

log_info "Fetching transactions for customer: $FINICITY_CUSTOMER_ID"
log_info "Date range: $TXN_FROM_DATE to $TXN_TO_DATE"
log_info "Transactions per page: $TXN_LIMIT"

# Extract account IDs from accounts file
ACCOUNT_IDS=$(jq -r '.accounts[].id' "$ACCOUNTS_FILE")

if [[ -z "$ACCOUNT_IDS" ]]; then
    log_error "No accounts found in $ACCOUNTS_FILE"
    exit 1
fi

TOTAL_ACCOUNTS=$(echo "$ACCOUNT_IDS" | wc -l | tr -d ' ')
CURRENT_ACCOUNT=0
TOTAL_TRANSACTIONS=0
TOTAL_PAGES=0

# Iterate through each account
while IFS= read -r ACCOUNT_ID; do
    CURRENT_ACCOUNT=$((CURRENT_ACCOUNT + 1))
    log_info "[$CURRENT_ACCOUNT/$TOTAL_ACCOUNTS] Processing account: $ACCOUNT_ID"

    # Pagination variables
    START=1
    PAGE_NUM=1
    MORE_AVAILABLE="true"
    ACCOUNT_TXN_COUNT=0

    # Fetch pages until no more available
    while [[ "$MORE_AVAILABLE" == "true" ]]; do
        OUTPUT_FILE="$OUTPUT_DIR/transactions_${ACCOUNT_ID}_page_${PAGE_NUM}.json"

        log_info "  Fetching page $PAGE_NUM (start=$START, limit=$TXN_LIMIT)..."

        # Fetch transactions for this account with pagination
        # showDailyBalance=true requests daily beginning and ending account balances
        curl -s -X GET "https://api.finicity.com/aggregation/v4/customers/$FINICITY_CUSTOMER_ID/accounts/$ACCOUNT_ID/transactions?fromDate=$TXN_FROM_DATE&toDate=$TXN_TO_DATE&start=$START&limit=$TXN_LIMIT&showDailyBalance=true" \
            -H "Finicity-App-Key: $FINICITY_APP_KEY" \
            -H "Finicity-App-Token: $FINICITY_TOKEN" \
            -H "Accept: application/json" \
            > "$OUTPUT_FILE"

        # Validate output file
        if ! validate_json "$OUTPUT_FILE"; then
            log_error "Failed to fetch transactions for account $ACCOUNT_ID, page $PAGE_NUM"
            exit 1
        fi

        # Get pagination info from response
        PAGE_TXN_COUNT=$(jq -r '.transactions | length // 0' "$OUTPUT_FILE")
        MORE_AVAILABLE=$(jq -r '.moreAvailable // "false"' "$OUTPUT_FILE")
        FOUND=$(jq -r '.found // 0' "$OUTPUT_FILE")

        ACCOUNT_TXN_COUNT=$((ACCOUNT_TXN_COUNT + PAGE_TXN_COUNT))
        TOTAL_TRANSACTIONS=$((TOTAL_TRANSACTIONS + PAGE_TXN_COUNT))
        TOTAL_PAGES=$((TOTAL_PAGES + 1))

        log_info "  ✓ Page $PAGE_NUM saved: $OUTPUT_FILE ($PAGE_TXN_COUNT transactions)"

        # Check if we should continue
        if [[ "$MORE_AVAILABLE" != "true" ]] || [[ "$PAGE_TXN_COUNT" -eq 0 ]]; then
            break
        fi

        # Move to next page
        START=$((START + PAGE_TXN_COUNT))
        PAGE_NUM=$((PAGE_NUM + 1))
    done

    log_info "  Account $ACCOUNT_ID complete: $ACCOUNT_TXN_COUNT transactions across $((PAGE_NUM)) page(s)"

done <<< "$ACCOUNT_IDS"

log_info "✓ All transactions fetched successfully!"
log_info "  Total accounts: $TOTAL_ACCOUNTS"
log_info "  Total transactions: $TOTAL_TRANSACTIONS"
log_info "  Total pages: $TOTAL_PAGES"
log_info "  Files saved to: $OUTPUT_DIR"

