#!/usr/bin/env zsh
set -euo pipefail

# Get address balance and account type
# Usage: crypto-address-info.sh <address> [chain]

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/crypto-common.sh"
source "$SCRIPT_DIR/crypto-evm.sh"

# Parse arguments
ADDRESS="${1:-}"
CHAIN="${2:-ethereum}"

# Normalize chain name
CHAIN=$(_cry_normalize_chain "$CHAIN")

if [[ -z "$CHAIN" ]]; then
    _cry_print_error "Invalid chain specified"
    echo ""
    _cry_print_supported_chains
    exit 1
fi

# Validate EVM chain
if ! _cry_is_evm_chain "$CHAIN"; then
    _cry_print_error "This skill is for EVM chains only. Use sol-account-info for Solana."
    echo ""
    _cry_print_evm_supported_chains
    exit 1
fi

# Validate address
if [[ -z "$ADDRESS" ]]; then
    _cry_print_error "Address is required"
    echo ""
    echo "### Usage"
    echo '```bash'
    echo "crypto-address-info.sh <address> [chain]"
    echo '```'
    echo ""
    echo "### Examples"
    echo '```bash'
    echo "# Check ENS name"
    echo "crypto-address-info.sh vitalik.eth"
    echo ""
    echo "# Check address on Polygon"
    echo "crypto-address-info.sh 0x1234... polygon"
    echo '```'
    exit 1
fi

if ! _cry_validate_address "$ADDRESS"; then
    _cry_print_error "Invalid address format: $ADDRESS"
    echo ""
    echo "Address must be a valid Ethereum address (0x + 40 hex characters) or ENS name."
    exit 1
fi

# Check for cast
if ! _cry_check_cast; then
    _cry_print_error "cast (Foundry) is not installed"
    echo ""
    _cry_print_cast_install_help
    exit 1
fi

# Check for RPC URL (required)
_cry_require_rpc "$CHAIN"

# Build RPC arguments
_cry_build_rpc_args "$CHAIN"

# Print header
_cry_print_header "Address Information" "$CHAIN"
echo "**Address:** \`$ADDRESS\`"
echo ""

# Print explorer link
EXPLORER_URL=$(_cry_get_explorer_url "$CHAIN")
echo "**Explorer:** [$EXPLORER_URL/address/$ADDRESS]($EXPLORER_URL/address/$ADDRESS)"
echo ""

# Get balance
echo "### Balance"
echo ""

BALANCE_EXIT=0
BALANCE_WEI=$(_cry_run_cast balance "${_CRY_RPC_ARGS[@]}" "$ADDRESS") || BALANCE_EXIT=$?

if [[ $BALANCE_EXIT -ne 0 ]]; then
    echo "Failed to fetch balance: $BALANCE_WEI"
    exit 1
fi

# Get native token symbol
NATIVE_SYMBOL=$(_cry_get_native_symbol "$CHAIN")

# Convert to ether
BALANCE_NATIVE=$(_cry_run_cast from-wei "$BALANCE_WEI" 2>/dev/null) || BALANCE_NATIVE="N/A"

echo "| Unit | Value |"
echo "|------|-------|"
echo "| Wei | $BALANCE_WEI |"
echo "| $NATIVE_SYMBOL | $BALANCE_NATIVE |"
echo ""

# Check if it's a contract
echo "### Account Type"
echo ""

CODE_EXIT=0
CODE=$(_cry_run_cast code "${_CRY_RPC_ARGS[@]}" "$ADDRESS") || CODE_EXIT=$?

if [[ $CODE_EXIT -ne 0 ]]; then
    echo "Failed to check account type: $CODE"
elif [[ -z "$CODE" || "$CODE" == "0x" ]]; then
    echo "**Type:** EOA (Externally Owned Account)"
    echo ""
    echo "This is a regular wallet address controlled by a private key."
else
    echo "**Type:** Smart Contract"
    echo ""
    CODE_SIZE=${#CODE}
    BYTE_SIZE=$(( (CODE_SIZE - 2) / 2 ))
    echo "**Bytecode Size:** $BYTE_SIZE bytes"
    echo ""
    echo "This address contains deployed contract code."
fi
