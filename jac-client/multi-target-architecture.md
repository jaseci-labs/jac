# Multi-Target Build System Architecture

## Overview

The multi-target build system enables `jac-client` to build applications for multiple platforms (web, desktop, mobile, etc.) from a single codebase. The system uses a target-based architecture where each target (web, desktop, mobile) implements a common interface, allowing for extensible platform support.

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Jac CLI Commands                        │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐        │
│  │ jac setup    │  │ jac build    │  │ jac start    │        │
│  │ <target>     │  │ --client <t> │  │ --client  │        │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘        │
└─────────┼──────────────────┼──────────────────┼─────────────────┘
          │                  │                  │
          ▼                  ▼                  ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Target Registry (Singleton)                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │  TargetRegistry                                          │  │
│  │  - register(target)                                      │  │
│  │  - get(name) -> Target                                    │  │
│  │  - get_default() -> Target                               │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
          │
          ├──────────────────┬──────────────────┐
          ▼                  ▼                  ▼
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐
│   WebTarget     │  │ DesktopTarget  │  │  MobileTarget   │
│                 │  │                 │  │   (Future)      │
│  - setup()      │  │  - setup()     │  │                 │
│  - build()      │  │  - build()     │  │                 │
│  - dev()        │  │  - dev()       │  │                 │
│  - start()      │  │  - start()     │  │                 │
└─────────────────┘  └────────┬────────┘  └─────────────────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  Desktop Build Flow  │
                    │                      │
                    │  1. WebTarget.build()│
                    │  2. Bundle Sidecar   │
                    │  3. Update Config    │
                    │  4. Tauri Build      │
                    └──────────────────────┘
```

## System Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Build Request Flow                            │
└─────────────────────────────────────────────────────────────────────┘

User Command: jac build main.jac --client desktop
                    │
                    ▼
        ┌───────────────────────┐
        │   CLI Handler         │
        │   (_handle_build)      │
        └───────────┬───────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │  TargetRegistry       │
        │  .get("desktop")      │
        └───────────┬───────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │  DesktopTarget.build() │
        └───────────┬───────────┘
                    │
        ┌───────────┼───────────┐
        │           │           │
        ▼           ▼           ▼
┌──────────┐  ┌──────────┐  ┌──────────┐
│ Web      │  │ Sidecar  │  │ Tauri    │
│ Bundle   │  │ Bundle   │  │ Build    │
│          │  │          │  │          │
│ 1. Compile│  │ 1. Find  │  │ 1. Update│
│    Jac   │  │   Entry  │  │   Config │
│ 2. Bundle│  │ 2. Run    │  │ 2. Run   │
│    JS    │  │   PyInst.│  │   Cargo  │
│ 3. Gen   │  │ 3. Output │  │ 3. Bundle│
│    HTML  │  │   Binary  │  │   App    │
└──────────┘  └──────────┘  └──────────┘
        │           │           │
        └───────────┼───────────┘
                    │
                    ▼
        ┌───────────────────────┐
        │   Final Bundle        │
        │   (.exe/.dmg/.AppImg) │
        └───────────────────────┘
```

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

#### 3. Desktop Target (`src/targets/desktop_target.jac`)

Target for Tauri-based desktop applications. It:

- Requires one-time setup via `jac setup desktop`
- Builds web bundle first, then wraps with Tauri
- Optionally bundles Jac backend as sidecar executable
- Supports dev mode with hot reload
- Supports production mode with built bundle

**Key Methods:**

- `setup()`: Scaffolds Tauri project structure (`src-tauri/`), generates configs
- `build()`: Builds web bundle, bundles sidecar (optional), then runs `cargo tauri build`
- `dev()`: Starts Vite dev server + Tauri dev window (hot reload)
- `start()`: Builds web bundle, launches Tauri with built bundle (production-like)

**Sidecar Integration:**

- `_bundle_sidecar()`: Uses PyInstaller to bundle Jac backend as executable
- `_add_sidecar_to_config()`: Adds sidecar to `tauri.conf.json` resources
- Sidecar provides local HTTP API server for desktop apps

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

#### `jac build <file> --client <target> [--platform <platform>]`

Builds the application for the specified target.

**Examples:**

```bash
jac build main.jac --client web
jac build main.jac --client desktop
jac build main.jac --client desktop --platform windows
```

**Web Target:**

- Compiles Jac → JavaScript
- Bundles with Vite
- Generates `index.html` in `.jac/client/dist/`
- Returns path to bundle file

**Desktop Target:**

- Builds web bundle first (via `WebTarget.build()`)
- Optionally bundles sidecar executable (if PyInstaller available)
- Updates `tauri.conf.json` to point to dist directory and include sidecar
- Runs `cargo tauri build`
- Returns path to installer/bundle

