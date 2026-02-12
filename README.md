# Finicity JSON to Ocrolus POC

This proof-of-concept demonstrates fetching customer, account, transaction, and institution data from Finicity's API and uploading it to Ocrolus.

## Architecture

The POC is built with a **modular architecture** for flexibility and reusability:

```
scripts/poc/finicity-json/
├── bin/                          # Entry point scripts
│   ├── fetch-all.sh              # Orchestrator: fetch all Finicity data
│   ├── add-daily-balances.sh     # Standalone: add dailyBalances to transactions
│   ├── upload-all.sh             # Orchestrator: process & upload to Ocrolus
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

### Part 2: Upload to Ocrolus
6. Authenticate with Ocrolus using OAuth2
7. Upload all JSON files to `POST https://api.ocrolus.com/v1/book/upload/json?aggregate_source=FINICITY`
   - Uploads customers.json and accounts.json as single files
   - Uploads all transaction JSON files (with dailyBalances from Finicity API)
   - Uploads all institution JSON files (one per institution)

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
2. Calls `upload-all.sh` to upload to Ocrolus
3. Saves output to `./output/`

### Fetch Orchestrator: `fetch-all.sh`
1. Loads environment variables from `.env`
2. Authenticates with Finicity
3. Fetches customer, accounts, transactions, and institutions data
4. Saves all JSON files to output directory (default: `./output/`)

### Upload Orchestrator: `upload-all.sh`
1. Loads environment variables from `.env`
2. Validates all required JSON files and directories exist
3. Authenticates with Ocrolus
4. Uploads all JSON files as multipart form data with `aggregate_source=FINICITY`
   - Each transaction file is uploaded with a separate `-F transactions=@file` parameter
   - Each institution file is uploaded with a separate `-F institutions=@file` parameter

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
[INFO] Output directory: .../scripts/poc/finicity-json/output
[INFO] Authenticating with Finicity...
[INFO] ✓ Finicity authentication successful
[INFO] Step 1/4: Fetching customer data...
[INFO] Fetching customer data for customer ID: 5033153951
[INFO] ✓ Customer data saved to: .../output/customers.json
[INFO] Step 2/4: Fetching accounts data...
[INFO] Fetching all accounts for customer: 5033153951
[INFO] ✓ Accounts data saved to: .../output/accounts.json (8 account(s))
[INFO] Step 3/4: Fetching transactions data...
[INFO] Fetching transactions for customer: 5033153951
[INFO] Date range: 1763065050 to 1770841050
[INFO] Transactions per page: 20
[INFO] [1/8] Processing account: 9012247539
[INFO]   Fetching page 1 (start=1, limit=20)...
[INFO]   ✓ Page 1 saved: .../transactions/transactions_9012247539_page_1.json (7 transactions)
[INFO]   Account 9012247539 complete: 7 transactions across 1 page(s)
[INFO] [2/8] Processing account: 9012247540
[INFO]   Fetching page 1 (start=1, limit=20)...
[INFO]   ✓ Page 1 saved: .../transactions/transactions_9012247540_page_1.json (7 transactions)
[INFO]   Account 9012247540 complete: 7 transactions across 1 page(s)
[INFO] ...
[INFO] ✓ All transactions fetched successfully!
[INFO]   Total accounts: 8
[INFO]   Total transactions: 57
[INFO]   Total pages: 8
[INFO] Step 4/4: Fetching institutions data...
[INFO] Fetching 1 institution(s)...
[INFO] Fetching institution 101732...
[INFO]   ✓ Saved to: .../output/institutions/institution_101732.json
[INFO] ✓ Institutions data saved to: .../output/institutions (1 institution(s))
[INFO] ✓ All Finicity data fetched successfully!
[INFO]
[INFO] PART 2: Uploading to Ocrolus
[INFO] -------------------------------------------------------------------
[INFO] Input directory: .../scripts/poc/finicity-json/output
[INFO] ✓ All required files found
[INFO] Authenticating with Ocrolus...
[INFO] ✓ Ocrolus authentication successful
[INFO] Uploading Finicity JSON bundle to Ocrolus...
[INFO] Validating input files...
[INFO] ✓ All input files validated
[INFO] Preview of JSON files being uploaded:
[INFO]   Customers: {"customer":{"id":"5033153951",...
[INFO]   Accounts: {"accounts":[{"id":"6040885682",...
[INFO]   Transactions: 57 transaction(s) across 8 file(s)
[INFO]   Institutions: 1 institution(s) across 1 file(s)
[INFO] Uploading Finicity JSON bundle to Ocrolus Book PK: 127707317...
[INFO] ✓ Upload successful!
{
  "status": 200,
  "message": "OK",
  "response": {
    "pk": 127707317,
    "uuid": "781a8706-4c93-43c3-8364-8280fd77cd12"
  }
}
[INFO] ✓ Upload completed successfully!
[INFO]
[INFO] ===================================================================
[INFO] ✓ POC completed successfully!
[INFO] ===================================================================
[INFO] Output saved to: .../scripts/poc/finicity-json/output
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
- Output is saved to `./output/` for inspection
- The scripts follow the Ocrolus documentation for Finicity JSON uploads

## References

- [Ocrolus Finicity Integration Guide](https://docs.ocrolus.com/docs/aggregator-finicity)
- [Ocrolus Upload JSON Endpoint](https://docs.ocrolus.com/reference/upload-plaid-json)

