# Configuration System Overview

A comprehensive guide to Jac Client's centralized configuration and package management system.

## Introduction

Jac Client uses a **configuration-first approach** where all project settings, dependencies, and build configurations are managed through a single `config.json` file. This provides:

- **Single source of truth**: All configuration in one place
- **Version control friendly**: Only `config.json` needs to be committed
- **Automatic generation**: Build files are generated from configuration
- **Type safety**: Structured JSON with validation

## Architecture

### Configuration Flow

```
┌─────────────────┐
│  config.json    │  ← Source of truth (committed to git)
│  (project root) │
└────────┬────────┘
         │
         │ Loaded by JacClientConfig
         │
         ▼
┌─────────────────┐
│  Merged Config  │  ← Defaults + User config (deep merge)
└────────┬────────┘
         │
         ├─────────────────┬─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│ ViteBundler  │  │PackageInstaller│  │  Other      │
│              │  │              │  │  Components  │
└──────┬───────┘  └──────┬───────┘  └──────┬───────┘
       │                  │                  │
       ▼                  ▼                  ▼
┌──────────────┐  ┌──────────────┐  ┌──────────────┐
│vite.config.js│  │package.json  │  │  Other       │
│(generated)   │  │(generated)   │  │  Generated   │
└──────────────┘  └──────────────┘  └──────────────┘
```

### Key Components

1. **JacClientConfig** (`config_loader.jac`)
   - Loads and validates `config.json`
   - Merges user config with defaults
   - Provides typed access to configuration sections

2. **PackageInstaller** (`package_installer.jac`)
   - Manages npm dependencies in `config.json`
   - Generates `package.json` from config
   - Runs npm install/uninstall

3. **ViteBundler** (`vite_bundler.jac`)
   - Generates `vite.config.js` from config
   - Handles build and bundling

## Configuration File Structure

### Complete config.json Structure

```json
{
  "vite": {
    "plugins": [],
    "lib_imports": [],
    "build": {},
    "server": {},
    "resolve": {}
  },
  "ts": {},
  "package": {
    "name": "my-app",
    "version": "1.0.0",
    "description": "My Jac application",
    "dependencies": {},
    "devDependencies": {}
  }
}
```

### Section Overview

| Section | Purpose | Documentation |
|---------|---------|--------------|
| `vite` | Vite build configuration (plugins, build options, server, resolve) | [Custom Configuration](./custom-config.md) |
| `ts` | TypeScript configuration (reserved for future use) | [Custom Configuration](./custom-config.md) |
| `package` | npm package management (dependencies, devDependencies) | [Package Management](./package-management.md) |

## Configuration Loading

### Default Configuration

The system starts with sensible defaults. **Important**: Default npm packages are automatically added during build time and should not be included in `config.json`:

**Automatically Added Packages:**

- **Dependencies**: `react`, `react-dom`, `react-router-dom`
- **DevDependencies**: `vite`, `@babel/cli`, `@babel/core`, `@babel/preset-env`, `@babel/preset-react`
- **TypeScript** (if detected): `typescript`, `@types/react`, `@types/react-dom`, `@vitejs/plugin-react`

**Default Config Structure:**

```json
{
  "vite": {
    "plugins": [],
    "lib_imports": [],
    "build": {},
    "server": {},
    "resolve": {
      "alias": {
        "@jac-client/utils": "compiled/client_runtime.js",
        "@jac-client/assets": "compiled/assets"
      },
      "extensions": [".mjs", ".js", ".mts", ".ts", ".jsx", ".tsx", ".json"]
    }
  },
  "ts": {},
  "package": {
    "name": "",
    "version": "1.0.0",
    "description": "",
    "dependencies": {},
    "devDependencies": {}
  }
}
```

> **Note**: The `package` section in `config.json` should only contain **custom packages** that aren't part of the defaults. React, Babel, and Vite packages are automatically added when `package.json` is generated.

