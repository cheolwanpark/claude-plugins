#!/usr/bin/env bash
#
# python-lint-common.sh - Shared library for python-lint plugin
# Contains namespaced functions used by both hook and project scripts
#
# All functions are prefixed with _pyl_ to avoid namespace collisions
#

# Ensure this script is sourced, not executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly" >&2
    exit 1
fi

# ============================================================================
# JSON Response Generation
# ============================================================================

# Generate JSON response for hooks using jq
# Args: $1=decision ("allow"|"block"), $2=reason, $3=event_name (optional), $4=context (optional)
# Returns: JSON string on stdout
_pyl_json_response() {
    local decision="${1:-allow}"
    local reason="${2:-No reason provided}"
    local event_name="${3:-}"
    local context="${4:-}"

    # Validate jq is available
    if ! command -v jq &>/dev/null; then
        echo '{"error": "jq not available", "decision": "allow"}'
        return 1
    fi

    # Generate JSON response with error handling
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
            }' 2>/dev/null || {
                echo "{\"error\": \"jq failed\", \"decision\": \"allow\"}"
                return 1
            }
    else
        jq -n \
            --arg decision "$decision" \
            --arg reason "$reason" \
            '{
                decision: $decision,
                reason: $reason
            }' 2>/dev/null || {
                echo "{\"error\": \"jq failed\", \"decision\": \"allow\"}"
                return 1
            }
    fi
}

# ============================================================================
# Input Parsing
# ============================================================================

# Parse file_path from hook JSON input using jq
# Args: $1=JSON input string
# Returns: file_path on stdout, or empty string if not found
_pyl_parse_file_path() {
    local input="${1:-}"

    if [[ -z "$input" ]]; then
        return 1
    fi

    # Validate jq is available
    if ! command -v jq &>/dev/null; then
        # Fallback: try to extract with python3
        if command -v python3 &>/dev/null; then
            echo "$input" | python3 -c "import sys, json; data = json.load(sys.stdin); print(data.get('tool_input', {}).get('file_path', ''))" 2>/dev/null || echo ""
        else
            echo ""
            return 1
        fi
        return
    fi

    # Use jq for parsing with error handling
    echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo ""
}

# ============================================================================
# Tool Checking
# ============================================================================

