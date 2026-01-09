# Custom Assets Handling

Configure custom asset types for your Jac Client build process to support Web Workers, Python scripts, and other specialized file types.

## Overview

By default, Jac Client handles common asset types like images, fonts, and CSS files. With custom asset configuration, you can extend this to include any file type, such as `.js`, `.py`, `.wasm`, or `.json`.

## Quick Start

### Configuration Location

Custom asset extensions are configured under `[plugins.client.assets]` in your `jac.toml`:

```toml
[project]
name = "my-app"
version = "1.0.0"
entry-point = "main.jac"

[plugins.client.assets]
custom_extensions = [".js", ".py"]
```

### Basic Example: Web Workers

```toml
[plugins.client.assets]
custom_extensions = [".js", ".py"]
```

**Project Structure:**

```
my-jac-project/
├── jac.toml
├── main.jac
└── assets/
    └── workers/
        ├── worker.js      # JavaScript Web Worker
        └── worker.py      # Python code for Pyodide
```

## Configuration Structure

### Asset Configuration Keys

#### `custom_extensions` (Array of Strings)

Specify file extensions to treat as copyable assets:

```toml
[plugins.client.assets]
custom_extensions = [".js", ".py", ".wasm", ".json"]
```

**Default Asset Types** (always supported):

- Images: `.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`, `.svg`, `.ico`
- Fonts: `.woff`, `.woff2`, `.ttf`, `.otf`, `.eot`
- Media: `.mp4`, `.webm`, `.mp3`, `.wav`
- Styles: `.css`

Custom extensions are **additive**, they don't replace default types.

## How It Works

### Build Process Workflow

```
1. Developer adds custom_extensions to jac.toml
   ↓
2. Assets placed in assets/ directory
   ↓
3. Build process reads config via get_config()
   ↓
4. AssetProcessor copies matching files to build/assets/
   ↓
5. Server dynamically routes custom asset types
   ↓
6. Assets accessible via /path/to/asset.ext
```

Custom assets are copied to `.jac/client/build/assets/` and served from their relative paths.

## Use Cases

1. **Web Workers with Python Backend**: Enable multi-threaded processing using JavaScript Web Workers with Python via Pyodide.

```toml
[plugins.client.assets]
custom_extensions = [".js", ".py"]
```

1. **Configuration Files**: Serve JSON configuration files as static assets.

```toml
[plugins.client.assets]
custom_extensions = [". json"]
```

1. **WebAssembly Modules**: Serve `.wasm` files for high-performance computations.

```toml
[plugins.client.assets]
custom_extensions = [". wasm"]
```

## Related Documentation

- [Configuration Overview](./configuration-overview.md) - Complete configuration guide
- [Custom Configuration](./custom-config.md) - Vite and TypeScript configuration
- [Package Management](./package-management.md) - Manage npm dependencies
- [All-in-One Example](https://github.com/jaseci-labs/jaseci/tree/main/jac-client/jac_client/examples/all-in-one) - Working example with Web Workers

---
