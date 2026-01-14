#!/usr/bin/env zsh
#
# crypto-evm.sh - EVM-specific helpers for crypto plugin
# Source this after crypto-common.sh for EVM operations
#
# All functions are prefixed with _cry_ to avoid namespace collisions
#

# Ensure this script is sourced, not executed
if [[ "${ZSH_ARGZERO:t}" == "${0:t}" ]]; then
    echo "Error: This script should be sourced, not executed directly" >&2
    exit 1
fi

# ============================================================================
# EVM Chain Configuration
# ============================================================================

typeset -A _CRY_CHAIN_IDS
_CRY_CHAIN_IDS=(
    ["ethereum"]="1"
    ["polygon"]="137"
    ["arbitrum"]="42161"
    ["optimism"]="10"
    ["base"]="8453"
    ["bsc"]="56"
)

typeset -A _CRY_RPC_ENV_VARS
_CRY_RPC_ENV_VARS=(
    ["ethereum"]="ETHEREUM_RPC_URL"
    ["polygon"]="POLYGON_RPC_URL"
    ["arbitrum"]="ARBITRUM_RPC_URL"
    ["optimism"]="OPTIMISM_RPC_URL"
    ["base"]="BASE_RPC_URL"
    ["bsc"]="BSC_RPC_URL"
)

typeset -A _CRY_API_KEY_VARS
_CRY_API_KEY_VARS=(
    ["ethereum"]="ETHERSCAN_API_KEY"
    ["polygon"]="POLYGONSCAN_API_KEY"
    ["arbitrum"]="ARBISCAN_API_KEY"
    ["optimism"]="OPTIMISM_API_KEY"
    ["base"]="BASESCAN_API_KEY"
    ["bsc"]="BSCSCAN_API_KEY"
)

# EVM fallback RPCs (PublicNode - no API key required)
_CRY_FALLBACK_RPC_URLS[ethereum]="https://ethereum-rpc.publicnode.com"
_CRY_FALLBACK_RPC_URLS[polygon]="https://polygon-bor-rpc.publicnode.com"
_CRY_FALLBACK_RPC_URLS[arbitrum]="https://arbitrum-one-rpc.publicnode.com"
_CRY_FALLBACK_RPC_URLS[optimism]="https://optimism-rpc.publicnode.com"
_CRY_FALLBACK_RPC_URLS[base]="https://base-rpc.publicnode.com"
_CRY_FALLBACK_RPC_URLS[bsc]="https://bsc-rpc.publicnode.com"

# EVM explorers
_CRY_EXPLORER_URLS[ethereum]="https://etherscan.io"
_CRY_EXPLORER_URLS[polygon]="https://polygonscan.com"
_CRY_EXPLORER_URLS[arbitrum]="https://arbiscan.io"
_CRY_EXPLORER_URLS[optimism]="https://optimistic.etherscan.io"
_CRY_EXPLORER_URLS[base]="https://basescan.org"
_CRY_EXPLORER_URLS[bsc]="https://bscscan.com"

_CRY_EXPLORER_NAMES[ethereum]="Etherscan"
_CRY_EXPLORER_NAMES[polygon]="Polygonscan"
_CRY_EXPLORER_NAMES[arbitrum]="Arbiscan"
_CRY_EXPLORER_NAMES[optimism]="Optimism Etherscan"
_CRY_EXPLORER_NAMES[base]="Basescan"
_CRY_EXPLORER_NAMES[bsc]="BSCScan"

_CRY_NATIVE_SYMBOLS[ethereum]="ETH"
_CRY_NATIVE_SYMBOLS[polygon]="MATIC"
_CRY_NATIVE_SYMBOLS[arbitrum]="ETH"
_CRY_NATIVE_SYMBOLS[optimism]="ETH"
_CRY_NATIVE_SYMBOLS[base]="ETH"
_CRY_NATIVE_SYMBOLS[bsc]="BNB"

# ============================================================================
# EVM Tool Checking
# ============================================================================

# Check if cast is installed
# Returns: 0 if installed, 1 if not
_cry_check_cast() {
    command -v cast &>/dev/null
}

# ============================================================================
# EVM Input Validation
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
# EVM RPC/API Helpers
# ============================================================================

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
# Falls back to ETHERSCAN_API_KEY if chain-specific key is not set
_cry_get_api_key() {
    local chain
    chain=$(_cry_normalize_chain "${1:-ethereum}")
    if [[ -z "$chain" ]]; then
        return
    fi

    # Try chain-specific key first
    local key_var="${_CRY_API_KEY_VARS[$chain]:-}"
    local api_key="${(P)key_var:-}"

    # Fall back to ETHERSCAN_API_KEY if chain-specific key not set
    if [[ -z "$api_key" && "$chain" != "ethereum" ]]; then
        api_key="${ETHERSCAN_API_KEY:-}"
    fi

    echo "$api_key"
}

# ============================================================================
# EVM Requirement Checking
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

# ============================================================================
# EVM Output Formatting / Help Messages
# ============================================================================

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
    if [[ "$chain" != "ethereum" ]]; then
        echo ""
        echo "**Or use fallback:** \`export ETHERSCAN_API_KEY=\"your-key\"\`"
    fi
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

# Print EVM supported chains
_cry_print_evm_supported_chains() {
    echo "### Supported EVM Chains"
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