### Deep Merge Strategy

User configuration is merged with defaults using deep merge:

- **Top-level keys**: User config overrides defaults
- **Nested objects**: Deep merged (user values override defaults)
- **Arrays**: User arrays replace defaults (no merging)
- **Missing keys**: Defaults are used

**Example**:

```json
// Default
{
  "vite": {
    "build": { "sourcemap": false, "minify": "esbuild" },
    "server": { "port": 5173 }
  }
}

// User config
{
  "vite": {
    "build": { "sourcemap": true }
  }
}

// Result (merged)
{
  "vite": {
    "build": { "sourcemap": true, "minify": "esbuild" },
    "server": { "port": 5173 }
  }
}
```

## Package Management

### Configuration-First Package Management

Unlike traditional npm projects, packages are managed through `config.json`. However, **default dependencies (React, Babel, Vite) are automatically added during build time** and should not be included:

```json
{
  "package": {
    "dependencies": {
      "lodash": "^4.17.21"
    },
    "devDependencies": {
      "sass": "^1.77.8"
    }
  }
}
```

> **Important**: React, React-DOM, React-Router-DOM, Vite, and all Babel packages are automatically added to the generated `package.json` during build time. Only include custom packages in `config.json`.

### Package Lifecycle

1. **Add Package**: `jac add --cl <package>`
   - Updates `config.json`
   - Regenerates `package.json`
   - Runs `npm install` for the specific package

2. **Install All Packages**: `jac add --cl` (no package name)
   - Reads all packages from `config.json`
   - Regenerates `package.json`
   - Runs `npm install` to install all configured packages

3. **Remove Package**: `jac remove --cl <package>`
   - Removes from `config.json`
   - Regenerates `package.json`
   - Runs `npm install`

4. **Build/Serve**: Automatically regenerates `package.json` if needed

### Generated Files

- **`.jac-client.configs/package.json`**: Generated from `config.json`
- **`.jac-client.configs/package-lock.json`**: Generated by npm
- **`node_modules/`**: Installed packages

> **Important**: Only `config.json` should be committed to version control. Generated files are automatically gitignored.

## Build Configuration

### Vite Configuration

Vite settings are configured through the `vite` section:

```json
{
  "vite": {
    "plugins": ["tailwindcss()"],
    "lib_imports": ["import tailwindcss from '@tailwindcss/vite'"],
    "build": {
      "sourcemap": true,
      "minify": "esbuild"
    },
    "server": {
      "port": 3000,
      "open": true
    },
    "resolve": {
      "alias": {
        "@components": "./src/components"
      }
    }
  }
}
```

### Generated vite.config.js

The system generates `vite.config.js` in `.jac-client.configs/`:

```javascript
import tailwindcss from '@tailwindcss/vite'

export default {
  plugins: [tailwindcss()],
  build: {
    sourcemap: true,
    minify: 'esbuild'
  },
  server: {
    port: 3000,
    open: true
  },
  resolve: {
    alias: {
      '@components': path.resolve(__dirname, '../src/components'),
      '@jac-client/utils': path.resolve(__dirname, '../compiled/client_runtime.js'),
      '@jac-client/assets': path.resolve(__dirname, '../compiled/assets')
    }
  }
}
```

## CLI Commands

### Configuration Commands

| Command | Purpose |
|---------|---------|
| `jac create_jac_app <name>` | Create new project (automatically creates `config.json`) |
| `jac generate_client_config` | Create default `config.json` (legacy projects only) |
| `jac add --cl <package>` | Add npm package |
| `jac remove --cl <package>` | Remove npm package |
| `jac add --cl` | Install all packages from config.json |

### Command Workflow

```bash
# 1. Create project
jac create_jac_app my-app
cd my-app

# 2. Config.json is automatically created with jac create_jac_app
# (For legacy projects, run: jac generate_client_config)

# 3. Add custom packages (React/Babel are added automatically)
jac add --cl lodash
jac add --cl -d sass

# 4. Customize build (edit config.json)
# Add plugins, build options, etc.

# 5. Build/serve
jac serve app.jac
```

