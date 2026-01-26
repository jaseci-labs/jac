# Jac Client Architecture Overview

## Vite-Enhanced Client Bundle System

The `jac-client` package uses a **Vite-based bundling system** to transform Jac code into optimized JavaScript bundles for web front-ends.

### Core Components

#### `ViteClientBundleBuilder`

Extends the base `ClientBundleBuilder` to provide Vite integration. Key responsibilities:

1. **Compilation Pipeline**
   - Compiles `.jac` files to JavaScript
   - Copies local `.js` files to temp directory
   - Preserves bare module specifiers (e.g., `"antd"`, `"react"`) for Vite to resolve

2. **Dependency Processing** (`_compile_dependencies_recursively`)
   - Recursively traverses import graphs
   - Processes both `.jac` and `.js` imports
   - Accumulates exports and globals across all modules
   - Writes compiled artifacts to `compiled/` directory
   - **Preserves nested folder structure** (see Nested Folder Handling below)

3. **Import Handling** (`_process_imports`)
   - **`.jac` imports**: Compiled and inlined
   - **`.js` imports**: Copied and inlined
   - **Bare specifiers**: Left as ES imports for Vite to bundle

4. **Bundle Generation** (`_bundle_with_vite`)
   - Creates React entry point (`main.js`) with:

     ```javascript
     import React from "react";
     import { createRoot } from "react-dom/client";
     import { app as App } from "./app.js";
     ```

   - Copies assets (`_copy_asset_files`)
   - Runs `bun run build` to bundle with Vite
   - Generates hashed bundle file (`client.[hash].js`)
   - Vite extracts CSS to `dist/main.css`
   - Returns bundle code and SHA256 hash

### Build Flow

![Build Pipeline](jac_client/docs/assets/pipe_line-v2.svg)

```
1. Module compilation
   ├── Compile root .jac file → JS
   ├── Extract exports & globals from manifest
   └── Generate client_runtime.js from client_runtime.cl.jac

2. Recursive dependency resolution
   ├── Traverse all .jac/.js imports
   ├── Compile/copy each to compiled/ directory (preserving folder structure)
   ├── Accumulate exports & globals
   └── Skip bare specifiers (handled by Vite)

3. Asset copying
   ├── Copy CSS and other assets to compiled/
   └── Ensures Vite can resolve CSS imports during bundling

4. Vite bundling
   ├── Write entry point (_entry.js)
   ├── Run bun run build (Vite handles JSX/TSX transpilation natively)
   ├── Process CSS imports and extract to dist/main.css
   ├── Locate generated bundle in dist/
   └── Return code + hash

5. Cleanup
   └── Remove compiled/ directory
```

### Nested Folder Handling

The compilation system preserves the folder structure of source files when writing to the `compiled/` directory, similar to TypeScript transpilation. This ensures that relative imports work correctly and prevents file name conflicts.

#### How It Works

1. **Source Root Detection**: The root module's parent directory is identified as the `source_root`
2. **Relative Path Calculation**: For each dependency file, the relative path from `source_root` is calculated
3. **Structure Preservation**: Files are written to `compiled/` maintaining the same relative folder structure

#### Example

Given the following source structure:

```
nested-basic/
├── src/
│   ├── app.jac                (root module)
│   ├── buttonroot.jac
│   └── components/
│       └── button.jac
└── jac.toml                   (entry-point = "src/app.jac")
```

The compiled output in `compiled/` will be:

```
compiled/
├── app.js                     (from src/app.jac)
├── buttonroot.js              (from src/buttonroot.jac)
└── components/
    └── button.js              (from src/components/button.jac)
```

**Note**: The `src/` directory is the `source_root`, so files are compiled to `compiled/` maintaining relative structure but without the `src/` prefix.

#### Benefits

- **Relative imports work correctly**: `import { CustomButton } from "./components/button.js"` resolves properly
- **No file name conflicts**: Files with the same name in different folders don't overwrite each other
- **Familiar structure**: Developers can organize code in nested folders just like in TypeScript/JavaScript projects
- **Consistent with modern tooling**: Matches the behavior of TypeScript, Babel, and other transpilers

#### Implementation Details

The `_compile_dependencies_recursively` method:

- Tracks `source_root` as the parent directory of the root module
- Calculates `relative_path = file_path.relative_to(source_root)` for each file
- Creates parent directories as needed with `mkdir(parents=True, exist_ok=True)`
- Handles edge cases where files might be outside `source_root` by falling back to filename-only

This ensures that the folder structure is preserved for:

- `.jac` files (compiled to `.js`)
- `.js` files (copied as-is)
- Other asset files (CSS, images, etc.)

### CSS Serving

CSS files are handled through a multi-stage process that ensures styles are properly bundled and served:

#### 1. CSS Import in Jac Code

