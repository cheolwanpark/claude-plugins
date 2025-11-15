# go-lint Plugin

Automatic Go linting and formatting for Claude Code using `goimports`, `go vet`, and `golangci-lint`.

## Features

- **Automatic formatting on file save**: Uses `goimports` to format code and organize imports
- **Static analysis on edits**: Runs `go vet` on edited files to catch common mistakes
- **Project-wide linting**: Comprehensive linting with `golangci-lint` via slash command
- **Respects project configuration**: Honors `.golangci.yml` if present
- **Fast feedback**: Single-file hooks optimized for speed

## Installation

### Required Tools

1. **goimports** - For formatting and import management:
   ```bash
   go install golang.org/x/tools/cmd/goimports@latest
   ```

2. **go** - Standard Go toolchain (includes `go vet`)
   - Download from [go.dev](https://go.dev/dl/)

3. **golangci-lint** - For comprehensive project linting:
   ```bash
   # macOS/Linux
   go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest

   # Alternative: Homebrew
   brew install golangci-lint

   # Verify installation
   golangci-lint --version
   ```

### Plugin Installation

The plugin is automatically loaded when you have this repository in your Claude Code plugins directory.

## Usage

### Automatic Hook (Single File)

The hook automatically runs when you edit or create Go files:

1. **Formatting**: Runs `goimports -w` to format code and organize imports (in-place modification)
2. **Static Analysis**: Runs `go vet` on the package containing the file for quick checks
3. **Non-blocking**: Always allows the operation to proceed (never blocks your workflow)

**Behavior:**
- The hook modifies files in-place to apply formatting
- Runs `go vet` silently on the package (not entire project) for performance
- Does not block operations even if issues are found (rust-lint pattern)
- Use `/go-lint:lint-project` for comprehensive error reporting

**File requirements:**
- Must be a `.go` file
- Must be under 1MB in size
- Must be in a valid Go project (has `go.mod`, `go.work`, or `.git` in parent directories)

**Example workflow:**
```go
// You edit a file with issues:
package main

import "fmt"
import "os"  // Will be organized by goimports

func main() {
    fmt.Println("Hello")
}
```

The hook will:
1. Automatically format and organize imports (saved to file)
2. Run `go vet` silently in the background
3. Allow the operation to proceed immediately

To see comprehensive lint results, run `/go-lint:lint-project`

### Project-wide Linting (Slash Command)

Run comprehensive linting on your entire project:

```bash
# Lint entire project
/go-lint:lint-project

# Lint specific directory
/go-lint:lint-project ./cmd

# Lint specific package
/go-lint:lint-project ./internal/api
```

**Output includes:**
- Summary of errors and warnings
- Top 20 errors (if any)
- Top 10 warnings (if any)
- File locations and linter names

**Example output:**
```markdown
## Go Linting Report

**Target:** ./...
**Project root:** /path/to/project
**Config:** .golangci.yml

### Summary

- **Errors:** 3
- **Warnings:** 0

### Errors

- **cmd/main.go:15:2** [errcheck] Error return value is not checked
- **internal/api/handler.go:42:10** [ineffassign] Ineffectual assignment to err
- **pkg/util/helper.go:8:6** [unused] func helper is unused
```

## Configuration

### golangci-lint Configuration

The plugin respects your project's `.golangci.yml` configuration file:

```yaml
# .golangci.yml
run:
  timeout: 5m
  tests: true

linters:
  enable:
    - errcheck
    - gosimple
    - govet
    - ineffassign
    - staticcheck
    - unused
    - gofmt
    - goimports

issues:
  max-issues-per-linter: 0
  max-same-issues: 0
```

If no config file is found, `golangci-lint` uses its default linters.

### Hook Behavior

The hook is configured in `hooks/hooks.json`:

```json
{
  "description": "Automatically lint and format Go files using goimports and go vet",
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/go-lint.sh",
            "timeout": 30
          }
        ]
      }
    ]
  }
}
```

- **Trigger**: PostToolUse on Edit|Write operations
- **Timeout**: 30 seconds
- **File types**: `*.go` files only

## How It Works

### Hook Workflow

1. **Parse input**: Extract file path from PostToolUse event
2. **Validate**: Check file extension, size, and existence
3. **Find project root**: Walk up directory tree to find `go.mod`, `go.work`, or `.git`
4. **Format**: Run `goimports -w` to format file in-place
5. **Analyze**: Run `go vet ./...` from project root
6. **Filter**: Show only issues in the edited file
7. **Report**: Return JSON with block/allow decision

### Project Linting Workflow

1. **Validate target**: Check directory exists
2. **Find project root**: Locate `go.mod` or `go.work`
3. **Detect config**: Look for `.golangci.yml`
4. **Run linter**: Execute `golangci-lint run --out-format=json --fix`
5. **Parse results**: Extract issues from JSON output
6. **Generate report**: Format as markdown with error/warning counts
7. **Exit**: Code 1 for errors, 0 for warnings/success

## Troubleshooting

### Hook not running

**Check tool installation:**
```bash
which goimports
which go
which golangci-lint
```

**Verify file size:**
```bash
# Files over 1MB are skipped
ls -lh yourfile.go
```

**Check project structure:**
```bash
# Must have go.mod, go.work, or .git
ls go.mod
```

### golangci-lint too slow

**Reduce linter scope** in `.golangci.yml`:
```yaml
linters:
  default: fast  # Use only fast linters

run:
  timeout: 2m
  skip-dirs:
    - vendor
    - third_party
```

**Enable caching:**
```bash
# golangci-lint caches by default in:
# macOS: ~/Library/Caches/golangci-lint
# Linux: ~/.cache/golangci-lint

# Clear cache if needed
golangci-lint cache clean
```

### False positives

**Disable specific linters** in `.golangci.yml`:
```yaml
linters:
  disable:
    - errcheck  # Too noisy for your project

issues:
  exclude-rules:
    - path: _test\.go
      linters:
        - errcheck  # Don't check errors in tests
```

**Add inline comments to suppress:**
```go
//nolint:errcheck // Ignore error here
foo()
```

### go vet fails but golangci-lint passes

`go vet` and `golangci-lint` use different checks. The hook runs `go vet` for fast feedback, while the project command runs the full `golangci-lint` suite.

To align them, enable `govet` in `.golangci.yml`:
```yaml
linters:
  enable:
    - govet
```

## Testing

Run the test suite:

```bash
cd plugins/go-lint/tests
./run-tests.sh
```

Tests cover:
- Hook behavior on clean files
- Hook behavior on files with errors
- Project root detection
- Tool availability checking
- JSON response generation

## Contributing

Contributions welcome! Please ensure:
- Tests pass
- Scripts are shellcheck-clean
- Documentation is updated
- Follows existing plugin patterns

## License

MIT
