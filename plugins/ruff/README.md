# Ruff Plugin for Claude Code

Automatically lint and format Python files with [ruff](https://github.com/astral-sh/ruff) whenever Claude edits or writes them.

## Features

- **Auto-fix linting issues**: Automatically fixes common Python linting violations (unused imports, formatting issues, etc.)
- **Auto-format code**: Formats Python code using Black-compatible style
- **Intelligent error reporting**: Reports unfixable linting issues back to Claude for resolution
- **Zero configuration**: Works out of the box with sensible defaults
- **Fast**: Powered by ruff, an extremely fast Python linter written in Rust

## Requirements

You must have `ruff` installed on your system:

```bash
# Install with pip
pip install ruff

# Or with Homebrew (macOS)
brew install ruff

# Or with pipx
pipx install ruff
```

Verify installation:

```bash
ruff --version
```

## Installation

This plugin is available through the useful-claude-plugins marketplace.

1. Add the marketplace to your Claude Code settings
2. Enable the "ruff" plugin
3. Claude will automatically lint and format Python files after editing them

## How It Works

The plugin uses a PostToolUse hook that triggers after Claude uses the `Edit` or `Write` tools:

1. **Detects Python files**: Only processes files with `.py` extension
2. **Auto-fixes violations**: Runs `ruff check --fix` to automatically fix linting issues
3. **Formats code**: Runs `ruff format` to apply consistent formatting
4. **Reports errors**: If there are unfixable linting violations, reports them to Claude

### Example Workflow

```python
# Claude writes this messy code:
import os
import sys
import json
x=1+2
def foo( ):
    pass
```

**Hook automatically transforms it to:**

```python
# Unused imports removed, code formatted
x = 1 + 2


def foo():
    pass
```

## Configuration

### Custom Ruff Settings

Create a `pyproject.toml` or `ruff.toml` in your project root to customize ruff behavior:

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

Or standalone `ruff.toml`:

```toml
line-length = 100
target-version = "py311"

[lint]
select = ["E", "F", "I", "N", "W"]
ignore = ["E501"]

[format]
quote-style = "double"
```

### Hook Timeout

The hook has a default timeout of 30 seconds. To change this, edit `hooks/hooks.json`:

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          {
            "type": "command",
            "command": "${CLAUDE_PLUGIN_ROOT}/hooks/ruff-lint-format.sh",
            "timeout": 60
          }
        ]
      }
    ]
  }
}
```

## What Gets Auto-Fixed

Ruff can automatically fix many common issues:

- **Import sorting**: Organizes imports alphabetically
- **Unused imports**: Removes unused import statements
- **Unused variables**: Removes unused variable assignments
- **Whitespace**: Fixes trailing whitespace, blank lines
- **Formatting**: Applies Black-compatible code style
- **Quote normalization**: Standardizes quote usage
- **And many more**: See [ruff rules](https://docs.astral.sh/ruff/rules/)

## What Gets Reported

If ruff finds issues it cannot auto-fix, Claude will see them and can address them:

- **Syntax errors**: Invalid Python syntax
- **Undefined names**: Variables used before definition
- **Type errors**: If using type checkers
- **Complex violations**: Issues requiring manual intervention

## Troubleshooting

### Hook not running

1. Check that ruff is installed: `which ruff`
2. Verify the plugin is enabled in Claude Code
3. Run `claude --debug` to see hook execution logs

### Ruff not found error

Install ruff:

```bash
pip install ruff
# or
brew install ruff
```

### Script permission denied

Make the script executable:

```bash
chmod +x plugins/ruff/hooks/ruff-lint-format.sh
```

### Timeout errors

Increase the timeout in `hooks/hooks.json` if working with very large files.

## License

MIT

## Author

Cheolwan Park

## Links

- [Ruff Documentation](https://docs.astral.sh/ruff/)
- [Ruff GitHub](https://github.com/astral-sh/ruff)
- [Claude Code Hooks Reference](https://docs.claude.com/claude-code/hooks)