#### `jac start <file> [--client <target>] [--dev]`

Starts the application for the specified target.

**Examples:**

```bash
jac start main.jac                    # Web target (default)
jac start main.jac --client desktop
jac start main.jac --client desktop --dev  # Dev mode with hot reload
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
│               ├── desktop_target.jac  # Desktop target interface
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
        ├── icons/
        │   └── icon.png               # App icon
        └── binaries/                  # Sidecar executables (after build)
            └── jac-sidecar            # Bundled Jac backend (optional)
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
2. **Bundle sidecar (optional)** - Uses PyInstaller to bundle Jac backend:
   - Finds sidecar entry point (`sidecar/main.py`)
   - Generates PyInstaller spec file
   - Runs PyInstaller to create executable (`jac-sidecar` or `jac-sidecar.exe`)
   - Outputs to `src-tauri/binaries/`
3. **Update Tauri config** - Sets `frontendDist` to dist directory path and adds sidecar to `bundle.resources`
4. **Run Tauri build** - Executes `cargo tauri build`
5. **Return bundle** - Returns path to installer (`.exe`, `.dmg`, `.AppImage`, etc.)

**Sidecar Bundling Details:**

- Entry point: `jac_client/plugin/src/targets/desktop/sidecar/main.py`
- Bundles: Jac runtime, server components, Python dependencies
- Output: Platform-specific executable in `src-tauri/binaries/`
- Integration: Added to `tauri.conf.json` `bundle.resources` array
- Optional: Build continues gracefully if PyInstaller is missing

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
- `bundle.resources` (includes sidecar executable if bundled)
- `bundle.icon` (app icon array)
- Window configuration
- Security settings

**Sidecar Configuration:**
When sidecar is bundled, it's automatically added to:

```json
{
  "bundle": {
    "resources": [
      "binaries/jac-sidecar"  // or "binaries/jac-sidecar.exe" on Windows
    ]
  }
}
```

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

## Sidecar Architecture

### Overview

The sidecar pattern allows desktop applications to run the Jac backend locally without requiring a separate server process. The sidecar is a bundled executable that provides the same HTTP API as `jac start`.

**Key Point:** The sidecar follows the exact same process as `jac start`:

1. **Compiles Jac code to Python** - Uses `Jac.jac_import()` to compile `.jac` files
2. **Introspects the compiled module** - Discovers functions, walkers, and their signatures
3. **Creates HTTP API endpoints** - Automatically converts Jac code to REST API
4. **Starts HTTP server** - Serves the API on localhost

### Sidecar Entry Point

**File:** `jac_client/plugin/src/targets/desktop/sidecar/main.py`

**Process Flow (Same as `jac start`):**

```
┌─────────────────────────────────────────────────────────┐
│         Sidecar Execution Flow                           │
└─────────────────────────────────────────────────────────┘

1. Parse Arguments
   │
   ├─ module-path: Path to .jac file
   ├─ port: HTTP server port (default: 8000)
   ├─ base-path: Project root directory
   └─ host: Bind address (default: 127.0.0.1)

2. Initialize Jac Runtime
   │
   └─ Import: jaclang.pycore.runtime.JacRuntime
      └─ Import: jaclang.runtimelib.server.JacAPIServer

3. Compile Jac Code to Python
   │
   └─ Jac.jac_import(target=module_name, base_path=base, lng="jac")
      │
      ├─ Parses .jac file
      ├─ Compiles to Python bytecode
      ├─ Loads into Python module
      └─ Returns compiled module

4. Create API Server
   │
   └─ ServerClass = Jac.get_api_server_class()
      └─ server = ServerClass(module_name, port, base_path)
         │
         ├─ ModuleIntrospector: Discovers functions/walkers
         ├─ ExecutionManager: Handles function/walker execution
         ├─ UserManager: Manages user authentication
         └─ HTTP Handler: Routes requests to appropriate handlers

5. Introspect Module (Automatic)
   │
   └─ server.introspector.load()
      │
      ├─ Scans compiled module for functions
      ├─ Scans compiled module for walkers
      ├─ Extracts function signatures (parameters, types)
      ├─ Extracts walker fields (has variables)
      └─ Creates API endpoint mappings

6. Start HTTP Server
   │
   └─ server.start(dev=False)
      │
      ├─ Registers endpoints:
      │  ├─ POST /user/register
      │  ├─ POST /user/login
      │  ├─ GET  /functions (list all functions)
      │  ├─ GET  /walkers (list all walkers)
      │  ├─ POST /function/<name> (call function)
      │  └─ POST /walker/<name> (spawn walker)
      │
      └─ Serves on http://host:port
