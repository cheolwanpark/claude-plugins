#!/usr/bin/env bash
#
# rust-lint-common.sh - Shared library for rust-lint plugin
# All functions prefixed with _rl_ to avoid namespace collisions
#

# Ensure sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly" >&2
    exit 1
fi

# ============================================================================
# JSON Response Generation
# ============================================================================

# Generate JSON response for hooks
# Args:
#   $1: decision (allow|block)
#   $2: reason (human-readable message)
#   $3: event_name (optional, e.g., "PostToolUse")
#   $4: context (optional, detailed additional info)
_rl_json_response() {
    local decision="${1:-allow}"
    local reason="${2:-No reason provided}"
    local event_name="${3:-}"
    local context="${4:-}"

    if ! command -v jq &>/dev/null; then
        echo '{"error": "jq not available", "decision": "allow"}'
        return 1
    fi

    if [[ -n "$event_name" && -n "$context" ]]; then
        jq -n \
            --arg decision "$decision" \
            --arg reason "$reason" \
            --arg event_name "$event_name" \
            --arg context "$context" \
            '{
                decision: $decision,
                reason: $reason,
                hookSpecificOutput: {
                    hookEventName: $event_name,
                    additionalContext: $context
                }
            }' 2>/dev/null
    else
        jq -n \
            --arg decision "$decision" \
            --arg reason "$reason" \
            '{
                decision: $decision,
                reason: $reason
            }' 2>/dev/null
    fi
}

# ============================================================================
# Input Parsing
# ============================================================================

# Parse file_path from hook JSON input
# Args:
#   $1: JSON input string
# Returns:
#   File path or empty string
_rl_parse_file_path() {
    local input="${1:-}"
    if [[ -z "$input" ]]; then
        return 1
    fi

    if ! command -v jq &>/dev/null; then
        echo ""
        return 1
    fi

    echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo ""
}

# ============================================================================
# Tool Detection
# ============================================================================

# Global array to store missing tools
declare -a _RL_MISSING_TOOLS

# Check if required tools are installed
# Args:
#   $@: List of tool names to check
# Returns:
#   0 if all tools found, 1 if any missing
#   Sets _RL_MISSING_TOOLS array with missing tool names
_rl_check_required_tools() {
    local tools=("$@")
    _RL_MISSING_TOOLS=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            _RL_MISSING_TOOLS+=("$tool")
        fi
    done

    if [[ ${#_RL_MISSING_TOOLS[@]} -gt 0 ]]; then
        return 1
    fi
    return 0
}

# ============================================================================
# Path Utilities
# ============================================================================

# Find project root by walking up directory tree
# Args:
#   $1: Starting directory (defaults to current directory)
# Returns:
#   Project root path
_rl_find_project_root() {
    local start_dir="${1:-.}"
    local current_dir

    current_dir="$(cd "$start_dir" 2>/dev/null && pwd)" || {
        echo "$start_dir"
        return 1
    }

    local search_depth=0
    local max_depth=10

    while [[ "$current_dir" != "/" ]] && [[ $search_depth -lt $max_depth ]]; do
        # Check for Cargo.toml first (most reliable for Rust)
        if [[ -f "$current_dir/Cargo.toml" ]]; then
            echo "$current_dir"
            return 0
        fi

        # Fallback to .git directory
        if [[ -d "$current_dir/.git" ]]; then
            echo "$current_dir"
            return 0
        fi

        current_dir="$(dirname "$current_dir")"
        ((search_depth++))
    done

    # If nothing found, return the starting directory
    echo "$(cd "$start_dir" 2>/dev/null && pwd)" || echo "$start_dir"
    return 0
}

# Get relative path from base to target
# Args:
#   $1: target path
#   $2: base path
# Returns:
#   Relative path
_rl_get_relative_path() {
    local target="$1"
    local base="$2"

    # Try realpath if available (Linux, modern macOS)
    if command -v realpath &>/dev/null; then
        realpath --relative-to="$base" "$target" 2>/dev/null && return 0
    fi

    # Try Python as fallback
    if command -v python3 &>/dev/null; then
        python3 -c 'import os, sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$target" "$base" 2>/dev/null && return 0
    fi

    # Manual fallback: if target starts with base, strip base prefix
    if [[ "$target" == "$base"/* ]]; then
        echo "${target#$base/}"
        return 0
    fi

    # Give up and return original
    echo "$target"
    return 1
}

# Get absolute path
# Args:
#   $1: path (relative or absolute)
# Returns:
#   Absolute path (or original path if resolution fails)
# Note: Always returns 0 to avoid breaking set -e scripts
_rl_get_absolute_path() {
    local path="$1"

    # Try realpath if available
    if command -v realpath &>/dev/null; then
        local result
        result=$(realpath "$path" 2>/dev/null)
        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi
    fi

    # Try Python as fallback
    if command -v python3 &>/dev/null; then
        local result
        result=$(python3 -c 'import os; import sys; print(os.path.realpath(sys.argv[1]))' "$path" 2>/dev/null)
        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi
    fi

    # Manual fallback
    if [[ -d "$path" ]]; then
        local result
        result=$(cd "$path" && pwd 2>/dev/null)
        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi
    elif [[ -f "$path" ]]; then
        local dir="$(dirname "$path")"
        local file="$(basename "$path")"
        local result
        result=$(cd "$dir" 2>/dev/null && echo "$(pwd)/$file")
        if [[ -n "$result" ]]; then
            echo "$result"
            return 0
        fi
    fi

    # Give up and return original (still return 0)
    echo "$path"
    return 0
}

# ============================================================================
# Cargo Workspace Utilities
# ============================================================================

# Get workspace root using cargo
# Returns:
#   Workspace root path or empty string
_rl_get_workspace_root() {
    if ! command -v cargo &>/dev/null; then
        return 1
    fi

    local workspace_root
    workspace_root=$(cargo locate-project --workspace 2>/dev/null | jq -r '.root' 2>/dev/null | xargs dirname 2>/dev/null)

    if [[ -n "$workspace_root" && -d "$workspace_root" ]]; then
        echo "$workspace_root"
        return 0
    fi

    return 1
}

# Check if current directory is in a Cargo workspace
# Returns:
#   0 if in workspace, 1 otherwise
_rl_is_in_workspace() {
    if ! command -v cargo &>/dev/null; then
        return 1
    fi

    local package_root
    local workspace_root

    package_root=$(cargo locate-project 2>/dev/null | jq -r '.root' 2>/dev/null | xargs dirname 2>/dev/null)
    workspace_root=$(cargo locate-project --workspace 2>/dev/null | jq -r '.root' 2>/dev/null | xargs dirname 2>/dev/null)

    if [[ -n "$package_root" && -n "$workspace_root" && "$package_root" != "$workspace_root" ]]; then
        return 0
    fi

    return 1
}
