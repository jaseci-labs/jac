# Custom Configuration

Customize your Jac Client build process through the `jac.toml` configuration file.

## Overview

Jac Client uses `jac.toml` (the standard Jac project configuration) to customize the Vite build process, add plugins, and override build options. Client-specific configuration goes under `[plugins.client]`.

## Quick Start

### Configuration Location

Vite configuration is placed under `[plugins.client.vite]` in your `jac.toml`:

```toml
[project]
name = "my-app"
version = "1.0.0"
entry-point = "src/app.jac"

[plugins.client.vite]
plugins = []
lib_imports = []

[plugins.client.vite.build]
# Build options

[plugins.client.vite.server]
# Dev server options
```

### Basic Example: Adding Tailwind CSS

```toml
[plugins.client.vite]
plugins = ["tailwindcss()"]
lib_imports = ["import tailwindcss from '@tailwindcss/vite'"]
```

## Configuration Structure

### Client Plugin Sections

- **`[plugins.client.vite]`**: Vite-specific configuration (plugins, build options, server, resolve)
- **`[plugins.client.ts]`**: TypeScript compiler options for `tsconfig.json`
- **`[dependencies.npm]`**: npm runtime dependencies
- **`[dependencies.npm.dev]`**: npm dev dependencies

> **Note**: For package management, see [Package Management](./package-management.md).

### Vite Configuration Keys

#### `plugins` (Array of Strings)

Add Vite plugins by providing function calls as strings:

```toml
[plugins.client.vite]
plugins = [
    "tailwindcss()",
    "react()",
    "myPlugin({ option: 'value' })"
]
```

#### `lib_imports` (Array of Strings)

Import statements required for the plugins:

```toml
[plugins.client.vite]
lib_imports = [
    "import tailwindcss from '@tailwindcss/vite'",
    "import react from '@vitejs/plugin-react'",
    "import myPlugin from 'my-vite-plugin'"
]
```

#### `[plugins.client.vite.build]`

Override Vite build options:

```toml
[plugins.client.vite.build]
sourcemap = true
minify = "esbuild"

[plugins.client.vite.build.rollupOptions.output]
# Rollup output options
```

**Common Options**:

- `sourcemap`: Enable source maps (`true`, `false`, `"inline"`, `"hidden"`)
- `minify`: Minification method (`"esbuild"`, `"terser"`, `false`)
- `outDir`: Output directory

#### `[plugins.client.vite.server]`

Configure the Vite development server:

```toml
[plugins.client.vite.server]
port = 3000
open = true
host = "0.0.0.0"
cors = true
```

#### `[plugins.client.vite.resolve]`

Override module resolution options:

```toml
[plugins.client.vite.resolve.alias]
"@components" = "./src/components"
"@utils" = "./src/utils"

[plugins.client.vite.resolve]
dedupe = ["react", "react-dom"]
```

**Default aliases** (automatically included):

- `@jac-client/utils` → `compiled/client_runtime.js`
- `@jac-client/assets` → `compiled/assets`

### TypeScript Configuration

#### `[plugins.client.ts]`

Customize the generated `tsconfig.json` by overriding compiler options:

```toml
[plugins.client.ts.compilerOptions]
target = "ES2022"
strict = false
noUnusedLocals = false
noUnusedParameters = false

[plugins.client.ts]
include = ["components/**/*", "lib/**/*"]
exclude = ["node_modules", "dist", "tests"]
```

#### How TypeScript Configuration Works

1. **Default tsconfig.json** is generated with sensible defaults
2. **User overrides** from `[plugins.client.ts]` are merged in
3. **compilerOptions**: User values override defaults
4. **include/exclude**: User values replace defaults entirely (if provided)
5. **Custom tsconfig.json**: If you provide your own `tsconfig.json` file, it's used as-is

#### Default Compiler Options

The following defaults are used (can be overridden):

```json
{
  "target": "ES2020",
  "module": "ESNext",
  "jsx": "react-jsx",
  "strict": true,
  "moduleResolution": "bundler",
  "noUnusedLocals": true,
  "noUnusedParameters": true
}
```

#### Example: Relaxed TypeScript Settings

```toml
[plugins.client.ts.compilerOptions]
strict = false
noUnusedLocals = false
noUnusedParameters = false
```

