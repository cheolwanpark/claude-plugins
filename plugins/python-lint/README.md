# Python Lint Plugin for Claude Code

Automatically lint, format, and type-check Python files with [ruff](https://github.com/astral-sh/ruff) and [pyright](https://github.com/microsoft/pyright) whenever Claude edits or writes them.

## Features

- **Auto-fixes** common Python linting violations (unused imports, formatting issues, etc.)
- **Formats** code using Black-compatible style with ruff
- **Type-checks** code with pyright static type checker
- **Reports** unfixable linting issues and type errors back to Claude for resolution

## Requirements

You must have the following tools installed on your system:

### Required Tools

**ruff** (Python linter and formatter):
```bash
# Install with pip
pip install ruff

# Or with uv
uv add --dev ruff

# Or with Homebrew (macOS)
brew install ruff

# Or with pipx
pipx install ruff
```

**pyright** (Python static type checker):
```bash
# Install with Homebrew (recommended on macOS)
brew install pyright

# Or with npm
npm install -g pyright

# Or with pip (Python wrapper)
pip install pyright
```

**jq** (JSON processor for parsing tool outputs):
```bash
# Install with Homebrew (macOS)
brew install jq

# Or with apt (Linux)
sudo apt-get install jq

# Or with yum (Linux)
sudo yum install jq
```

**realpath** (path resolution utility, part of coreutils):
```bash
# Usually pre-installed on Linux
# On macOS, install coreutils:
brew install coreutils

# Verify:
which realpath
```

### Verify Installation

```bash
ruff --version
pyright --version
jq --version
realpath --version
```

## Installation

This plugin is available through the useful-claude-plugins marketplace.

1. Add the marketplace to your Claude Code settings
2. Enable the "python-lint" plugin
3. Claude will automatically lint, format, and type-check Python files after editing them

## How It Works

The plugin uses a PostToolUse hook that triggers after Claude uses the `Edit` or `Write` tools:

1. **Detects Python files**: Only processes files with `.py` extension
2. **Auto-fixes violations**: Runs `ruff check --fix` to automatically fix linting issues
3. **Formats code**: Runs `ruff format` to apply consistent formatting
4. **Checks for lint errors**: Runs `ruff check --output-format=json` to capture unfixable issues
5. **Type-checks**: Runs `pyright` on the file to check for type errors
6. **Reports issues**: If there are unfixable linting violations or type errors, reports them to Claude

**Example:**
- Claude writes `import os; x=1+2` → Hook transforms to `x = 1 + 2` (unused import removed, spacing fixed)
- Claude writes `def foo(x: int) -> str: return x` → Hook reports type error: "Expression of type 'int' cannot be assigned to return type 'str'"

## Configuration

### Ruff Configuration

Create a `pyproject.toml` in your project root to customize ruff behavior:

```toml
# pyproject.toml
[tool.ruff]
line-length = 100
target-version = "py311"

[tool.ruff.lint]
select = ["E", "F", "I", "N", "W"]
ignore = ["E501"]  # Ignore line length

[tool.ruff.format]
quote-style = "double"
indent-style = "space"
```

Alternatively, use `ruff.toml` or `.ruff.toml`. See the [ruff configuration docs](https://docs.astral.sh/ruff/configuration/) for all options.

### Pyright Configuration

**Important:** For accurate type checking, you should configure pyright for your project. Create a `pyrightconfig.json` in your project root:

```json
{
  "pythonVersion": "3.11",
  "typeCheckingMode": "basic",
  "include": ["src"],
  "exclude": ["**/node_modules", "**/__pycache__", ".venv"],
  "reportMissingImports": true,
  "reportMissingTypeStubs": false
}
```

Or add to your `pyproject.toml`:

```toml
[tool.pyright]
pythonVersion = "3.11"
typeCheckingMode = "basic"
include = ["src"]
exclude = ["**/node_modules", "**/__pycache__", ".venv"]
reportMissingImports = true
reportMissingTypeStubs = false
```

See the [pyright configuration docs](https://microsoft.github.io/pyright/#/configuration) for all options.

### Type Checking Modes

Pyright offers three strictness levels:
- **basic**: Default, balanced checking (recommended for most projects)
- **standard**: More strict, catches more potential issues
- **strict**: Very strict, enforces comprehensive type annotations

## Limitations

- **Per-file type checking**: The hook runs pyright on individual files, which means it checks types based on the project configuration but analyzes one file at a time. This is faster but may miss some cross-file type inconsistencies that full project analysis would catch.
- **Performance**: Type checking adds overhead. On large projects, you may notice a slight delay after editing Python files.
- **Configuration required**: Without a `pyrightconfig.json` or `pyproject.toml` configuration, pyright may report many false positives for missing imports or use default settings that don't match your project.

## What Gets Auto-Fixed

Ruff can automatically fix many issues including:
- Unused imports
- Import sorting
- Whitespace and indentation
- Quote normalization
- Trailing commas
- Blank lines

See the full list of [auto-fixable ruff rules](https://docs.astral.sh/ruff/rules/).

## What Gets Reported

The following issues are reported to Claude for manual resolution:

**From ruff:**
- Syntax errors
- Undefined names
- Complex linting violations that can't be auto-fixed

**From pyright:**
- Type mismatches (e.g., assigning `int` to a `str` variable)
- Missing type annotations (depending on configuration)
- Invalid attribute access
- Incorrect function call signatures
- Unreachable code
- Missing imports or modules

## Example Output

When the hook detects issues, Claude will see output like:

```json
{
  "lintingIssues": [
    {
      "code": "F821",
      "message": "Undefined name `undefined_var`",
      "location": {"row": 10, "column": 5},
      "end_location": {"row": 10, "column": 18},
      "filename": "example.py"
    }
  ],
  "typeErrors": [
    {
      "severity": "error",
      "message": "Cannot assign to \"str\" from \"int\"",
      "range": {
        "start": {"line": 15, "character": 5},
        "end": {"line": 15, "character": 10}
      }
    }
  ]
}
```

## Troubleshooting

### Hook Not Running
- Check if tools are installed: `which ruff pyright jq realpath`
- Confirm plugin is enabled in Claude Code settings
- Run with debug mode for logs

### Missing Tools
- **Ruff not found**: Install with `brew install ruff` or `pip install ruff`
- **Pyright not found**: Install with `brew install pyright` or `npm install -g pyright`
- **jq not found**: Install with `brew install jq` or your package manager
- **realpath not found**: Install coreutils with `brew install coreutils` (macOS) or use your package manager (Linux)

### Permission Denied
```bash
chmod +x plugins/python-lint/hooks/python-lint.sh
```

### Too Many Type Errors
- Create a `pyrightconfig.json` with appropriate settings for your project
- Use `"typeCheckingMode": "basic"` for less strict checking
- Add exclusions for third-party code or test files
- Set `"reportMissingImports": false` if dealing with dynamic imports

### Slow Performance
- Type checking adds overhead; this is expected
- Optimize your `pyrightconfig.json` to exclude unnecessary directories
- Consider excluding large test directories or generated files
- The hook has a 30-second timeout; very large files may timeout

### False Positive Type Errors
- Ensure your project has proper type stubs installed: `pip install types-*`
- Check that your Python version in `pyrightconfig.json` matches your actual version
- Add `# type: ignore` comments for known false positives

## Breaking Changes (v2.0.0)

This is a major version update with breaking changes:

- **Plugin renamed**: `ruff` → `python-lint`
  - You must uninstall the old "ruff" plugin and install the new "python-lint" plugin
- **New dependencies**: `pyright`, `jq`, and `realpath` (coreutils) are now required
- **Hook script renamed**: `ruff-lint-format.sh` → `python-lint.sh`
- **New behavior**: Type checking is now always enabled (was linting-only before)

### Migration Steps

1. Uninstall the old plugin: `claude-code plugin remove ruff` (if applicable)
2. Install required tools:
   - macOS: `brew install pyright jq coreutils`
   - Linux: `sudo apt-get install pyright jq` (realpath usually pre-installed)
3. Install the new plugin: Enable "python-lint" from the marketplace
4. Create pyright configuration: Add `pyrightconfig.json` or `[tool.pyright]` section to `pyproject.toml`

## License

MIT

## Author

Cheolwan Park

## Links

- [Ruff Documentation](https://docs.astral.sh/ruff/)
- [Ruff GitHub](https://github.com/astral-sh/ruff)
- [Pyright Documentation](https://microsoft.github.io/pyright/)
- [Pyright GitHub](https://github.com/microsoft/pyright)
- [Claude Code Documentation](https://docs.claude.com/claude-code)
