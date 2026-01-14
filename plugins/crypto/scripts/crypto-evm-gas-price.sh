#!/usr/bin/env zsh
set -euo pipefail

# Get current gas price
# Usage: crypto-gas-price.sh [chain]

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/crypto-common.sh"
source "$SCRIPT_DIR/crypto-evm.sh"

# Parse arguments
CHAIN="${1:-ethereum}"

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
    _cry_print_error "This skill is for EVM chains only. Use sol-fees for Solana."
    echo ""
    _cry_print_evm_supported_chains
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
_cry_print_header "Gas Price" "$CHAIN"

# Get gas price
GAS_EXIT=0
GAS_WEI=$(_cry_run_cast gas-price "${_CRY_RPC_ARGS[@]}") || GAS_EXIT=$?

if [[ $GAS_EXIT -ne 0 ]]; then
    echo "**Error:** Failed to fetch gas price"
    echo ""
    echo "$GAS_WEI"
    exit 1
fi

# Convert to gwei
GAS_GWEI=$(_cry_run_cast to-unit "$GAS_WEI" gwei 2>/dev/null) || GAS_GWEI="N/A"

echo "### Current Gas Price"
echo ""
echo "| Unit | Value |"
echo "|------|-------|"
echo "| Wei | $GAS_WEI |"
echo "| Gwei | $GAS_GWEI |"
echo ""

# Get native token symbol
NATIVE_SYMBOL=$(_cry_get_native_symbol "$CHAIN")

# Estimate common transaction costs
echo "### Estimated Transaction Costs"
echo ""
echo "| Transaction Type | Gas Limit | Estimated Cost |"
echo "|------------------|-----------|----------------|"

# Use awk for calculations (more portable than bc)
# Native transfer (21000 gas)
NATIVE_TRANSFER_COST=$(awk "BEGIN {printf \"%.8f\", $GAS_WEI * 21000 / 10^18}" 2>/dev/null) || NATIVE_TRANSFER_COST="N/A"
echo "| $NATIVE_SYMBOL Transfer | 21,000 | $NATIVE_TRANSFER_COST $NATIVE_SYMBOL |"

# ERC20 transfer (~65000 gas)
ERC20_COST=$(awk "BEGIN {printf \"%.8f\", $GAS_WEI * 65000 / 10^18}" 2>/dev/null) || ERC20_COST="N/A"
echo "| ERC20 Transfer | ~65,000 | $ERC20_COST $NATIVE_SYMBOL |"

# DEX swap (~150000 gas)
SWAP_COST=$(awk "BEGIN {printf \"%.8f\", $GAS_WEI * 150000 / 10^18}" 2>/dev/null) || SWAP_COST="N/A"
echo "| DEX Swap | ~150,000 | $SWAP_COST $NATIVE_SYMBOL |"

# NFT mint (~100000 gas)
NFT_COST=$(awk "BEGIN {printf \"%.8f\", $GAS_WEI * 100000 / 10^18}" 2>/dev/null) || NFT_COST="N/A"
echo "| NFT Mint | ~100,000 | $NFT_COST $NATIVE_SYMBOL |"
