# Complete Testing Guide: Desktop Target in a Fresh Project

This guide provides step-by-step instructions to test the desktop target (Tauri) functionality in a completely fresh Jac project from scratch.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Creating a Fresh Project](#creating-a-fresh-project)
3. [Initial Setup](#initial-setup)
4. [Desktop Target Setup](#desktop-target-setup)
5. [Testing Web Target (Baseline)](#testing-web-target-baseline)
6. [Testing Desktop Target](#testing-desktop-target)
7. [Testing Sidecar Functionality](#testing-sidecar-functionality)
8. [Full Build and Distribution](#full-build-and-distribution)
9. [Verification Checklist](#verification-checklist)
10. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### 1. System Requirements

**Python Environment:**
```bash
# Verify Python 3.12+
python3 --version

# Install jaclang and jac-client
pip install jaclang jac-client

# Install PyInstaller (for sidecar bundling)
pip install pyinstaller
```

**Rust Toolchain (for desktop builds):**
```bash
# Install Rust (if not already installed)
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh

# Verify installation
rustc --version
cargo --version

# Install Tauri CLI
cargo install tauri-cli
```

**Build Tools:**

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install build-essential \
    libwebkit2gtk-4.0-dev \
    curl \
    wget \
    libssl-dev \
    libgtk-3-dev \
    libayatana-appindicator3-dev \
    librsvg2-dev
```

**Fedora:**
```bash
sudo dnf install gcc gcc-c++ \
    webkit2gtk3-devel.x86_64 \
    openssl-devel \
    curl \
    wget \
    libappindicator \
    librsvg2-devel
```

**Arch Linux:**
```bash
sudo pacman -S base-devel \
    webkit2gtk \
    curl \
    wget \
    openssl \
    appmenu-gtk-module \
    gtk3 \
    libappindicator-gtk3 \
    librsvg \
    libvips
```

**macOS:**
```bash
# Install Xcode Command Line Tools
xcode-select --install
```

**Windows:**
- Install [Visual Studio Build Tools](https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022) or Visual Studio with C++ support

### 2. Verify Installation

```bash
# Check all tools are available
jac --version
python3 -c "import jaclang; print('jaclang OK')"
python3 -c "import jac_client; print('jac-client OK')"
pyinstaller --version
cargo --version
cargo tauri --version
```

---

## Creating a Fresh Project

### Step 1: Create a New Directory

```bash
# Create a fresh project directory
cd /tmp  # or any location you prefer
mkdir my-desktop-app
cd my-desktop-app
```

### Step 2: Create a Basic Jac Application

Create `main.jac`:

```jac
"""Main entry point for desktop app."""

# Client-side imports
cl import from react { useEffect }

# Client-side component
cl {
    def:pub app() -> any {
        has count: int = 0;
        has message: str = "Hello from Desktop!";

        useEffect(lambda -> None {
            console.log("App mounted, count:", count);
        }, []);

        return <div style={{
            padding: "2rem",
            fontFamily: "Arial, sans-serif",
            maxWidth: "800px",
            margin: "0 auto"
        }}>
            <h1>{message}</h1>
            <p>Count: {count}</p>
            <div style={{display: "flex", gap: "1rem", marginTop: "1rem"}}>
                <button
                    onClick={lambda -> None { count = count + 1; }}
                    style={{
                        padding: "0.5rem 1rem",
                        fontSize: "1rem",
                        cursor: "pointer"
                    }}
                >
                    Increment
                </button>
                <button
                    onClick={lambda -> None { count = 0; }}
                    style={{
                        padding: "0.5rem 1rem",
                        fontSize: "1rem",
                        cursor: "pointer"
                    }}
                >
                    Reset
                </button>
            </div>
            <div style={{marginTop: "2rem", padding: "1rem", backgroundColor: "#f0f0f0"}}>
                <h2>Desktop Target Test</h2>
                <p>If you can see this in a native window, the desktop target is working!</p>
            </div>
        </div>;
    }
}
```

### Step 3: Create Project Configuration

Create `jac.toml`:

```toml
[project]
name = "my-desktop-app"
version = "1.0.0"
description = "My first desktop app with Jac"
entry-point = "main.jac"

[dependencies.npm]
jac-client-node = "1.0.4"

[dependencies.npm.dev]
"@jac-client/dev-deps" = "1.0.0"

[serve]
base_route_app = "app"
```

---

## Initial Setup

### Step 1: Verify Project Structure

```bash
# Check files exist
ls -la
# Should show: main.jac, jac.toml
```

### Step 2: Test Jac Compilation

```bash
# Try to compile the Jac file
jac run main.jac

# Or just verify syntax
jac check main.jac
```

**Expected:** No errors, file compiles successfully.

---

## Desktop Target Setup

### Step 1: Run Setup Command

```bash
jac setup desktop
```

**Expected Output:**
```
🖥️  Setting up desktop target (Tauri)
  Project directory: /tmp/my-desktop-app
  Project name: my-desktop-app, version: 1.0.0
  Identifier: com.myapp
  Creating src-tauri/ directory structure...
  ✔ Created src-tauri
  Generating Tauri configuration...
  ✔ Generated tauri.conf.json
  Generating Cargo.toml...
  ✔ Generated Cargo.toml
  Generating build.rs...
  ✔ Generated build.rs
  Generating main.rs...
  ✔ Generated main.rs
  Creating icon...
  ✔ Created icon
  Updating jac.toml...
  ✔ Added [desktop] section to jac.toml
  ✔ Desktop target setup complete!
```

### Step 2: Verify Setup

```bash
# Check directory structure
ls -la src-tauri/
# Should show: tauri.conf.json, Cargo.toml, build.rs, src/, icons/, binaries/

# Check Tauri config
cat src-tauri/tauri.conf.json
# Should show valid JSON with productName, version, identifier, etc.

# Check jac.toml was updated
grep -A 5 "\[desktop\]" jac.toml
# Should show [desktop] section with name, identifier, version
```

**Expected Structure:**
```
my-desktop-app/
├── main.jac
├── jac.toml
└── src-tauri/
    ├── tauri.conf.json
    ├── Cargo.toml
    ├── build.rs
    ├── src/
    │   └── main.rs
    ├── icons/
    │   └── icon.png
    └── binaries/  (empty initially)
```

---

## Testing Web Target (Baseline)

Before testing desktop, verify the web target works (regression test):

### Step 1: Build Web Target

```bash
jac build main.jac --client web
```

**Expected Output:**
```
🌐 Building web target...
  Compiling Jac code...
  ✔ Compiled successfully
  Bundling with Vite...
  ✔ Bundle created: .jac/client/dist/client.[hash].js
  Generating index.html...
  ✔ Generated index.html
  ✔ Web build complete: .jac/client/dist/
```

### Step 2: Verify Web Build Output

```bash
# Check dist directory
ls -lh .jac/client/dist/
# Should show: index.html, client.[hash].js

# Check HTML content
head -20 .jac/client/dist/index.html
# Should show HTML with script tags
```

### Step 3: Test Web Dev Server

```bash
# Start web dev server (in one terminal)
jac start main.jac --dev

# In another terminal, test the endpoint
curl http://localhost:8000/
# Or open browser: http://localhost:8000/cl/app
```

**Expected:**
- Dev server starts on port 8000
- Browser shows the app with counter
- Hot reload works (edit `main.jac`, see changes)

**Stop:** Press `Ctrl+C` in the dev server terminal.

---

## Testing Desktop Target

### Test 1: Desktop Dev Mode (Hot Reload)

```bash
jac start main.jac --client desktop --dev
```

**Expected Behavior:**
1. Vite dev server starts on port 5173
2. Tauri dev window opens automatically
3. App loads in the native window
4. Counter buttons work
5. Hot reload works (edit `main.jac`, changes appear in window)

**Verify:**
- Window has native title bar
- Window is resizable
- App content displays correctly
- Buttons are clickable
- Console logs appear in terminal

**Stop:** Press `Ctrl+C` (both Vite and Tauri will stop)

### Test 2: Desktop Production Mode (Built Bundle)

```bash
jac start main.jac --client desktop
```

**Expected Behavior:**
1. Web bundle is built first
2. `index.html` is generated
3. Tauri window opens with built bundle
4. App works correctly (no dev server)

**Verify:**
- Window opens with built app
- All functionality works
- No network requests (everything is bundled)

**Stop:** Press `Ctrl+C`

### Test 3: Desktop Build (Full Build)

```bash
# Clean previous builds (optional)
rm -rf src-tauri/target

# Build desktop target
jac build main.jac --client desktop
```

**Expected Output:**
```
🖥️  Building desktop app (Tauri)
  Step 1: Building web bundle...
  ✔ Web bundle built: .jac/client/dist/
  Step 1.5: Bundling sidecar (Jac backend)...
  Running PyInstaller...
  ✔ Sidecar bundled: src-tauri/binaries/jac-sidecar
  Step 2: Updating Tauri configuration...
  ✔ Updated tauri.conf.json
  Step 3: Building Tauri app...
  [Cargo build output...]
  ✔ Desktop build complete: src-tauri/target/release/bundle/
```

**This may take 5-15 minutes on first build** (Rust compilation).

**Verify Build Output:**
```bash
# Check sidecar was created
ls -lh src-tauri/binaries/
# Should show: jac-sidecar (or jac-sidecar.exe on Windows)

# Check Tauri config was updated
grep -A 3 "resources" src-tauri/tauri.conf.json
# Should show sidecar in resources array

# Check bundle was created
find src-tauri/target -name "*.AppImage" -o -name "*.exe" -o -name "*.dmg" | head -1
# Should find installer file
```

**Expected Bundle Locations:**
- **Linux:** `src-tauri/target/release/bundle/appimage/{app-name}_*.AppImage` (or `{app-name}.AppDir` if appimagetool is not installed)
- **Windows:** `src-tauri/target/x86_64-pc-windows-msvc/release/bundle/msi/{app-name}_*.exe`
- **macOS:** `src-tauri/target/aarch64-apple-darwin/release/bundle/dmg/{app-name}_*.dmg`

**Note:** Replace `{app-name}` with your actual project name from `jac.toml`. For example, if your project is named `my-jac-app`, the Linux AppImage will be `my-jac-app_*.AppImage` or `my-jac-app.AppDir`.

---

## Testing Sidecar Functionality

The sidecar is a bundled executable that provides the Jac backend API server.

### Test 1: Sidecar Execution

```bash
# Run sidecar directly
./src-tauri/binaries/jac-sidecar --module-path main.jac --port 8002
```

**Expected Output:**
```
Jac Sidecar starting...
  Module: main
  Base path: /tmp/my-desktop-app
  Server: http://127.0.0.1:8002

Press Ctrl+C to stop the server
```

**In another terminal, test the API:**
```bash
# Test root endpoint
curl http://localhost:8002/

# Test functions endpoint
curl http://localhost:8002/functions

# Test walkers endpoint
curl http://localhost:8002/walkers
```

**Expected:**
- All endpoints return valid JSON
- No "No module named 'jaclang'" errors
- Server responds correctly

**Stop:** Press `Ctrl+C` in the sidecar terminal

### Test 2: Sidecar with Backend Code

Create a more complete example with backend functions:

**Update `main.jac`:**
```jac
"""Main entry point with backend functions."""

# Backend function
def:pub greet(name: str) -> str {
    return f"Hello, {name}!";
}

def:pub add(a: int, b: int) -> int {
    return a + b;
}

# Client-side component
cl import from react { useEffect }
cl import from '@jac-client/utils' { jacSpawn }

cl {
    def:pub app() -> any {
        has count: int = 0;
        has greeting: str = "";
        has result: int = 0;

        async def testBackend() -> None {
            # Test function call
            greet_result = await jacSpawn("greet", "", {"name": "Desktop User"});
            greeting = greet_result.data;
            
            add_result = await jacSpawn("add", "", {"a": 5, "b": 3});
            result = add_result.data;
        }

        useEffect(lambda -> None {
            testBackend();
        }, []);

        return <div style={{
            padding: "2rem",
            fontFamily: "Arial, sans-serif",
            maxWidth: "800px",
            margin: "0 auto"
        }}>
            <h1>Desktop App with Backend</h1>
            <p>Count: {count}</p>
            <p>Greeting: {greeting}</p>
            <p>5 + 3 = {result}</p>
            <button
                onClick={lambda -> None { count = count + 1; }}
                style={{padding: "0.5rem 1rem", fontSize: "1rem", cursor: "pointer"}}
            >
                Increment
            </button>
        </div>;
    }
}
```

**Rebuild sidecar:**
```bash
# Clean old sidecar
rm -rf src-tauri/binaries/jac-sidecar*

# Rebuild
jac build main.jac --client desktop
```

**Test sidecar with functions:**
```bash
# Start sidecar
./src-tauri/binaries/jac-sidecar --module-path main.jac --port 8003 &

# Wait a moment
sleep 2

# Test function endpoints
curl -X POST http://localhost:8003/function/greet \
  -H "Content-Type: application/json" \
  -d '{"name": "World"}'

curl -X POST http://localhost:8003/function/add \
  -H "Content-Type: application/json" \
  -d '{"a": 10, "b": 20}'

# Stop sidecar
pkill -f jac-sidecar
```

**Expected:**
- `greet` returns: `{"data": "Hello, World!"}`
- `add` returns: `{"data": 30}`
- No compilation errors

---

## Full Build and Distribution

### Step 1: Clean Build

```bash
# Clean everything
rm -rf .jac/client/dist
rm -rf src-tauri/target
rm -rf src-tauri/binaries/jac-sidecar*

# Full rebuild
jac build main.jac --client desktop
```

### Step 2: Test the Built App

**Linux:**

Tauri creates an `AppDir` directory, but to create the final `.AppImage` file, you need `appimagetool` installed.

**Option 1: Install appimagetool (recommended)**

```bash
# Download and install appimagetool
wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage
chmod +x appimagetool-x86_64.AppImage
sudo mv appimagetool-x86_64.AppImage /usr/local/bin/appimagetool

# Or on Ubuntu/Debian, you can install from the package manager:
# sudo apt-get install appimagetool
```

After installing `appimagetool`, rebuild:
```bash
jac build main.jac --client desktop --platform linux
```

**Option 2: Manually create AppImage from AppDir**

If the build only created the `AppDir` (not the `.AppImage`), you can create it manually:

```bash
# Navigate to the appimage directory
cd src-tauri/target/release/bundle/appimage

# Create AppImage using appimagetool
appimagetool my-jac-app.AppDir my-jac-app.AppImage

# Make it executable
chmod +x my-jac-app.AppImage

# Run the AppImage
./my-jac-app.AppImage
```

**Note:** The AppImage file will be named based on your app's name from `jac.toml` (e.g., `my-jac-app.AppImage`), not `my-desktop-app_*.AppImage`.

### Step 3: Test the Sidecar from the Executable

The sidecar is bundled with the desktop app and **automatically starts** when you launch the app! However, you can also test it manually if needed.

**For Linux (AppImage):**

```bash
# Extract the AppImage to access bundled resources
./my-jac-app.AppImage --appimage-extract

# The sidecar is in the extracted AppDir
cd squashfs-root

# Find the sidecar (it's in the resources directory)
find . -name "jac-sidecar*" -type f

# Run the sidecar (adjust path based on your app structure)
# The sidecar is typically in usr/bin/ or the resources directory
./usr/bin/jac-sidecar --module-path main.jac --port 8000

# Or if it's a wrapper script:
./usr/bin/jac-sidecar.sh --module-path main.jac --port 8000
```

**Alternative: Access from AppDir (before creating AppImage):**

```bash
# If you only have the AppDir, the sidecar is in the resources
cd src-tauri/target/release/bundle/appimage/my-jac-app.AppDir

# The sidecar should be accessible here (check the structure)
# It's bundled as a resource, so it might be in usr/bin/ or similar
find . -name "jac-sidecar*" -type f

# Run it
./usr/bin/jac-sidecar --module-path main.jac --port 8000
```

**Automatic Sidecar Startup:**

When you launch the desktop app (AppImage, .exe, or .dmg), the sidecar automatically starts in the background. You can immediately test the API:

**Test the sidecar API (automatic startup):**

Since the sidecar starts automatically, you can test it right away:

```bash
# Test root endpoint
curl http://localhost:8000/

# Test functions endpoint
curl http://localhost:8000/functions

# Test walkers endpoint  
curl http://localhost:8000/walkers

# Test a function call (if you have functions defined)
curl -X POST http://localhost:8000/function/greet \
  -H "Content-Type: application/json" \
  -d '{"name": "World"}'
```

**Note:** The sidecar now **automatically starts** when you open the desktop app! The Tauri app is configured to:
1. Find the bundled sidecar executable in resources
2. Launch it as a background process on app startup
3. Stop it when the app closes

If the sidecar fails to start automatically, check the console output for error messages. The app will continue to run even if the sidecar doesn't start (it will just show a warning).

**Windows:**
```bash
# Run the installer
.\src-tauri\target\x86_64-pc-windows-msvc\release\bundle\msi\my-desktop-app_*.exe
```

**macOS:**
```bash
# Open the DMG
open src-tauri/target/aarch64-apple-darwin/release/bundle/dmg/my-desktop-app_*.dmg
```

**Expected:**
- App installs/opens correctly
- Window opens with your app
- All functionality works
- Sidecar is included (if bundled)

### Step 3: Verify Bundle Contents

**Linux:**
```bash
# Extract and inspect AppImage (optional)
./my-desktop-app_*.AppImage --appimage-extract
ls -la squashfs-root/
# Should show: usr/bin/my-desktop-app, usr/lib/, etc.
```

**Verify sidecar is included:**
```bash
# Check if sidecar is in the bundle
find squashfs-root -name "jac-sidecar"
# Should find the sidecar executable
```

---

## Verification Checklist

Use this checklist to verify everything is working:

### ✅ Prerequisites
- [ ] Python 3.12+ installed
- [ ] `jaclang` installed and working
- [ ] `jac-client` installed and working
- [ ] `pyinstaller` installed
- [ ] Rust toolchain installed
- [ ] Tauri CLI installed
- [ ] System dependencies installed (Linux)

### ✅ Project Setup
- [ ] Fresh project directory created
- [ ] `main.jac` file created with valid Jac code
- [ ] `jac.toml` created with project config
- [ ] Jac code compiles without errors

### ✅ Desktop Target Setup
- [ ] `jac setup desktop` runs successfully
- [ ] `src-tauri/` directory created
- [ ] `tauri.conf.json` generated correctly
- [ ] `Cargo.toml` generated correctly
- [ ] `build.rs` and `main.rs` generated
- [ ] Icon created
- [ ] `jac.toml` updated with `[desktop]` section

### ✅ Web Target (Baseline)
- [ ] `jac build --client web` works
- [ ] Web bundle created in `.jac/client/dist/`
- [ ] `index.html` generated correctly
- [ ] Web dev server works (`jac start --dev`)
- [ ] App displays correctly in browser

### ✅ Desktop Dev Mode
- [ ] `jac start --client desktop --dev` works
- [ ] Vite dev server starts on port 5173
- [ ] Tauri dev window opens
- [ ] App displays correctly in window
- [ ] Hot reload works (edit file, see changes)
- [ ] Buttons/interactions work

### ✅ Desktop Production Mode
- [ ] `jac start --client desktop` works
- [ ] Web bundle is built first
- [ ] Tauri window opens with built bundle
- [ ] App works without dev server

### ✅ Desktop Build
- [ ] `jac build --client desktop` completes successfully
- [ ] Sidecar bundles correctly (if PyInstaller available)
- [ ] `jac-sidecar` executable created in `src-tauri/binaries/`
- [ ] Tauri config updated with sidecar in resources
- [ ] Final bundle/installer created
- [ ] Build output is in expected location

### ✅ Sidecar Functionality
- [ ] Sidecar executable runs without errors
- [ ] Sidecar can compile Jac code
- [ ] Sidecar starts HTTP server
- [ ] API endpoints respond correctly (`/`, `/functions`, `/walkers`)
- [ ] Function endpoints work (`/function/<name>`)
- [ ] No "No module named 'jaclang'" errors

### ✅ Full Integration
- [ ] Built app can be installed/run
- [ ] App window opens correctly
- [ ] All UI elements work
- [ ] Backend functions work (if implemented)
- [ ] Sidecar is included in bundle (if bundled)

---

## Troubleshooting

### Issue: `jac setup desktop` fails

**Symptoms:**
- Error about missing Rust/Cargo
- Error about missing system dependencies

**Solutions:**
1. Verify Rust is installed: `cargo --version`
2. Install system dependencies (see Prerequisites)
3. Check Tauri CLI: `cargo tauri --version`
4. Try installing Tauri CLI: `cargo install tauri-cli`

### Issue: Sidecar shows "No module named 'jaclang'"

**Symptoms:**
- Sidecar fails to start
- Error about missing jaclang module

**Solutions:**
1. Verify `jaclang` is installed: `python3 -c "import jaclang; print(jaclang.__file__)"`
2. Rebuild sidecar: `rm -rf src-tauri/binaries/jac-sidecar* && jac build --client desktop`
3. Check PyInstaller output for warnings
4. Ensure you're using the same Python environment for building and running

### Issue: Desktop build fails with Rust errors

**Symptoms:**
- Cargo build errors
- Missing dependencies

**Solutions:**
1. Update Rust: `rustup update`
2. Check `Cargo.toml` is valid
3. Try `cargo clean` in `src-tauri/` directory
4. Check Tauri version compatibility

### Issue: Tauri window doesn't open

**Symptoms:**
- Build succeeds but no window appears
- Process starts but exits immediately

**Solutions:**
1. Check Tauri logs in terminal
2. Verify `tauri.conf.json` is valid JSON
3. Check window configuration in `tauri.conf.json`
4. Try running `cargo tauri dev` directly in `src-tauri/` directory

### Issue: Hot reload doesn't work

**Symptoms:**
- Changes to `main.jac` don't appear in window
- Dev server doesn't detect changes

**Solutions:**
1. Verify Vite dev server is running (check terminal output)
2. Check file watcher permissions
3. Try restarting dev server
4. Check for file system errors

### Issue: Sidecar API endpoints don't work

**Symptoms:**
- Sidecar starts but endpoints return errors
- Functions/walkers not found

**Solutions:**
1. Verify `.jac` file has `def:pub` functions or `walker` definitions
2. Check module path is correct: `--module-path main.jac`
3. Check sidecar logs for compilation errors
4. Test with a simple function first

### Issue: Build output not found

**Symptoms:**
- Build completes but can't find installer

**Solutions:**
1. Check platform-specific output location:
   - Linux: `src-tauri/target/release/bundle/appimage/`
   - Windows: `src-tauri/target/x86_64-pc-windows-msvc/release/bundle/msi/`
   - macOS: `src-tauri/target/aarch64-apple-darwin/release/bundle/dmg/`
2. Use `find` command: `find src-tauri/target -name "*.AppImage" -o -name "*.exe" -o -name "*.dmg"`
3. Check build logs for actual output path

---

## Quick Test Summary

For a quick smoke test, run these commands in order:

```bash
# 1. Create fresh project
mkdir test-desktop && cd test-desktop
# Create main.jac and jac.toml (see examples above)

# 2. Setup desktop
jac setup desktop

# 3. Test web target (baseline)
jac build main.jac --client web
ls .jac/client/dist/

# 4. Test desktop dev
jac start main.jac --client desktop --dev
# (Verify window opens, then Ctrl+C)

# 5. Test desktop production
jac start main.jac --client desktop
# (Verify window opens, then Ctrl+C)

# 6. Build desktop
jac build main.jac --client desktop

# 7. Test sidecar
./src-tauri/binaries/jac-sidecar --module-path main.jac --port 8002 &
sleep 2
curl http://localhost:8002/
pkill -f jac-sidecar

# 8. Verify bundle
find src-tauri/target -name "*.AppImage" -o -name "*.exe" -o -name "*.dmg" | head -1
```

**If all these pass, everything is working! ✅**

---

## Additional Resources

- **Architecture Documentation:** See `multi-target-architecture.md`
- **Verification Guide:** See `VERIFICATION_GUIDE.md` (for existing projects)
- **Desktop Target Docs:** See `jac_client/docs/multi-targets/desktop-target.md`
- **Tauri Documentation:** https://tauri.app/

---

## Success Criteria

✅ **Everything is working if:**

1. ✅ Fresh project can be created and configured
2. ✅ `jac setup desktop` creates all required files
3. ✅ Web target still works (no regressions)
4. ✅ Desktop dev mode opens window with hot reload
5. ✅ Desktop production mode opens window with built bundle
6. ✅ Desktop build creates installer/bundle
7. ✅ Sidecar bundles and runs correctly
8. ✅ Sidecar can compile and serve Jac code
9. ✅ Built app can be installed and run
10. ✅ All functionality works in final bundle

---

**Happy testing! 🚀**