CSS files are imported in Jac code using the `cl import` syntax:

```jac
cl import ".styles.css";
```

This gets compiled to JavaScript:

```javascript
import "./styles.css";
```

#### 2. Asset Copying

CSS and other asset files are copied to the `compiled/` directory:

- **Why**: Vite needs access to CSS files during bundling
- **When**: Before `bun run build`
- **What**: Copies `.css`, `.scss`, `.sass`, `.less`, and image files
- **Location**: Source CSS files → `compiled/` directory

#### 3. Vite CSS Processing

Vite processes CSS imports during bundling:

- Extracts CSS from JavaScript imports
- Bundles and minifies CSS
- Outputs to `dist/main.css` (default filename)
- Preserves CSS import statements in the bundle

#### 4. HTML Template Generation

The `JacClientModuleIntrospector.render_page()` method:

- Detects CSS files in the `dist/` directory
- Generates a hash from the CSS file content for cache busting
- Includes a `<link>` tag in the HTML `<head>`:

  ```html
  <link rel="stylesheet" href="/static/main.css?hash=abc123..."/>
  ```

#### 5. Server-Side CSS Serving

The `JacAPIServer` handles CSS file requests:

- **Route**: `/static/*.css` (e.g., `/static/main.css`)
- **Handler**: Reads CSS file from build output directory
- **Response**: Serves with `text/css` content type
- **Locations checked** (in order):
  1. `{base_path}/.jac/client/dist/{filename}.css` (primary)
  2. `{base_path}/dist/{filename}.css` (fallback)
  3. `{base_path}/assets/{filename}.css` (static assets)

**Implementation** (`server.impl.jac`):

```jac
# CSS files from .jac/client/dist/ (primary) or dist/ (fallback)
if path.endswith('.css') {
    # Check .jac/client/dist/ first
    if client_build_dist_file.exists() {
        css_content = client_build_dist_file.read_text(encoding='utf-8');
        Jac.send_css(self, css_content);
        return;
    } elif dist_file.exists() {
        # Fallback to dist/ location
        css_content = dist_file.read_text(encoding='utf-8');
        Jac.send_css(self, css_content);
        return;
    }
}
```

#### CSS File Flow

```
app.jac (cl import ".styles.css")
  ↓
compiled/app.js (import "./styles.css")
  ↓
_copy_asset_files: styles.css → compiled/styles.css
  ↓
Vite: Processes CSS import, extracts to .jac/client/dist/main.css
  ↓
HTML: <link href="/static/main.css?hash=..."/>
  ↓
Server: Serves from .jac/client/dist/main.css (or dist/main.css for fallback)
```

### Key Design Decisions

- **No inlining of external packages**: Bare imports like `"antd"` remain as imports for Vite's tree-shaking and code-splitting
- **Export collection**: All client exports are aggregated across the dependency tree
- **React-based**: Entry point uses React 18's `createRoot` API
- **Hash-based caching**: Bundle hash enables browser cache invalidation
- **Temp directory isolation**: Builds in `vite_package_json.parent/compiled/` to avoid conflicts
- **Folder structure preservation**: Nested folder structures are preserved in `compiled/` directory, similar to TypeScript transpilation, ensuring relative imports work correctly
- **CSS asset handling**: CSS files are copied after Babel compilation to ensure Vite can resolve imports, then extracted to separate files for optimal loading

### Package Management System

The Jac Client uses a **configuration-driven package management system** that abstracts npm package management into `config.json`, automatically generating `package.json` during the build process.

#### Package Configuration in config.json

The `package` section in `config.json` contains only the essential package metadata that developers need to manage:

```json
{
  "package": {
    "name": "my-app",
    "version": "1.0.0",
    "description": "My Jac application",
    "dependencies": {},
    "devDependencies": {}
  }
}
```

**Key Design Principles:**

- **Minimal Configuration**: Only `name`, `version`, `description`, `dependencies`, and `devDependencies` are stored in `config.json`
- **Build-Time Generation**: All other `package.json` fields (scripts, babel config, `type: 'module'`, etc.) are automatically generated during build
- **Default Dependencies**: Core dependencies (React, Vite) are automatically included and merged with user-defined dependencies

#### Package.json Generation

The `package.json` file is dynamically generated from `jac.toml` by `ViteBundler.create_package_json()`:

1. **Location**: Generated in `.jac/client/configs/package.json` (primary location)
2. **Temporary Root Copy**: Also copied to `.jac/client/` temporarily for bun commands
3. **Auto-Generated Fields**:
   - `type: 'module'` (always included)
   - `scripts` (build, dev, preview)
   - Default dependencies (React, Vite)
   - Default devDependencies (Vite plugins, TypeScript types if needed)