#### Example: Custom Include Paths

```toml
[plugins.client.ts]
include = ["components/**/*", "lib/**/*", "types/**/*"]
```

### Response Configuration

#### Configure Custom Headers

Custom headers can be added by using an enviornmental variable and mentioning the custom headers.

```toml
[environments.response.headers]
"Cross-Origin-Opener-Policy" = "same-origin"
"Cross-Origin-Embedder-Policy" = "require-corp"
```

## How It Works

### Configuration Workflow

```
1. Developer edits jac.toml
   ↓
2. Build process loads jac.toml via JacClientConfig
   ↓
3. Config merged with defaults (deep merge)
   ↓
4. ViteBundler generates vite.config.js in .jac-client.configs/
   ↓
5. Vite uses generated config for bundling
   ↓
6. Generated config is gitignored (jac.toml is committed)
```

### Generated Config Location

The generated `vite.config.js` is created in `.jac-client.configs/vite.config.js`. This directory is gitignored - only `jac.toml` should be committed.

## Examples

### Example 1: Tailwind CSS

```toml
[plugins.client.vite]
plugins = ["tailwindcss()"]
lib_imports = ["import tailwindcss from '@tailwindcss/vite'"]

[dependencies.npm.dev]
"@tailwindcss/vite" = "^4.1.17"
tailwindcss = "^4.1.17"
```

### Example 2: Multiple Plugins

```toml
[plugins.client.vite]
plugins = [
    "react()",
    "tailwindcss()",
    "myCustomPlugin({ option: 'value' })"
]
lib_imports = [
    "import react from '@vitejs/plugin-react'",
    "import tailwindcss from '@tailwindcss/vite'",
    "import myCustomPlugin from 'my-vite-plugin'"
]
```

### Example 3: Custom Build Options

```toml
[plugins.client.vite.build]
sourcemap = true
minify = "esbuild"

[plugins.client.vite.build.rollupOptions.output.manualChunks]
react-vendor = ["react", "react-dom"]
router = ["react-router-dom"]
```

### Example 4: Development Server Configuration

```toml
[plugins.client.vite.server]
port = 3000
open = true
host = "0.0.0.0"
cors = true
```

### Example 5: Custom Path Aliases

```toml
[plugins.client.vite.resolve.alias]
"@components" = "./src/components"
"@utils" = "./src/utils"
"@styles" = "./src/styles"
```

## Best Practices

### 1. Only Override What You Need

The default configuration handles most use cases:

```toml
[plugins.client.vite]
plugins = ["tailwindcss()"]
lib_imports = ["import tailwindcss from '@tailwindcss/vite'"]
```

### 2. Keep Plugins and Imports in Sync

For each plugin, ensure there's a corresponding import:

```toml
[plugins.client.vite]
plugins = ["myPlugin()"]
lib_imports = ["import myPlugin from 'my-plugin'"]
```

### 3. Version Control

- **Commit**: `jac.toml` (your customizations)
- **Don't commit**: `.jac-client.configs/` (generated files)

### 4. Test After Changes

After modifying `jac.toml`, test your build:

```bash
jac serve src/app.jac
```

## Troubleshooting

### Config Not Applied

**Problem**: Changes aren't reflected in the build.

**Solution**:

- Ensure `jac.toml` is in the project root
- Check TOML syntax is valid
- The build process should automatically regenerate

### Plugin Not Working

**Problem**: Plugin is added but not working.

**Solution**:

- Verify the plugin is installed: `jac add --cl --dev <plugin-package>`
- Check that the import statement matches the plugin package name
- Check the generated `vite.config.js` in `.jac-client.configs/`

### TOML Syntax Errors

**Problem**: Invalid TOML syntax.

**Solution**:

- Use a TOML validator
- Strings with special chars need quotes: `"@types/react"`
- Arrays use `[ ]` notation

## Related Documentation

- [Package Management](./package-management.md) - Manage npm dependencies
- [Configuration Overview](./configuration-overview.md) - Complete configuration guide
- [Tailwind CSS](../styling/tailwind.md) - Tailwind CSS setup
- [Vite Documentation](https://vitejs.dev/config/) - Full Vite configuration reference
