# Multi-Target Build System Architecture

## Overview

The multi-target build system enables `jac-client` to build applications for multiple platforms (web, desktop, mobiel etc..) from a single codebase. The system uses a target-based architecture where each target (web, desktop, mobile) implements a common interface, allowing for extensible platform support.

## Architecture

### Core Components

#### 1. Target Registry (`src/targets/registry.jac`)

The `TargetRegistry` is a singleton that manages all available build targets. It provides:
- Target registration and retrieval
- Default target management
- Target discovery

**Base Target Class:**
```jac
class Target {
    has name: str;                    # Target identifier (e.g., "web", "desktop")
    has default: bool = False;        # Whether this is the default target
    has requires_setup: bool = False; # Whether setup is required before use
    has config_section: str = "";     # jac.toml section for target config
    has required_dependencies: list[str] = [];
    has output_dir: Optional[Path] = None;

    def setup(self: Target, project_dir: Path) -> None abs;
    def build(self: Target, entry_file: Path, project_dir: Path, platform: Optional[str] = None) -> Path abs;
    def dev(self: Target, entry_file: Path, project_dir: Path) -> None abs;
    def start(self: Target, entry_file: Path, project_dir: Path) -> None abs;
}
```

#### 2. Web Target (`src/targets/WebTarget.jac`)

The default target for web applications. It:
- Compiles Jac code to JavaScript using the Jac runtime
- Bundles with Vite using `ViteClientBundleBuilder`
- Generates static `index.html` with proper client runtime initialization
- Cleans dist directory before each build for fresh outputs

**Key Methods:**
- `build()`: Compiles and bundles the web application, generates `index.html`
- `_generate_index_html()`: Creates static HTML with `__jac_init__` script tag for client runtime

#### 3. Desktop Target (`src/targets/DesktopTarget.jac`)

Target for Tauri-based desktop applications. It:
- Requires one-time setup via `jac setup desktop`
- Builds web bundle first, then wraps with Tauri
- Supports dev mode with hot reload
- Supports production mode with built bundle

**Key Methods:**
- `setup()`: Scaffolds Tauri project structure (`src-tauri/`), generates configs
- `build()`: Builds web bundle, then runs `cargo tauri build`
- `dev()`: Starts Vite dev server + Tauri dev window (hot reload)
- `start()`: Builds web bundle, launches Tauri with built bundle (production-like)

## CLI Integration

### Commands

#### `jac setup <target>`
One-time initialization for a target. Currently supports:
- `jac setup desktop`: Sets up Tauri project structure

**What it does:**
- Creates `src-tauri/` directory structure
- Generates `tauri.conf.json`, `Cargo.toml`, `build.rs`, `main.rs`
- Creates placeholder icon
- Adds `[desktop]` section to `jac.toml`
- Checks for Rust toolchain and system dependencies

#### `jac build <file> --target <target> [--platform <platform>]`
Builds the application for the specified target.

**Examples:**
```bash
jac build main.jac --target web
jac build main.jac --target desktop
jac build main.jac --target desktop --platform windows
```

**Web Target:**
- Compiles Jac → JavaScript
- Bundles with Vite
- Generates `index.html` in `.jac/client/dist/`
- Returns path to bundle file

**Desktop Target:**
- Builds web bundle first (via `WebTarget.build()`)
- Updates `tauri.conf.json` to point to dist directory
- Runs `cargo tauri build`
- Returns path to installer/bundle

#### `jac start <file> [--cl-target <target>] [--dev]`
Starts the application for the specified target.

**Examples:**
```bash
jac start main.jac                    # Web target (default)
jac start main.jac --cl-target desktop
jac start main.jac --cl-target desktop --dev  # Dev mode with hot reload
```

**Web Target:**
- Uses existing `jac start` behavior (API server + optional Vite dev server)

**Desktop Target:**
- **Without `--dev`**: Builds web bundle, launches Tauri with built bundle
- **With `--dev`**: Starts Vite dev server, launches Tauri dev window (hot reload)

## File Structure

