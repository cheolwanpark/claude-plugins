#!/usr/bin/env bash
# Common library for go-lint plugin
# This file should be sourced, not executed directly

# Source guard
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Error: This script should be sourced, not executed directly" >&2
    exit 1
fi

# Namespace prefix: _gol_ (go-lint)

# Generate JSON response for hooks
# Args: decision, reason, event_name, context
_gol_json_response() {
    local decision="${1:-allow}"
    local reason="${2:-}"
    local event_name="${3:-PostToolUse}"
    local context="${4:-}"

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
        }'
}

# Exit with JSON response
# Args: decision, reason, event_name, context
_gol_safe_exit() {
    _gol_json_response "$@"
    exit 0
}

# Parse file path from stdin JSON input
# Returns: file path or empty string
_gol_parse_file_path() {
    local input="${1:-}"
    if [[ -z "$input" ]]; then
        input=$(cat)
    fi

    echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null || echo ""
}

# Check if required tools are available
# Args: tool1 tool2 ...
# Sets: _gol_MISSING_TOOLS array
_gol_check_required_tools() {
    _gol_MISSING_TOOLS=()

    for tool in "$@"; do
        if ! command -v "$tool" &>/dev/null; then
            _gol_MISSING_TOOLS+=("$tool")
        fi
    done

    if [[ ${#_gol_MISSING_TOOLS[@]} -gt 0 ]]; then
        return 1
    fi
    return 0
}

# Find Go project root by walking up directory tree
# Args: start_dir
# Returns: project root path or empty string
_gol_find_project_root() {
    local current_dir="${1:-.}"
    current_dir=$(cd "$current_dir" && pwd)

    # Walk up directory tree looking for project markers
    while [[ "$current_dir" != "/" ]]; do
        # Check for go.mod (primary marker)
        if [[ -f "$current_dir/go.mod" ]]; then
            echo "$current_dir"
            return 0
        fi

        # Check for go.work (workspace)
        if [[ -f "$current_dir/go.work" ]]; then
            echo "$current_dir"
            return 0
        fi

        # Check for .git (fallback)
        if [[ -d "$current_dir/.git" ]]; then
            echo "$current_dir"
            return 0
        fi

        current_dir=$(dirname "$current_dir")
    done

    # No project root found
    echo ""
    return 1
}

# Get relative path from base to target
# Args: base_path, target_path
# Returns: relative path
_gol_get_relative_path() {
    local base="${1}"
    local target="${2}"

    # Try using realpath if available
    if command -v realpath &>/dev/null; then
        base=$(realpath "$base" 2>/dev/null || echo "$base")
        target=$(realpath "$target" 2>/dev/null || echo "$target")
    fi

    # Try using Python if available
    if command -v python3 &>/dev/null; then
        python3 -c "import os.path; print(os.path.relpath('$target', '$base'))" 2>/dev/null && return 0
    fi

    # Fallback: just return the target path
    echo "$target"
}

# Get absolute path
# Args: path
# Returns: absolute path
_gol_get_absolute_path() {
    local path="${1}"

    # Try using realpath if available
    if command -v realpath &>/dev/null; then
        realpath "$path" 2>/dev/null && return 0
    fi

    # Try using Python if available
    if command -v python3 &>/dev/null; then
        python3 -c "import os.path; print(os.path.abspath('$path'))" 2>/dev/null && return 0
    fi

    # Fallback: use cd and pwd
    if [[ -d "$path" ]]; then
        (cd "$path" && pwd)
    elif [[ -f "$path" ]]; then
        (cd "$(dirname "$path")" && echo "$(pwd)/$(basename "$path")")
    else
        echo "$path"
    fi
}

# Detect golangci-lint config file
# Args: project_root
# Returns: config file path or empty string
_gol_detect_golangci_config() {
    local project_root="${1}"

    local config_files=(
        ".golangci.yml"
        ".golangci.yaml"
        ".golangci.json"
    )

    for config_file in "${config_files[@]}"; do
        if [[ -f "$project_root/$config_file" ]]; then
            echo "$project_root/$config_file"
            return 0
        fi
    done

    echo ""
    return 1
}

# Build golangci-lint config arguments
# Args: project_root
# Returns: config arguments string
_gol_build_golangci_config_args() {
    local project_root="${1}"
    local config_file

    config_file=$(_gol_detect_golangci_config "$project_root")

    if [[ -n "$config_file" ]]; then
        echo "--config=$config_file"
    else
        echo ""
    fi
}
