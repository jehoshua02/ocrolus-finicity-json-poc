#!/usr/bin/env bash
#
# Fetch All Finicity Data - Orchestrator Script
#
# This script orchestrates fetching all Finicity data (customer, accounts,
# transactions, institutions) and saves them to an output directory.
#
# Required Environment Variables:
#   FINICITY_PARTNER_ID       - Finicity partner ID
#   FINICITY_PARTNER_SECRET   - Finicity partner secret
#   FINICITY_APP_KEY          - Finicity app key
#   FINICITY_CUSTOMER_ID      - Finicity customer ID to fetch data for
#
# Optional Environment Variables:
#   FINICITY_ACCOUNT_ID       - Specific account ID (if omitted, fetches all customer accounts)
#   TXN_FROM_DATE             - Unix timestamp for transaction start (defaults to 90 days ago)
#   TXN_TO_DATE               - Unix timestamp for transaction end (defaults to now)
#   TXN_LIMIT                 - Number of transactions per page (defaults to 20)
#   OUTPUT_DIR                - Directory to save JSON files (defaults to ./output)
#
# Output:
#   Creates JSON files in OUTPUT_DIR:
#   - customers.json
#   - accounts.json
#   - transactions/ (directory with paginated transaction files per account)
#   - institutions.json
#

set -euo pipefail

# Get script directory (bin directory)
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get project root directory (parent of bin)
PROJECT_DIR="$(cd "$BIN_DIR/.." && pwd)"

# Source common utilities and authentication libraries
source "$PROJECT_DIR/src/lib/common.sh"
source "$PROJECT_DIR/src/lib/finicity-auth.sh"

# Load .env file
load_env_file

# Validate required environment variables
validate_required_vars FINICITY_PARTNER_ID FINICITY_PARTNER_SECRET FINICITY_APP_KEY FINICITY_CUSTOMER_ID || exit 1

# Set defaults for optional variables
TXN_FROM_DATE="${TXN_FROM_DATE:-$(date -u -v-90d +%s 2>/dev/null || date -u -d '90 days ago' +%s)}"
TXN_TO_DATE="${TXN_TO_DATE:-$(date -u +%s)}"
OUTPUT_DIR="${OUTPUT_DIR:-$PROJECT_DIR/output/original}"

# Export for use by fetch scripts
export TXN_FROM_DATE
export TXN_TO_DATE

# Clean and create output directory
if [[ -d "$OUTPUT_DIR" ]]; then
    log_info "Cleaning existing output directory: $OUTPUT_DIR"
    rm -rf "$OUTPUT_DIR"
fi
mkdir -p "$OUTPUT_DIR"
log_info "Output directory: $OUTPUT_DIR"

# Step 1: Authenticate with Finicity
finicity_authenticate || exit 1

# Step 2: Fetch customer data
log_info "Step 1/4: Fetching customer data..."
"$PROJECT_DIR/src/finicity/fetch-customer.sh" "$OUTPUT_DIR/customers.json" || exit 1

# Step 3: Fetch accounts data
log_info "Step 2/4: Fetching accounts data..."
"$PROJECT_DIR/src/finicity/fetch-accounts.sh" "$OUTPUT_DIR/accounts.json" || exit 1

# Extract institution IDs from accounts for later use
INSTITUTION_IDS=$(jq -r '.accounts[].institutionId // empty' "$OUTPUT_DIR/accounts.json" | sort -u)

# Step 4: Fetch transactions data
log_info "Step 3/4: Fetching transactions data..."
TRANSACTIONS_DIR="$OUTPUT_DIR/transactions"
mkdir -p "$TRANSACTIONS_DIR"
"$PROJECT_DIR/src/finicity/fetch-transactions.sh" "$TRANSACTIONS_DIR" "$OUTPUT_DIR/accounts.json" || exit 1

# Step 5: Fetch institutions data
log_info "Step 4/4: Fetching institutions data..."
INSTITUTIONS_DIR="$OUTPUT_DIR/institutions"
mkdir -p "$INSTITUTIONS_DIR"
if [[ -n "$INSTITUTION_IDS" ]]; then
    "$PROJECT_DIR/src/finicity/fetch-institutions.sh" "$INSTITUTIONS_DIR" $INSTITUTION_IDS || exit 1
else
    log_warn "No institution IDs found, creating empty institutions directory"
    "$PROJECT_DIR/src/finicity/fetch-institutions.sh" "$INSTITUTIONS_DIR" || exit 1
fi

log_info "✓ All Finicity data fetched successfully!"
log_info "Files saved to: $OUTPUT_DIR"
log_info "  - customers.json"
log_info "  - accounts.json"
log_info "  - transactions/ (individual transaction files per account per page)"
log_info "  - institutions/ (individual institution files per institution)"

