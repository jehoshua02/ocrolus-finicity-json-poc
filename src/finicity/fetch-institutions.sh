#!/usr/bin/env bash
#
# Fetch Institutions Data from Finicity
#
# This script fetches institution data from Finicity for given institution IDs
# and saves each institution to its own JSON file.
#
# Required Environment Variables:
#   FINICITY_APP_KEY          - Finicity app key
#   FINICITY_TOKEN            - Finicity authentication token
#
# Required Arguments:
#   $1 - Output directory path for institution JSON files
#   $2+ - Institution IDs (space-separated)
#
# Output:
#   Creates individual JSON files in the output directory:
#   - institution_<id>.json (one per institution)
#

set -euo pipefail

# Source common utilities
_FETCH_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$_FETCH_DIR/../lib/common.sh"

# Validate arguments
if [[ $# -lt 1 ]]; then
    log_error "Usage: $0 <output_directory> [institution_id1 institution_id2 ...]"
    log_error "Example: $0 /tmp/institutions 101732 102105"
    exit 1
fi

OUTPUT_DIR="$1"
shift  # Remove first argument, leaving institution IDs

# Validate required environment variables
validate_required_vars FINICITY_APP_KEY FINICITY_TOKEN || exit 1

# Create output directory
mkdir -p "$OUTPUT_DIR"

# If no institution IDs provided, exit early
if [[ $# -eq 0 ]]; then
    log_warn "No institution IDs provided, no institution files will be created"
    log_info "✓ Output directory created: $OUTPUT_DIR"
    exit 0
fi

log_info "Fetching $# institution(s)..."

# Fetch each institution and save to individual files
FETCHED_COUNT=0
for INSTITUTION_ID in "$@"; do
    log_info "Fetching institution $INSTITUTION_ID..."

    OUTPUT_FILE="$OUTPUT_DIR/institution_$INSTITUTION_ID.json"

    # Fetch the institution data
    RESPONSE=$(curl -s -X GET "https://api.finicity.com/institution/v2/institutions/$INSTITUTION_ID" \
        -H "Finicity-App-Key: $FINICITY_APP_KEY" \
        -H "Finicity-App-Token: $FINICITY_TOKEN" \
        -H "Accept: application/json")

    # Validate JSON response
    if ! echo "$RESPONSE" | jq empty 2>/dev/null; then
        log_warn "Invalid JSON for institution $INSTITUTION_ID, skipping"
        continue
    fi

    # Write response to output file
    echo "$RESPONSE" | jq '.' > "$OUTPUT_FILE"

    # Validate output file
    if ! validate_json "$OUTPUT_FILE"; then
        log_warn "Failed to save institution $INSTITUTION_ID, skipping"
        rm -f "$OUTPUT_FILE"
        continue
    fi

    FETCHED_COUNT=$((FETCHED_COUNT + 1))
    log_info "  ✓ Saved to: $OUTPUT_FILE"
done

log_info "✓ Institutions data saved to: $OUTPUT_DIR ($FETCHED_COUNT institution(s))"

