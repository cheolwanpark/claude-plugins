#!/usr/bin/env zsh
set -euo pipefail

# Fetch Solana program IDL
# Usage: crypto-sol-program-idl.sh <program_address> [chain]

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/crypto-common.sh"
source "$SCRIPT_DIR/crypto-solana.sh"

# Parse arguments
PROGRAM_ID="${1:-}"
CHAIN="${2:-solana}"

# Validate required argument
if [[ -z "$PROGRAM_ID" ]]; then
    _cry_print_error "Program address required"
    echo ""
    echo "**Usage:** crypto-sol-program-idl.sh <program_address> [chain]"
    echo ""
    echo "**Example:**"
    echo '```bash'
    echo 'crypto-sol-program-idl.sh MarBmsSgKXdrN1egZf5sqe1TMai9K1rChYNDJgjq7aD solana'
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
    _cry_print_error "This skill is for Solana only. Use evm-contract-source for EVM chains."
    echo ""
    _cry_print_solana_supported_chains
    exit 1
fi

# Validate address format
if ! _cry_validate_sol_address "$PROGRAM_ID"; then
    _cry_print_error "Invalid Solana program address format"
    echo ""
    echo "Expected: Base58 encoded address (32-44 characters)"
    echo "Got: ${#PROGRAM_ID} characters"
    exit 1
fi

# Check for anchor CLI
if ! _cry_check_anchor_cli; then
    _cry_print_error "anchor CLI is not installed"
    echo ""
    _cry_print_anchor_install_help
    exit 1
fi

# Get cluster name - anchor uses different names than solana CLI
SOLANA_NETWORK=$(_cry_get_solana_network "$CHAIN")
# Map to anchor cluster names: mainnet-beta -> mainnet
case "$SOLANA_NETWORK" in
    mainnet-beta) ANCHOR_CLUSTER="mainnet" ;;
    *) ANCHOR_CLUSTER="$SOLANA_NETWORK" ;;
esac

# Print header
_cry_print_header "Solana Program IDL" "$CHAIN"

echo "**Program:** \`$PROGRAM_ID\`"
echo "**Cluster:** $ANCHOR_CLUSTER"
echo ""

# Fetch IDL using anchor
IDL_EXIT=0
IDL_OUTPUT=$(anchor idl fetch "$PROGRAM_ID" --provider.cluster "$ANCHOR_CLUSTER" 2>&1) || IDL_EXIT=$?

if [[ $IDL_EXIT -ne 0 ]]; then
    if [[ "$IDL_OUTPUT" == *"does not exist"* ]] || [[ "$IDL_OUTPUT" == *"not found"* ]] || [[ "$IDL_OUTPUT" == *"AccountNotFound"* ]]; then
        echo "### IDL Not Available"
        echo ""
        echo "This program does not have a published IDL on-chain."
        echo ""
        echo "**Possible reasons:**"
        echo "- Not an Anchor program (native or built without Anchor)"
        echo "- IDL was not published on-chain with \`anchor idl init\`"
        echo "- Program does not exist at this address"
        echo ""
        echo "**Alternatives:**"
        echo "- Check the program's GitHub repository for the IDL file"
        echo "- Use \`anchor idl parse\` if you have the source code"
    else
        echo "**Error:** Failed to fetch IDL"
        echo ""
        echo '```'
        echo "$IDL_OUTPUT"
        echo '```'
    fi
else
    echo "### Program IDL"
    echo ""
    echo '```json'
    echo "$IDL_OUTPUT"
    echo '```'
fi

# Explorer link (properly handles devnet cluster param)
EXPLORER_LINK=$(_cry_build_solana_explorer_url "$CHAIN" "address/$PROGRAM_ID")
echo ""
echo "**Explorer:** [View on Solana Explorer]($EXPLORER_LINK)"
