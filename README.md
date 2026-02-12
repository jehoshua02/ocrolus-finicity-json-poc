# Finicity JSON to Ocrolus POC

This proof-of-concept demonstrates fetching customer, account, transaction, and institution data from Finicity's API and uploading it to Ocrolus.

## Architecture

The POC is built with a **modular architecture** for flexibility and reusability:

```
scripts/poc/finicity-json/
├── bin/                          # Entry point scripts
│   ├── fetch-all.sh              # Orchestrator: fetch all Finicity data
│   ├── transform-for-ocrolus.sh  # Transform: add missing fields for Ocrolus
│   ├── upload-all.sh             # Orchestrator: upload to Ocrolus
│   ├── get-book-errors.sh        # Check for upload errors
│   └── fetch-and-upload.sh       # Main: complete end-to-end flow
├── src/                          # Source code
│   ├── lib/                      # Shared library functions
│   │   ├── common.sh             # Logging, validation, utilities
│   │   ├── finicity-auth.sh      # Finicity authentication
│   │   └── ocrolus-auth.sh       # Ocrolus authentication
│   ├── finicity/                 # Finicity data fetching scripts
│   │   ├── fetch-customer.sh     # Fetch customer data
│   │   ├── fetch-accounts.sh     # Fetch accounts data
│   │   ├── fetch-transactions.sh # Fetch transactions data
│   │   └── fetch-institutions.sh # Fetch institutions data
│   └── ocrolus/                  # Ocrolus upload scripts
│       └── upload-to-ocrolus.sh  # Upload JSON bundle to Ocrolus
└── output/                       # Generated output files
    ├── original/                 # Original Finicity JSON (unmodified)
    └── transformed/              # Transformed JSON for Ocrolus upload
```

## Overview

### Part 1: Fetch Finicity JSON
1. Authenticate with Finicity using partner credentials
2. Fetch Customer JSON from `/aggregation/v1/customers/{customerId}`
3. Fetch Accounts JSON from `/aggregation/v1/customers/{customerId}/accounts`
4. Fetch Transactions JSON from `/aggregation/v4/customers/{customerId}/accounts/{accountId}/transactions` with pagination support
   - Fetches transactions per account (not customer-level)
   - Handles pagination automatically (default: 20 transactions per page)
   - Saves one JSON file per page per account
5. Fetch Institution(s) JSON from `/institution/v2/institutions/{institutionId}`
6. Save all original Finicity JSON to `output/original/`

### Part 2: Transform Data for Ocrolus
7. Transform Finicity JSON to add missing fields that may be required by Ocrolus
   - Add default values for missing customer fields (firstName, lastName, email, phone, etc.)
   - Add missing account fields (oldestTransactionDate, realAccountNumberLast4, detail object)
   - Transformation can be toggled on/off per data type via environment variables
8. Save transformed JSON to `output/transformed/`

### Part 3: Upload to Ocrolus
9. Authenticate with Ocrolus using OAuth2
10. Upload all transformed JSON files to `POST https://api.ocrolus.com/v1/book/upload/json?aggregate_source=FINICITY`
   - Uploads customers.json and accounts.json as single files
   - Uploads all transaction JSON files (with dailyBalances from Finicity API)
   - Uploads all institution JSON files (one per institution)

### Part 4: Check for Errors
11. Fetch book status from Ocrolus to check for upload errors
12. Display document status and any rejection reasons

## Prerequisites

- `bash` shell
- `curl` command-line tool
- `jq` JSON processor (install via `brew install jq` on macOS)

## Required Environment Variables

```bash
export FINICITY_PARTNER_ID="your-partner-id"
export FINICITY_PARTNER_SECRET="your-partner-secret"
export FINICITY_APP_KEY="your-app-key"
export FINICITY_CUSTOMER_ID="customer-id-to-fetch"
export OCROLUS_CLIENT_ID="your-ocrolus-client-id"
export OCROLUS_CLIENT_SECRET="your-ocrolus-client-secret"
export OCROLUS_BOOK_PK="book-pk-to-upload-to"
```

## Optional Environment Variables

```bash
# Fetch only a specific account (default: all customer accounts)
export FINICITY_ACCOUNT_ID="specific-account-id"

# Transaction date range (defaults to last 90 days)
export TXN_FROM_DATE="1640995200"  # Unix timestamp
export TXN_TO_DATE="1672531200"    # Unix timestamp

# Transactions per page for pagination (default: 20, max: 1000)
export TXN_LIMIT="20"

# Transformation toggles (default: true)
# Set to "false" to disable transformations for specific data types
export TRANSFORM_CUSTOMERS="false"
export TRANSFORM_ACCOUNTS="false"
export TRANSFORM_TRANSACTIONS="false"
export TRANSFORM_INSTITUTIONS="false"
```

