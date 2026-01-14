#!/usr/bin/env zsh
set -euo pipefail

# Get Solana account info
# Usage: crypto-sol-account-info.sh <address> [chain]

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/crypto-common.sh"
source "$SCRIPT_DIR/crypto-solana.sh"

# Parse arguments
ADDRESS="${1:-}"
CHAIN="${2:-solana}"

# Validate required argument
if [[ -z "$ADDRESS" ]]; then
    _cry_print_error "Account address required"
    echo ""
    echo "**Usage:** crypto-sol-account-info.sh <address> [chain]"
    echo ""
    echo "**Example:**"
    echo '```bash'
    echo 'crypto-sol-account-info.sh vines1vzrYbzLMRdu58ou5XTby4qAqVRLmqo36NKPTg solana'
    echo '```'
    exit 1
fi

# Normalize chain name
CHAIN=$(_cry_normalize_chain "$CHAIN")

if [[ -z "$CHAIN" ]]; then
    _cry_print_error "Invalid chain specified"
    echo ""
    _cry_print_solana_supported_chains
    exit 1
fi

# Validate Solana chain
if ! _cry_is_solana_chain "$CHAIN"; then
    _cry_print_error "This skill is for Solana only. Use evm-address-info for EVM chains."
    echo ""
    _cry_print_solana_supported_chains
    exit 1
fi

# Validate address format
if ! _cry_validate_sol_address "$ADDRESS"; then
    _cry_print_error "Invalid Solana address format"
    echo ""
    echo "Expected: Base58 encoded address (32-44 characters)"
    echo "Got: ${#ADDRESS} characters"
    exit 1
fi

# Check for solana CLI
if ! _cry_check_solana_cli; then
    _cry_print_error "solana CLI is not installed"
    echo ""
    _cry_print_solana_install_help
    exit 1
fi

# Build URL arguments
_cry_build_solana_url_args "$CHAIN"

# Print header
_cry_print_header "Solana Account Info" "$CHAIN"

echo "**Address:** \`$ADDRESS\`"
echo ""

# Get balance
BALANCE_EXIT=0
BALANCE_OUTPUT=$(_cry_run_solana balance "$ADDRESS" --lamports "${_CRY_SOLANA_URL_ARGS[@]}") || BALANCE_EXIT=$?

if [[ $BALANCE_EXIT -ne 0 ]]; then
    # Balance might fail if account doesn't exist
    BALANCE_LAMPORTS="0"
else
    # Extract just the number (remove " lamports" suffix if present)
    BALANCE_LAMPORTS="${BALANCE_OUTPUT%% *}"
fi

BALANCE_SOL=$(_cry_lamports_to_sol "$BALANCE_LAMPORTS")

echo "### Balance"
echo ""
echo "| Unit | Value |"
echo "|------|-------|"
echo "| Lamports | $BALANCE_LAMPORTS |"
echo "| SOL | $BALANCE_SOL |"
echo ""

# Get account info (includes executable status, owner, etc.)
ACCOUNT_EXIT=0
ACCOUNT_OUTPUT=$(_cry_run_solana account "$ADDRESS" --output json-compact "${_CRY_SOLANA_URL_ARGS[@]}") || ACCOUNT_EXIT=$?

if [[ $ACCOUNT_EXIT -ne 0 ]]; then
    if [[ "$ACCOUNT_OUTPUT" == *"does not exist"* ]] || [[ "$ACCOUNT_OUTPUT" == *"not found"* ]]; then
        echo "### Account Type"
        echo ""
        echo "**Status:** Account does not exist or has no data (wallet with 0 balance)"
    else
        echo "### Account Info"
        echo ""
        echo "**Error:** Failed to get account info"
        echo ""
        echo '```'
        echo "$ACCOUNT_OUTPUT"
        echo '```'
    fi
else
    # Parse JSON output for key fields (format: {"account":{"owner":"...", ...}, "pubkey":"..."})
    # Use sed to extract values since we can't rely on jq
    OWNER=$(echo "$ACCOUNT_OUTPUT" | sed -n 's/.*"owner"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -1)
    EXECUTABLE=$(echo "$ACCOUNT_OUTPUT" | sed -n 's/.*"executable"[[:space:]]*:[[:space:]]*\([a-z]*\).*/\1/p' | head -1)
    DATA_LEN=$(echo "$ACCOUNT_OUTPUT" | sed -n 's/.*"space"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)
    RENT_EPOCH=$(echo "$ACCOUNT_OUTPUT" | sed -n 's/.*"rentEpoch"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' | head -1)

    # Determine account type using well-known program IDs
    if [[ "$EXECUTABLE" == "true" ]]; then
        ACCOUNT_TYPE="Program (Executable)"
    elif [[ "$OWNER" == "$_CRY_TOKEN_PROGRAM" ]]; then
        ACCOUNT_TYPE="Token Account"
    elif [[ "$OWNER" == "$_CRY_SYSTEM_PROGRAM" ]]; then
        ACCOUNT_TYPE="System Account (Wallet)"
    elif [[ "$OWNER" == "$_CRY_BPF_UPGRADEABLE_LOADER" ]] || [[ "$OWNER" == "$_CRY_BPF_LOADER2" ]]; then
        ACCOUNT_TYPE="Program (BPF Loader)"
    else
        ACCOUNT_TYPE="Data Account"
    fi

    echo "### Account Type"
    echo ""
    echo "**Type:** $ACCOUNT_TYPE"
    echo ""
    echo "### Account Details"
    echo ""
    echo "| Property | Value |"
    echo "|----------|-------|"
    [[ -n "$OWNER" ]] && echo "| Owner | \`$OWNER\` |"
    [[ -n "$EXECUTABLE" ]] && echo "| Executable | $EXECUTABLE |"
    [[ -n "$DATA_LEN" ]] && echo "| Data Size | $DATA_LEN bytes |"
    [[ -n "$RENT_EPOCH" ]] && echo "| Rent Epoch | $RENT_EPOCH |"
fi

# Explorer link (properly handles devnet cluster param)
EXPLORER_LINK=$(_cry_build_solana_explorer_url "$CHAIN" "address/$ADDRESS")
echo ""
echo "**Explorer:** [View on Solana Explorer]($EXPLORER_LINK)"
