# Package Management

Manage npm dependencies for your Jac Client projects through a centralized configuration system.

## Overview

Jac Client provides a unified package management system that:

- Manages dependencies through `config.json` (not `package.json`)
- Automatically generates `package.json` from your configuration
- Integrates seamlessly with the build system
- Supports both regular and scoped packages

## Quick Start

### Adding a Package

Add a package to your project:

```bash
jac add --cl lodash
```

Add a package with a specific version:

```bash
jac add --cl lodash@^4.17.21
```

Add a dev dependency:

```bash
jac add --cl -d @types/react
```

### Removing a Package

Remove a package from dependencies:

```bash
jac remove --cl lodash
```

Remove a package from devDependencies:

```bash
jac remove --cl -D @types/react
```

### Installing All Packages

Install all packages listed in `config.json`:

```bash
jac add --cl
```

> **Note**: When you run `jac add --cl` without specifying a package name, it installs all packages listed in the `dependencies` and `devDependencies` sections of your `config.json`. This is useful after manually editing `config.json` or when setting up a project on a new machine.

## How It Works

### Configuration-First Approach

Unlike traditional npm projects, Jac Client uses `config.json` as the source of truth for package management:

```
config.json (source of truth)
    ↓
PackageInstaller updates config.json
    ↓
ViteBundler generates package.json
    ↓
npm install installs packages
```

### Package Storage

Packages are stored in `config.json` under the `package` section. However, **default dependencies are automatically added during build time** and should not be included in `config.json`:

**Automatically Added (Don't include in config.json):**

- **Dependencies**: `react`, `react-dom`, `react-router-dom`
- **DevDependencies**: `vite`, `@babel/cli`, `@babel/core`, `@babel/preset-env`, `@babel/preset-react`
- **TypeScript packages** (if TypeScript is detected): `typescript`, `@types/react`, `@types/react-dom`, `@vitejs/plugin-react`

**Only include custom packages in config.json:**

```json
{
  "package": {
    "name": "my-app",
    "version": "1.0.0",
    "dependencies": {
      "lodash": "^4.17.21"
    },
    "devDependencies": {
      "sass": "^1.77.8"
    }
  }
}
```

> **Note**: React, React-DOM, React-Router-DOM, and all Babel packages are automatically added to the generated `package.json` during build time. You only need to add custom packages that aren't part of the defaults.

### Default Dependencies (Automatically Added)

The following dependencies are **automatically added during build time** and should **not** be included in `config.json`:

**Runtime Dependencies (always added):**

- `react` (^19.2.0)
- `react-dom` (^19.2.0)
- `react-router-dom` (^6.30.1)

**Development Dependencies (always added):**

- `vite` (^6.4.1)
- `@babel/cli` (^7.28.3)
- `@babel/core` (^7.28.5)
- `@babel/preset-env` (^7.28.5)
- `@babel/preset-react` (^7.28.5)

**TypeScript Dependencies (added if TypeScript is detected):**

- `typescript` (^5.3.3)
- `@types/react` (^18.2.45)
- `@types/react-dom` (^18.2.18)
- `@vitejs/plugin-react` (^4.2.1)

> **Important**: Only add custom packages to `config.json`. The build system automatically includes all default dependencies when generating `package.json`.

### Generated Files

The system automatically generates `package.json` in `.jac-client.configs/` directory:

- **Location**: `.jac-client.configs/package.json`
- **Purpose**: Used by npm for actual package installation
- **Git**: This directory is automatically gitignored
- **Source**: Generated from `config.json` during build/install

## CLI Commands

### `jac add --cl [package]`

Add a package to your project.

#### Basic Usage

```bash
# Add to dependencies (default)
jac add --cl lodash

# Add to devDependencies
jac add --cl -d @types/react

# Add with specific version
jac add --cl lodash@^4.17.21

# Install all packages from config.json
jac add --cl
```

#### Flags

- `--cl`: Required flag indicating client-side package management
- `-D`: Add to `devDependencies` instead of `dependencies`

#### Package Name Formats

**Regular packages:**

```bash
jac add --cl lodash              # Latest version
jac add --cl lodash@^4.17.21     # Specific version
jac add --cl react@18.0.0        # Exact version
```

**Scoped packages:**

```bash
jac add --cl @types/react                    # Latest version
jac add --cl @types/react@^18.0.0            # Specific version
jac add --cl @vitejs/plugin-react@^4.0.0    # Scoped with version
```

#### What Happens

**When adding a specific package** (`jac add --cl <package>`):

1. Package is added to `config.json` (dependencies or devDependencies)
2. `package.json` is regenerated from `config.json`
3. `npm install` is run to install the package
4. `package-lock.json` is created/updated

**When installing all packages** (`jac add --cl` without package name):

1. Reads all packages from `config.json` (both `dependencies` and `devDependencies`)
2. `package.json` is regenerated from `config.json`
3. `npm install` is run to install **all** configured packages
4. `package-lock.json` is created/updated with all packages

### `jac remove --cl <package>`

Remove a package from your project.

#### Basic Usage

```bash
# Remove from dependencies
jac remove --cl lodash

# Remove from devDependencies
jac remove --cl -D @types/react
```

#### Flags

- `--cl`: Required flag indicating client-side package management
- `-D`: Remove from `devDependencies` instead of `dependencies`

#### What Happens

1. Package is removed from `config.json`
2. `package.json` is regenerated from `config.json`
3. `npm install` is run to update `node_modules`
4. Package is removed from `node_modules`

## Manual Configuration

You can also manually edit `config.json` to manage packages:

```json
{
  "package": {
    "dependencies": {
      "lodash": "^4.17.21",
      "react": "^18.0.0"
    },
    "devDependencies": {
      "@types/react": "^18.0.0",
      "vite": "^5.0.0"
    }
  }
}
```

After manual edits, run:

```bash
jac add --cl
```

This will **install all packages** listed in both `dependencies` and `devDependencies` sections of your `config.json`. The command:

1. Regenerates `package.json` from `config.json`
2. Runs `npm install` to install all configured packages
3. Updates `package-lock.json` accordingly

## Package Version Management

### Version Formats

The system supports all npm version formats:

```json
{
  "package": {
    "dependencies": {
      "exact": "1.2.3",              // Exact version
      "caret": "^1.2.3",             // Compatible version (^)
      "tilde": "~1.2.3",             // Approximate version (~)
      "range": ">=1.2.3 <2.0.0",     // Version range
      "latest": "latest",            // Latest version
      "tag": "beta"                  // Version tag
    }
  }
}
```

### Default Version

If no version is specified, the package is added with `"latest"`:

```bash
jac add --cl lodash
# Adds: "lodash": "latest"
```

## Scoped Packages

Scoped packages (packages starting with `@`) are fully supported:

```bash
# Add scoped package
jac add --cl @types/react

# Add scoped package with version
jac add --cl @types/react@^18.0.0

# Remove scoped package
jac remove --cl @types/react
```

The system correctly parses scoped packages by finding the version separator (`@`) after the scope name.

## Integration with Build System

### Automatic Regeneration

The build system automatically regenerates `package.json` from `config.json`:

1. **During `jac add --cl <package>`**: Regenerates before running npm install for the specific package
2. **During `jac add --cl`** (no package): Regenerates and installs **all packages** from `config.json`
3. **During `jac remove --cl`**: Regenerates before running npm install
4. **During `jac serve`**: Regenerates if config.json changed
5. **During `jac build`**: Regenerates before building

### Package.json Location

Generated `package.json` is stored in `.jac-client.configs/`:

```
project-root/
├── config.json              # Your source of truth (committed)
├── .jac-client.configs/     # Generated files (gitignored)
│   ├── package.json         # Generated from config.json
│   ├── package-lock.json    # Generated by npm
│   └── vite.config.js      # Generated Vite config
└── node_modules/            # Installed packages
```

## Best Practices

### 1. Use CLI Commands

Prefer CLI commands over manual editing:

```bash
# Good: Use CLI
jac add --cl lodash

# Less ideal: Manual edit (requires running jac add --cl after)
```

### 2. Commit config.json, Not package.json

- **Commit**: `config.json` (your source of truth)
- **Don't commit**: `.jac-client.configs/package.json` (generated)

The `.gitignore` automatically excludes generated files.

### 3. Version Pinning for Production

For production apps, pin exact versions or use caret ranges:

```json
{
  "package": {
    "dependencies": {
      "react": "^18.2.0",      // Caret for minor updates
      "lodash": "4.17.21"      // Exact for stability
    }
  }
}
```

### 4. Keep Dependencies Organized

Separate runtime dependencies from dev dependencies (only custom packages):

```json
{
  "package": {
    "dependencies": {
      "lodash": "^4.17.21"
    },
    "devDependencies": {
      "@types/lodash": "^4.17.21",
      "sass": "^1.77.8"
    }
  }
}
```

> **Note**: React, Babel, and Vite packages are automatically added during build time and don't need to be in `config.json`.

### 5. Regular Updates

Keep packages updated:

```bash
# Check for outdated packages
npm outdated

# Update versions in config.json, then install all packages
jac add --cl
```

> **Note**: `jac add --cl` (without a package name) installs all packages from `config.json`, making it perfect for syncing dependencies after manual edits or when setting up on a new machine.

## Troubleshooting

### Package Not Found

**Problem**: Error when adding a package.

**Solution**:

- Verify package name is correct
- Check npm registry is accessible
- Ensure you have internet connection

### Version Conflicts

**Problem**: Package version conflicts during installation.

**Solution**:

- Check `package.json` in `.jac-client.configs/` for conflicts
- Update conflicting packages to compatible versions
- Use `npm ls` to see dependency tree

### Config Not Applied

**Problem**: Changes to `config.json` not reflected.

**Solution**:

- Run `jac add --cl` to regenerate and install
- Check JSON syntax is valid
- Verify package names are correct

### npm Command Not Found

**Problem**: `npm command not found` error.

**Solution**:

- Ensure Node.js and npm are installed
- Verify npm is in your PATH
- Check Node.js version: `node --version`

### Scoped Package Issues

**Problem**: Scoped package not parsed correctly.

**Solution**:

- Use the CLI command (handles scoping automatically)
- For manual edits, ensure format: `"@scope/package": "version"`

## Examples

### Example 1: TypeScript Support

TypeScript dependencies are automatically added when TypeScript is detected (via `tsconfig.json` or TypeScript packages in config). You don't need to manually add React or TypeScript types - they're included automatically.

If you need additional TypeScript-related packages:

```bash
# Add additional TypeScript tooling (if needed)
jac add --cl -d @types/lodash
```

Result in `config.json`:

```json
{
  "package": {
    "dependencies": {},
    "devDependencies": {
      "@types/lodash": "latest"
    }
  }
}
```

> **Note**: React, React-DOM, React-Router-DOM, and TypeScript packages (`typescript`, `@types/react`, `@types/react-dom`, `@vitejs/plugin-react`) are automatically added during build time when TypeScript is detected.

### Example 2: Adding Tailwind CSS

```bash
# Add Tailwind
jac add --cl -d @tailwindcss/vite
jac add --cl -d tailwindcss
```

Then update `config.json`:

```json
{
  "vite": {
    "plugins": ["tailwindcss()"],
    "lib_imports": ["import tailwindcss from '@tailwindcss/vite'"]
  },
  "package": {
    "devDependencies": {
      "@tailwindcss/vite": "latest",
      "tailwindcss": "latest"
    }
  }
}
```

### Example 3: Complete Setup

```bash
# Create project
jac create_jac_app my-app
cd my-app

# Add custom dependencies (React/Babel are added automatically)
jac add --cl lodash@^4.17.21

# Add custom dev dependencies
jac add --cl -d @types/lodash
jac add --cl -d sass
```

> **Note**: React, React-DOM, React-Router-DOM, Vite, and Babel packages are automatically added during build time. You only need to add custom packages like `lodash`, `sass`, `tailwindcss`, etc.

## Related Documentation

- [Configuration System Overview](./configuration-overview.md) - Complete guide to the configuration system
- [Custom Configuration](./custom-config.md) - Configure Vite build settings
- [Working with TypeScript](../working-with-ts.md) - TypeScript setup