4. **Merged Fields**:
   - User-defined `dependencies` merged with defaults
   - User-defined `devDependencies` merged with defaults
   - User-defined `scripts` merged with defaults

#### Package Installation Workflow

The `jac add --npm` command manages packages through `jac.toml`:

```
1. Developer runs: jac add --npm lodash
   ↓
2. PackageInstaller updates jac.toml (adds lodash to dependencies.npm)
   ↓
3. ViteBundler.create_package_json() generates package.json from jac.toml
   ↓
4. package.json copied to .jac/client/ (bun requires it there)
   ↓
5. bun install runs (installs all packages from package.json)
   ↓
6. bun.lockb moved to .jac/client/configs/
   ↓
7. Temporary package.json removed (keeps only .jac/client/configs/package.json)
```

#### File Lifecycle

**During Build/Install:**

- `.jac/client/configs/package.json` - Generated from `jac.toml` (source of truth)
- `.jac/client/package.json` - Temporary copy for bun commands
- `.jac/client/bun.lockb` - Generated by bun, then moved to `.jac/client/configs/`

**After Build/Install:**

- `.jac/client/configs/package.json` - Persisted (generated file)
- `.jac/client/configs/bun.lockb` - Persisted (lock file)
- `.jac/client/package.json` - Removed (not needed after bun install)
- `jac.toml` (root) - Source configuration (committed to git)

#### CLI Commands

**Add Package:**

```bash
jac add --npm lodash              # Add to dependencies
jac add --npm -d @types/react     # Add to devDependencies
jac add --npm lodash@^4.17.21     # Add with specific version
```

**Install All Packages:**

```bash
jac add --npm                     # Install all packages from jac.toml (uses bun)
```

**Remove Package:**

```bash
jac remove --npm lodash            # Remove from dependencies
jac remove --npm -d @types/react   # Remove from devDependencies
```

**Project Creation:**

```bash
jac create --use client my-app            # Creates jac.toml with organized folder structure
```

#### Benefits

- **Clean Project Root**: No `package.json` clutter in project root
- **Version Control Friendly**: Only `jac.toml` needs to be committed
- **Simplified Configuration**: Developers only manage essential package info
- **Automatic Defaults**: Build tools and scripts are automatically configured
- **Bun Compatibility**: Temporary `package.json` in `.jac/client/` ensures bun commands work correctly

### Configuration System

The Jac Client uses a **JSON-based configuration system** that allows developers to customize the build process through a simple `config.json` file in the project root.

#### Configuration File Structure

The `config.json` file uses a hierarchical structure with predefined keys for different configuration types:

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

#### Configuration Processing

1. **Config Loading** (`JacClientConfig`)
   - Loads `config.json` from project root
   - Merges user config with defaults using deep merge
   - Creates default config file if it doesn't exist
   - Validates JSON structure

2. **Config Generation** (`ViteBundler.create_vite_config`)
   - Reads configuration from `jac.toml`
   - Generates `vite.config.js` in `.jac/client/configs/` directory
   - Injects user customizations into the generated config
   - Automatically includes base plugins and required aliases

3. **Build Execution**
   - Uses generated `vite.config.js` for Vite bundling
   - Config is regenerated on each build to reflect latest changes

#### Configuration Keys

##### `package.*`

Package configuration for dependencies. See [Package Management Architecture](./package_management.md) for detailed documentation.

**Fields**:

- `package.name`: Project name (auto-populated from project filename)
- `package.version`: Project version (default: "1.0.0")
- `package.description`: Project description
- `package.dependencies`: Runtime packages
- `package.devDependencies`: Development packages

**Example**:

```json
{
  "package": {
    "name": "my-app",
    "version": "1.0.0",
    "description": "My Jac application",
    "dependencies": {
      "lodash": "^4.17.21"
    },
    "devDependencies": {
      "@types/react": "^18.2.45"
    }
  }
}
```

**Note**: Other `package.json` fields (scripts, type) are automatically generated during build.

##### `vite.plugins`

Array of plugin function calls to add to Vite config:

```json
{
  "vite": {
    "plugins": ["tailwindcss()"]
  }
}
```

##### `vite.lib_imports`

Array of import statements for plugins and libraries:

```json
{
  "vite": {
    "lib_imports": ["import tailwindcss from '@tailwindcss/vite'"]
  }
}
```

##### `vite.build`

Object with build options that override defaults:

```json
{
  "vite": {
    "build": {
      "sourcemap": true,
      "minify": "esbuild"
    }
  }
}
```

##### `vite.server`

Object with dev server options:

```json
{
  "vite": {
    "server": {
      "port": 3000,
      "open": true
    }
  }
}
```

##### `vite.resolve`

Object with resolve options (merged with base aliases):

```json
{
  "vite": {
    "resolve": {
      "dedupe": ["react", "react-dom"]
    }
  }
}
```

