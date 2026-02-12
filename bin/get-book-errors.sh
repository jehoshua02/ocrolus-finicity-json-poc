#!/usr/bin/env bash
#
# Get Book Errors from Ocrolus
#
# This script retrieves the status and errors for a specific Ocrolus Book.
# It fetches the book status which includes document processing errors.
#
# Required Environment Variables:
#   OCROLUS_CLIENT_ID         - Ocrolus OAuth2 client ID
#   OCROLUS_CLIENT_SECRET     - Ocrolus OAuth2 client secret
#
# Optional Environment Variables:
#   OCROLUS_BOOK_PK           - Default book PK to check (can be overridden by argument)
#
# Optional Arguments:
#   $1 - Book PK (primary key) to check for errors (defaults to OCROLUS_BOOK_PK from env)
#
# Output:
#   Displays book status and any document errors in a readable format
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
validate_required_vars OCROLUS_CLIENT_ID OCROLUS_CLIENT_SECRET || exit 1

# Get Book PK from argument or environment variable
if [[ $# -ge 1 ]]; then
    BOOK_PK="$1"
elif [[ -n "${OCROLUS_BOOK_PK:-}" ]]; then
    BOOK_PK="$OCROLUS_BOOK_PK"
else
    log_error "Usage: $0 [book_pk]"
    log_error "Example: $0 127707317"
    log_error "Or set OCROLUS_BOOK_PK in your .env file"
    exit 1
fi

log_info "Fetching book status for Book PK: $BOOK_PK"

# Authenticate with Ocrolus
ocrolus_authenticate || exit 1

# Fetch book status from Ocrolus
BOOK_STATUS_RESPONSE=$(curl -s -X GET "https://api.ocrolus.com/v1/book/status?pk=$BOOK_PK" \
    -H "Authorization: Bearer $OCROLUS_TOKEN" \
    -H "Accept: application/json")

# Validate JSON response
if ! echo "$BOOK_STATUS_RESPONSE" | jq empty 2>/dev/null; then
    log_error "Invalid JSON received from Ocrolus API"
    log_error "Response: $BOOK_STATUS_RESPONSE"
    exit 1
fi

# Check for API errors
API_STATUS=$(echo "$BOOK_STATUS_RESPONSE" | jq -r '.status // empty')
if [[ "$API_STATUS" != "200" && -n "$API_STATUS" ]]; then
    log_error "API request failed with status: $API_STATUS"
    echo "$BOOK_STATUS_RESPONSE" | jq '.'
    exit 1
fi

# Parse and display book information
log_info "✓ Book status retrieved successfully"
echo ""
echo "=========================================="
echo "Book Information"
echo "=========================================="
echo "Book PK: $(echo "$BOOK_STATUS_RESPONSE" | jq -r '.response.pk // "N/A"')"
echo "Book UUID: $(echo "$BOOK_STATUS_RESPONSE" | jq -r '.response.uuid // "N/A"')"
echo "Book Name: $(echo "$BOOK_STATUS_RESPONSE" | jq -r '.response.name // "N/A"')"
echo "Book Status: $(echo "$BOOK_STATUS_RESPONSE" | jq -r '.response.book_status // "N/A"')"
echo "Book Class: $(echo "$BOOK_STATUS_RESPONSE" | jq -r '.response.book_class // "N/A"')"
echo "Created: $(echo "$BOOK_STATUS_RESPONSE" | jq -r '.response.created_ts // "N/A"')"
echo ""

# Check for documents and errors (Ocrolus uses 'docs' field)
DOCUMENTS=$(echo "$BOOK_STATUS_RESPONSE" | jq -r '.response.docs // []')
DOC_COUNT=$(echo "$DOCUMENTS" | jq 'length')

if [[ "$DOC_COUNT" -eq 0 ]]; then
    log_info "No documents found in this book"
    exit 0
fi

echo "=========================================="
echo "Documents ($DOC_COUNT total)"
echo "=========================================="

# Count documents with errors
ERROR_COUNT=0
REJECTED_COUNT=0

# Display document information
echo "$DOCUMENTS" | jq -c '.[]' | while read -r doc; do
    echo ""
    echo "----------------------------------------"
    echo "Document:"
    echo "----------------------------------------"
    echo "$doc" | jq '.'
done

echo ""
echo "=========================================="

# Count errors for summary
REJECTED_COUNT=$(echo "$DOCUMENTS" | jq '[.[] | select(.status == "REJECTED")] | length')
VERIFIED_COUNT=$(echo "$DOCUMENTS" | jq '[.[] | select(.status == "VERIFICATION_COMPLETE")] | length')

echo "Summary:"
echo "  Total Documents: $DOC_COUNT"
echo "  Verified: $VERIFIED_COUNT"
echo "  Rejected: $REJECTED_COUNT"
echo ""

if [[ "$REJECTED_COUNT" -eq 0 ]]; then
    log_info "✓ No errors found in any documents"
else
    log_warn "⚠️  Found $REJECTED_COUNT document(s) with errors"
fi