## Usage

All scripts automatically load environment variables from a `.env` file in the `scripts/poc/finicity-json/` directory.

### Quick Start: Complete End-to-End Flow

```bash
# 1. Copy the example .env file
cp scripts/poc/finicity-json/.env.example scripts/poc/finicity-json/.env

# 2. Edit the .env file with your credentials
vim scripts/poc/finicity-json/.env

# 3. Run the complete flow (fetch + upload)
./scripts/poc/finicity-json/bin/fetch-and-upload.sh
```

### Modular Usage Examples

#### Fetch All Finicity Data (without uploading)

```bash
# Fetch all data and save to ./output directory
./scripts/poc/finicity-json/bin/fetch-all.sh

# Or specify a custom output directory
OUTPUT_DIR=/tmp/finicity-data ./scripts/poc/finicity-json/bin/fetch-all.sh
```

#### Upload Pre-Fetched Data

```bash
# Upload from default ./output directory
./scripts/poc/finicity-json/bin/upload-all.sh

# Or upload from a custom directory
./scripts/poc/finicity-json/bin/upload-all.sh /path/to/json/files
```

#### Fetch Individual Data Types

```bash
# First, authenticate with Finicity
source scripts/poc/finicity-json/src/lib/common.sh
source scripts/poc/finicity-json/src/lib/finicity-auth.sh
finicity_authenticate

# Then fetch specific data
./scripts/poc/finicity-json/src/finicity/fetch-customer.sh /tmp/customers.json
./scripts/poc/finicity-json/src/finicity/fetch-accounts.sh /tmp/accounts.json

# Fetch transactions (requires accounts.json to be fetched first)
./scripts/poc/finicity-json/src/finicity/fetch-transactions.sh /tmp/transactions /tmp/accounts.json

# Fetch institutions (saves each institution to its own file)
./scripts/poc/finicity-json/src/finicity/fetch-institutions.sh /tmp/institutions 101732 102105
```

#### Re-Upload Same Data to Different Book

```bash
# Upload previously fetched data to a different Ocrolus book
OCROLUS_BOOK_PK=12345 ./scripts/poc/finicity-json/bin/upload-all.sh ./output
```

## What the Scripts Do

### Main Orchestrator: `fetch-and-upload.sh`
1. Calls `fetch-all.sh` to fetch all Finicity data
2. Calls `transform-for-ocrolus.sh` to transform the data
3. Calls `upload-all.sh` to upload transformed data to Ocrolus
4. Calls `get-book-errors.sh` to check for upload errors
5. Saves output to `./output/original/` and `./output/transformed/`

### Fetch Orchestrator: `fetch-all.sh`
1. Loads environment variables from `.env`
2. Authenticates with Finicity
3. Fetches customer, accounts, transactions, and institutions data
4. Saves all JSON files to output directory (default: `./output/original/`)

### Transform Script: `transform-for-ocrolus.sh`
1. Reads original Finicity JSON from `output/original/`
2. Transforms data by adding missing fields that may be required by Ocrolus:
   - **Customers**: Adds default values for firstName, lastName, email, phone, lastModifiedDate, applicationId
   - **Accounts**: Adds oldestTransactionDate, realAccountNumberLast4, detail object
   - **Transactions**: Currently no transformations (copies as-is)
   - **Institutions**: Currently no transformations (copies as-is)
3. Each transformation can be toggled on/off via environment variables
4. Saves transformed JSON to `output/transformed/`

### Upload Orchestrator: `upload-all.sh`
1. Loads environment variables from `.env`
2. Validates all required JSON files and directories exist
3. Authenticates with Ocrolus
4. Uploads all JSON files as multipart form data with `aggregate_source=FINICITY`
   - Each transaction file is uploaded with a separate `-F transactions=@file` parameter
   - Each institution file is uploaded with a separate `-F institutions=@file` parameter

### Error Checker: `get-book-errors.sh`
1. Fetches book status from Ocrolus API
2. Displays book information and document statuses
3. Shows rejection reasons for any rejected documents
4. Warns if any documents have errors

### Individual Fetch Scripts
- **`fetch-customer.sh`**: Fetches single customer data, wraps in `{customer: {...}}`
- **`fetch-accounts.sh`**: Fetches all accounts or specific account
- **`fetch-transactions.sh`**: Fetches transactions per account with pagination support
  - Uses account-level endpoint: `/aggregation/v4/customers/{customerId}/accounts/{accountId}/transactions`
  - Automatically handles pagination (configurable via `TXN_LIMIT`, default: 20)
  - Saves one JSON file per page per account: `transactions_{accountId}_page_{pageNum}.json`
  - **Includes `showDailyBalance=true` parameter to fetch daily balances from Finicity**
  - Preserves full Finicity response with metadata including `dailybalances` array
