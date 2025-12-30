#!/usr/bin/env zsh
#
# crypto-common.sh - Shared library for crypto plugin
# Contains namespaced functions used by all crypto scripts
#
# All functions are prefixed with _cry_ to avoid namespace collisions
#

set -euo pipefail

# Ensure this script is sourced, not executed
if [[ "${ZSH_ARGZERO:t}" == "${0:t}" ]]; then
    echo "Error: This script should be sourced, not executed directly" >&2
    exit 1
fi

# ============================================================================
# Chain Configuration
# ============================================================================

# Declare associative arrays for chain configuration (zsh syntax)
typeset -A _CRY_CHAIN_IDS
typeset -A _CRY_RPC_ENV_VARS
typeset -A _CRY_FALLBACK_RPC_URLS
typeset -A _CRY_API_KEY_VARS
typeset -A _CRY_EXPLORER_URLS
typeset -A _CRY_EXPLORER_NAMES
typeset -A _CRY_NATIVE_SYMBOLS

# Initialize chain configuration
_CRY_CHAIN_IDS=(
    ["ethereum"]="1"
    ["polygon"]="137"
    ["arbitrum"]="42161"
    ["optimism"]="10"
    ["base"]="8453"
    ["bsc"]="56"
)

_CRY_RPC_ENV_VARS=(
    ["ethereum"]="ETHEREUM_RPC_URL"
    ["polygon"]="POLYGON_RPC_URL"
    ["arbitrum"]="ARBITRUM_RPC_URL"
    ["optimism"]="OPTIMISM_RPC_URL"
    ["base"]="BASE_RPC_URL"
    ["bsc"]="BSC_RPC_URL"
)

# Fallback public RPC URLs (PublicNode - no API key required)
# Used when environment variables are not configured
_CRY_FALLBACK_RPC_URLS=(
    ["ethereum"]="https://ethereum-rpc.publicnode.com"
    ["polygon"]="https://polygon-bor-rpc.publicnode.com"
    ["arbitrum"]="https://arbitrum-one-rpc.publicnode.com"
    ["optimism"]="https://optimism-rpc.publicnode.com"
    ["base"]="https://base-rpc.publicnode.com"
    ["bsc"]="https://bsc-rpc.publicnode.com"
)

_CRY_API_KEY_VARS=(
    ["ethereum"]="ETHERSCAN_API_KEY"
    ["polygon"]="POLYGONSCAN_API_KEY"
    ["arbitrum"]="ARBISCAN_API_KEY"
    ["optimism"]="OPTIMISM_API_KEY"
    ["base"]="BASESCAN_API_KEY"
    ["bsc"]="BSCSCAN_API_KEY"
)

_CRY_EXPLORER_URLS=(
    ["ethereum"]="https://etherscan.io"
    ["polygon"]="https://polygonscan.com"
    ["arbitrum"]="https://arbiscan.io"
    ["optimism"]="https://optimistic.etherscan.io"
    ["base"]="https://basescan.org"
    ["bsc"]="https://bscscan.com"
)

_CRY_EXPLORER_NAMES=(
    ["ethereum"]="Etherscan"
    ["polygon"]="Polygonscan"
    ["arbitrum"]="Arbiscan"
    ["optimism"]="Optimism Etherscan"
    ["base"]="Basescan"
    ["bsc"]="BSCScan"
)

# Native symbols already declared above, just initialize
_CRY_NATIVE_SYMBOLS=(
    ["ethereum"]="ETH"
    ["polygon"]="MATIC"
    ["arbitrum"]="ETH"
    ["optimism"]="ETH"
    ["base"]="ETH"
    ["bsc"]="BNB"
)

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
        ethereum|eth|mainnet) echo "ethereum" ;;
        polygon|matic) echo "polygon" ;;
        arbitrum|arb) echo "arbitrum" ;;
        optimism|op) echo "optimism" ;;
        base) echo "base" ;;
        bsc|binance|bnb) echo "bsc" ;;
        *) echo "" ;;
    esac
}

# Get chain ID for a chain
# Args: $1=chain name
# Returns: chain ID on stdout, empty if invalid chain
_cry_get_chain_id() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")
    if [[ -z "$chain" ]]; then
        return 1
    fi
    echo "${_CRY_CHAIN_IDS[$chain]:-}"
}

# Get native token symbol for a chain
# Args: $1=chain name
# Returns: Symbol on stdout (ETH, MATIC, BNB, etc.)
_cry_get_native_symbol() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")
    echo "${_CRY_NATIVE_SYMBOLS[$chain]:-ETH}"
}

