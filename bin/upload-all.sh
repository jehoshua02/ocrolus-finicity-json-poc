#!/usr/bin/env bash
#
# Upload All Finicity JSON to Ocrolus - Orchestrator Script
#
# This script orchestrates uploading pre-fetched Finicity JSON files to Ocrolus.
#
# Required Environment Variables:
#   OCROLUS_CLIENT_ID         - Ocrolus OAuth2 client ID
#   OCROLUS_CLIENT_SECRET     - Ocrolus OAuth2 client secret
#   OCROLUS_BOOK_PK           - Ocrolus Book PK to upload into
#
# Optional Arguments:
#   $1 - Input directory containing JSON files (defaults to ./output)
#
# Expected Files in Input Directory:
#   - customers.json
#   - accounts.json
#   - transactions/ (directory with individual transaction files per account per page)
#   - institutions/ (directory with individual institution files per institution)
#
# Note: Transaction files should include dailyBalances field (fetched with showDailyBalance=true)
#

set -euo pipefail

# Get script directory (bin directory)
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get project root directory (parent of bin)
PROJECT_DIR="$(cd "$BIN_DIR/.." && pwd)"

# Source common utilities and authentication libraries
source "$PROJECT_DIR/src/lib/common.sh"
source "$PROJECT_DIR/src/lib/ocrolus-auth.sh"

# Load .env file
load_env_file

# Validate required environment variables
validate_required_vars OCROLUS_CLIENT_ID OCROLUS_CLIENT_SECRET OCROLUS_BOOK_PK || exit 1

# Get input directory (default to ./output)
INPUT_DIR="${1:-$PROJECT_DIR/output}"

if [[ ! -d "$INPUT_DIR" ]]; then
    log_error "Input directory not found: $INPUT_DIR"
    exit 1
fi

log_info "Input directory: $INPUT_DIR"

# Validate all required files and directories exist
CUSTOMERS_FILE="$INPUT_DIR/customers.json"
ACCOUNTS_FILE="$INPUT_DIR/accounts.json"
TRANSACTIONS_DIR="$INPUT_DIR/transactions"
INSTITUTIONS_DIR="$INPUT_DIR/institutions"

# Check for required files
for file in "$CUSTOMERS_FILE" "$ACCOUNTS_FILE"; do
    if [[ ! -f "$file" ]]; then
        log_error "Required file not found: $file"
        exit 1
    fi
done

# Check for transactions directory
if [[ ! -d "$TRANSACTIONS_DIR" ]]; then
    log_error "Transactions directory not found: $TRANSACTIONS_DIR"
    exit 1
fi

# Check for institutions directory
if [[ ! -d "$INSTITUTIONS_DIR" ]]; then
    log_error "Institutions directory not found: $INSTITUTIONS_DIR"
    exit 1
fi

log_info "✓ All required files and directories found"

# Step 1: Authenticate with Ocrolus
log_info "Step 1/2: Authenticating with Ocrolus..."
ocrolus_authenticate || exit 1

# Step 2: Upload to Ocrolus
log_info "Step 2/2: Uploading Finicity JSON bundle to Ocrolus..."
"$PROJECT_DIR/src/upload/upload-to-ocrolus.sh" \
    "$CUSTOMERS_FILE" \
    "$ACCOUNTS_FILE" \
    "$TRANSACTIONS_DIR" \
    "$INSTITUTIONS_DIR" || exit 1

log_info "✓ Upload completed successfully!"

