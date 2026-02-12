#!/usr/bin/env bash
#
# Upload Finicity JSON Bundle to Ocrolus
#
# This script uploads JSON files (customers, accounts, transactions, institutions)
# to Ocrolus Book using the Finicity aggregator endpoint.
# Supports multiple transaction JSON files (one per page per account) and
# multiple institution JSON files (one per institution).
#
# Required Environment Variables:
#   OCROLUS_TOKEN             - Ocrolus OAuth2 access token
#   OCROLUS_BOOK_PK           - Ocrolus Book PK to upload into
#
# Required Arguments:
#   $1 - Path to customers.json
#   $2 - Path to accounts.json
#   $3 - Path to transactions directory (containing transaction JSON files)
#   $4 - Path to institutions directory (containing institution JSON files)
#
# Output:
#   Prints the Ocrolus API response JSON
#   Returns 0 on success, 1 on failure
#

set -euo pipefail

# Source common utilities
_UPLOAD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_UPLOAD_DIR/../lib/common.sh"

# Validate arguments
if [[ $# -lt 4 ]]; then
    log_error "Usage: $0 <customers.json> <accounts.json> <transactions_dir> <institutions_dir>"
    log_error "Example: $0 /tmp/customers.json /tmp/accounts.json /tmp/transactions /tmp/institutions"
    exit 1
fi

CUSTOMERS_FILE="$1"
ACCOUNTS_FILE="$2"
TRANSACTIONS_DIR="$3"
INSTITUTIONS_DIR="$4"

# Validate required environment variables
validate_required_vars OCROLUS_TOKEN OCROLUS_BOOK_PK || exit 1

# Validate customers and accounts files exist and contain valid JSON
log_info "Validating input files..."
for file in "$CUSTOMERS_FILE" "$ACCOUNTS_FILE"; do
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        exit 1
    fi
    validate_json "$file" || exit 1
done

# Validate transactions directory exists
if [[ ! -d "$TRANSACTIONS_DIR" ]]; then
    log_error "Transactions directory not found: $TRANSACTIONS_DIR"
    exit 1
fi

# Validate institutions directory exists
if [[ ! -d "$INSTITUTIONS_DIR" ]]; then
    log_error "Institutions directory not found: $INSTITUTIONS_DIR"
    exit 1
fi

# Find all transaction JSON files
TRANSACTION_FILES=($(find "$TRANSACTIONS_DIR" -name "transactions_*.json" -type f | sort))

if [[ ${#TRANSACTION_FILES[@]} -eq 0 ]]; then
    log_error "No transaction files found in: $TRANSACTIONS_DIR"
    exit 1
fi

log_info "Found ${#TRANSACTION_FILES[@]} transaction file(s)"

# Validate all transaction files
TOTAL_TRANSACTIONS=0
for txn_file in "${TRANSACTION_FILES[@]}"; do
    if ! validate_json "$txn_file"; then
        log_error "Invalid JSON in transaction file: $txn_file"
        exit 1
    fi
    TXN_COUNT=$(jq -r '.transactions | length // 0' "$txn_file")
    TOTAL_TRANSACTIONS=$((TOTAL_TRANSACTIONS + TXN_COUNT))
done

# Find all institution JSON files
INSTITUTION_FILES=($(find "$INSTITUTIONS_DIR" -name "institution_*.json" -type f | sort))

if [[ ${#INSTITUTION_FILES[@]} -eq 0 ]]; then
    log_error "No institution files found in: $INSTITUTIONS_DIR"
    exit 1
fi

log_info "Found ${#INSTITUTION_FILES[@]} institution file(s)"

# Validate all institution files
TOTAL_INSTITUTIONS=0
for inst_file in "${INSTITUTION_FILES[@]}"; do
    if ! validate_json "$inst_file"; then
        log_error "Invalid JSON in institution file: $inst_file"
        exit 1
    fi
    INST_COUNT=$(jq -r '.institutions | length // 0' "$inst_file")
    TOTAL_INSTITUTIONS=$((TOTAL_INSTITUTIONS + INST_COUNT))
done

log_info "✓ All input files validated"

# Preview what we're uploading
log_info "Preview of JSON files being uploaded:"
log_info "  Customers: $(jq -c '.' "$CUSTOMERS_FILE" | head -c 100)..."
log_info "  Accounts: $(jq -c '.' "$ACCOUNTS_FILE" | head -c 100)..."
log_info "  Transactions: $TOTAL_TRANSACTIONS transaction(s) across ${#TRANSACTION_FILES[@]} file(s)"
log_info "  Institutions: $TOTAL_INSTITUTIONS institution(s) across ${#INSTITUTION_FILES[@]} file(s)"

# Upload to Ocrolus
log_info "Uploading Finicity JSON bundle to Ocrolus Book PK: $OCROLUS_BOOK_PK..."

# Build curl command with all transaction and institution files
CURL_CMD=(
    curl -s -X POST "https://api.ocrolus.com/v1/book/upload/json?aggregate_source=FINICITY"
    -H "Authorization: Bearer $OCROLUS_TOKEN"
    -H "Accept: application/json"
    -F "pk=$OCROLUS_BOOK_PK"
    -F "accounts=@$ACCOUNTS_FILE"
    -F "customers=@$CUSTOMERS_FILE"
)

# Add each transaction file as a separate -F parameter
for txn_file in "${TRANSACTION_FILES[@]}"; do
    CURL_CMD+=(-F "transactions=@$txn_file")
done

# Add each institution file as a separate -F parameter
for inst_file in "${INSTITUTION_FILES[@]}"; do
    CURL_CMD+=(-F "institutions=@$inst_file")
done

# Log the curl command for debugging (mask the token)
log_info "Executing curl command:"
MASKED_CMD=("${CURL_CMD[@]}")
for i in "${!MASKED_CMD[@]}"; do
    if [[ "${MASKED_CMD[$i]}" == "Bearer "* ]]; then
        MASKED_CMD[$i]="Bearer ***MASKED***"
    fi
done
log_info "  ${MASKED_CMD[*]}"

# Execute the upload
UPLOAD_RESPONSE=$("${CURL_CMD[@]}")

# Check response
UPLOAD_STATUS=$(echo "$UPLOAD_RESPONSE" | jq -r '.status // empty')
UPLOAD_MESSAGE=$(echo "$UPLOAD_RESPONSE" | jq -r '.message // .response.message // empty')

if [[ "$UPLOAD_STATUS" == "200" ]]; then
    log_info "✓ Upload successful!"
    echo "$UPLOAD_RESPONSE" | jq '.'
    exit 0
else
    log_error "Upload failed with status: $UPLOAD_STATUS"
    log_error "Message: $UPLOAD_MESSAGE"
    echo "$UPLOAD_RESPONSE" | jq '.'
    exit 1
fi

