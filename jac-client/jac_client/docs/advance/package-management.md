# Package Management

Manage npm dependencies for your Jac Client projects through the unified `jac.toml` configuration.

## Overview

Jac Client integrates with the core Jac package management system:

- Manages dependencies through `jac.toml` (the standard Jac project config)
- Uses `[dependencies.npm]` and `[dependencies.npm.dev]` sections
- Automatically generates `package.json` from your configuration
- Integrates seamlessly with the build system

## Quick Start

### Adding a Package

Add a package to your project:

```bash
jac add --npm lodash
```

Add a package with a specific version:

```bash
jac add --npm lodash@^4.17.21
```

Add a dev dependency:

```bash
jac add --npm --dev @types/react
```

### Removing a Package

Remove a package from dependencies:

```bash
jac remove --npm lodash
```

Remove a package from devDependencies:

```bash
jac remove --npm --dev @types/react
```

### Installing All Packages

Install all packages listed in `jac.toml`:

```bash
jac add --npm
```

> **Note**: When you run `jac add --npm` without specifying a package name, it installs all packages listed in the `[dependencies.npm]` and `[dependencies.npm.dev]` sections of your `jac.toml`.

## Configuration in jac.toml

### Basic Structure

npm dependencies are configured in your `jac.toml` file:

```toml
[project]
name = "my-app"
version = "1.0.0"
description = "My Jac application"
entry-point = "main.jac"

[dependencies.npm]
lodash = "^4.17.21"
axios = "^1.6.0"

[dependencies.npm.dev]
sass = "^1.77.8"
"@types/lodash" = "^4.17.0"
```

### Package Storage

- **Runtime dependencies**: `[dependencies.npm]` section
- **Dev dependencies**: `[dependencies.npm.dev]` section

### Example jac.toml

```toml
[project]
name = "my-app"
version = "1.0.0"
description = "My Jac application"
entry-point = "main.jac"

# Vite configuration (optional)
[plugins.client.vite]
plugins = ["tailwindcss()"]
lib_imports = ["import tailwindcss from '@tailwindcss/vite'"]

[plugins.client.vite.build]
sourcemap = true

[plugins.client.vite.server]
port = 3000

# npm dependencies
[dependencies.npm]
lodash = "^4.17.21"

[dependencies.npm.dev]
"@tailwindcss/vite" = "latest"
tailwindcss = "latest"
```

## How It Works

### Configuration Flow

```
jac.toml (source of truth)
    ↓
JacClientConfig reads from jac.toml
    ↓
ViteBundler generates package.json
    ↓
npm install installs packages
```

### Generated Files

The system automatically generates `package.json` in `.jac/client/configs/` directory:

- **Location**: `.jac/client/configs/package.json`
- **Purpose**: Used by npm for actual package installation
- **Git**: The `.jac/` directory is automatically gitignored
- **Source**: Generated from `jac.toml` during build/install

## CLI Commands

### `jac add --npm [package]`

Add a package to your project.

#### Basic Usage

```bash
# Add to dependencies (default)
jac add --npm lodash

# Add to devDependencies
jac add --npm --dev @types/react

# Add with specific version
jac add --npm lodash@^4.17.21

# Install all packages from jac.toml
jac add --npm
```

#### Flags

- `--npm`: Required flag indicating client-side (npm) package
- `--dev` or `-d`: Add to dev dependencies

#### Package Name Formats

**Regular packages:**

```bash
jac add --npm lodash              # Latest version
jac add --npm lodash@^4.17.21     # Specific version
jac add --npm react@18.0.0        # Exact version
```

**Scoped packages:**

```bash
jac add --npm @types/react                    # Latest version
jac add --npm @types/react@^18.0.0            # Specific version
jac add --npm @vitejs/plugin-react@^4.0.0    # Scoped with version
```

#### What Happens

**When adding a specific package** (`jac add --npm <package>`):

1. Package is added to `jac.toml` (`[dependencies.npm]` or `[dependencies.npm.dev]`)
2. `jac.toml` is saved
3. `package.json` is regenerated from `jac.toml`
4. `npm install` is run to install the package

**When installing all packages** (`jac add --npm` without package name):

1. Reads all packages from `jac.toml`
2. `package.json` is regenerated
3. `npm install` is run to install all packages