# Get RPC URL for a chain (from env var or fallback)
# Args: $1=chain name
# Returns: RPC URL on stdout (from env var, or PublicNode fallback)
_cry_get_rpc_url() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")
    if [[ -z "$chain" ]]; then
        return
    fi

    # First try environment variable
    local rpc_var="${_CRY_RPC_ENV_VARS[$chain]:-}"
    local rpc_url="${(P)rpc_var:-}"

    # If not set, use PublicNode fallback
    if [[ -z "$rpc_url" ]]; then
        rpc_url="${_CRY_FALLBACK_RPC_URLS[$chain]:-}"
    fi

    echo "$rpc_url"
}

# Check if using fallback RPC URL for a chain
# Args: $1=chain name
# Returns: 0 if using fallback, 1 if using configured env var
_cry_is_using_fallback_rpc() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")
    if [[ -z "$chain" ]]; then
        return 1
    fi

    local rpc_var="${_CRY_RPC_ENV_VARS[$chain]:-}"
    local rpc_url="${(P)rpc_var:-}"

    if [[ -z "$rpc_url" ]]; then
        return 0  # Using fallback
    fi
    return 1  # Using configured env var
}

# Get API key for a chain's block explorer
# Args: $1=chain name
# Returns: API key on stdout (may be empty)
_cry_get_api_key() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")
    if [[ -z "$chain" ]]; then
        return
    fi

    local key_var="${_CRY_API_KEY_VARS[$chain]:-}"
    echo "${(P)key_var:-}"
}

# Get explorer URL for a chain
# Args: $1=chain name
# Returns: Explorer URL on stdout
_cry_get_explorer_url() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")
    echo "${_CRY_EXPLORER_URLS[$chain]:-https://etherscan.io}"
}

# Get explorer name for a chain
# Args: $1=chain name
# Returns: Explorer name on stdout
_cry_get_explorer_name() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")
    echo "${_CRY_EXPLORER_NAMES[$chain]:-Etherscan}"
}

# ============================================================================
# Tool Checking
# ============================================================================

# Check if cast is installed
# Returns: 0 if installed, 1 if not
_cry_check_cast() {
    if ! command -v cast &>/dev/null; then
        return 1
    fi
    return 0
}

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
# Requirement Checking
# ============================================================================

# Require RPC URL to be available for a chain
# Args: $1=chain name
# Returns: 0 (always succeeds due to fallback), prints notice if using fallback
_cry_require_rpc() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")
    local rpc_url
    rpc_url=$(_cry_get_rpc_url "$chain")

    # This should never happen since we have fallbacks, but just in case
    if [[ -z "$rpc_url" ]]; then
        _cry_print_error "RPC URL not available for $chain"
        echo ""
        _cry_print_rpc_help "$chain"
        exit 1
    fi
    # Success - RPC is available (either from env var or fallback)
}

# Require API key to be set for a chain, exit with error if not
# Args: $1=chain name
# Returns: 0 if set, exits with error if not
_cry_require_api_key() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")
    local api_key
    api_key=$(_cry_get_api_key "$chain")

    if [[ -z "$api_key" ]]; then
        _cry_print_api_key_warning "$chain"
        exit 1
    fi
}

# ============================================================================
# Input Validation
# ============================================================================

# Validate Ethereum address format
# Args: $1=address
# Returns: 0 if valid, 1 if invalid
_cry_validate_address() {
    local address="${1:-}"

    # Check if it's an ENS name (contains a dot)
    if [[ "$address" == *"."* ]]; then
        return 0
    fi

    # Check hex address format (0x + 40 hex chars)
    if [[ "$address" =~ ^0x[a-fA-F0-9]{40}$ ]]; then
        return 0
    fi

    return 1
}

# Validate transaction hash format
# Args: $1=tx hash
# Returns: 0 if valid, 1 if invalid
_cry_validate_tx_hash() {
    local hash="${1:-}"

    # Check hex format (0x + 64 hex chars)
    if [[ "$hash" =~ ^0x[a-fA-F0-9]{64}$ ]]; then
        return 0
    fi

    return 1
}

# Validate block number/tag
# Args: $1=block
# Returns: 0 if valid, 1 if invalid
_cry_validate_block() {
    local block="${1:-}"

    # Check for valid tags
    case "$block" in
        latest|pending|earliest|finalized|safe) return 0 ;;
    esac

    # Check for numeric block number
    if [[ "$block" =~ ^[0-9]+$ ]]; then
        return 0
    fi

    # Check for hex block number
    if [[ "$block" =~ ^0x[a-fA-F0-9]+$ ]]; then
        return 0
    fi

    return 1
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
    local explorer_name
    explorer_name=$(_cry_get_explorer_name "$chain")
    local chain_id
    chain_id=$(_cry_get_chain_id "$chain")

    echo "## $title"
    echo ""
    echo "**Chain:** $chain (ID: $chain_id)"
    echo "**Explorer:** $explorer_name"

    # Show RPC source info
    if _cry_is_using_fallback_rpc "$chain"; then
        echo "**RPC:** PublicNode (fallback)"
    fi
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

