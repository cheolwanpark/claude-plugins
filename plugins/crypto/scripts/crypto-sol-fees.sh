#!/usr/bin/env zsh
set -euo pipefail

# Get Solana network fees
# Usage: crypto-sol-fees.sh [chain]

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/crypto-common.sh"
source "$SCRIPT_DIR/crypto-solana.sh"

# Parse arguments
CHAIN="${1:-solana}"

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
    _cry_print_error "This skill is for Solana only. Use evm-gas-price for EVM chains."
    echo ""
    _cry_print_solana_supported_chains
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
_cry_print_header "Solana Network Fees" "$CHAIN"

# Get recent prioritization fees
FEES_EXIT=0
FEES_OUTPUT=$(_cry_run_solana recent-prioritization-fees "${_CRY_SOLANA_URL_ARGS[@]}") || FEES_EXIT=$?

echo "### Base Fee"
echo ""
echo "| Fee Type | Amount |"
echo "|----------|--------|"
echo "| Per Signature | 5,000 lamports (0.000005 SOL) |"
echo ""

if [[ $FEES_EXIT -eq 0 && -n "$FEES_OUTPUT" ]]; then
    echo "### Recent Prioritization Fees"
    echo ""
    echo '```'
    echo "$FEES_OUTPUT"
    echo '```'
    echo ""
fi

echo "### Fee Calculation"
echo ""
echo "**Total Fee** = Base Fee + (Compute Units x Priority Fee per CU)"
echo ""
echo "### Common Transaction Costs"
echo ""
echo "| Transaction Type | Typical Cost |"
echo "|------------------|--------------|"
echo "| SOL Transfer | ~0.000005 SOL |"
echo "| Token Transfer | ~0.00001 SOL |"
echo "| DEX Swap | ~0.0001-0.001 SOL |"
echo "| NFT Mint | ~0.01-0.02 SOL (rent) |"