- **`fetch-institutions.sh`**: Fetches multiple institutions and saves each to its own file
  - Saves one JSON file per institution: `institution_{institutionId}.json`
  - Each file contains `{institutions: [...]}` format with a single institution

### Daily Balances
Transaction files fetched from Finicity include a `dailybalances` field (required by Ocrolus):
```json
{
  "found": 8,
  "displaying": 8,
  "transactions": [...],
  "dailybalances": [
    {
      "date": 1769065200,
      "beginning": -210.15,
      "ending": -211.37
    },
    ...
  ]
}
```
This data comes directly from Finicity's API using the `showDailyBalance=true` query parameter.

## Expected Output

```
[INFO] ===================================================================
[INFO] POC: Fetch Finicity JSON and Upload to Ocrolus
[INFO] ===================================================================
[INFO]
[INFO] PART 1: Fetching Finicity Data
[INFO] -------------------------------------------------------------------
[INFO] Loading environment variables from .../scripts/poc/finicity-json/.env
[INFO] Output directory: .../scripts/poc/finicity-json/output/original
[INFO] Authenticating with Finicity...
[INFO] ✓ Finicity authentication successful
[INFO] Step 1/4: Fetching customer data...
[INFO] Fetching customer data for customer ID: 9011211613
[INFO] ✓ Customer data saved to: .../output/original/customers.json
[INFO] Step 2/4: Fetching accounts data...
[INFO] Fetching all accounts for customer: 9011211613
[INFO] ✓ Accounts data saved to: .../output/original/accounts.json (8 account(s))
[INFO] Step 3/4: Fetching transactions data...
[INFO] Fetching transactions for customer: 9011211613
[INFO] Date range: 1763112575 to 1770888575
[INFO] Transactions per page: 20
[INFO] [1/8] Processing account: 9012247539
[INFO]   Fetching page 1 (start=1, limit=20)...
[INFO]   ✓ Page 1 saved: .../transactions/transactions_9012247539_page_1.json (7 transactions)
[INFO]   Account 9012247539 complete: 7 transactions across 1 page(s)
[INFO] ...
[INFO] ✓ All transactions fetched successfully!
[INFO]   Total accounts: 8
[INFO]   Total transactions: 50
[INFO]   Total pages: 8
[INFO] Step 4/4: Fetching institutions data...
[INFO] Fetching 1 institution(s)...
[INFO] Fetching institution 101732...
[INFO]   ✓ Saved to: .../output/original/institutions/institution_101732.json
[INFO] ✓ Institutions data saved to: .../output/original/institutions (1 institution(s))
[INFO] ✓ All Finicity data fetched successfully!
[INFO]
[INFO] PART 2: Transforming Data for Ocrolus
[INFO] -------------------------------------------------------------------
[INFO] ===================================================================
[INFO] Transforming Finicity JSON for Ocrolus
[INFO] ===================================================================
[INFO] Source directory: .../output/original
[INFO] Target directory: .../output/transformed
[INFO] Transformation settings:
[INFO]   Customers: true
[INFO]   Accounts: true
[INFO]   Transactions: true
[INFO]   Institutions: true
[INFO]
[INFO] Step 1/4: Transforming customers.json...
[INFO] ✓ Customers data transformed
[INFO]
[INFO] Step 2/4: Transforming accounts.json...
[INFO] ✓ Accounts data transformed (8 account(s))
[INFO]
[INFO] Step 3/4: Transforming transactions...
[INFO] ✓ Transaction files transformed (8 file(s))
[INFO]
[INFO] Step 4/4: Transforming institutions...
[INFO] ✓ Institution files transformed (1 file(s))
[INFO]
[INFO] ✓ Transformation complete!
[INFO] Transformed files saved to: .../output/transformed
[INFO]
[INFO] PART 3: Uploading to Ocrolus
[INFO] -------------------------------------------------------------------
[INFO] Input directory: .../output/transformed
[INFO] ✓ All required files and directories found
[INFO] Step 1/2: Authenticating with Ocrolus...
[INFO] ✓ Ocrolus authentication successful
[INFO] Step 2/2: Uploading Finicity JSON bundle to Ocrolus...
[INFO] Validating input files...
[INFO] ✓ All input files validated
[INFO] Preview of JSON files being uploaded:
[INFO]   Customers: {"id":"9011211613","username":"95bf9601-82cc-4634-8915-b2de8e27d667",...
[INFO]   Accounts: {"accounts":[{"id":"9012247539","number":"xxxxxx8888",...
[INFO]   Transactions: 50 transaction(s) across 8 file(s)
[INFO]   Institutions: 1 institution(s) across 1 file(s)
[INFO] Uploading Finicity JSON bundle to Ocrolus Book PK: 69976519...
[INFO] ✓ Upload successful!
{
  "status": 200,
  "response": {
    "uploaded_docs": [
      {
        "pk": 127818384,
        "id": 127818384,
        "uuid": "517f4385-34d8-486c-97b7-b37ef0d7c117",
        "name": "2fbda29a-2333-4cfd-9948-21c1f16388d0",
        "checksum": "75a0937978a536a5f15051b0cfc5ae71",
        "created_ts": "2026-02-12T09:29:39.521077"
      }
    ]
  },
  "message": "OK"
}
[INFO] ✓ Upload completed successfully!
[INFO]
[INFO] PART 4: Checking for Upload Errors
[INFO] -------------------------------------------------------------------
[INFO] Fetching book status for Book PK: 69976519
[INFO] ✓ Book status retrieved successfully

==========================================
Book Information
==========================================
Book PK: 69976519
Book UUID: d458e84f-66c9-49a8-a61b-cf66964036f2
Book Name: dev - Borrower 17858897
Book Status: VERIFIED
Book Class: COMPLETE
Created: 2026-02-11T17:48:55Z

==========================================
Documents (1 total)
==========================================

Document PK: 127818384
  UUID: 517f4385-34d8-486c-97b7-b37ef0d7c117
  Name: 2fbda29a-2333-4cfd-9948-21c1f16388d0
  Status: REJECTED
  Class: COMPLETE
  ⚠️  REJECTION REASON: Finicity JSON Parse Error

==========================================
Summary:
  Total Documents: 1
  Verified: 0
  Rejected: 1

[WARN] ⚠️  Found 1 document(s) with errors
[INFO]
[INFO] ===================================================================
[INFO] ✓ POC completed successfully!
[INFO] ===================================================================
[INFO] Original Finicity data: .../output/original
[INFO] Transformed data: .../output/transformed
```