# Print RPC configuration help
# Args: $1=chain name
_cry_print_rpc_help() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")
    local rpc_var="${_CRY_RPC_ENV_VARS[$chain]:-ETHEREUM_RPC_URL}"

    echo "### RPC Configuration Required"
    echo ""
    echo "This command requires an RPC endpoint for $chain."
    echo ""
    echo "Set the environment variable:"
    echo '```bash'
    echo "export $rpc_var=\"https://your-rpc-endpoint.com\""
    echo '```'
    echo ""
    echo "You can get RPC endpoints from:"
    echo "- [Alchemy](https://www.alchemy.com/)"
    echo "- [Infura](https://infura.io/)"
    echo "- [QuickNode](https://www.quicknode.com/)"
    echo ""
    echo "Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.)"
}

# Print API key configuration help
# Args: $1=chain name
_cry_print_api_key_help() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")
    local key_var="${_CRY_API_KEY_VARS[$chain]:-ETHERSCAN_API_KEY}"
    local explorer_name
    explorer_name=$(_cry_get_explorer_name "$chain")
    local explorer_url
    explorer_url=$(_cry_get_explorer_url "$chain")

    echo "### API Key Required"
    echo ""
    echo "This command requires an API key for $explorer_name."
    echo ""
    echo "1. Get a free API key from: $explorer_url/apis"
    echo "2. Set the environment variable:"
    echo '```bash'
    echo "export $key_var=\"your-api-key-here\""
    echo '```'
    echo ""
    echo "Add this to your shell profile (~/.bashrc, ~/.zshrc, etc.)"
}

# Print API key missing warning (brief for agent consumption)
# Args: $1=chain name
_cry_print_api_key_warning() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")
    local key_var="${_CRY_API_KEY_VARS[$chain]:-ETHERSCAN_API_KEY}"
    local explorer_url
    explorer_url=$(_cry_get_explorer_url "$chain")

    echo "## Error: Missing API Key"
    echo ""
    echo "**Required:** \`export $key_var=\"your-key\"\`"
    echo ""
    echo "Get free key: $explorer_url/apis"
}

# Print Foundry installation instructions
_cry_print_cast_install_help() {
    echo "### Foundry Installation Required"
    echo ""
    echo "This plugin requires \`cast\` from the Foundry toolkit."
    echo ""
    echo "Install Foundry:"
    echo '```bash'
    echo "curl -L https://foundry.paradigm.xyz | bash"
    echo "foundryup"
    echo '```'
    echo ""
    echo "Verify installation:"
    echo '```bash'
    echo "cast --version"
    echo '```'
}

# Print supported chains
_cry_print_supported_chains() {
    echo "### Supported Chains"
    echo ""
    echo "| Chain | Aliases | Chain ID |"
    echo "|-------|---------|----------|"
    echo "| ethereum | eth, mainnet | 1 |"
    echo "| polygon | matic | 137 |"
    echo "| arbitrum | arb | 42161 |"
    echo "| optimism | op | 10 |"
    echo "| base | - | 8453 |"
    echo "| bsc | binance, bnb | 56 |"
}

# ============================================================================
# Cast Command Helpers
# ============================================================================

# Build RPC arguments for cast
# Args: $1=chain name
# Sets: _CRY_RPC_ARGS array
_cry_build_rpc_args() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")

    _CRY_RPC_ARGS=()

    local rpc_url
    rpc_url=$(_cry_get_rpc_url "$chain")
    if [[ -n "$rpc_url" ]]; then
        _CRY_RPC_ARGS+=(--rpc-url "$rpc_url")
    fi
}

# Build Etherscan arguments for cast
# Args: $1=chain name
# Sets: _CRY_ETHERSCAN_ARGS array
_cry_build_etherscan_args() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")

    _CRY_ETHERSCAN_ARGS=()

    local chain_id
    chain_id=$(_cry_get_chain_id "$chain")
    _CRY_ETHERSCAN_ARGS+=(--chain "$chain_id")

    local api_key
    api_key=$(_cry_get_api_key "$chain")
    if [[ -n "$api_key" ]]; then
        _CRY_ETHERSCAN_ARGS+=(--etherscan-api-key "$api_key")
    fi
}

# Run a cast command with error handling
# Args: $@=cast command and arguments
# Returns: exit code from cast, output on stdout
_cry_run_cast() {
    local output
    local exit_code=0

    output=$(cast "$@" 2>&1) || exit_code=$?

    echo "$output"
    return $exit_code
}
