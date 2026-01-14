#!/usr/bin/env zsh
#
# crypto-solana.sh - Solana-specific helpers for crypto plugin
# Source this after crypto-common.sh for Solana operations
#
# All functions are prefixed with _cry_ to avoid namespace collisions
#

# Ensure this script is sourced, not executed
if [[ "${ZSH_ARGZERO:t}" == "${0:t}" ]]; then
    echo "Error: This script should be sourced, not executed directly" >&2
    exit 1
fi

# ============================================================================
# Solana Chain Configuration
# ============================================================================

typeset -A _CRY_SOLANA_NETWORKS
_CRY_SOLANA_NETWORKS=(
    ["solana"]="mainnet-beta"
    ["solana-devnet"]="devnet"
)

typeset -A _CRY_SOLANA_RPC_ENV_VARS
_CRY_SOLANA_RPC_ENV_VARS=(
    ["solana"]="SOLANA_RPC_URL"
    ["solana-devnet"]="SOLANA_DEVNET_RPC_URL"
)

# Solana fallback RPCs (public endpoints)
_CRY_FALLBACK_RPC_URLS[solana]="https://api.mainnet-beta.solana.com"
_CRY_FALLBACK_RPC_URLS[solana-devnet]="https://api.devnet.solana.com"

# Solana explorers (base URLs - cluster param added by accessor for devnet)
_CRY_EXPLORER_URLS[solana]="https://explorer.solana.com"
_CRY_EXPLORER_URLS[solana-devnet]="https://explorer.solana.com"

# Well-known Solana program IDs
readonly _CRY_TOKEN_PROGRAM="TokenkegQfeZyiNwAJbNbGKPFXCWuBvf9Ss623VQ5DA"
readonly _CRY_SYSTEM_PROGRAM="11111111111111111111111111111111"
readonly _CRY_BPF_UPGRADEABLE_LOADER="BPFLoaderUpgradeab1e11111111111111111111111"
readonly _CRY_BPF_LOADER2="BPFLoader2111111111111111111111111111111111"

_CRY_EXPLORER_NAMES[solana]="Solana Explorer"
_CRY_EXPLORER_NAMES[solana-devnet]="Solana Explorer (Devnet)"

_CRY_NATIVE_SYMBOLS[solana]="SOL"
_CRY_NATIVE_SYMBOLS[solana-devnet]="SOL"

# ============================================================================
# Solana Tool Checking
# ============================================================================

# Check if solana CLI is installed
# Returns: 0 if installed, 1 if not
_cry_check_solana_cli() {
    command -v solana &>/dev/null
}

# Check if anchor CLI is installed
# Returns: 0 if installed, 1 if not
_cry_check_anchor_cli() {
    command -v anchor &>/dev/null
}

# ============================================================================
# Solana Input Validation
# ============================================================================

