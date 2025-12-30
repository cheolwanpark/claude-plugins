#!/usr/bin/env zsh
set -euo pipefail

# Fetch verified contract source code from block explorer
# Usage: crypto-contract-source.sh <address> [chain]

# Setup paths
SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"

# Source common library
source "$SCRIPT_DIR/crypto-common.sh"

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

# Validate address
if [[ -z "$ADDRESS" ]]; then
    _cry_print_error "Address is required"
    echo ""
    echo "### Usage"
    echo '```bash'
    echo "crypto-contract-source.sh <address> [chain]"
    echo '```'
    echo ""
    echo "### Examples"
    echo '```bash'
    echo "# Ethereum mainnet"
    echo "crypto-contract-source.sh 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2"
    echo ""
    echo "# Polygon"
    echo "crypto-contract-source.sh 0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff polygon"
    echo '```'
    exit 1
fi

# Contract source requires hex address (Etherscan API doesn't resolve ENS)
if [[ ! "$ADDRESS" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
    _cry_print_error "Invalid address format: $ADDRESS"
    echo ""
    echo "Address must be a valid hex address (0x + 40 hex characters)."
    echo ""
    echo "**Note:** ENS names are not supported for contract source lookup."
    echo "Use \`cast resolve-name <ens-name>\` to get the hex address first."
    exit 1
fi

# Check for cast
if ! _cry_check_cast; then
    _cry_print_error "cast (Foundry) is not installed"
    echo ""
    _cry_print_cast_install_help
    exit 1
fi

# Check for API key (required for etherscan-source)
_cry_require_api_key "$CHAIN"

# Build etherscan arguments
_cry_build_etherscan_args "$CHAIN"

# Print header
_cry_print_header "Contract Source Code" "$CHAIN"
echo "**Address:** \`$ADDRESS\`"
echo ""

# Print explorer link
EXPLORER_URL=$(_cry_get_explorer_url "$CHAIN")
echo "**Explorer:** [$EXPLORER_URL/address/$ADDRESS#code]($EXPLORER_URL/address/$ADDRESS#code)"
echo ""

echo "### Source Code"
echo ""
echo '```solidity'

# Fetch source code using cast source (formerly etherscan-source)
CAST_EXIT=0
RESULT=$(_cry_run_cast source "${_CRY_ETHERSCAN_ARGS[@]}" "$ADDRESS") || CAST_EXIT=$?

if [[ $CAST_EXIT -ne 0 ]]; then
    echo '```'
    echo ""
    echo "### Error"
    echo ""
    echo "Failed to fetch source code."
    echo ""
    echo "**Possible reasons:**"
    echo "- Contract is not verified on $(_cry_get_explorer_name "$CHAIN")"
    echo "- Address is an EOA (externally owned account), not a contract"
    echo "- API rate limit exceeded"
    echo "- Invalid API key"
    echo ""
    echo "**Raw error:**"
    echo '```'
    echo "$RESULT"
    echo '```'
    exit 1
fi

echo "$RESULT"
echo '```'