# Check if required tools are installed
# Args: $@=list of required tools
# Returns: 0 if all tools available, 1 if any missing (sets _PYL_MISSING_TOOLS array)
_pyl_check_required_tools() {
    local tools=("$@")
    _PYL_MISSING_TOOLS=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            _PYL_MISSING_TOOLS+=("$tool")
        fi
    done

    if [[ ${#_PYL_MISSING_TOOLS[@]} -gt 0 ]]; then
        return 1
    fi
    return 0
}

# ============================================================================
# Project Root Detection
# ============================================================================

# Find project root by walking up from a given directory
# Args: $1=starting directory (defaults to current directory)
# Returns: project root path on stdout
_pyl_find_project_root() {
    local start_dir="${1:-.}"
    local current_dir

    # Resolve to absolute path
    current_dir="$(cd "$start_dir" 2>/dev/null && pwd)" || {
        echo "$start_dir"
        return 1
    }

    local search_depth=0
    local max_depth=10

    # Walk up directory tree looking for project markers
    while [[ "$current_dir" != "/" ]] && [[ $search_depth -lt $max_depth ]]; do
        # Check for project markers (first match wins)
        if [[ -d "$current_dir/.git" ]]; then
            echo "$current_dir"
            return 0
        fi
        if [[ -f "$current_dir/pyproject.toml" ]]; then
            echo "$current_dir"
            return 0
        fi
        if [[ -f "$current_dir/pyrightconfig.json" ]]; then
            echo "$current_dir"
            return 0
        fi
        if [[ -f "$current_dir/ruff.toml" ]] || [[ -f "$current_dir/.ruff.toml" ]]; then
            echo "$current_dir"
            return 0
        fi

        current_dir="$(dirname "$current_dir")"
        ((search_depth++))
    done

    # No project root found, return starting directory
    echo "$(cd "$start_dir" 2>/dev/null && pwd)" || echo "$start_dir"
    return 0
}

# ============================================================================
# Config Detection
# ============================================================================

# Detect if user has a ruff configuration file
# Args: $1=project root directory
# Returns: 0 if config exists, 1 if not
_pyl_detect_ruff_config() {
    local project_root="${1:-.}"

    # Check for dedicated ruff config files
    if [[ -f "$project_root/ruff.toml" ]] || [[ -f "$project_root/.ruff.toml" ]]; then
        return 0
    fi

    # Check if pyproject.toml exists and contains [tool.ruff] section
    if [[ -f "$project_root/pyproject.toml" ]]; then
        if grep -Eq '^\[tool\.ruff(\]|\.)' "$project_root/pyproject.toml" 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# Build ruff config arguments array
# Args: $1=project root, $2=plugin root
# Returns: Sets _PYL_RUFF_CONFIG_ARGS array
_pyl_build_ruff_config_args() {
    local project_root="${1:-.}"
    local plugin_root="${2}"

    _PYL_RUFF_CONFIG_ARGS=()

    if ! _pyl_detect_ruff_config "$project_root"; then
        # No user config found, use plugin's default
        if [[ -n "$plugin_root" ]] && [[ -f "$plugin_root/ruff.toml" ]]; then
            _PYL_RUFF_CONFIG_ARGS=(--config "$plugin_root/ruff.toml")
        fi
    fi
}

# ============================================================================
# Virtual Environment
# ============================================================================

# Activate virtual environment if found
# Args: $1=project root directory
# Returns: 0 if venv activated or not found, sets _PYL_VENV_ACTIVATED=true if activated
_pyl_activate_venv() {
    local project_root="${1:-.}"
    _PYL_VENV_ACTIVATED=false

    # Check common venv locations
    for venv_path in "$project_root/.venv" "$project_root/venv"; do
        if [[ -f "$venv_path/bin/activate" ]]; then
            # Attempt to activate (suppress errors if already activated)
            # shellcheck disable=SC1091
            if source "$venv_path/bin/activate" 2>/dev/null; then
                _PYL_VENV_ACTIVATED=true
                return 0
            fi
        fi
    done

    return 0
}

# ============================================================================
# Path Utilities
# ============================================================================

# Get relative path from base to target
# Args: $1=target path, $2=base path
# Returns: relative path on stdout
_pyl_get_relative_path() {
    local target="$1"
    local base="$2"

    # Try realpath first if available (most reliable)
    if command -v realpath &>/dev/null; then
        realpath --relative-to="$base" "$target" 2>/dev/null && return 0
    fi

    # Fallback to python3 (safer than bash string manipulation)
    if command -v python3 &>/dev/null; then
        python3 -c 'import os, sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$target" "$base" 2>/dev/null && return 0
    fi

    # Last resort: simple string substitution (only works if target starts with base/)
    if [[ "$target" == "$base"/* ]]; then
        echo "${target#$base/}"
        return 0
    fi

    # Give up and return target as-is
    echo "$target"
    return 1
}

# Get absolute path
# Args: $1=path
# Returns: absolute path on stdout
_pyl_get_absolute_path() {
    local path="$1"

    # Try realpath first if available
    if command -v realpath &>/dev/null; then
        realpath "$path" 2>/dev/null && return 0
    fi

    # Fallback to python3
    if command -v python3 &>/dev/null; then
        python3 -c 'import os; import sys; print(os.path.realpath(sys.argv[1]))' "$path" 2>/dev/null && return 0
    fi

    # Fallback: cd and pwd (works for files and directories)
    if [[ -d "$path" ]]; then
        (cd "$path" && pwd) 2>/dev/null && return 0
    elif [[ -f "$path" ]]; then
        local dir="$(dirname "$path")"
        local file="$(basename "$path")"
        (cd "$dir" && echo "$(pwd)/$file") 2>/dev/null && return 0
    fi

    # Give up and return path as-is
    echo "$path"
    return 1
}
