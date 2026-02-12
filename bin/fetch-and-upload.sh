#!/usr/bin/env bash
#
# POC: Fetch Finicity JSON and Upload to Ocrolus
#
# This script demonstrates the complete end-to-end flow of fetching customer,
# account, transaction, and institution data from Finicity's API, then uploading
# all four JSON files to Ocrolus.
#
# This is now a simple orchestrator that uses modular scripts:
# - fetch-all.sh: Fetches all Finicity data
# - upload-all.sh: Uploads JSON bundle to Ocrolus
#
# Required Environment Variables:
#   FINICITY_PARTNER_ID       - Finicity partner ID
#   FINICITY_PARTNER_SECRET   - Finicity partner secret
#   FINICITY_APP_KEY          - Finicity app key
#   FINICITY_CUSTOMER_ID      - Finicity customer ID to fetch data for
#   OCROLUS_CLIENT_ID         - Ocrolus OAuth2 client ID
#   OCROLUS_CLIENT_SECRET     - Ocrolus OAuth2 client secret
#   OCROLUS_BOOK_PK           - Ocrolus Book PK to upload into
#
# Optional Environment Variables:
#   FINICITY_ACCOUNT_ID       - Specific account ID (if omitted, fetches all customer accounts)
#   TXN_FROM_DATE             - Unix timestamp for transaction start (defaults to 90 days ago)
#   TXN_TO_DATE               - Unix timestamp for transaction end (defaults to now)
#

set -euo pipefail

# Get script directory (bin directory)
BIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Get project root directory (parent of bin)
PROJECT_DIR="$(cd "$BIN_DIR/.." && pwd)"

# Source common utilities
source "$PROJECT_DIR/src/lib/common.sh"

# Load .env file
load_env_file

# Set output directories
export OUTPUT_DIR="$PROJECT_DIR/output/original"
export TRANSFORMED_DIR="$PROJECT_DIR/output/transformed"
mkdir -p "$OUTPUT_DIR"

log_info "==================================================================="
log_info "POC: Fetch Finicity JSON and Upload to Ocrolus"
log_info "==================================================================="
log_info ""

# Step 1: Fetch all Finicity data
log_info "PART 1: Fetching Finicity Data"
log_info "-------------------------------------------------------------------"
"$BIN_DIR/fetch-all.sh" || exit 1

log_info ""
log_info "PART 2: Transforming Data for Ocrolus"
log_info "-------------------------------------------------------------------"

# Step 2: Transform the data (add missing fields with fake values)
"$BIN_DIR/transform-for-ocrolus.sh" || exit 1

log_info ""
log_info "PART 3: Uploading to Ocrolus"
log_info "-------------------------------------------------------------------"

# Step 3: Upload transformed data to Ocrolus
"$BIN_DIR/upload-all.sh" "$TRANSFORMED_DIR" || exit 1

log_info ""
log_info "PART 4: Checking for Upload Errors"
log_info "-------------------------------------------------------------------"

# Step 4: Check for errors in the uploaded book
"$BIN_DIR/get-book-errors.sh" "$OCROLUS_BOOK_PK" || exit 1

log_info ""
log_info "==================================================================="
log_info "✓ POC completed successfully!"
log_info "==================================================================="
log_info "Original Finicity data: $OUTPUT_DIR"
log_info "Transformed data: $TRANSFORMED_DIR"