## Error Handling

The script will exit with an error if:
- Any required environment variable is missing
- Finicity authentication fails
- Any API request returns invalid JSON
- Ocrolus authentication fails
- Ocrolus upload fails (non-200 status)

## Benefits of Modular Architecture

- **Flexibility**: Fetch without uploading, or upload pre-fetched data
- **Reusability**: Use individual scripts in other workflows
- **Testability**: Test each component independently
- **Maintainability**: Changes to one step don't affect others
- **Debugging**: Easier to debug individual steps
- **Composability**: Mix and match scripts for different use cases

## Data Transformation

The POC includes a transformation step that adds missing fields to Finicity JSON data before uploading to Ocrolus. This ensures compatibility with Ocrolus's requirements while preserving the original Finicity data.

### Why Transform?

Ocrolus may require certain fields that Finicity doesn't always provide. The transformation step adds default/fake values for these missing fields to prevent upload failures.

### What Gets Transformed?

- **Customers**: Adds firstName, lastName, email, phone, lastModifiedDate, applicationId if missing
- **Accounts**: Adds oldestTransactionDate, realAccountNumberLast4, detail object if missing
- **Transactions**: Currently no transformations (future-proofing)
- **Institutions**: Currently no transformations (future-proofing)

### Controlling Transformations

You can toggle transformations on/off for each data type using environment variables:

```bash
# In your .env file
TRANSFORM_CUSTOMERS="true"      # Set to "false" to disable customer transformations
TRANSFORM_ACCOUNTS="true"       # Set to "false" to disable account transformations
TRANSFORM_TRANSACTIONS="true"   # Set to "false" to disable transaction transformations
TRANSFORM_INSTITUTIONS="true"   # Set to "false" to disable institution transformations
```

When a transformation is disabled, the original Finicity data is copied as-is to the transformed directory.

### Directory Structure

- `output/original/` - Original Finicity JSON (never modified)
- `output/transformed/` - Transformed JSON ready for Ocrolus upload

## Notes

- All scripts automatically load `.env` file from the script directory
- All JSON responses are validated before proceeding
- Transaction date range defaults to the last 90 days if not specified
- Transactions are fetched using account-level endpoint with pagination support
  - Default limit: 20 transactions per page (configurable via `TXN_LIMIT`)
  - Finicity enforces a maximum of 1000 transactions per request
  - Each page is saved as a separate JSON file for easier processing
  - Full Finicity response structure is preserved (including metadata)
- Multiple institutions are supported and will be fetched and combined
- Original Finicity data is saved to `./output/original/` for inspection
- Transformed data is saved to `./output/transformed/` for upload
- The scripts follow the Ocrolus documentation for Finicity JSON uploads
- After upload, the script automatically checks for errors and displays rejection reasons

## References

- [Ocrolus Finicity Integration Guide](https://docs.ocrolus.com/docs/aggregator-finicity)
- [Ocrolus Upload JSON Endpoint](https://docs.ocrolus.com/reference/upload-plaid-json)

