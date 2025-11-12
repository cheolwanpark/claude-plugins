# Rust Lint Plugin for Claude Code

Automatically format Rust files with **rustfmt** and provide on-demand comprehensive linting with **clippy**.

## Features

- ✅ **Auto-formatting**: Automatically formats `.rs` files on every edit/write using `rustfmt`
- 🚀 **Fast hook execution**: Hook completes in <2s (formatting only, no compilation)
- 🔍 **Comprehensive linting**: On-demand project-wide clippy analysis via slash command
- 🗂️ **Workspace support**: Automatically detects and handles Cargo workspaces
- 🧹 **Isolated builds**: Build artifacts stored in `/tmp` to avoid project pollution
- 🛡️ **Graceful degradation**: Clear error messages when tools are missing
- 📊 **Detailed reports**: Markdown-formatted reports with file:line:column references

## Why This Architecture?

Unlike ESLint or Ruff, **clippy requires full cargo compilation** and can take 5-30+ seconds even on small projects. Running clippy on every file save would make the editor unresponsive.

**Our solution:**
- **Hook (PostToolUse)**: Fast rustfmt-only formatting (<2s)
- **Command (`/rust-lint:lint-project`)**: Comprehensive clippy analysis (user-initiated, acceptable wait time)

This design provides immediate formatting feedback while preserving comprehensive linting when you need it.

## Requirements

