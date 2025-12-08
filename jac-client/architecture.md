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
   - Runs `npm run compile` then copies assets (`_copy_asset_files`)
   - Runs `npm run build` to bundle with Vite
   - Generates hashed bundle file (`client.[hash].js`)
   - Vite extracts CSS to `dist/main.css`
   - Returns bundle code and SHA256 hash

### Build Flow

![Build Pipeline](jac_client/docs/assets/pipe_line-v2.svg)


```
1. Module compilation
   ├── Compile root .jac file → JS
   ├── Extract exports & globals from manifest
   └── Generate client_runtime.js from client_runtime.jac

2. Recursive dependency resolution
   ├── Traverse all .jac/.js imports
   ├── Compile/copy each to compiled/ directory (preserving folder structure)
   ├── Accumulate exports & globals
   └── Skip bare specifiers (handled by Vite)

3. Babel compilation
   ├── Run npm run compile
   ├── Transpile JavaScript from compiled/ to build/
   └── Preserves CSS import statements

4. Asset copying
   ├── Copy CSS and other assets from compiled/ to build/
   └── Ensures Vite can resolve CSS imports during bundling

5. Vite bundling
   ├── Write entry point (main.js)
   ├── Run npm run build
   ├── Process CSS imports and extract to dist/main.css
   ├── Locate generated bundle in dist/
   └── Return code + hash

6. Cleanup
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
├── app.jac                    (root module)
├── buttonroot.jac
└── components/
    └── button.jac
```

The compiled output in `compiled/` will be:
```
compiled/
├── app.js                     (from app.jac)
├── buttonroot.js              (from buttonroot.jac)
└── components/
    └── button.js              (from components/button.jac)
```

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

#### 2. Asset Copying (`_copy_asset_files`)
After Babel compilation, CSS and other asset files are copied from `compiled/` to `build/`:
- **Why**: Babel only transpiles JavaScript, so CSS files need manual copying
- **When**: After `npm run compile`, before `npm run build`
- **What**: Copies `.css`, `.scss`, `.sass`, `.less`, and image files
- **Location**: `compiled/styles.css` → `build/styles.css`

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
- **Handler**: Reads CSS file from `dist/` directory
- **Response**: Serves with `text/css` content type
- **Location**: `{base_path}/dist/{filename}.css`

**Implementation** (`server.py`):
```python
# CSS files from dist directory
if path.startswith("/static/") and path.endswith(".css"):
    css_file = base_path / "dist" / Path(path).name
    if css_file.exists():
        css_content = css_file.read_text(encoding="utf-8")
        ResponseBuilder.send_css(self, css_content)
```

#### CSS File Flow
```
app.jac (cl import ".styles.css")
  ↓
compiled/app.js (import "./styles.css")
  ↓
Babel: compiled/app.js → build/app.js (preserves import)
  ↓
_copy_asset_files: compiled/styles.css → build/styles.css
  ↓
Vite: Processes CSS import, extracts to dist/main.css
  ↓
HTML: <link href="/static/main.css?hash=..."/>
  ↓
Server: Serves from dist/main.css
```

### Key Design Decisions

- **No inlining of external packages**: Bare imports like `"antd"` remain as imports for Vite's tree-shaking and code-splitting
- **Export collection**: All client exports are aggregated across the dependency tree
- **React-based**: Entry point uses React 18's `createRoot` API
- **Hash-based caching**: Bundle hash enables browser cache invalidation
- **Temp directory isolation**: Builds in `vite_package_json.parent/compiled/` to avoid conflicts
- **Folder structure preservation**: Nested folder structures are preserved in `compiled/` directory, similar to TypeScript transpilation, ensuring relative imports work correctly
- **CSS asset handling**: CSS files are copied after Babel compilation to ensure Vite can resolve imports, then extracted to separate files for optimal loading

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
  "ts": {}
}
```

#### Configuration Processing

1. **Config Loading** (`JacClientConfig`)
   - Loads `config.json` from project root
   - Merges user config with defaults using deep merge
   - Creates default config file if it doesn't exist
   - Validates JSON structure

2. **Config Generation** (`ViteBundler.create_vite_config`)
   - Reads configuration from `config.json`
   - Generates `vite.config.js` in `.jac-client.configs/` directory
   - Injects user customizations into the generated config
   - Automatically includes base plugins and required aliases

3. **Build Execution**
   - Uses generated `vite.config.js` for Vite bundling
   - Config is regenerated on each build to reflect latest changes

#### Configuration Keys

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
  - `@jac-client/utils` → `compiled/client_runtime.js`
  - `@jac-client/assets` → `compiled/assets`
- **Build settings**: Entry point, output directory, file naming
- **Extensions**: JavaScript and TypeScript file extensions

#### Generated Vite Config

The generated `vite.config.js` in `.jac-client.configs/` includes:

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
      "@jac-client/utils": path.resolve(projectRoot, "compiled/client_runtime.js"),
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
4. ViteBundler generates vite.config.js in .jac-client.configs/
   ↓
5. Vite uses generated config for bundling
   ↓
6. Generated config is gitignored (config.json is committed)
```

#### Benefits

- **Simple**: JSON format is easy to edit and understand
- **Standardized**: Predefined keys prevent configuration errors
- **Extensible**: Easy to add new config types (e.g., `ts`)
- **Maintainable**: Defaults are always preserved
- **Version controlled**: `config.json` can be committed to git
- **Auto-generated**: `vite.config.js` is generated automatically

### Configuration Parameters

- `vite_package_json`: Path to package.json (must exist)
- `runtime_path`: Path to client runtime file
- `vite_output_dir`: Build output (defaults to `compiled/dist/assets`)
- `vite_minify`: Enable/disable minification
