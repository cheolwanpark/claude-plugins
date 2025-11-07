# TypeScript Lint Plugin

A Claude Code plugin for automatic TypeScript/JavaScript linting and formatting using ESLint and Prettier.

**⚠️ Important**: This plugin requires you to configure ESLint and Prettier in your project. It runs your linting tools, but doesn't provide them.

## Features

- **Automatic Formatting**: Files are automatically formatted with Prettier on save
- **Automatic Linting**: ESLint auto-fixes issues when possible
- **Smart Blocking**: Only blocks on actual errors, not warnings
- **TypeScript Support**: Full support for TypeScript
- **React/JSX Support**: Optional React support via eslint-plugin-react
- **Uses Your Configuration**: Respects your project's ESLint and Prettier configs
- **Project-Wide Linting**: Slash command for comprehensive project analysis

## Installation & Setup

### Step 1: Install Dependencies in Your Project

```bash
npm install --save-dev \
  eslint \
  prettier \
  @typescript-eslint/parser \
  @typescript-eslint/eslint-plugin \
  typescript \
  eslint-config-prettier
```

For React projects, also install:

```bash
npm install --save-dev eslint-plugin-react
```

### Step 2: Create ESLint Configuration

Copy the example config from the plugin to your project root:

```bash
# From the plugin directory
cp eslint.config.example.js /your-project-root/eslint.config.js
```

Or create your own `eslint.config.js` in your project root. The plugin provides a template at `eslint.config.example.js` with TypeScript + React support.

**Minimal ESLint config example:**

```javascript
// eslint.config.js
import typescriptEslint from '@typescript-eslint/eslint-plugin';
import typescriptParser from '@typescript-eslint/parser';

export default [
  {
    files: ['**/*.{js,ts,tsx}'],
    languageOptions: {
      parser: typescriptParser,
    },
    plugins: {
      '@typescript-eslint': typescriptEslint,
    },
    rules: {
      '@typescript-eslint/no-unused-vars': 'error',
    },
  },
];
```

### Step 3: Create Prettier Configuration (Optional)

Create `.prettierrc.js` in your project root:

```bash
# From the plugin directory
cp .prettierrc.example.js /your-project-root/.prettierrc.js
```

Or let Prettier use its defaults (recommended for most projects).

## Usage

### Automatic Linting (Hook)

The plugin automatically runs after every Edit or Write operation:

1. **Format**: Prettier formats the file
2. **Auto-fix**: ESLint fixes what it can automatically
3. **Report**: Only reports unfixable errors

The hook will:
- ✅ Allow with message if warnings are found
- 🚫 Block if errors are found (with detailed error messages)
- ✅ Allow silently if no issues found

### Project-Wide Linting (Slash Command)

Run comprehensive linting on your entire project:

```
/typescript-lint:lint-project
```

Or specify a directory:

```
/typescript-lint:lint-project src/
```

This will:
1. Format all files with Prettier
2. Run ESLint with auto-fix on all files
3. Generate a detailed markdown report with:
   - Summary of files checked
   - All errors found
   - Warnings found (first 10)

## Configuration

### Example Configurations Provided

The plugin includes example configurations you can copy to your project:

- **`eslint.config.example.js`**: TypeScript + React ESLint config
- **`.prettierrc.example.js`**: Standard Prettier settings

These are templates - copy them to your project and customize as needed.

### Configuration Precedence

The plugin uses **your project's configuration files**:

**ESLint** (searched in your project root):
- `eslint.config.js` (recommended - flat config)
- `.eslintrc.js`
- `.eslintrc.json`
- `.eslintrc.yml`
- `package.json` (eslintConfig field)

**Prettier** (searched in your project root):
- `.prettierrc`
- `.prettierrc.js`
- `.prettierrc.json`
- `prettier.config.js`
- `package.json` (prettier field)

If no config is found, ESLint will error and the plugin will provide helpful instructions.

## Supported File Types

- `.js` - JavaScript
- `.jsx` - JavaScript with JSX
- `.ts` - TypeScript
- `.tsx` - TypeScript with JSX
- `.mjs` - ES Module JavaScript
- `.cjs` - CommonJS JavaScript

## How It Works

