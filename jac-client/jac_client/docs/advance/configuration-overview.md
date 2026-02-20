# Configuration System Overview

A comprehensive guide to Jac Client's configuration and package management system.

## Introduction

Jac Client uses `jac.toml` (the standard Jac project configuration file) for all settings. This provides:

- **Single source of truth**: All configuration in one place
- **Unified with core Jac**: Same config file for all Jac features
- **Version control friendly**: Only `jac.toml` needs to be committed
- **Automatic generation**: Build files are generated from configuration

## Architecture

### Configuration Flow

```
┌─────────────────┐
│   jac.toml      │  ← Source of truth (committed to git)
│  (project root) │
└────────┬────────┘
         │
         │ Loaded by JacClientConfig (wraps core JacConfig)
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
│ ViteBundler  │  │ npm install  │  │  Other       │
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

1. **JacConfig** (core `jaclang.project.config`)
   - Core configuration class for all Jac projects
   - Manages `jac.toml` loading and saving
   - Handles `[dependencies.npm]` sections

2. **JacClientConfig** (`config_loader.jac`)
   - Wraps core JacConfig for client-specific access
   - Reads from `[plugins.client]` for vite/ts config
   - Reads from `[dependencies.npm]` for packages

3. **ViteBundler** (`vite_bundler.jac`)
   - Generates `vite.config.js` from config
   - Generates `package.json` from npm dependencies
   - Handles build and bundling

## Configuration File Structure

### Complete jac.toml Structure

```toml
[project]
name = "my-app"
version = "1.0.0"
description = "My Jac application"
entry-point = "main.jac"

# Vite configuration
[plugins.client.vite]
plugins = []
lib_imports = []

[plugins.client.vite.build]
sourcemap = false
minify = "esbuild"

[plugins.client.vite.server]
port = 5173

[plugins.client.vite.resolve]
# Custom resolve options

# Debug mode (enabled by default)
[plugins.client]
debug = true  # Set to false to disable raw error output

# TypeScript configuration (optional)
[plugins.client.ts.compilerOptions]
strict = true
target = "ES2020"

# npm dependencies
[dependencies.npm]
lodash = "^4.17.21"

[dependencies.npm.dev]
sass = "^1.77.8"
```

### Section Overview

| Section | Purpose | Documentation |
|---------|---------|--------------|
| `[project]` | Project metadata | Core Jac config |
| `[serve]` | Server and routing configuration | See below |
| `[plugins.client]` | Client plugin settings (debug mode) | See below |
| `[plugins.client.vite]` | Vite build configuration | [Custom Configuration](./custom-config.md) |
| `[plugins.client.ts]` | tsconfig.json customization | [Custom Configuration](./custom-config.md) |
| `[dependencies.npm]` | npm runtime dependencies | [Package Management](./package-management.md) |
| `[dependencies.npm.dev]` | npm dev dependencies | [Package Management](./package-management.md) |

### Server Configuration (`[serve]`)

The `[serve]` section configures how `jac start` handles routing for client-side applications:

```toml
[serve]
cl_route_prefix = "cl"      # URL prefix for client apps (default: "cl")
base_route_app = "app"      # Client app to serve at root "/" (default: none)
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `cl_route_prefix` | string | `"cl"` | The URL path prefix for client-side apps. Apps are served at `/<prefix>/<app_name>`. |
| `base_route_app` | string | `""` | Name of a client app to serve at the root `/` path. When set, visiting `/` renders this app instead of the API info page. |

**Example: Custom route prefix**

```toml
[serve]
cl_route_prefix = "pages"
```

With this config, client apps are accessed at `/pages/MyApp` instead of `/cl/MyApp`.

**Example: Serve app at root**

```toml
[serve]
base_route_app = "app"
```

With this config, visiting `/` renders the `app` client function directly, making it the default landing page.

### Debug Mode (`[plugins.client]`)

The `[plugins.client]` section configures debug settings for the client plugin:

```toml
[plugins.client]
debug = true      # Enable/disable debug mode (default: true)
```

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `debug` | bool | `true` | When enabled, raw error output is displayed for easier debugging. Set to `false` for cleaner production error messages. |

Debug mode can also be controlled via environment variable:

- `JAC_DEBUG=1` or `JAC_DEBUG=true` enables debug mode regardless of config

## Configuration Loading

### Default Configuration

The system starts with sensible defaults.

**Default Vite Config Structure:**

```toml
[plugins.client.vite]
plugins = []
lib_imports = []

[plugins.client.vite.build]
# Default build options

[plugins.client.vite.server]
# Default server options

[plugins.client.vite.resolve.alias]
"@jac/runtime" = "compiled/client_runtime.js"
"@jac-client/assets" = "compiled/assets"
```

### Deep Merge Strategy

User configuration is merged with defaults using deep merge:

- **Top-level keys**: User config overrides defaults
- **Nested objects**: Deep merged (user values override defaults)
- **Arrays**: User arrays replace defaults (no merging)
- **Missing keys**: Defaults are used

