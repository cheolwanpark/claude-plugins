#!/usr/bin/env zsh
set -euo pipefail

# Get transaction details by hash
# Usage: crypto-tx-info.sh <tx_hash> [chain]

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/crypto-common.sh"
source "$SCRIPT_DIR/crypto-evm.sh"

# Parse arguments
TX_HASH="${1:-}"
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
    _cry_print_error "This skill is for EVM chains only. Use sol-tx-info for Solana."
    echo ""
    _cry_print_evm_supported_chains
    exit 1
fi

# Validate tx hash
if [[ -z "$TX_HASH" ]]; then
    _cry_print_error "Transaction hash is required"
    echo ""
    echo "### Usage"
    echo '```bash'
    echo "crypto-tx-info.sh <tx_hash> [chain]"
    echo '```'
    exit 1
fi

if ! _cry_validate_tx_hash "$TX_HASH"; then
    _cry_print_error "Invalid transaction hash format: $TX_HASH"
    echo ""
    echo "Transaction hash must be 0x + 64 hex characters."
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
_cry_print_header "Transaction Details" "$CHAIN"
echo "**Transaction:** \`$TX_HASH\`"
echo ""

# Print explorer link
EXPLORER_URL=$(_cry_get_explorer_url "$CHAIN")
echo "**Explorer:** [$EXPLORER_URL/tx/$TX_HASH]($EXPLORER_URL/tx/$TX_HASH)"
echo ""

echo "### Transaction Data"
echo ""
echo '```json'

# Fetch transaction using cast tx --json
CAST_EXIT=0
RESULT=$(_cry_run_cast tx "${_CRY_RPC_ARGS[@]}" --json "$TX_HASH") || CAST_EXIT=$?

if [[ $CAST_EXIT -ne 0 ]]; then
    echo '```'
    echo ""
    echo "### Error"
    echo ""
    echo "Failed to fetch transaction."
    echo ""
    echo "**Possible reasons:**"
    echo "- Transaction not found on $CHAIN"
    echo "- Invalid transaction hash"
    echo "- RPC endpoint issue"
    echo ""
    echo "**Raw error:**"
    echo '```'
    echo "$RESULT"
    echo '```'
    exit 1
fi

echo "$RESULT"
echo '```'
