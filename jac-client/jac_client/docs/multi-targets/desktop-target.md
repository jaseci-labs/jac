# Desktop Target

The **desktop target** wraps your web application in a native desktop window using Tauri. Your Jac code runs in a webview, but users get a native desktop experience.

---

## Overview

The desktop target creates native desktop applications that can be distributed as installers for Windows, macOS, and Linux.

**Features:**

- ✅ Native desktop applications
- ✅ Cross-platform (Windows, macOS, Linux)
- ✅ Small bundle size (uses system webview)
- ✅ Hot reload in dev mode
- ✅ Production builds create installers

---

## Prerequisites

### Install Rust

Visit [https://rustup.rs](https://rustup.rs) and follow the installation instructions, or run:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

Verify installation:

```bash
rustc --version
cargo --version
```

### Install Build Tools

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

### Install System Dependencies (Linux)

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

---

## Getting Started

### Step 1: Setup Desktop Target

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

### Step 2: Development Mode

Start developing with hot reload:

```bash
jac start main.jac --client desktop --dev
```

This will:

1. Start a Vite dev server on port 5173
2. Launch Tauri dev window
3. Enable hot module replacement (HMR)
4. Show your app with live reload

**Press `Ctrl+C` to stop.**

### Step 3: Production Mode

Test with built bundle (production-like):

```bash
jac start main.jac --client desktop
```

This will:

1. Build the web bundle
2. Generate `index.html`
3. Launch Tauri with the built bundle

**Press `Ctrl+C` to stop.**

### Step 4: Build for Distribution

Create platform-specific installers:

```bash
jac build main.jac --client desktop
```

This creates installers in `src-tauri/target/release/bundle/`:

- **Windows**: `.exe` installer
- **macOS**: `.dmg` or `.app` bundle
- **Linux**: `.AppImage`, `.deb`, or `.rpm`

---

## Platform-Specific Builds

### Building for Windows

```bash
jac build main.jac --client desktop --platform windows
```

**Output:** `.exe` installer in `src-tauri/target/x86_64-pc-windows-msvc/release/bundle/`

### Building for macOS

```bash
jac build main.jac --client desktop --platform macos
```

**Output:** `.dmg` or `.app` bundle in `src-tauri/target/aarch64-apple-darwin/release/bundle/` (or `x86_64-apple-darwin` for Intel)

### Building for Linux

```bash
jac build main.jac --client desktop --platform linux
```

**Output:** `.AppImage`, `.deb`, or `.rpm` in `src-tauri/target/x86_64-unknown-linux-gnu/release/bundle/`

### Building for All Platforms

```bash
jac build main.jac --client desktop --platform all
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
jac build main.jac --client web
jac start main.jac --client desktop
```

### Port 5173 already in use

Change the Vite port in the dev configuration, or stop the process using port 5173.

### Build takes too long

- First build compiles Rust dependencies (can take 5-10 minutes)
- Subsequent builds are faster (only your code changes)

---

## Best Practices

### 1. Use Dev Mode for Development

Always use `--dev` flag during development for hot reload:

```bash
jac start main.jac --client desktop --dev
```

### 2. Test Production Builds

Before distributing, test the production build:

```bash
jac start main.jac --client desktop  # No --dev flag
```

### 3. Customize Window Size

Edit `src-tauri/tauri.conf.json` to set appropriate window dimensions for your app.

### 4. Add App Icon

Replace `src-tauri/icons/icon.png` with your app icon (recommended: 512x512px PNG).

### 5. Version Management

Update version in both `jac.toml` and `src-tauri/tauri.conf.json` for consistency.

---

## Distribution

### Testing the Installer

**Linux (.AppImage):**

```bash
chmod +x src-tauri/target/release/bundle/*.AppImage
./src-tauri/target/release/bundle/*.AppImage
```

**Linux (.deb):**

```bash
sudo dpkg -i src-tauri/target/release/bundle/*.deb
```

**Windows:**
Double-click the `.exe` file to install.

**macOS:**
Open the `.dmg` and drag the app to Applications.

### Distributing Your App

After building, distribute the installer files from `src-tauri/target/release/bundle/`:

- Share the installer file with users
- Upload to app stores (if applicable)
- Host on your website for download

---

## FAQ

**Q: Can I use the same codebase for web and desktop?**
A: Yes! The same Jac code works for both targets. The build system handles the differences.

**Q: Do I need separate builds for each platform?**
A: For production, yes. Use `--platform` flag to build for specific platforms. For development, Tauri automatically uses your current platform.

**Q: Can I customize the Tauri window?**
A: Yes! Edit `src-tauri/tauri.conf.json` to customize window size, title, and other properties.

**Q: How do I distribute my desktop app?**
A: After building with `jac build --client desktop`, distribute the installer files from `src-tauri/target/release/bundle/`.

**Q: Can I use backend features in desktop apps?**
A: Yes! Desktop apps can use the same backend features (walkers, nodes, etc.) as web apps.

**Q: What's the difference between `--dev` and without it?**
A: `--dev` uses a Vite dev server with hot reload. Without it, builds the web bundle first and uses the static files.

**Q: Can I build for a different platform than I'm running on?**
A: Yes, but it requires cross-compilation setup. Use `--platform` flag to specify the target platform.

---

## Next Steps

- **[Web Target Guide](web-target.md)**: Learn about web builds
- **[Routing](../routing.md)**: Add multi-page navigation to your desktop app
- **[Advanced State](../advanced-state.md)**: Manage complex state in desktop apps
- **[Imports](../imports.md)**: Use third-party libraries in desktop builds
- **[Styling](../styling/)**: Style your desktop app with CSS or Tailwind

---

Happy building! 🖥️
