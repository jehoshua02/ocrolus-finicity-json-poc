#!/usr/bin/env bash
#
# Transform Finicity JSON for Ocrolus Upload
#
# This script reads Finicity JSON files from the output directory,
# transforms them by adding fake/default values for missing fields,
# and writes the transformed files to a new directory.
#
# This ensures the original Finicity data remains unchanged while
# providing Ocrolus with complete data that may be required.
#
# Required Environment Variables:
#   None (uses relative paths)
#
# Optional Environment Variables:
#   OUTPUT_DIR                      - Source directory with original Finicity JSON (default: output/original)
#   TRANSFORMED_DIR                 - Target directory for transformed JSON (default: output/transformed)
#   TRANSFORM_CUSTOMER_FIRSTNAME    - Add default firstName if missing (default: true)
#   TRANSFORM_CUSTOMER_LASTNAME     - Add default lastName if missing (default: true)
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

# Set directories
SOURCE_DIR="${OUTPUT_DIR:-$PROJECT_DIR/output/original}"
TARGET_DIR="${TRANSFORMED_DIR:-$PROJECT_DIR/output/transformed}"

# Set transformation toggles (default to true if not set)
TRANSFORM_CUSTOMER_FIRSTNAME="${TRANSFORM_CUSTOMER_FIRSTNAME:-true}"
TRANSFORM_CUSTOMER_LASTNAME="${TRANSFORM_CUSTOMER_LASTNAME:-true}"

log_info "==================================================================="
log_info "Transforming Finicity JSON for Ocrolus"
log_info "==================================================================="
log_info "Source directory: $SOURCE_DIR"
log_info "Target directory: $TARGET_DIR"
log_info "Customer transformation settings:"
log_info "  firstName: $TRANSFORM_CUSTOMER_FIRSTNAME"
log_info "  lastName: $TRANSFORM_CUSTOMER_LASTNAME"

# Validate source directory exists
if [[ ! -d "$SOURCE_DIR" ]]; then
    log_error "Source directory does not exist: $SOURCE_DIR"
    exit 1
fi

# Clean and create target directory
rm -rf "$TARGET_DIR"
mkdir -p "$TARGET_DIR"
mkdir -p "$TARGET_DIR/transactions"
mkdir -p "$TARGET_DIR/institutions"

log_info ""
log_info "Step 1/4: Transforming customers.json..."

# Transform customers.json - add fake values for fields that may be required by Ocrolus
if [[ -f "$SOURCE_DIR/customers.json" ]]; then
    # Build jq transformation based on enabled flags
    JQ_TRANSFORM="."

    if [[ "$TRANSFORM_CUSTOMER_FIRSTNAME" == "true" ]]; then
        JQ_TRANSFORM="$JQ_TRANSFORM | if .firstName == null or .firstName == \"\" then .firstName = \"Test\" else . end"
    fi

    if [[ "$TRANSFORM_CUSTOMER_LASTNAME" == "true" ]]; then
        JQ_TRANSFORM="$JQ_TRANSFORM | if .lastName == null or .lastName == \"\" then .lastName = \"User\" else . end"
    fi

    # Apply transformation
    jq "$JQ_TRANSFORM" "$SOURCE_DIR/customers.json" > "$TARGET_DIR/customers.json"

    validate_json "$TARGET_DIR/customers.json" || exit 1
    log_info "✓ Customers data transformed"
else
    log_error "customers.json not found in source directory"
    exit 1
fi

log_info ""
log_info "Step 2/4: Copying accounts.json..."

# Copy accounts.json as-is
if [[ -f "$SOURCE_DIR/accounts.json" ]]; then
    cp "$SOURCE_DIR/accounts.json" "$TARGET_DIR/accounts.json"
    ACCOUNT_COUNT=$(jq '.accounts | length' "$TARGET_DIR/accounts.json")
    log_info "✓ Accounts data copied ($ACCOUNT_COUNT account(s))"
else
    log_error "accounts.json not found in source directory"
    exit 1
fi

log_info ""
log_info "Step 3/4: Copying transactions..."

# Copy transaction files as-is
TRANSACTION_COUNT=0
if [[ -d "$SOURCE_DIR/transactions" ]]; then
    for txn_file in "$SOURCE_DIR/transactions"/*.json; do
        if [[ -f "$txn_file" ]]; then
            filename=$(basename "$txn_file")
            cp "$txn_file" "$TARGET_DIR/transactions/$filename"
            TRANSACTION_COUNT=$((TRANSACTION_COUNT + 1))
        fi
    done
    log_info "✓ Transaction files copied ($TRANSACTION_COUNT file(s))"
else
    log_warn "No transactions directory found"
fi

log_info ""
log_info "Step 4/4: Copying institutions..."

# Copy institution files as-is
INSTITUTION_COUNT=0
if [[ -d "$SOURCE_DIR/institutions" ]]; then
    for inst_file in "$SOURCE_DIR/institutions"/*.json; do
        if [[ -f "$inst_file" ]]; then
            filename=$(basename "$inst_file")
            cp "$inst_file" "$TARGET_DIR/institutions/$filename"
            INSTITUTION_COUNT=$((INSTITUTION_COUNT + 1))
        fi
    done
    log_info "✓ Institution files copied ($INSTITUTION_COUNT file(s))"
else
    log_warn "No institutions directory found"
fi

log_info ""
log_info "✓ Transformation complete!"
log_info "Transformed files saved to: $TARGET_DIR"

