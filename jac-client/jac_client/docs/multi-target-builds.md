# Multi-Target Builds: Web, Desktop, and More

> **New in jac-client**: Build your Jac application for multiple platforms from a single codebase!

Jac now supports building your application for different targets - web browsers, desktop applications, and more. Write your code once, deploy everywhere.

---

## Quick Start

### Building for Web (Default)

The web target is the default and requires no setup:

```bash
# Build for web
jac build main.jac --target web

# Or simply (web is default)
jac build main.jac
```

### Building for Desktop

Desktop builds use Tauri to create native desktop applications:

```bash
# 1. One-time setup
jac setup desktop

# 2. Build for desktop
jac build main.jac --target desktop

# 3. Or start in dev mode
jac start main.jac --cl-target desktop --dev
```

---

## Targets Overview

### Web Target

The **web target** is the default build target. It compiles your Jac code to JavaScript and bundles it with Vite for optimal web performance.

**Features:**
- ✅ No setup required
- ✅ Automatic HTML generation
- ✅ CSS bundling
- ✅ Production-ready builds
- ✅ Works with all existing Jac features

**Usage:**
```bash
# Build
jac build main.jac --target web

# Start dev server
jac start main.jac

# Start production server
jac start main.jac --no-dev
```

**Output:**
- Compiled JavaScript bundle: `.jac/client/dist/client.[hash].js`
- Generated HTML: `.jac/client/dist/index.html`
- CSS files: `.jac/client/dist/styles.css` (if present)

### Desktop Target

The **desktop target** wraps your web application in a native desktop window using Tauri. Your Jac code runs in a webview, but users get a native desktop experience.

**Features:**
- ✅ Native desktop applications
- ✅ Cross-platform (Windows, macOS, Linux)
- ✅ Small bundle size (uses system webview)
- ✅ Hot reload in dev mode
- ✅ Production builds create installers