## File Organization

### Project Structure

```
project-root/
├── config.json                    # ← Source of truth (committed)
├── app.jac                        # Your Jac application
├── components/                    # TypeScript components (optional)
├── assets/                        # Static assets
├── compiled/                      # Compiled output
│   ├── client_runtime.js
│   └── assets/
├── .jac-client.configs/          # Generated files (gitignored)
│   ├── package.json              # Generated from config.json
│   ├── package-lock.json         # Generated by npm
│   └── vite.config.js            # Generated from config.json
└── node_modules/                  # Installed packages
```

### Version Control

**Commit**:

- `config.json` - Your configuration
- `app.jac` - Your application code
- `components/` - Your components
- `assets/` - Your assets

**Don't Commit** (automatically gitignored):

- `.jac-client.configs/` - Generated files
- `node_modules/` - Dependencies
- `compiled/` - Build output

## Best Practices

### 1. Use CLI for Package Management

```bash
# Good: Use CLI
jac add --cl lodash

# Less ideal: Manual edit
# (requires running jac add --cl after)
```

### 2. Minimal Configuration

Only specify what you need to override:

```json
{
  "vite": {
    "plugins": ["tailwindcss()"],
    "lib_imports": ["import tailwindcss from '@tailwindcss/vite'"]
  }
}
```

### 3. Keep Config Organized

Group related settings:

```json
{
  "vite": {
    "plugins": [...],
    "build": {...},
    "server": {...}
  },
  "package": {
    "dependencies": {...},
    "devDependencies": {...}
  }
}
```

### 4. Version Pinning

Pin versions for production:

```json
{
  "package": {
    "dependencies": {
      "react": "^18.2.0",      // Caret for minor updates
      "lodash": "4.17.21"      // Exact for critical packages
    }
  }
}
```

### 5. Regular Updates

Keep packages updated:

```bash
# Check outdated packages
npm outdated

# Update in config.json, then reinstall
jac add --cl
```

## Troubleshooting

### Config Not Loading

**Problem**: Configuration not being applied.

**Solutions**:

- Verify `config.json` is in project root
- Check JSON syntax is valid
- Ensure file encoding is UTF-8
- Check file permissions

### Package Installation Fails

**Problem**: `npm install` fails.

**Solutions**:

- Verify Node.js and npm are installed
- Check internet connection
- Clear npm cache: `npm cache clean --force`
- Check package names are correct

### Generated Files Out of Sync

**Problem**: Generated files don't match config.json.

**Solutions**:

- Run `jac add --cl` to regenerate
- Delete `.jac-client.configs/` and rebuild
- Check config.json syntax

### Merge Conflicts

**Problem**: Configuration merge produces unexpected results.

**Solutions**:

- Understand deep merge behavior (arrays replace, objects merge)
- Check default configuration
- Verify JSON structure

## Advanced Topics

### Programmatic Access

Access configuration programmatically:

```python
from jac_client.plugin.src.config_loader import JacClientConfig
from pathlib import Path

config_loader = JacClientConfig(Path('.'))
config = config_loader.load()

vite_config = config_loader.get_vite_config()
package_config = config_loader.get_package_config()
```

### Custom Build Scripts

Add custom npm scripts to `package` section:

```json
{
  "package": {
    "scripts": {
      "custom": "echo 'Custom script'"
    }
  }
}
```

### Environment-Specific Configs

While JSON doesn't support conditionals, you can:

1. Use build scripts to process config
2. Maintain separate config files
3. Use environment variables in build scripts

## Related Documentation

- [Custom Configuration](./custom-config.md) - Detailed Vite configuration guide
- [Package Management](./package-management.md) - Complete package management guide
- [Architecture Overview](../../../architecture.md) - System architecture details