```
jac-client/
├── jac_client/
│   └── plugin/
│       ├── cli.jac                    # CLI command handlers
│       └── src/
│           └── targets/
│               ├── registry.jac        # Target base class & registry
│               ├── registry.impl.jac  # Registry implementation
│               ├── register.jac        # Target registration
│               ├── WebTarget.jac       # Web target implementation
│               ├── DesktopTarget.jac  # Desktop target interface
│               └── DesktopTarget.impl.jac  # Desktop target implementation
└── testapp/
    ├── main.jac                       # Entry point
    ├── jac.toml                       # Project config
    ├── .jac/
    │   └── client/
    │       └── dist/                  # Web build output
    │           ├── index.html         # Generated HTML
    │           └── client.[hash].js    # Bundled JavaScript
    └── src-tauri/                     # Tauri project (after setup)
        ├── tauri.conf.json            # Tauri configuration
        ├── Cargo.toml                 # Rust dependencies
        ├── build.rs                   # Build script
        ├── src/
        │   └── main.rs                # Rust entry point
        └── icons/
            └── icon.png               # App icon
```

## Implementation Details

### Web Target Build Process

1. **Clean dist directory** - Removes old build artifacts
2. **Load module** - Uses `Jac.jac_import()` to compile `.jac` file
3. **Build bundle** - Uses `ViteClientBundleBuilder.build()` to:
   - Compile Jac → JavaScript
   - Bundle with Vite
   - Output to `.jac/client/dist/client.[hash].js`
4. **Generate HTML** - Creates `index.html` with:
   - Proper HTML head (via `HeaderBuilder`)
   - `__jac_init__` script tag with module/function info
   - Script tag pointing to bundle file
   - CSS link if CSS file exists

### Desktop Target Setup Process

1. **Create directory structure** - `src-tauri/`, `src-tauri/src/`, `src-tauri/icons/`
2. **Generate Tauri config** - `tauri.conf.json` with Tauri v2 structure
3. **Generate Cargo.toml** - Rust dependencies (Tauri v2)
4. **Generate build.rs** - Required build script for Tauri v2
5. **Generate main.rs** - Minimal Rust entry point
6. **Generate icon** - Placeholder `icon.png`
7. **Update jac.toml** - Adds `[desktop]` section

### Desktop Target Build Process

1. **Build web bundle** - Calls `WebTarget.build()` to create web bundle
2. **Update Tauri config** - Sets `frontendDist` to dist directory path
3. **Run Tauri build** - Executes `cargo tauri build`
4. **Return bundle** - Returns path to installer (`.exe`, `.dmg`, `.AppImage`, etc.)

### Desktop Target Dev Process

1. **Update Tauri config** - Sets `devUrl` to `http://localhost:5173`
2. **Start Vite dev server** - Runs on port 5173 with HMR
3. **Launch Tauri dev** - Runs `cargo tauri dev` which opens window
4. **Signal handling** - Gracefully shuts down both processes on Ctrl+C

### Desktop Target Start Process

1. **Build web bundle** - Creates fresh web bundle with `index.html`
2. **Update Tauri config** - Sets `frontendDist` to dist directory
3. **Launch Tauri dev** - Uses built bundle (production-like, no hot reload)

## Configuration

### jac.toml

```toml
[project]
name = "myapp"
version = "1.0.0"
entry-point = "main.jac"

[desktop]
# Desktop-specific configuration
# (Currently minimal, can be extended)
```

### tauri.conf.json

Generated during `jac setup desktop`, includes:
- `productName`, `version`, `identifier`
- `build.devUrl` (for dev mode)
- `build.frontendDist` (for production mode)
- Window configuration
- Security settings

## Tauri v2 Compatibility

The implementation uses Tauri v2 configuration structure:
- `devUrl` instead of `devPath`
- `frontendDist` instead of `distDir`
- No `withGlobalTauri` (removed in v2)
- Requires `build.rs` file
- Requires icon files

## Error Handling

- **Missing setup**: Clear error if desktop target used without setup
- **Missing dependencies**: Checks for Rust, Cargo, build tools
- **Build failures**: Propagates errors with context
- **Signal handling**: Graceful shutdown of dev servers

## Future Extensions

The architecture supports adding new targets by:
1. Creating a new class inheriting from `Target`
2. Implementing `setup()`, `build()`, `dev()`, `start()` methods
3. Registering the target in `register.jac`

Potential targets:
- Mobile (React Native, Capacitor)
- Electron (alternative to Tauri)
- Server-side rendering (SSR)
- Static site generation (SSG)