## Package Management

### Configuration-First Package Management

Packages are managed through `jac.toml`:

```toml
[dependencies.npm]
lodash = "^4.17.21"

[dependencies.npm.dev]
sass = "^1.77.8"
```

### Package Lifecycle

1. **Add Package**: `jac add --npm <package>`
   - Updates `jac.toml`
   - Regenerates `package.json`
   - Runs `npm install`

2. **Install All Packages**: `jac add --npm` (no package name)
   - Reads all packages from `jac.toml`
   - Regenerates `package.json`
   - Runs `npm install`

3. **Remove Package**: `jac remove --npm <package>`
   - Removes from `jac.toml`
   - Regenerates `package.json`
   - Runs `npm install`

### Generated Files

- **`.jac/client/configs/package.json`**: Generated from `jac.toml`
- **`.jac/client/configs/package-lock.json`**: Generated by npm
- **`node_modules/`**: Installed packages

> **Important**: Only `jac.toml` should be committed to version control.

## Build Configuration

### Vite Configuration

Vite settings are configured through the `[plugins.client.vite]` section:

```toml
[plugins.client.vite]
plugins = ["tailwindcss()"]
lib_imports = ["import tailwindcss from '@tailwindcss/vite'"]

[plugins.client.vite.build]
sourcemap = true
minify = "esbuild"

[plugins.client.vite.server]
port = 3000
open = true

[plugins.client.vite.resolve.alias]
"@components" = "./src/components"
```

### Generated vite.config.js

The system generates `vite.config.js` in `.jac/client/configs/`:

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
      '@jac/runtime': path.resolve(__dirname, '../compiled/client_runtime.js')
    }
  }
}
```

## CLI Commands

### Configuration Commands

| Command | Purpose |
|---------|---------|
| `jac create --use client <name>` | Create new client project with `jac.toml` |
| `jac add --npm <package>` | Add npm package |
| `jac remove --npm <package>` | Remove npm package |
| `jac add --npm` | Install all packages from jac.toml |

### Command Workflow

```bash
# 1. Create project
jac create --use client my-app
cd my-app

# 2. jac.toml is automatically created with organized folder structure

# 3. Add custom packages
jac add --npm lodash
jac add --npm --dev sass

# 4. Customize build (edit jac.toml)

# 5. Build/serve
jac start main.jac
```

## File Organization

### Project Structure

```
project-root/
├── jac.toml                   # ← Source of truth (committed)
├── main.jac                   # Your Jac application
├── components/                # TypeScript components (optional)
├── assets/                    # Static assets
├── compiled/                  # Compiled output
│   ├── client_runtime.js
│   └── assets/
├── .jac/                      # Build artifacts (gitignored)
│   └── client/
│       ├── configs/           # Generated config files
│       │   ├── package.json   # Generated from jac.toml
│       │   ├── package-lock.json  # Generated by npm
│       │   └── vite.config.js # Generated from jac.toml
│       ├── build/             # Vite build output
│       └── compiled/          # Compiled JS
└── node_modules/              # Installed packages
```

### Version Control

**Commit**:

- `jac.toml` - Your configuration
- `main.jac` - Your application code
- `components/` - Your components
- `assets/` - Your assets

**Don't Commit** (automatically gitignored):

- `.jac/` - All build artifacts (cache, packages, client, data)
- `node_modules/` - Dependencies
- `compiled/` - Build output

## Best Practices

### 1. Use CLI for Package Management

```bash
# Good: Use CLI
jac add --npm lodash

# Less ideal: Manual edit
# (requires running jac add --npm after)
```

### 2. Minimal Configuration

Only specify what you need to override:

```toml
[plugins.client.vite]
plugins = ["tailwindcss()"]
lib_imports = ["import tailwindcss from '@tailwindcss/vite'"]
```

### 3. Keep Config Organized

Group related settings:

```toml
[plugins.client.vite]
plugins = [...]

[plugins.client.vite.build]
sourcemap = true

[dependencies.npm]
lodash = "^4.17.21"
```

### 4. Version Pinning

Pin versions for production:

```toml
[dependencies.npm]
lodash = "4.17.21"      # Exact for critical packages
axios = "^1.6.0"        # Caret for minor updates
```

## Troubleshooting

### Config Not Loading

**Problem**: Configuration not being applied.

**Solutions**:

- Verify `jac.toml` is in project root
- Check TOML syntax is valid
- Ensure file encoding is UTF-8

### Package Installation Fails

**Problem**: `npm install` fails.

**Solutions**:

- Verify Node.js and npm are installed
- Check internet connection
- Clear npm cache: `npm cache clean --force`
- Check package names are correct

### Generated Files Out of Sync

**Problem**: Generated files don't match jac.toml.

**Solutions**:

- Run `jac add --npm` to regenerate
- Delete `.jac/client/` and rebuild
- Check jac.toml syntax

## Related Documentation

- [Custom Configuration](./custom-config.md) - Detailed Vite configuration guide
- [Package Management](./package-management.md) - Complete package management guide