**Prerequisites:**
- Rust toolchain (install from [rustup.rs](https://rustup.rs/))
- Build tools (gcc/cc)
- System dependencies (varies by OS)

**Usage:**
```bash
# One-time setup
jac setup desktop

# Build for current platform
jac build main.jac --target desktop

# Build for specific platform
jac build main.jac --target desktop --platform windows
jac build main.jac --target desktop --platform macos
jac build main.jac --target desktop --platform linux

# Start in dev mode (hot reload)
jac start main.jac --cl-target desktop --dev

# Start with built bundle (production-like)
jac start main.jac --cl-target desktop
```

**Output:**
- Windows: `.exe` installer
- macOS: `.dmg` or `.app`
- Linux: `.AppImage`, `.deb`, or `.rpm`

---

## Getting Started with Desktop

### Step 1: Install Prerequisites

#### Install Rust

Visit [https://rustup.rs](https://rustup.rs) and follow the installation instructions, or run:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Verify installation:
```bash
rustc --version
cargo --version
```

#### Install Build Tools

**Ubuntu/Debian:**
```bash
sudo apt-get install build-essential
```

**Fedora:**
```bash
sudo dnf install gcc gcc-c++
```

**Arch Linux:**
```bash
sudo pacman -S base-devel
```

**macOS:**
Install Xcode Command Line Tools:
```bash
xcode-select --install
```

**Windows:**
Install [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022) or Visual Studio with C++ support.

#### Install System Dependencies (Linux)

**Ubuntu/Debian:**
```bash
sudo apt-get install libwebkit2gtk-4.0-dev \
    build-essential \
    curl \
    wget \
    libssl-dev \
    libgtk-3-dev \
    libayatana-appindicator3-dev \
    librsvg2-dev
```

**Fedora:**
```bash
sudo dnf install webkit2gtk3-devel.x86_64 \
    openssl-devel \
    curl \
    wget \
    libappindicator \
    librsvg2-devel
```

**Arch Linux:**
```bash
sudo pacman -S webkit2gtk \
    base-devel \
    curl \
    wget \
    openssl \
    appmenu-gtk-module \
    gtk3 \
    libappindicator-gtk3 \
    librsvg \
    libvips
```

### Step 2: Setup Desktop Target

Run the setup command in your Jac project:

```bash
jac setup desktop
```

This will:
- Create `src-tauri/` directory structure
- Generate Tauri configuration files
- Create Rust project files
- Add desktop configuration to `jac.toml`

**What gets created:**
```
your-project/
├── src-tauri/
│   ├── tauri.conf.json    # Tauri configuration
│   ├── Cargo.toml         # Rust dependencies
│   ├── build.rs           # Build script
│   ├── src/
│   │   └── main.rs        # Rust entry point
│   └── icons/
│       └── icon.png       # App icon
└── jac.toml               # Updated with [desktop] section
```

### Step 3: Build or Run

**Development mode (with hot reload):**
```bash
jac start main.jac --cl-target desktop --dev
```

This will:
1. Start a Vite dev server on port 5173
2. Launch Tauri dev window
3. Enable hot module replacement (HMR)
4. Show your app with live reload

**Production mode (build first, then run):**
```bash
jac start main.jac --cl-target desktop
```

This will:
1. Build the web bundle
2. Generate `index.html`
3. Launch Tauri with the built bundle

**Build for distribution:**
```bash
jac build main.jac --target desktop
```

This creates platform-specific installers in `src-tauri/target/release/bundle/`.

---

## Platform-Specific Builds

### Building for Windows

```bash
jac build main.jac --target desktop --platform windows
```

**Output:** `.exe` installer in `src-tauri/target/x86_64-pc-windows-msvc/release/bundle/`

### Building for macOS

```bash
jac build main.jac --target desktop --platform macos
```

**Output:** `.dmg` or `.app` bundle in `src-tauri/target/aarch64-apple-darwin/release/bundle/` (or `x86_64-apple-darwin` for Intel)

### Building for Linux

```bash
jac build main.jac --target desktop --platform linux
```

**Output:** `.AppImage`, `.deb`, or `.rpm` in `src-tauri/target/x86_64-unknown-linux-gnu/release/bundle/`

### Building for All Platforms

```bash
jac build main.jac --target desktop --platform all
```

This builds installers for all supported platforms (requires cross-compilation setup).

---

## Configuration

### Desktop Configuration

After running `jac setup desktop`, you can customize the desktop app in `src-tauri/tauri.conf.json`:

```json
{
  "productName": "My App",
  "version": "1.0.0",
  "identifier": "com.example.myapp",
  "app": {
    "windows": [
      {
        "title": "My App",
        "width": 1200,
        "height": 800,
        "minWidth": 800,
        "minHeight": 600,
        "resizable": true,
        "fullscreen": false
      }
    ]
  }
}
```

### jac.toml Configuration

The `[desktop]` section in `jac.toml` is automatically added during setup:

```toml
[desktop]
# Desktop-specific configuration
# (Currently minimal, can be extended)
```

---

## How It Works

### Web Target Build Process

1. **Compile**: Jac code is compiled to JavaScript
2. **Bundle**: Vite bundles the JavaScript and dependencies
3. **Generate HTML**: Static `index.html` is created with:
   - Proper HTML head (meta tags, title, etc.)
   - `__jac_init__` script tag for client runtime
   - Script tag pointing to the bundled JavaScript
   - CSS links (if CSS files exist)

### Desktop Target Build Process

1. **Build Web Bundle**: First builds the web bundle (same as web target)
2. **Update Tauri Config**: Points Tauri to the dist directory
3. **Build Tauri**: Runs `cargo tauri build` to create native app
4. **Package**: Creates platform-specific installer

### Desktop Target Dev Process

1. **Start Vite Dev Server**: Runs on `http://localhost:5173` with HMR
2. **Update Tauri Config**: Sets `devUrl` to the dev server
3. **Launch Tauri**: Opens dev window connected to Vite server
4. **Hot Reload**: Changes to your code automatically reload in the window

---

## Troubleshooting

### "Rust/Cargo not found"

Install Rust from [rustup.rs](https://rustup.rs/):
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

### "Build tools not found"

Install build tools for your platform (see Prerequisites section above).

### "Desktop target not set up"

Run the setup command:
```bash
jac setup desktop
```

### "Tauri CLI not found"

Install Tauri CLI:
```bash
cargo install tauri-cli
```

Or via npm:
```bash
npm install -D @tauri-apps/cli
```

### Build fails with GTK/WebKit errors (Linux)

Install system dependencies (see Prerequisites section above).

### Empty window in Tauri

Make sure `index.html` exists in `.jac/client/dist/`. Rebuild:
```bash
jac build main.jac --target web
jac start main.jac --cl-target desktop
```

### Port 5173 already in use

Change the Vite port in the dev configuration, or stop the process using port 5173.

---

## Best Practices

### 1. Use Dev Mode for Development

Always use `--dev` flag during development for hot reload:
```bash
jac start main.jac --cl-target desktop --dev
```

### 2. Test Production Builds

Before distributing, test the production build:
```bash
jac start main.jac --cl-target desktop  # No --dev flag
```

### 3. Customize Window Size

Edit `src-tauri/tauri.conf.json` to set appropriate window dimensions for your app.

### 4. Add App Icon

Replace `src-tauri/icons/icon.png` with your app icon (recommended: 512x512px PNG).

### 5. Version Management

Update version in both `jac.toml` and `src-tauri/tauri.conf.json` for consistency.

---

## Examples

### Basic Desktop App

```jac
# main.jac
cl {
    def:pub app() -> any {
        has count: int = 0;
        
        return <div style={{padding: "2rem"}}>
            <h1>Desktop App</h1>
            <p>Count: {count}</p>
            <button onClick={lambda -> None { count = count + 1; }}>
                Increment
            </button>
        </div>;
    }
}
```

Build and run:
```bash
jac setup desktop
jac start main.jac --cl-target desktop --dev
```

### Full-Stack Desktop App

Your desktop app can use the same backend features as web apps:

```jac
# main.jac
cl {
    def:pub app() -> any {
        has todos: list = [];
        
        async def loadTodos() -> None {
            response = root spawn get_todos();
            todos = response.reports[0];
        }
        
        useEffect(lambda -> None {
            loadTodos();
        }, []);
        
        return <div>
            <h1>Todo Desktop App</h1>
            {todos.map(lambda todo: any -> any {
                return <div key={todo._jac_id}>{todo.text}</div>;
            })}
        </div>;
    }
}
```

---

## Next Steps

- **[Routing](routing.md)**: Add multi-page navigation to your desktop app
- **[Advanced State](advanced-state.md)**: Manage complex state in desktop apps
- **[Imports](imports.md)**: Use third-party libraries in desktop builds
- **[Styling](styling/)**: Style your desktop app with CSS or Tailwind

---

## FAQ

**Q: Can I use the same codebase for web and desktop?**  
A: Yes! The same Jac code works for both targets. The build system handles the differences.

**Q: Do I need separate builds for each platform?**  
A: For production, yes. Use `--platform` flag to build for specific platforms. For development, Tauri automatically uses your current platform.

**Q: Can I customize the Tauri window?**  
A: Yes! Edit `src-tauri/tauri.conf.json` to customize window size, title, and other properties.

**Q: How do I distribute my desktop app?**  
A: After building with `jac build --target desktop`, distribute the installer files from `src-tauri/target/release/bundle/`.

**Q: Can I use backend features in desktop apps?**  
A: Yes! Desktop apps can use the same backend features (walkers, nodes, etc.) as web apps.

**Q: What's the difference between `--dev` and without it?**  
A: `--dev` uses a Vite dev server with hot reload. Without it, builds the web bundle first and uses the static files.

---

Happy building! 🚀


