#!/usr/bin/env zsh
#
# crypto-common.sh - Shared base library for crypto plugin
# Contains chain-agnostic utilities used by both EVM and Solana
#
# All functions are prefixed with _cry_ to avoid namespace collisions
#

set -euo pipefail

# Ensure this script is sourced, not executed
if [[ "${ZSH_ARGZERO:t}" == "${0:t}" ]]; then
    echo "Error: This script should be sourced, not executed directly" >&2
    exit 1
fi

# Get script directory for sourcing other libraries
_CRY_SCRIPT_DIR="$(cd "$(dirname "${(%):-%x}")" && pwd)"

# ============================================================================
# Chain Type Detection
# ============================================================================

# All supported chains (both EVM and Solana)
typeset -A _CRY_CHAIN_TYPES
_CRY_CHAIN_TYPES=(
    ["ethereum"]="evm"
    ["polygon"]="evm"
    ["arbitrum"]="evm"
    ["optimism"]="evm"
    ["base"]="evm"
    ["bsc"]="evm"
    ["solana"]="solana"
    ["solana-devnet"]="solana"
)

# Declare shared configuration arrays (populated by chain-specific libs)
typeset -A _CRY_EXPLORER_URLS
typeset -A _CRY_EXPLORER_NAMES
typeset -A _CRY_NATIVE_SYMBOLS
typeset -A _CRY_FALLBACK_RPC_URLS

# ============================================================================
# Chain Resolution
# ============================================================================

# Normalize chain name to canonical form
# Args: $1=chain name or alias
# Returns: canonical chain name on stdout, or empty if invalid
_cry_normalize_chain() {
    local input="${1:-ethereum}"
    local lower_input
    lower_input=$(echo "$input" | tr '[:upper:]' '[:lower:]')

    case "$lower_input" in
        # EVM chains
        ethereum|eth|mainnet) echo "ethereum" ;;
        polygon|matic) echo "polygon" ;;
        arbitrum|arb) echo "arbitrum" ;;
        optimism|op) echo "optimism" ;;
        base) echo "base" ;;
        bsc|binance|bnb) echo "bsc" ;;
        # Solana chains
        solana|sol) echo "solana" ;;
        solana-devnet|sol-devnet|devnet) echo "solana-devnet" ;;
        *) echo "" ;;
    esac
}

# Get chain type (evm or solana)
# Args: $1=chain name
# Returns: "evm", "solana", or empty string
_cry_get_chain_type() {
    local chain
    chain=$(_cry_normalize_chain "${1:-}")
    echo "${_CRY_CHAIN_TYPES[$chain]:-}"
}

# Check if chain is EVM
# Args: $1=chain name
# Returns: 0 if EVM, 1 otherwise
_cry_is_evm_chain() {
    [[ "$(_cry_get_chain_type "$1")" == "evm" ]]
}

# Check if chain is Solana
# Args: $1=chain name
# Returns: 0 if Solana, 1 otherwise
_cry_is_solana_chain() {
    [[ "$(_cry_get_chain_type "$1")" == "solana" ]]
}

# ============================================================================
# Shared Configuration Accessors
# ============================================================================

# Get explorer URL for a chain
# Args: $1=chain name
# Returns: Explorer URL on stdout
_cry_get_explorer_url() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")
    echo "${_CRY_EXPLORER_URLS[$chain]:-}"
}

# Get explorer name for a chain
# Args: $1=chain name
# Returns: Explorer name on stdout
_cry_get_explorer_name() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")
    echo "${_CRY_EXPLORER_NAMES[$chain]:-Unknown}"
}

# Get native token symbol for a chain
# Args: $1=chain name
# Returns: Symbol on stdout (ETH, MATIC, SOL, etc.)
_cry_get_native_symbol() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")
    echo "${_CRY_NATIVE_SYMBOLS[$chain]:-}"
}

# Get fallback RPC URL for a chain
# Args: $1=chain name
# Returns: RPC URL on stdout
_cry_get_fallback_rpc_url() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")
    echo "${_CRY_FALLBACK_RPC_URLS[$chain]:-}"
}

# ============================================================================
# Tool Checking
# ============================================================================

# Check if required tools are installed
# Args: $@=list of required tools
# Returns: 0 if all tools available, 1 if any missing (sets _CRY_MISSING_TOOLS array)
_cry_check_required_tools() {
    local tools=("$@")
    _CRY_MISSING_TOOLS=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            _CRY_MISSING_TOOLS+=("$tool")
        fi
    done

    if [[ ${#_CRY_MISSING_TOOLS[@]} -gt 0 ]]; then
        return 1
    fi
    return 0
}

# ============================================================================
# Output Formatting
# ============================================================================

# Print a header for command output
# Args: $1=title, $2=chain name
_cry_print_header() {
    local title="${1:-}"
    local chain="${2:-ethereum}"
    chain=$(_cry_normalize_chain "$chain")
    local chain_type
    chain_type=$(_cry_get_chain_type "$chain")
    local explorer_name
    explorer_name=$(_cry_get_explorer_name "$chain")

    echo "## $title"
    echo ""
    echo "**Chain:** $chain ($chain_type)"
    echo "**Explorer:** $explorer_name"
    echo ""
}

# Print an error message
# Args: $1=error message
_cry_print_error() {
    local message="${1:-An error occurred}"
    echo "## Error"
    echo ""
    echo "$message"
}

# Print supported chains
_cry_print_supported_chains() {
    echo "### Supported Chains"
    echo ""
    echo "**EVM:** ethereum, polygon, arbitrum, optimism, base, bsc"
    echo "**Solana:** solana, solana-devnet"
}