```

**Responsibilities:**

- Parse command-line arguments (module path, port, host)
- Initialize Jac runtime
- **Compile Jac code to Python** (via `Jac.jac_import()`)
- **Introspect compiled module** (automatic via `JacAPIServer`)
- **Create HTTP API endpoints** (automatic conversion)
- Start HTTP API server
- Handle graceful shutdown

**Usage:**

```bash
jac-sidecar --module-path main.jac --port 8000 --base-path .
```

**What Happens Internally:**

1. `Jac.jac_import()` compiles `main.jac` → Python module
2. `JacAPIServer` introspects the compiled module:
   - Finds all `def:pub` functions → `/function/<name>` endpoints
   - Finds all `walker` definitions → `/walker/<name>` endpoints
   - Extracts signatures (parameters, types, return types)
3. HTTP server automatically exposes these as REST API
4. Frontend can call functions/walkers via HTTP requests

### Sidecar Bundling Process

```
┌─────────────────────────────────────────────────────────┐
│              Sidecar Bundling Flow                       │
└─────────────────────────────────────────────────────────┘

1. Check PyInstaller availability
   │
   ├─ Found → Continue
   └─ Not Found → Skip (optional, build continues)

2. Locate sidecar entry point
   │
   ├─ Try: Path(__file__).parent / "desktop" / "sidecar" / "main.py"
   ├─ Try: Import via importlib.util.find_spec()
   └─ Try: project_dir / "src-tauri" / "sidecar" / "main.py"

3. Generate PyInstaller spec
   │
   ├─ Include: jaclang, jaclang.pycore, jaclang.runtimelib
   ├─ Hidden imports: All Jac runtime modules
   └─ Output: Temporary .spec file

4. Run PyInstaller
   │
   ├─ Input: sidecar/main.py
   ├─ Output: src-tauri/binaries/jac-sidecar[.exe]
   └─ Cleanup: Remove temporary spec file

5. Add to Tauri config
   │
   └─ Update: tauri.conf.json bundle.resources array
```

### Sidecar Communication

```
┌──────────────┐         HTTP          ┌──────────────┐
│   Frontend   │ ◄───────────────────► │   Sidecar    │
│  (Tauri App) │    (localhost:8000)   │  (Executable)│
└──────────────┘                        └──────┬───────┘
                                               │
                                               ▼
                                        ┌──────────────────┐
                                        │  Compiled Python │
                                        │  Module (from    │
                                        │   Jac.jac_import)│
                                        └──────────┬───────┘
                                                   │
                                                   ▼
                                        ┌──────────────────┐
                                        │  JacAPIServer    │
                                        │  - Introspector  │
                                        │  - Exec Manager  │
                                        │  - User Manager  │
                                        └──────────────────┘
```

**Communication Flow:**

1. **Frontend makes HTTP request** to `http://localhost:8000/function/my_function`
2. **Sidecar HTTP server** receives request
3. **JacAPIServer routes** to appropriate handler:
   - Looks up function/walker in introspected module
   - Validates authentication (if required)
   - Executes function/walker with provided parameters
4. **Response returned** to frontend (JSON format)

**How Jac Code Becomes API Endpoints:**

```jac
// Example: main.jac
def:pub greet(name: str) -> str {
    return f"Hello, {name}!";
}

walker my_walker {
    has name: str;
    root {
        std.out("Walking with: ", here.name);
    }
}
```

**Automatically becomes:**

```
POST /function/greet
Body: {"name": "Alice"}
Response: {"data": "Hello, Alice!"}

POST /walker/my_walker
Body: {"name": "Bob", "target_node": "..."}
Response: {"data": {...}}
```

**API Compatibility:**

- **Same endpoints as `jac start` server**
- `/user/register`, `/user/login` - User management
- `/functions` - List all functions
- `/walkers` - List all walkers
- `/function/<name>` - Call a function
- `/walker/<name>` - Spawn a walker
- `/<cl_route_prefix>/<name>` - Client-side routes
- All endpoints support authentication (token-based)

### Sidecar Lifecycle

**During Build:**

- Sidecar is bundled into executable
- Added to Tauri resources
- Included in final app bundle

**During Runtime:**

- Tauri app can launch sidecar process
- Sidecar runs as separate process
- **Sidecar compiles Jac code on startup** (via `Jac.jac_import()`)
- **Sidecar introspects compiled module** (discovers functions/walkers)
- **Sidecar creates HTTP endpoints** (automatic API generation)
- Frontend connects via HTTP
- Sidecar manages Jac runtime lifecycle
- **All Jac code is executed as Python** (compiled from Jac)

**Shutdown:**

- Sidecar handles SIGINT/SIGTERM
- Gracefully shuts down HTTP server
- Cleans up Jac runtime

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

**Sidecar Enhancements:**

- Auto-start sidecar on app launch
- Sidecar process management from Tauri
- IPC communication (alternative to HTTP)
- Sidecar health checks and monitoring