#### Base Configuration

The system automatically includes essential configuration:

- **Base plugins**: React plugin (if TypeScript is detected)
- **Required aliases**:
  - `@jac/runtime` → `compiled/client_runtime.js`
  - `@jac-client/assets` → `compiled/assets`
- **Build settings**: Entry point, output directory, file naming
- **Extensions**: JavaScript and TypeScript file extensions

#### Generated Vite Config

The generated `vite.config.js` in `.jac/client/configs/` includes:

```javascript
export default defineConfig({
  plugins: [
    react(),           // Base plugin (if TS)
    tailwindcss()      // User plugins from config.json
  ],
  root: projectRoot,
  build: {
    rollupOptions: {
      input: path.resolve(projectRoot, "build/main.js"),
      output: {
        entryFileNames: "client.[hash].js",
        assetFileNames: "[name].[ext]",
      },
    },
    outDir: path.resolve(projectRoot, "dist"),
    emptyOutDir: true,
    // User build overrides from config.json
  },
  resolve: {
    alias: {
      "@jac/runtime": path.resolve(projectRoot, "compiled/client_runtime.js"),
      "@jac-client/assets": path.resolve(projectRoot, "compiled/assets"),
    },
    extensions: [".mjs", ".js", ".mts", ".ts", ".jsx", ".tsx", ".json"],
    // User resolve overrides from config.json
  },
});
```

#### Configuration Workflow

```
1. Developer edits config.json in project root
   ↓
2. Build process loads config.json via JacClientConfig
   ↓
3. Config merged with defaults (deep merge)
   ↓
4. ViteBundler generates:
   ├── vite.config.js in .jac/client/configs/
   └── package.json in .jac/client/configs/ (from jac.toml)
   ↓
5. package.json copied to .jac/client/ (temporary, for bun commands)
   ↓
6. Vite uses generated configs for bundling
   ↓
7. Generated configs are gitignored (jac.toml is committed)
```

**Package Management Workflow**:

```
1. Developer runs: jac add --npm lodash
   ↓
2. PackageInstaller updates jac.toml (dependencies.npm)
   ↓
3. ViteBundler generates package.json from jac.toml
   ↓
4. bun install runs (installs packages)
   ↓
5. bun.lockb moved to .jac/client/configs/
   ↓
6. Temporary package.json removed (keeps only .jac/client/configs/)
```

**Remove Workflow**:

```
1. Developer runs: jac remove --npm lodash
   ↓
2. PackageInstaller removes package from jac.toml
   ↓
3. ViteBundler regenerates package.json from updated jac.toml
   ↓
4. bun install runs (removes package from node_modules)
   ↓
5. bun.lockb moved to .jac/client/configs/
   ↓
6. Temporary package.json removed (keeps only .jac/client/configs/)
```

#### Benefits

- **Simple**: JSON format is easy to edit and understand
- **Standardized**: Predefined keys prevent configuration errors
- **Extensible**: Easy to add new config types (e.g., `ts`)
- **Maintainable**: Defaults are always preserved
- **Version controlled**: `jac.toml` can be committed to git
- **Auto-generated**: `vite.config.js` is generated automatically

### Configuration Parameters

- `vite_package_json`: Path to package.json (must exist)
- `runtime_path`: Path to client runtime file
- `vite_output_dir`: Build output (defaults to `compiled/dist/assets`)
- `vite_minify`: Enable/disable minification

### HTML Meta Data Configuration

The Jac Client provides a comprehensive **HTML meta data configuration system** that allows developers to customize SEO, social media, and browser metadata for their client applications through `jac.toml`.

#### Meta Data Configuration in jac.toml

Meta data is configured in the `[plugin.client.app_meta_data]` section of `jac.toml`:

```toml
[plugin.client.app_meta_data]
charset = "UTF-8"
title = "My Awesome App"
viewport = "width=device-width, initial-scale=1"
description = "A powerful application built with Jac"
robots = "index, follow"
canonical = "https://example.com/app"

# OpenGraph metadata for social media
og_type = "website"
og_title = "My Awesome App"
og_description = "A powerful application built with Jac"
og_url = "https://example.com/app"
og_image = "https://example.com/og-image.png"

# Browser/PWA metadata
theme_color = "#4a90e2"
icon = "/assets/favicon.ico"
```

#### Meta Data Processing Flow

The meta data system follows a structured processing pipeline:

```
1. Load configuration from jac.toml
   ↓
2. Extract [plugin.client.app_meta_data] section
   ↓
3. Merge with default values (see meta_defaults)
   ↓
4. Apply HEAD_SCHEMA to structure tags
   ↓
5. Generate HTML head content with build_head()
   ↓
6. Inject into page template with CSS links
   ↓
7. Serve rendered HTML with proper meta tags
```
