#!/usr/bin/env zsh
set -euo pipefail

# Get Solana slot/block info
# Usage: crypto-sol-slot-info.sh [slot] [chain]

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Source libraries
source "$SCRIPT_DIR/crypto-common.sh"
source "$SCRIPT_DIR/crypto-solana.sh"

# Parse arguments
SLOT="${1:-latest}"
CHAIN="${2:-solana}"

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
    _cry_print_error "This skill is for Solana only. Use evm-block-info for EVM chains."
    echo ""
    _cry_print_solana_supported_chains
    exit 1
fi

# Validate slot if not "latest"
if [[ "$SLOT" != "latest" ]] && ! _cry_validate_sol_slot "$SLOT"; then
    _cry_print_error "Invalid slot format"
    echo ""
    echo "Expected: numeric slot number or 'latest'"
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
_cry_print_header "Solana Slot Info" "$CHAIN"

if [[ "$SLOT" == "latest" ]]; then
    # Get current slot
    SLOT_EXIT=0
    CURRENT_SLOT=$(_cry_run_solana slot "${_CRY_SOLANA_URL_ARGS[@]}") || SLOT_EXIT=$?

    if [[ $SLOT_EXIT -ne 0 ]]; then
        echo "**Error:** Failed to get current slot"
        echo ""
        echo "$CURRENT_SLOT"
        exit 1
    fi

    echo "### Current Slot"
    echo ""
    echo "**Slot:** $CURRENT_SLOT"
    echo ""

    # Get epoch info
    EPOCH_EXIT=0
    EPOCH_OUTPUT=$(_cry_run_solana epoch-info "${_CRY_SOLANA_URL_ARGS[@]}") || EPOCH_EXIT=$?

    if [[ $EPOCH_EXIT -eq 0 ]]; then
        echo "### Epoch Info"
        echo ""
        echo '```'
        echo "$EPOCH_OUTPUT"
        echo '```'
    fi
else
    # Get specific block by slot
    BLOCK_EXIT=0
    BLOCK_OUTPUT=$(_cry_run_solana block "$SLOT" "${_CRY_SOLANA_URL_ARGS[@]}") || BLOCK_EXIT=$?

    if [[ $BLOCK_EXIT -ne 0 ]]; then
        echo "**Error:** Failed to get block at slot $SLOT"
        echo ""
        echo "$BLOCK_OUTPUT"
        exit 1
    fi

    echo "### Block at Slot $SLOT"
    echo ""
    echo '```'
    echo "$BLOCK_OUTPUT"
    echo '```'
fi

# Explorer link (properly handles devnet cluster param)
if [[ "$SLOT" == "latest" ]]; then
    EXPLORER_LINK=$(_cry_build_solana_explorer_url "$CHAIN" "")
    # Remove trailing slash if present
    EXPLORER_LINK="${EXPLORER_LINK%/}"
    echo ""
    echo "**Explorer:** [$EXPLORER_LINK]($EXPLORER_LINK)"
else
    EXPLORER_LINK=$(_cry_build_solana_explorer_url "$CHAIN" "block/$SLOT")
    echo ""
    echo "**Explorer:** [Slot $SLOT]($EXPLORER_LINK)"
fi