# Validate Solana address format (Base58, 32-44 chars)
# Args: $1=address
# Returns: 0 if valid, 1 if invalid
_cry_validate_sol_address() {
    local address="${1:-}"

    # Check length (32-44 chars typical for Base58 encoded public keys)
    if [[ ${#address} -lt 32 || ${#address} -gt 44 ]]; then
        return 1
    fi

    # Check Base58 character set (no 0, O, I, l)
    if [[ ! "$address" =~ ^[1-9A-HJ-NP-Za-km-z]+$ ]]; then
        return 1
    fi

    return 0
}

# Validate Solana signature format (Base58, 87-88 chars)
# Args: $1=signature
# Returns: 0 if valid, 1 if invalid
_cry_validate_sol_signature() {
    local sig="${1:-}"

    # Check length (87-88 chars typical for Base58 encoded signatures)
    if [[ ${#sig} -lt 86 || ${#sig} -gt 90 ]]; then
        return 1
    fi

    # Check Base58 character set (no 0, O, I, l)
    if [[ ! "$sig" =~ ^[1-9A-HJ-NP-Za-km-z]+$ ]]; then
        return 1
    fi

    return 0
}

# Validate Solana slot number
# Args: $1=slot
# Returns: 0 if valid, 1 if invalid
_cry_validate_sol_slot() {
    local slot="${1:-}"

    # Check for "latest" tag
    if [[ "$slot" == "latest" ]]; then
        return 0
    fi

    # Check for numeric slot number
    if [[ "$slot" =~ ^[0-9]+$ ]]; then
        return 0
    fi

    return 1
}

# ============================================================================
# Solana RPC Helpers
# ============================================================================

# Get Solana network name (mainnet-beta, devnet)
# Args: $1=chain name
# Returns: network name on stdout
_cry_get_solana_network() {
    local chain
    chain=$(_cry_normalize_chain "${1:-solana}")
    echo "${_CRY_SOLANA_NETWORKS[$chain]:-mainnet-beta}"
}

# Get RPC URL for a Solana chain (from env var or fallback)
# Args: $1=chain name
# Returns: RPC URL on stdout
_cry_get_solana_rpc_url() {
    local chain
    chain=$(_cry_normalize_chain "${1:-solana}")
    if [[ -z "$chain" ]]; then
        return
    fi

    # First try environment variable
    local rpc_var="${_CRY_SOLANA_RPC_ENV_VARS[$chain]:-}"
    local rpc_url="${(P)rpc_var:-}"

    # If not set, use fallback
    if [[ -z "$rpc_url" ]]; then
        rpc_url="${_CRY_FALLBACK_RPC_URLS[$chain]:-}"
    fi

    echo "$rpc_url"
}

# Build --url argument for solana CLI
# Args: $1=chain name
# Sets: _CRY_SOLANA_URL_ARGS array
_cry_build_solana_url_args() {
    local chain
    chain=$(_cry_normalize_chain "${1:-solana}")

    _CRY_SOLANA_URL_ARGS=()

    local rpc_url
    rpc_url=$(_cry_get_solana_rpc_url "$chain")
    if [[ -n "$rpc_url" ]]; then
        _CRY_SOLANA_URL_ARGS+=(--url "$rpc_url")
    fi
}

# ============================================================================
# Solana Unit Conversion
# ============================================================================

# Convert lamports to SOL
# Args: $1=lamports
# Returns: SOL amount on stdout (9 decimal places)
_cry_lamports_to_sol() {
    local lamports="${1:-0}"
    awk "BEGIN {printf \"%.9f\", $lamports / 1000000000}"
}

# Convert SOL to lamports
# Args: $1=SOL
# Returns: lamports on stdout
_cry_sol_to_lamports() {
    local sol="${1:-0}"
    awk "BEGIN {printf \"%.0f\", $sol * 1000000000}"
}

# ============================================================================
# Solana Command Helpers
# ============================================================================

# Run a solana CLI command with error handling
# Args: $@=solana command and arguments
# Returns: exit code from solana, output on stdout
_cry_run_solana() {
    local output
    local exit_code=0

    output=$(solana "$@" 2>&1) || exit_code=$?

    echo "$output"
    return $exit_code
}

# ============================================================================
# Solana Output Formatting / Help Messages
# ============================================================================

# Print Solana CLI installation help
_cry_print_solana_install_help() {
    echo "### Solana CLI Installation Required"
    echo ""
    echo "This skill requires the Solana CLI."
    echo ""
    echo "Install Solana CLI:"
    echo '```bash'
    echo 'sh -c "$(curl -sSfL https://release.anza.xyz/stable/install)"'
    echo '```'
    echo ""
    echo "Add to your PATH:"
    echo '```bash'
    echo 'export PATH="$HOME/.local/share/solana/install/active_release/bin:$PATH"'
    echo '```'
    echo ""
    echo "Verify installation:"
    echo '```bash'
    echo "solana --version"
    echo '```'
}

# Print Anchor CLI installation help
_cry_print_anchor_install_help() {
    echo "### Anchor CLI Installation Required"
    echo ""
    echo "This skill requires the Anchor CLI for IDL fetching."
    echo ""
    echo "Install Anchor CLI (requires Rust):"
    echo '```bash'
    echo 'cargo install --git https://github.com/coral-xyz/anchor anchor-cli --locked'
    echo '```'
    echo ""
    echo "Verify installation:"
    echo '```bash'
    echo "anchor --version"
    echo '```'
}

# Print Solana RPC configuration help
# Args: $1=chain name
_cry_print_solana_rpc_help() {
    local chain
    chain=$(_cry_normalize_chain "${1:-solana}")
    local rpc_var="${_CRY_SOLANA_RPC_ENV_VARS[$chain]:-SOLANA_RPC_URL}"

    echo "### Solana RPC Configuration"
    echo ""
    echo "For better performance, configure a custom RPC endpoint:"
    echo ""
    echo '```bash'
    echo "export $rpc_var=\"https://your-rpc-endpoint.com\""
    echo '```'
    echo ""
    echo "You can get RPC endpoints from:"
    echo "- [Helius](https://www.helius.dev/) (recommended)"
    echo "- [QuickNode](https://www.quicknode.com/)"
    echo "- [Alchemy](https://www.alchemy.com/)"
    echo ""
    echo "The default public RPC is rate-limited."
}

# Print Solana supported chains
_cry_print_solana_supported_chains() {
    echo "### Supported Solana Chains"
    echo ""
    echo "| Chain | Aliases | Network |"
    echo "|-------|---------|---------|"
    echo "| solana | sol | mainnet-beta |"
    echo "| solana-devnet | sol-devnet, devnet | devnet |"
}

# Build Solana explorer URL with proper cluster parameter for devnet
# Args: $1=chain name, $2=path (e.g., "address/xxx" or "tx/yyy")
# Returns: Full explorer URL on stdout
_cry_build_solana_explorer_url() {
    local chain
    chain=$(_cry_normalize_chain "${1:-solana}")
    local path="${2:-}"
    local base_url="${_CRY_EXPLORER_URLS[$chain]:-https://explorer.solana.com}"

    if [[ "$chain" == "solana-devnet" ]]; then
        echo "${base_url}/${path}?cluster=devnet"
    else
        echo "${base_url}/${path}"
    fi
}
