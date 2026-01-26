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
entry-point = "main.jac"

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
- **`[plugins.client.configs]`**: Generic config file generation (postcss, tailwind, eslint, etc.)
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

- `@jac/runtime` → `compiled/client_runtime.js`
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

### Generic Config Files

#### `[plugins.client.configs]`

Generate JavaScript config files for npm packages directly from `jac.toml`. Each key under `[plugins.client.configs]` becomes a `<name>.config.js` file in `.jac/client/configs/`.

This is useful for tools that expect a `*.config.js` file, such as:

- PostCSS (`postcss.config.js`)
- Tailwind CSS v3 (`tailwind.config.js`)
- ESLint (`eslint.config.js`)
- Prettier (`prettier.config.js`)
- Any npm package using the `*.config.js` convention

#### Example: PostCSS + Tailwind v3

```toml
[plugins.client.configs.postcss]
plugins = ["tailwindcss", "autoprefixer"]

[plugins.client.configs.tailwind]
content = ["./**/*.jac", "./**/*.cl.jac", "./.jac/client/**/*.{js,jsx,ts,tsx}"]
plugins = []

[plugins.client.configs.tailwind.theme.extend.fontFamily]
sans = ["Inter", "system-ui", "-apple-system", "sans-serif"]

[plugins.client.configs.tailwind.theme.extend.colors]
primary = "#3490dc"
```

This generates:

**`.jac/client/configs/postcss.config.js`**:

```javascript
module.exports = {
  "plugins": ["tailwindcss", "autoprefixer"]
};
```

**`.jac/client/configs/tailwind.config.js`**:

```javascript
module.exports = {
  "content": ["./**/*.jac", "./**/*.cl.jac", "./.jac/client/**/*.{js,jsx,ts,tsx}"],
  "plugins": [],
  "theme": {
    "extend": {
      "fontFamily": {
        "sans": ["Inter", "system-ui", "-apple-system", "sans-serif"]
      },
      "colors": {
        "primary": "#3490dc"
      }
    }
  }
};
```

#### How It Works

1. TOML config under `[plugins.client.configs.<name>]` is parsed
2. The config data is converted to JSON format
3. A `<name>.config.js` file is generated with `module.exports = <json>`
4. Generated files are placed in `.jac/client/configs/`

#### When to Use

Use `[plugins.client.configs]` for:

- **PostCSS plugins** (Tailwind v3, autoprefixer, etc.)
- **Tailwind v3** configuration (for projects not using Tailwind v4's native Vite plugin)
- **Any npm tool** that uses `*.config.js` files

Use `[plugins.client.vite]` for:

- **Vite plugins** that integrate directly with the Vite build process
- **Tailwind v4** via `@tailwindcss/vite` plugin

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
4. ViteBundler generates vite.config.js in .jac/client/configs/
   ↓
5. Vite uses generated config for bundling
   ↓
6. Generated config is gitignored (jac.toml is committed)
```

### Generated Config Location

The generated `vite.config.js` is created in `.jac/client/configs/vite.config.js`. The `.jac/` directory is gitignored - only `jac.toml` should be committed.

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
- **Don't commit**: `.jac/` (all generated build artifacts)

### 4. Test After Changes

After modifying `jac.toml`, test your build:

```bash
jac start main.jac
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

- Verify the plugin is installed: `jac add --npm --dev <plugin-package>`
- Check that the import statement matches the plugin package name
- Check the generated `vite.config.js` in `.jac/client/configs/`

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
