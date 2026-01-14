#!/usr/bin/env zsh
set -euo pipefail

# Get Solana transaction info
# Usage: crypto-sol-tx-info.sh <signature> [chain]

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/crypto-common.sh"
source "$SCRIPT_DIR/crypto-solana.sh"

# Parse arguments
SIGNATURE="${1:-}"
CHAIN="${2:-solana}"

# Validate required argument
if [[ -z "$SIGNATURE" ]]; then
    _cry_print_error "Transaction signature required"
    echo ""
    echo "**Usage:** crypto-sol-tx-info.sh <signature> [chain]"
    echo ""
    echo "**Example:**"
    echo '```bash'
    echo 'crypto-sol-tx-info.sh 5UfDuX...signature solana'
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
    _cry_print_error "This skill is for Solana only. Use evm-tx-info for EVM chains."
    echo ""
    _cry_print_solana_supported_chains
    exit 1
fi

# Validate signature format
if ! _cry_validate_sol_signature "$SIGNATURE"; then
    _cry_print_error "Invalid Solana signature format"
    echo ""
    echo "Expected: Base58 encoded signature (86-90 characters)"
    echo "Got: ${#SIGNATURE} characters"
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
_cry_print_header "Solana Transaction" "$CHAIN"

echo "**Signature:** \`$SIGNATURE\`"
echo ""

# Get transaction confirmation and details
TX_EXIT=0
TX_OUTPUT=$(_cry_run_solana confirm "$SIGNATURE" -v "${_CRY_SOLANA_URL_ARGS[@]}") || TX_EXIT=$?

if [[ $TX_EXIT -ne 0 ]]; then
    # Check if transaction not found
    if [[ "$TX_OUTPUT" == *"not found"* ]] || [[ "$TX_OUTPUT" == *"Unable to get"* ]]; then
        echo "### Transaction Not Found"
        echo ""
        echo "The transaction signature was not found on the network."
        echo ""
        echo "Possible reasons:"
        echo "- Transaction does not exist"
        echo "- Transaction is too old (pruned)"
        echo "- Wrong network (try solana-devnet)"
    else
        echo "**Error:** Failed to get transaction"
        echo ""
        echo '```'
        echo "$TX_OUTPUT"
        echo '```'
    fi
    exit 1
fi

echo "### Transaction Details"
echo ""
echo '```'
echo "$TX_OUTPUT"
echo '```'

# Explorer link (properly handles devnet cluster param)
EXPLORER_LINK=$(_cry_build_solana_explorer_url "$CHAIN" "tx/$SIGNATURE")
echo ""
echo "**Explorer:** [View on Solana Explorer]($EXPLORER_LINK)"
