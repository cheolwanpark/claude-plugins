#!/usr/bin/env zsh
set -euo pipefail

# Get block information
# Usage: crypto-block-info.sh [block] [chain]

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Source common library
source "$SCRIPT_DIR/crypto-common.sh"

# Parse arguments
BLOCK="${1:-latest}"
CHAIN="${2:-ethereum}"

# Normalize chain name
CHAIN=$(_cry_normalize_chain "$CHAIN")

if [[ -z "$CHAIN" ]]; then
    _cry_print_error "Invalid chain specified"
    echo ""
    _cry_print_supported_chains
    exit 1
fi

# Validate block
if ! _cry_validate_block "$BLOCK"; then
    _cry_print_error "Invalid block identifier: $BLOCK"
    echo ""
    echo "Valid formats:"
    echo "- Block number: 18000000"
    echo "- Hex block: 0x112A880"
    echo "- Tags: latest, pending, earliest, finalized, safe"
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
_cry_print_header "Block Information" "$CHAIN"
echo "**Block:** \`$BLOCK\`"
echo ""

echo "### Block Data"
echo ""
echo '```json'

# Fetch block using cast block --json
CAST_EXIT=0
RESULT=$(_cry_run_cast block "${_CRY_RPC_ARGS[@]}" --json "$BLOCK") || CAST_EXIT=$?

if [[ $CAST_EXIT -ne 0 ]]; then
    echo '```'
    echo ""
    echo "### Error"
    echo ""
    echo "Failed to fetch block."
    echo ""
    echo "**Possible reasons:**"
    echo "- Block not found on $CHAIN"
    echo "- Invalid block number"
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
