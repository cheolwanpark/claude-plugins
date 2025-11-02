# Ruff Plugin for Claude Code

Automatically lint and format Python files with [ruff](https://github.com/astral-sh/ruff) whenever Claude edits or writes them.

## Features

- Auto-fixes common Python linting violations (unused imports, formatting issues, etc.)
- Formats code using Black-compatible style
- Reports unfixable issues back to Claude for resolution

## Requirements

You must have `ruff` installed on your system:

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
4. **Reports errors**: If there are unfixable linting violations, reports them to Claude and blocks execution to prevent building on broken code

**Example:** Claude writes `import os; x=1+2` → Hook transforms to `x = 1 + 2` (unused import removed, spacing fixed)

## Configuration

### Custom Ruff Settings

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

## What Gets Auto-Fixed

Ruff can automatically fix many issues including unused imports, import sorting, whitespace, formatting (Black-compatible), and quote normalization. See the full list of [auto-fixable ruff rules](https://docs.astral.sh/ruff/rules/).

## What Gets Reported

Unfixable issues (syntax errors, undefined names, type errors, complex violations) are reported to Claude and block execution until resolved.

## Troubleshooting

- **Hook not running**: Check `which ruff` to verify installation, confirm plugin is enabled, or run `claude --debug` for logs
- **Ruff not found**: Install with `pip install ruff`, `uv add --dev ruff`, or `brew install ruff`
- **Permission denied**: Run `chmod +x plugins/ruff/hooks/ruff-lint-format.sh`
- **Timeout errors**: Increase timeout in `hooks/hooks.json` for large files

## License

MIT

## Author

Cheolwan Park

## Links

- [Ruff Documentation](https://docs.astral.sh/ruff/)
- [Ruff GitHub](https://github.com/astral-sh/ruff)
- [Claude Code Hooks Reference](https://docs.claude.com/claude-code/hooks)