- **Rust toolchain** (rustc, cargo): Install from [rustup.rs](https://rustup.rs)
- **rustfmt**: `rustup component add rustfmt`
- **clippy**: `rustup component add clippy`
- **jq**: JSON processor
  - macOS: `brew install jq`
  - Ubuntu/Debian: `apt-get install jq`
  - Other: See [jq download page](https://stedolan.github.io/jq/download/)

## Installation

### 1. Install the plugin

Place this plugin in your Claude Code plugins directory:

```bash
# If you haven't cloned the repository
cd ~/.claude/plugins  # or your plugins directory
git clone https://github.com/cheolwanpark/useful-claude-plugins
cd useful-claude-plugins/plugins/rust-lint

# Or if you already have the repository
cd /path/to/useful-claude-plugins/plugins/rust-lint
```

### 2. Install Rust components

```bash
rustup component add rustfmt clippy
```

### 3. Verify installation

```bash
rustfmt --version
cargo clippy --version
jq --version
```

### 4. Enable the plugin in Claude Code

The plugin will be automatically detected by Claude Code. You can verify it's loaded by checking for the `/rust-lint:lint-project` command.

## How It Works

### Hook Behavior (Automatic)

**Triggered on:** Every `Edit` or `Write` operation on `.rs` files

**What it does:**
1. Validates file is `.rs` and <1MB
2. Checks if `rustfmt` is installed
3. Runs `rustfmt --check` to see if formatting is needed
4. If needed, runs `rustfmt` to auto-format
5. Returns `allow` decision (never blocks)

**Performance:**
- Typical execution time: <1 second
- No compilation required
- No clippy analysis (too slow for hooks)

**File size limit:** Files larger than 1MB are skipped to avoid timeouts. Use `cargo fmt` manually for large files.

### Slash Command (On-Demand)

**Command:** `/rust-lint:lint-project [directory]`

**What it does:**
1. Finds the Cargo workspace/project root
2. Checks formatting with `cargo fmt --check`
3. Runs `cargo clippy --workspace --all-targets --no-deps`
4. Generates a markdown report with:
   - Summary (error count, warning count)
   - Formatting issues (if any)
   - Clippy errors (up to 20 shown)
   - Clippy warnings (up to 10 shown)
5. Exits with code 1 if errors found, 0 otherwise

**Performance:**
- First run: 10-30 seconds (requires compilation)
- Subsequent runs: 2-10 seconds (incremental compilation)

**Build artifacts:** Isolated to `/tmp/claude-rust-lint-cache-<project-hash>` to avoid polluting your project directory.

## Configuration

### rustfmt Configuration

Create a `rustfmt.toml` or `.rustfmt.toml` in your project root:

```toml
# Edition must match Cargo.toml
edition = "2021"

# Line width
max_width = 100

# Indentation
hard_tabs = false
tab_spaces = 4

# Imports
imports_granularity = "Crate"
group_imports = "StdExternalCrate"

# Trailing commas
trailing_comma = "Vertical"

# Use field init shorthand
use_field_init_shorthand = true
```

**Generate default config:**
```bash
rustfmt --print-config default > rustfmt.toml
```

### clippy Configuration

**Option 1: Cargo.toml [lints] (Recommended for Rust 1.74+)**

```toml
[lints.clippy]
# Enable groups
all = "warn"
pedantic = "warn"

# Deny specific lints
unwrap_used = "deny"
expect_used = "warn"

# Allow noisy pedantic lints
missing_errors_doc = "allow"
missing_panics_doc = "allow"
module_name_repetitions = "allow"
```

**Option 2: clippy.toml or .clippy.toml**

```toml
# Cognitive complexity threshold
cognitive-complexity-threshold = 30

# Maximum allowed type complexity
type-complexity-threshold = 250

# Maximum allowed function parameters
too-many-arguments-threshold = 7

# Allowed variable names
allowed-names = ["i", "j", "k", "x", "y", "z"]
```

**Option 3: Source code attributes**

```rust
#![warn(clippy::all)]
#![warn(clippy::pedantic)]
#![deny(clippy::unwrap_used)]
#![allow(clippy::missing_errors_doc)]
```

### Workspace Configuration

For Cargo workspaces, configure lints in the workspace root's `Cargo.toml`:

```toml
[workspace]
members = ["crate1", "crate2"]

[workspace.lints.clippy]
pedantic = "warn"
unwrap_used = "deny"
```

Member crates can inherit workspace lints:

```toml
# In member Cargo.toml
[lints]
workspace = true
```

## Usage Examples

### Automatic Formatting (Hook)

```rust
// Before saving (badly formatted)
pub fn example(x:i32,y:i32)->i32{x+y}

// After saving (auto-formatted by rustfmt)
pub fn example(x: i32, y: i32) -> i32 {
    x + y
}
```

The hook runs automatically and formats the file silently.

### Manual Project Linting (Command)

```bash
# In your chat with Claude
/rust-lint:lint-project

# Or specify a directory
/rust-lint:lint-project path/to/workspace
```

**Example output:**

```markdown
# Rust Lint Report

**Project:** `/Users/you/project/my-rust-app`

## Summary
- **Formatting:** ✅ All files properly formatted
- **Clippy Errors:** 0
- **Clippy Warnings:** 3

## Clippy Warnings
- **src/main.rs:15:9** - `clippy::unwrap_used` - called `.unwrap()` on an `Option` value
- **src/lib.rs:42:13** - `clippy::needless_return` - unneeded `return` statement
- **src/utils.rs:8:5** - `clippy::single_match` - you seem to be trying to use `match` for destructuring a single pattern

## ✅ All Checks Passed!
```

## Troubleshooting

### "Missing required tools: rustfmt"

**Problem:** rustfmt is not installed or not in PATH.

**Solution:**
```bash
rustup component add rustfmt
rustfmt --version  # Verify installation
```

### "Missing required tools: cargo"

**Problem:** Rust toolchain is not installed.

**Solution:**
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source $HOME/.cargo/env
cargo --version  # Verify installation
```

### "Missing required tools: jq"

**Problem:** jq is not installed.

**Solution:**
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Fedora
sudo dnf install jq
```

### "Not a Rust Project"

**Problem:** No `Cargo.toml` found in the current directory or parent directories.

**Solution:** Make sure you're running the command from within a Rust project:
```bash
# Create a new project if needed
cargo new my-project
cd my-project
/rust-lint:lint-project
```

### "File is too large to format automatically"

**Problem:** The file is larger than 1MB and was skipped by the hook.

**Solution:** Format manually:
```bash
cargo fmt
# Or for a specific file
rustfmt path/to/large-file.rs
```

### Hook seems slow or times out

**Problem:** The hook is taking longer than expected.

**Possible causes:**
- Very large file (close to 1MB limit)
- Network/disk issues
- Rust toolchain not properly installed

**Solution:**
1. Check file size: `ls -lh path/to/file.rs`
2. Verify rustfmt works: `rustfmt --check path/to/file.rs`
3. Check rustfmt version: `rustfmt --version`

### Clippy command fails with "could not compile"

**Problem:** Project has compilation errors preventing clippy from running.

**Solution:** Fix compilation errors first:
```bash
cargo check  # See compilation errors
cargo build  # Fix errors
/rust-lint:lint-project  # Try again
```

### Clippy shows warnings for dependencies

**Problem:** Clippy is analyzing dependency code.

**Solution:** This shouldn't happen (we use `--no-deps`), but if it does:
```bash
# The plugin already uses --no-deps, but you can run manually:
cargo clippy --no-deps
```

## Comparison with Other Lint Plugins

| Feature | rust-lint | typescript-lint | python-lint |
|---------|-----------|-----------------|-------------|
| **Hook Speed** | <2s | <5s | <1s |
| **Auto-formatting** | Yes (rustfmt) | Yes (prettier) | Yes (ruff) |
| **Hook Linting** | No (too slow) | Yes (ESLint) | Yes (ruff) |
| **Command Linting** | Yes (clippy) | Optional (tsc) | Yes (ruff + pyright) |
| **Type Checking** | N/A (built-in) | Optional (tsc) | Yes (pyright) |
| **Workspace Support** | Yes | Yes (monorepos) | Yes |
| **Build Artifacts** | Isolated (/tmp) | None (no build) | None (no build) |
| **Default Config** | No | No | Yes |

**Key difference:** Rust's compilation model makes per-file linting impractical for hooks. We optimize for fast formatting in hooks and defer comprehensive analysis to user-initiated commands.

## Technical Details

### Hook Response Format

The hook communicates with Claude Code via JSON:

**Success (formatted):**
```json
{
  "decision": "allow",
  "reason": "Formatting applied with rustfmt"
}
```

**Success (already formatted):**
```json
{
  "decision": "allow",
  "reason": "File is already well-formatted"
}
```

**Error (syntax error):**
```json
{
  "decision": "allow",
  "reason": "rustfmt failed (syntax error or incomplete code)",
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "  error: expected item, found `}`\n  ..."
  }
}
```

### Command Exit Codes

| Exit Code | Meaning |
|-----------|---------|
| 0 | No errors (warnings are OK) |
| 1 | Clippy errors or formatting issues found |

### Build Artifact Isolation

Clippy generates build artifacts in `target/`. To avoid polluting your project:

```bash
# Plugin uses --target-dir flag
cargo clippy --target-dir=/tmp/claude-rust-lint-cache-<hash>
```

The cache directory is based on your project path hash, so multiple projects don't interfere with each other.

**Cleanup:** You can safely delete these directories:
```bash
rm -rf /tmp/claude-rust-lint-cache-*
```

## Testing

Run the test suite to verify the plugin works correctly:

```bash
cd plugins/rust-lint/tests
./run-tests.sh
```

**Test coverage:**
- Unit tests for common library functions
- Hook tests (clean files, formatting, errors, edge cases)
- Project script tests (markdown output, error detection)

## Contributing

Contributions are welcome! Please:

1. Test your changes: `./tests/run-tests.sh`
2. Ensure scripts pass shellcheck: `shellcheck scripts/*.sh hooks/*.sh`
3. Update README if adding features
4. Follow existing code style

## License

MIT License - see repository root for details.

## Author

Cheolwan Park ([@cheolwanpark](https://github.com/cheolwanpark))

## Links

- **Rust**: https://www.rust-lang.org/
- **rustfmt**: https://github.com/rust-lang/rustfmt
- **clippy**: https://github.com/rust-lang/rust-clippy
- **Claude Code**: https://docs.anthropic.com/claude-code
- **Repository**: https://github.com/cheolwanpark/useful-claude-plugins
