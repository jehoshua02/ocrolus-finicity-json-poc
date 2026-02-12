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
#   OUTPUT_DIR              - Source directory with original Finicity JSON (default: output/original)
#   TRANSFORMED_DIR         - Target directory for transformed JSON (default: output/transformed)
#   TRANSFORM_CUSTOMERS     - Enable customer transformations (default: true)
#   TRANSFORM_ACCOUNTS      - Enable account transformations (default: true)
#   TRANSFORM_TRANSACTIONS  - Enable transaction transformations (default: true)
#   TRANSFORM_INSTITUTIONS  - Enable institution transformations (default: true)
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
TRANSFORM_CUSTOMERS="${TRANSFORM_CUSTOMERS:-true}"
TRANSFORM_ACCOUNTS="${TRANSFORM_ACCOUNTS:-true}"
TRANSFORM_TRANSACTIONS="${TRANSFORM_TRANSACTIONS:-true}"
TRANSFORM_INSTITUTIONS="${TRANSFORM_INSTITUTIONS:-true}"

log_info "==================================================================="
log_info "Transforming Finicity JSON for Ocrolus"
log_info "==================================================================="
log_info "Source directory: $SOURCE_DIR"
log_info "Target directory: $TARGET_DIR"
log_info "Transformation settings:"
log_info "  Customers: $TRANSFORM_CUSTOMERS"
log_info "  Accounts: $TRANSFORM_ACCOUNTS"
log_info "  Transactions: $TRANSFORM_TRANSACTIONS"
log_info "  Institutions: $TRANSFORM_INSTITUTIONS"

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
    if [[ "$TRANSFORM_CUSTOMERS" == "true" ]]; then
        jq '
        if .firstName == null or .firstName == "" then
            .firstName = "Test"
        else
            .
        end |
        if .lastName == null or .lastName == "" then
            .lastName = "User"
        else
            .
        end |
        if .phone == null or .phone == "" then
            .phone = "555-123-4567"
        else
            .
        end |
        if .email == null or .email == "" then
            .email = "test.user@example.com"
        else
            .
        end |
        if .applicationId == null or .applicationId == "" then
            .applicationId = "test-application-id"
        else
            .
        end
        ' "$SOURCE_DIR/customers.json" > "$TARGET_DIR/customers.json"

        validate_json "$TARGET_DIR/customers.json" || exit 1
        log_info "✓ Customers data transformed"
    else
        cp "$SOURCE_DIR/customers.json" "$TARGET_DIR/customers.json"
        log_info "✓ Customers data copied (transformation disabled)"
    fi
else
    log_error "customers.json not found in source directory"
    exit 1
fi

log_info ""
log_info "Step 2/4: Transforming accounts.json..."

# Transform accounts.json - add missing fields
if [[ -f "$SOURCE_DIR/accounts.json" ]]; then
    if [[ "$TRANSFORM_ACCOUNTS" == "true" ]]; then
        jq '
        .accounts |= map(
            # Add oldestTransactionDate if missing
            if .oldestTransactionDate == null or .oldestTransactionDate == "" then
                .oldestTransactionDate = 1707739200
            else
                .
            end |
            # Add detail object if missing (for accounts like Credit Card)
            if .detail == null then
                .detail = {}
            else
                .
            end |
            # Add realAccountNumberLast4 if missing
            if .realAccountNumberLast4 == null or .realAccountNumberLast4 == "" then
                .realAccountNumberLast4 = .accountNumberDisplay
            else
                .
            end
        )
        ' "$SOURCE_DIR/accounts.json" > "$TARGET_DIR/accounts.json"

        validate_json "$TARGET_DIR/accounts.json" || exit 1
        ACCOUNT_COUNT=$(jq '.accounts | length' "$TARGET_DIR/accounts.json")
        log_info "✓ Accounts data transformed ($ACCOUNT_COUNT account(s))"
    else
        cp "$SOURCE_DIR/accounts.json" "$TARGET_DIR/accounts.json"
        ACCOUNT_COUNT=$(jq '.accounts | length' "$TARGET_DIR/accounts.json")
        log_info "✓ Accounts data copied ($ACCOUNT_COUNT account(s), transformation disabled)"
    fi
else
    log_error "accounts.json not found in source directory"
    exit 1
fi

log_info ""
log_info "Step 3/4: Transforming transactions..."

# Transform transaction files - copy as-is for now (can add transformations later if needed)
TRANSACTION_COUNT=0
if [[ -d "$SOURCE_DIR/transactions" ]]; then
    for txn_file in "$SOURCE_DIR/transactions"/*.json; do
        if [[ -f "$txn_file" ]]; then
            filename=$(basename "$txn_file")
            if [[ "$TRANSFORM_TRANSACTIONS" == "true" ]]; then
                # Currently no transformations for transactions, just copy
                # Add transformation logic here if needed in the future
                cp "$txn_file" "$TARGET_DIR/transactions/$filename"
            else
                cp "$txn_file" "$TARGET_DIR/transactions/$filename"
            fi
            TRANSACTION_COUNT=$((TRANSACTION_COUNT + 1))
        fi
    done
    if [[ "$TRANSFORM_TRANSACTIONS" == "true" ]]; then
        log_info "✓ Transaction files transformed ($TRANSACTION_COUNT file(s))"
    else
        log_info "✓ Transaction files copied ($TRANSACTION_COUNT file(s), transformation disabled)"
    fi
else
    log_warn "No transactions directory found"
fi

log_info ""
log_info "Step 4/4: Transforming institutions..."

# Transform institution files - remove null offerBusinessAccounts and offerPersonalAccounts fields
INSTITUTION_COUNT=0
if [[ -d "$SOURCE_DIR/institutions" ]]; then
    for inst_file in "$SOURCE_DIR/institutions"/*.json; do
        if [[ -f "$inst_file" ]]; then
            filename=$(basename "$inst_file")
            if [[ "$TRANSFORM_INSTITUTIONS" == "true" ]]; then
                # Remove offerBusinessAccounts and offerPersonalAccounts fields from institution object
                jq 'del(.institution.offerBusinessAccounts, .institution.offerPersonalAccounts)' "$inst_file" > "$TARGET_DIR/institutions/$filename"

                validate_json "$TARGET_DIR/institutions/$filename" || exit 1
            else
                cp "$inst_file" "$TARGET_DIR/institutions/$filename"
            fi
            INSTITUTION_COUNT=$((INSTITUTION_COUNT + 1))
        fi
    done
    if [[ "$TRANSFORM_INSTITUTIONS" == "true" ]]; then
        log_info "✓ Institution files transformed ($INSTITUTION_COUNT file(s))"
    else
        log_info "✓ Institution files copied ($INSTITUTION_COUNT file(s), transformation disabled)"
    fi
else
    log_warn "No institutions directory found"
fi

log_info ""
log_info "✓ Transformation complete!"
log_info "Transformed files saved to: $TARGET_DIR"