### Hook Behavior

1. **File Validation**: Checks if file is a supported type
2. **Size Check**: Skips files larger than 1MB
3. **Dependency Check**: Verifies ESLint/Prettier are installed
4. **Format**: Runs `npx prettier --write FILE`
5. **Lint**: Runs `npx eslint --fix FILE`
6. **Report**: Only reports unfixable issues

### Project-Wide Behavior

1. Finds project root (looks for `package.json`, `tsconfig.json`, or `.git`)
2. Runs `npx prettier --write "**/*.{js,jsx,ts,tsx,mjs,cjs}"`
3. Runs `npx eslint --fix "**/*.{js,jsx,ts,tsx,mjs,cjs}"`
4. Generates markdown report with all remaining issues

## Troubleshooting

### "Missing dependencies" Error

**Problem**: Hook reports ESLint or Prettier not found

**Solution**:
1. Make sure you're in your project directory
2. Install dependencies: `npm install --save-dev eslint prettier`
3. Verify installation: `npx eslint --version` and `npx prettier --version`

### "ESLint config not found" Error

**Problem**: ESLint can't find a configuration file

**Solution**:
1. Copy the example config: `cp /path/to/plugin/eslint.config.example.js ./eslint.config.js`
2. Or create your own `eslint.config.js` in your project root
3. Make sure you installed the required packages (see Step 1)

### "Cannot find module '@typescript-eslint/parser'" Error

**Problem**: ESLint config references packages that aren't installed

**Solution**:
```bash
npm install --save-dev \
  @typescript-eslint/parser \
  @typescript-eslint/eslint-plugin
```

### Hook Not Running

1. Check file extension is supported (.js, .jsx, .ts, .tsx, .mjs, .cjs)
2. Check file size is under 1MB
3. Verify Node.js is installed: `node --version`

### Prettier/ESLint Conflicts

**Problem**: Prettier and ESLint disagree on formatting

**Solution**: Install `eslint-config-prettier` to disable ESLint formatting rules:

```bash
npm install --save-dev eslint-config-prettier
```

Then add to your `eslint.config.js`:

```javascript
import prettierConfig from 'eslint-config-prettier';

export default [
  // ... your other configs
  prettierConfig  // Must be last!
];
```

## Comparison with python-lint

| Feature | python-lint | typescript-lint |
|---------|-------------|-----------------|
| Language | Python | TypeScript/JavaScript |
| Linter | Ruff (single binary) | ESLint (requires packages) |
| Formatter | Ruff | Prettier |
| Setup | Minimal (Ruff auto-installs) | User configures |
| Config | Optional (plugin provides defaults) | **Required** (user must configure) |
| Implementation | Shell scripts | Shell scripts with npx |

## Architecture

The plugin is intentionally simple:

1. **Shell scripts only** - No Node.js wrappers
2. **Uses npx** - Finds tools in your project's node_modules
3. **Your config** - Plugin doesn't provide configs, only examples
4. **Minimal dependencies** - Plugin itself has no dependencies

This design means:
- ✅ No `require()` errors
- ✅ Works with any ESLint/Prettier version
- ✅ No plugin maintenance for config updates
- ✅ Full control over your linting setup
- ⚠️ Requires initial project setup

## FAQ

**Q: Why doesn't the plugin provide a default config?**

A: JavaScript tooling (ESLint, Prettier) requires installed packages. Unlike Python's Ruff (a single binary), ESLint configs can't use `require()` without those packages being installed. This plugin provides example configs you can copy and customize.

**Q: Can I use my existing ESLint/Prettier setup?**

A: Yes! The plugin uses whatever ESLint and Prettier configuration you have in your project.

**Q: Do I need both ESLint and Prettier?**

A: The plugin works best with both, but you can use either one. If only one is installed, the plugin will skip the missing tool and continue with the other.

**Q: What if I don't want React support?**

A: Simply don't install `eslint-plugin-react` and remove React-related config from your `eslint.config.js`.

## Contributing

Contributions are welcome! Please ensure:

1. Scripts remain dependency-free (no npm packages in plugin)
2. Error messages are helpful and actionable
3. Tests cover different project setups
4. README stays updated with setup instructions

## License

MIT
