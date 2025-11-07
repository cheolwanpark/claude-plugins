# TypeScript Lint Plugin

Automatically format and lint TypeScript/JavaScript files using Prettier and ESLint after every edit.

## Features

- **Auto-format on save**: Prettier formats your code automatically
- **Auto-fix lint issues**: ESLint fixes problems when possible
- **Smart error handling**: Blocks on errors, allows with warnings
- **Project-wide linting**: Slash command to lint entire codebase
- **TypeScript + React**: Full support for TS, JS, JSX, TSX files
- **Uses your config**: Respects your existing ESLint and Prettier settings

## Quick Start

### 1. Install Dependencies

In your project directory:

```bash
npm install --save-dev eslint prettier @typescript-eslint/parser @typescript-eslint/eslint-plugin
```

For React projects, also add:

```bash
npm install --save-dev eslint-plugin-react
```

### 2. Create ESLint Config

Create `eslint.config.js` in your project root:

**Basic TypeScript config:**
```javascript
import typescriptEslint from '@typescript-eslint/eslint-plugin';
import typescriptParser from '@typescript-eslint/parser';

export default [
  {
    files: ['**/*.{js,jsx,ts,tsx}'],
    languageOptions: {
      parser: typescriptParser,
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module',
      },
    },
    plugins: {
      '@typescript-eslint': typescriptEslint,
    },
    rules: {
      '@typescript-eslint/no-unused-vars': 'error',
      '@typescript-eslint/no-explicit-any': 'warn',
    },
  },
];
```

**With React support:**
```javascript
import typescriptEslint from '@typescript-eslint/eslint-plugin';
import typescriptParser from '@typescript-eslint/parser';
import react from 'eslint-plugin-react';

export default [
  {
    files: ['**/*.{js,jsx,ts,tsx}'],
    languageOptions: {
      parser: typescriptParser,
      parserOptions: {
        ecmaVersion: 'latest',
        sourceType: 'module',
        ecmaFeatures: {
          jsx: true,
        },
      },
    },
    plugins: {
      '@typescript-eslint': typescriptEslint,
      react,
    },
    rules: {
      '@typescript-eslint/no-unused-vars': 'error',
      'react/jsx-uses-react': 'error',
      'react/jsx-uses-vars': 'error',
    },
    settings: {
      react: {
        version: 'detect',
      },
    },
  },
];
```

### 3. Create Prettier Config (Optional)

Create `.prettierrc` in your project root:

```json
{
  "semi": true,
  "singleQuote": true,
  "tabWidth": 2,
  "trailingComma": "es5"
}
```

Or use Prettier's defaults by not creating a config file.

### 4. Prevent ESLint/Prettier Conflicts

Install the compatibility config:

```bash
npm install --save-dev eslint-config-prettier
```

Add to your `eslint.config.js`:

```javascript
import prettierConfig from 'eslint-config-prettier';

export default [
  // ... your other configs
  prettierConfig, // Must be last!
];
```

## How It Works

### Automatic Linting (Hook)

After every `Edit` or `Write` operation, the plugin:

1. **Validates file**: Checks extension and size (max 1MB)
2. **Finds project root**: Looks for `package.json`, `tsconfig.json`, or `.git`
3. **Formats**: Runs `npx prettier --write <file>`
4. **Lints**: Runs `npx eslint --fix <file>`
5. **Reports issues**:
   - ✅ Silently allows if no issues
   - ⚠️ Allows with message if warnings found
   - 🚫 Blocks if errors found

**Supported file types**: `.js`, `.jsx`, `.ts`, `.tsx`, `.mjs`, `.cjs`, `.mts`, `.cts`

**Hook behavior**:
- Files > 1MB are skipped (performance)
- Missing dependencies cause graceful skip with message
- Configuration errors are reported but don't block

### Project-Wide Linting (Slash Command)

Lint your entire codebase:

```
/typescript-lint:lint-project
```

Or specify a directory:

```
/typescript-lint:lint-project src/
```

This command:
1. Finds project root
2. Formats all supported files with Prettier
3. Runs ESLint with auto-fix on all files
4. Generates a markdown report with:
   - Error count and details (up to 20 shown)
   - Warning count and details (up to 10 shown)
   - File statistics

## Configuration

### Config File Discovery

The plugin uses `npx`, which runs ESLint and Prettier from your project's `node_modules`. These tools automatically search for configuration files:

**ESLint** searches upward from the file for:
- `eslint.config.js` (flat config, recommended)
- `.eslintrc.js`
- `.eslintrc.json`
- `.eslintrc.yml`
- `package.json` with `eslintConfig` field

**Prettier** searches upward for:
- `.prettierrc`
- `.prettierrc.js`
- `.prettierrc.json`
- `prettier.config.js`
- `package.json` with `prettier` field

### Project Root Detection

The plugin determines your project root by searching upward from the edited file for:
1. `package.json`
2. `tsconfig.json`
3. `.git` directory

Commands run from the project root, ensuring config files are found correctly.

## Troubleshooting

### "Missing required tools: npx"

**Problem**: Node.js is not installed.

**Solution**: Install Node.js from https://nodejs.org/