### `jac remove --npm <package>`

Remove a package from your project.

#### Basic Usage

```bash
# Remove from dependencies
jac remove --npm lodash

# Remove from devDependencies
jac remove --npm --dev @types/react
```

#### What Happens

1. Package is removed from `jac.toml`
2. `package.json` is regenerated
3. `npm install` is run to update `node_modules`

## Package Version Management

### Version Formats

The system supports all npm version formats:

```toml
[dependencies.npm]
exact = "1.2.3"              # Exact version
caret = "^1.2.3"             # Compatible version (^)
tilde = "~1.2.3"             # Approximate version (~)
range = ">=1.2.3 <2.0.0"     # Version range
latest = "latest"            # Latest version
```

### Default Version

If no version is specified, the package is added with `"latest"`:

```bash
jac add --npm lodash
# Adds: lodash = "latest" to [dependencies.npm]
```

## Integration with Build System

### Automatic Regeneration

The build system automatically regenerates `package.json` from `jac.toml`:

1. **During `jac add --npm <package>`**: Regenerates and installs the specific package
2. **During `jac add --npm`** (no package): Regenerates and installs all packages
3. **During `jac remove --npm`**: Regenerates after removal
4. **During `jac start`**: Regenerates if jac.toml changed
5. **During `jac build`**: Regenerates before building

### Package.json Location

Generated `package.json` is stored in `.jac/client/configs/`:

```
project-root/
├── jac.toml                 # Your source of truth (committed)
├── main.jac                 # Your Jac application
├── .jac/                    # Build artifacts (gitignored)
│   └── client/
│       └── configs/
│           ├── package.json     # Generated from jac.toml
│           ├── package-lock.json  # Generated by npm
│           └── vite.config.js   # Generated Vite config
└── node_modules/            # Installed packages
```

## Best Practices

### 1. Use CLI Commands

Prefer CLI commands over manual editing:

```bash
# Good: Use CLI
jac add --npm lodash

# Less ideal: Manual edit (but works)
# Edit jac.toml, then run: jac add --npm
```

### 2. Commit jac.toml, Not package.json

- **Commit**: `jac.toml` (your source of truth)
- **Don't commit**: `.jac/` directory (all build artifacts are generated)

### 3. Version Pinning for Production

For production apps, pin versions:

```toml
[dependencies.npm]
lodash = "4.17.21"      # Exact for stability

[dependencies.npm.dev]
sass = "^1.77.8"        # Caret for dev tools
```

### 4. Keep Dependencies Organized

Only include custom packages (defaults are auto-added):

```toml
[dependencies.npm]
lodash = "^4.17.21"

[dependencies.npm.dev]
"@types/lodash" = "^4.17.21"
sass = "^1.77.8"
```

## Troubleshooting

### Package Not Found

**Problem**: Error when adding a package.

**Solution**:

- Verify package name is correct
- Check npm registry is accessible
- Ensure you have internet connection

### npm Command Not Found

**Problem**: `npm command not found` error.

**Solution**:

- Ensure Node.js and npm are installed
- Verify npm is in your PATH
- Check Node.js version: `node --version`

### Config Not Applied

**Problem**: Changes to `jac.toml` not reflected.

**Solution**:

- Run `jac add --npm` to regenerate and install
- Check TOML syntax is valid
- Verify package names are correct

## Examples

### Example 1: Adding Tailwind CSS

```bash
# Add Tailwind packages
jac add --npm --dev @tailwindcss/vite
jac add --npm --dev tailwindcss
```

Then update `jac.toml` for Vite plugin:

```toml
[plugins.client.vite]
plugins = ["tailwindcss()"]
lib_imports = ["import tailwindcss from '@tailwindcss/vite'"]
```

### Example 2: Complete Setup

```bash
# Create project
jac create --use client my-app
cd my-app

# Add custom dependencies
jac add --npm lodash@^4.17.21
jac add --npm --dev @types/lodash
jac add --npm --dev sass

# Build/serve
jac start main.jac
```

## Related Documentation

- [Configuration System Overview](./configuration-overview.md) - Complete guide to the configuration system
- [Custom Configuration](./custom-config.md) - Configure Vite build settings
- [Working with TypeScript](../working-with-ts.md) - TypeScript setup