```bash
# Verify installation
node --version
npx --version
```

### "Missing required tools: jq"

**Problem**: jq JSON processor is not installed.

**Solution**:
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Verify
jq --version
```

### "Missing dependencies: prettier eslint"

**Problem**: ESLint or Prettier not installed in your project.

**Solution**:
```bash
cd /path/to/your/project
npm install --save-dev eslint prettier
```

### "ESLint config error"

**Problem**: ESLint can't find a configuration file.

**Solution**: Create `eslint.config.js` in your project root (see Quick Start section above).

### "Prettier formatting failed"

**Causes**:
- Syntax errors in the file
- Unsupported file type
- Conflicting Prettier plugins

**Solution**: Check the error message for details. Common fixes:
```bash
# Test Prettier manually
npx prettier --write yourfile.ts

# Check for syntax errors
npx prettier --check yourfile.ts
```

### Hook Not Running

**Check**:
1. File extension is supported (`.js`, `.jsx`, `.ts`, `.tsx`, `.mjs`, `.cjs`, `.mts`, `.cts`)
2. File is under 1MB
3. You're in a project with `package.json` or `tsconfig.json`

### ESLint and Prettier Disagree on Formatting

**Problem**: ESLint reports formatting errors that Prettier doesn't fix.

**Solution**: Install `eslint-config-prettier` to disable ESLint's formatting rules:

```bash
npm install --save-dev eslint-config-prettier
```

Import it in your `eslint.config.js` (must be last):

```javascript
import prettierConfig from 'eslint-config-prettier';

export default [
  // ... other configs
  prettierConfig,
];
```

### Warnings vs Errors

**ESLint severity levels:**
- **Warnings** (severity 1): Hook allows the operation, shows warning message
- **Errors** (severity 2): Hook blocks the operation, requires manual fixes

**To change rule severity** in your `eslint.config.js`:
```javascript
rules: {
  '@typescript-eslint/no-unused-vars': 'warn',  // Allow with warning
  '@typescript-eslint/no-explicit-any': 'error', // Block
  'no-console': 'off',                            // Ignore
}
```

## Technical Details

### Architecture

- **Implementation**: Pure bash scripts, no Node.js wrapper
- **Tool execution**: Uses `npx` to run project-local ESLint/Prettier
- **JSON handling**: Uses `jq` for parsing and generating hook responses
- **Config management**: No default config provided, uses your project's setup
- **Hook timeout**: 30 seconds (defined in `hooks.json`)

### Why No Default Config?

Unlike the `python-lint` plugin (which bundles Ruff), JavaScript tooling requires installed npm packages. ESLint configs can't `import` packages that aren't in your `node_modules`. This plugin provides **examples** you can copy, but you must configure ESLint/Prettier yourself.

**Advantages of this approach:**
- ✅ Works with any ESLint/Prettier version
- ✅ No `require()` errors from missing packages
- ✅ Full control over your linting rules
- ✅ Plugin doesn't need updates when ESLint changes

**Trade-off:**
- ⚠️ Requires initial project setup

### Exit Codes

**ESLint exit codes:**
- `0` - No problems found
- `1` - Warnings or errors found (JSON still valid)
- `2` - Fatal error (config missing, parse error, etc.)

The hook handles all three cases and provides appropriate feedback.

### Hook JSON Response Format

The hook outputs JSON to communicate with Claude Code:

```json
{
  "decision": "allow|block",
  "reason": "Human-readable message",
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "Detailed error messages"
  }
}
```

- **allow**: Operation proceeds, Claude sees the reason
- **block**: Operation is prevented, Claude must fix issues

## Comparison with python-lint

| Feature | python-lint | typescript-lint |
|---------|-------------|-----------------|
| **Linter** | Ruff (single binary) | ESLint (npm package) |
| **Formatter** | Ruff | Prettier |
| **Setup** | Minimal (Ruff auto-installs) | Manual (user installs deps) |
| **Config** | Optional (plugin provides default) | Required (user must create) |
| **Type checking** | Pyright included | Not included |
| **Speed** | Very fast (Rust) | Moderate (Node.js) |

## FAQ

**Q: Do I need both ESLint and Prettier?**

A: The plugin checks for both but will work with only one installed. However, for best results, use both:
- Prettier handles formatting (spaces, commas, line breaks)
- ESLint handles code quality (unused vars, best practices)

**Q: Can I use my existing ESLint config?**

A: Yes! The plugin uses whatever config is in your project. It doesn't override or provide defaults.

**Q: What about monorepos?**

A: The plugin finds the nearest `package.json` upward from the edited file. If you have multiple `package.json` files, it uses the closest one.

**Q: Why does the hook skip large files?**

A: Files over 1MB are skipped to prevent timeouts. The 30-second hook timeout could be exceeded on very large files. You can still lint them with the project-wide command.

**Q: Can I disable the hook for certain files?**

A: Use ESLint's `ignorePatterns` or `.eslintignore` file:

```javascript
// eslint.config.js
export default [
  {
    ignores: ['dist/**', 'build/**', '**/*.min.js'],
  },
  // ... rest of config
];
```

## License

MIT
