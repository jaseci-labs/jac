"""Implementation of DesktopTarget methods."""
import from pathlib { Path }
import from typing { Optional, Any }
import from jaclang.cli.console { console }
import from jaclang.project.config { get_config }
import subprocess;
import json;
import shutil;
import os;
import platform;

"""Setup desktop target - scaffold Tauri project structure."""
impl DesktopTarget.setup(self: DesktopTarget, project_dir: Path) -> None {
    console.print("\n🖥️  Setting up desktop target (Tauri)", style="bold");
    console.print(f"  Project directory: {project_dir}", style="muted");
    
    # Check if already set up
    tauri_dir = project_dir / "src-tauri";
    if tauri_dir.exists() {
        console.warning("Desktop target already set up. Skipping...");
        return;
    }
    
    # Get project config
    config = get_config();
    if not config {
        raise RuntimeError("No jac.toml found");
    }
    
    project_name = config.project.name or "my-jac-app";
    project_version = config.project.version or "1.0.0";
    console.print(f"  Project name: {project_name}, version: {project_version}", style="muted");
    
    # Generate identifier from project name
    identifier = _generate_identifier(project_name);
    console.print(f"  Identifier: {identifier}", style="muted");
    
    # Create src-tauri directory structure
    console.print("  Creating src-tauri/ directory structure...", style="muted");
    try {
        tauri_dir.mkdir(parents=True, exist_ok=True);
        (tauri_dir / "src").mkdir(exist_ok=True);
        (tauri_dir / "binaries").mkdir(exist_ok=True);
        console.print(f"  ✔ Created {tauri_dir}", style="success");
    } except Exception as e {
        raise RuntimeError(f"Failed to create src-tauri directory: {e}");
    }
    
    # Generate tauri.conf.json
    try {
        _generate_tauri_config(tauri_dir, project_name, identifier, project_version);
    } except Exception as e {
        raise RuntimeError(f"Failed to generate tauri.conf.json: {e}");
    }
    
    # Generate Cargo.toml
    try {
        _generate_cargo_toml(tauri_dir, project_name, identifier);
    } except Exception as e {
        raise RuntimeError(f"Failed to generate Cargo.toml: {e}");
    }
    
    # Generate build.rs
    try {
        _generate_build_rs(tauri_dir);
    } except Exception as e {
        raise RuntimeError(f"Failed to generate build.rs: {e}");
    }
    
    # Generate icons
    try {
        _generate_default_icons(tauri_dir);
    } except Exception as e {
        raise RuntimeError(f"Failed to generate icons: {e}");
    }
    
    # Generate main.rs
    try {
        _generate_main_rs(tauri_dir);
    } except Exception as e {
        raise RuntimeError(f"Failed to generate main.rs: {e}");
    }
    
    # Add [desktop] section to jac.toml
    try {
        _add_desktop_config(project_dir, project_name, identifier, project_version);
    } except Exception as e {
        raise RuntimeError(f"Failed to add [desktop] section to jac.toml: {e}");
    }
    
    # Check Rust toolchain
    _check_rust_toolchain();
    
    # Check Linux system dependencies
    _check_linux_dependencies();
    
    # Check/install Tauri CLI
    _check_tauri_cli();
    
    console.success("Desktop target setup complete!");
    console.print("\nNext steps:", style="bold");
    console.print("  1. Build: jac build main.jac --target desktop");
    console.print("  2. Dev:   jac start main.jac --target desktop");
}

"""Generate identifier from project name."""
def _generate_identifier(name: str) -> str {
    # Convert to lowercase, replace spaces/special chars with dots
    identifier = name.lower();
    identifier = identifier.replace(" ", ".");
    identifier = identifier.replace("_", ".");
    identifier = identifier.replace("-", ".");
    # Remove invalid characters (keep only alphanumeric and dots)
    filtered = "";
    for char in identifier {
        if char.isalnum() or char == "." {
            filtered += char;
        }
    }
    identifier = filtered;
    # Ensure it starts with a letter
    if identifier and not identifier[0].isalpha() {
        identifier = "com." + identifier;
    }
    # Default if empty
    if not identifier {
        identifier = "com.example.myapp";
    }
    return identifier;
}

"""Generate tauri.conf.json."""
def _generate_tauri_config(tauri_dir: Path, name: str, identifier: str, version: str) -> None {
    config = {
        "productName": name,
        "version": version,
        "identifier": identifier,
        "build": {
            "devUrl": "http://localhost:5173",
            "frontendDist": "../.jac/client/dist"
        },
        "app": {
            "windows": [
                {
                    "title": name,
                    "width": 1200,
                    "height": 800,
                    "minWidth": 800,
                    "minHeight": 600,
                    "resizable": True,
                    "fullscreen": False
                }
            ],
            "security": {
                "csp": None
            }
        },
        "bundle": {
            "active": True,
            "targets": "all",
            "icon": []
        },
        "plugins": {}
    };
    
    config_path = tauri_dir / "tauri.conf.json";
    with open(config_path, "w") as f {
        json.dump(config, f, indent=2);
    }
    try {
        rel_path = config_path.relative_to(tauri_dir.parent);
        console.print(f"  ✔ Generated {rel_path}", style="success");
    } except ValueError {
        console.print(f"  ✔ Generated {config_path.name}", style="success");
    }
}

"""Generate Cargo.toml."""
def _generate_cargo_toml(tauri_dir: Path, name: str, identifier: str) -> None {
    # Sanitize name for Cargo (Rust package names)
    cargo_name = name.lower().replace(" ", "-").replace("_", "-");
    cargo_name = "".join(c if c.isalnum() or c == "-" else "" for c in cargo_name);
    if not cargo_name {
        cargo_name = "my-jac-app";
    }
    
    cargo_toml = f'''[package]
name = "{cargo_name}"
version = "0.1.0"
description = "A Tauri desktop app built with Jac"
authors = ["you"]
license = ""
repository = ""
edition = "2021"

[build-dependencies]
tauri-build = {{ version = "2.0", features = [] }}

[dependencies]
tauri = {{ version = "2.0", features = [] }}
serde = {{ version = "1", features = ["derive"] }}
serde_json = "1"

[features]
# This feature is used for production builds or when `devPath` points to the filesystem
custom-protocol = ["tauri/custom-protocol"]
''';
    
    cargo_path = tauri_dir / "Cargo.toml";
    with open(cargo_path, "w") as f {
        f.write(cargo_toml);
    }
    try {
        rel_path = cargo_path.relative_to(tauri_dir.parent);
        console.print(f"  ✔ Generated {rel_path}", style="success");
    } except ValueError {
        console.print(f"  ✔ Generated {cargo_path.name}", style="success");
    }
}

"""Generate build.rs (required for Tauri v2)."""
def _generate_build_rs(tauri_dir: Path) -> None {
    build_rs = '''fn main() {
    tauri_build::build()
}
''';
    
    build_path = tauri_dir / "build.rs";
    with open(build_path, "w") as f {
        f.write(build_rs);
    }
    try {
        rel_path = build_path.relative_to(tauri_dir.parent);
        console.print(f"  ✔ Generated {rel_path}", style="success");
    } except ValueError {
        console.print(f"  ✔ Generated build.rs", style="success");
    }
}

"""Generate default placeholder icons for Tauri."""
def _generate_default_icons(tauri_dir: Path) -> None {
    icons_dir = tauri_dir / "icons";
    icons_dir.mkdir(exist_ok=True);
    
    # Create a minimal 1x1 PNG icon as placeholder
    # This is a base64-encoded minimal PNG (1x1 transparent pixel)
    # PNG header + minimal IHDR + IEND chunks
    minimal_png = bytes([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A,  # PNG signature
        0x00, 0x00, 0x00, 0x0D,  # IHDR chunk length
        0x49, 0x48, 0x44, 0x52,  # IHDR
        0x00, 0x00, 0x00, 0x01,  # width = 1
        0x00, 0x00, 0x00, 0x01,  # height = 1
        0x08, 0x06, 0x00, 0x00, 0x00,  # bit depth, color type, etc.
        0x1F, 0x15, 0xC4, 0x89,  # CRC
        0x00, 0x00, 0x00, 0x0A,  # IDAT chunk length
        0x49, 0x44, 0x41, 0x54,  # IDAT
        0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, 0x05, 0x00, 0x01,  # minimal zlib data
        0x0D, 0x0A, 0x2D, 0xB4,  # CRC
        0x00, 0x00, 0x00, 0x00,  # IEND chunk length
        0x49, 0x45, 0x4E, 0x44,  # IEND
        0xAE, 0x42, 0x60, 0x82   # CRC
    ]);
    
    # Write icon.png (Tauri will use this and generate other sizes if needed)
    icon_path = icons_dir / "icon.png";
    with open(icon_path, "wb") as f {
        f.write(minimal_png);
    }
    
    console.print("  ✔ Generated default icons", style="success");
    console.warning("  Note: Replace icons/icon.png with your app icon (1024x1024 PNG recommended)");
}

"""Generate main.rs."""
def _generate_main_rs(tauri_dir: Path) -> None {
    main_rs = '''// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

fn main() {
    tauri::Builder::default()
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
''';
    
    main_path = tauri_dir / "src" / "main.rs";
    with open(main_path, "w") as f {
        f.write(main_rs);
    }
    try {
        rel_path = main_path.relative_to(tauri_dir.parent);
        console.print(f"  ✔ Generated {rel_path}", style="success");
    } except ValueError {
        console.print(f"  ✔ Generated src/main.rs", style="success");
    }
}

"""Add [desktop] section to jac.toml."""
def _add_desktop_config(project_dir: Path, name: str, identifier: str, version: str) -> None {
    # Read existing jac.toml
    jac_toml_path = project_dir / "jac.toml";
    if not jac_toml_path.exists() {
        raise RuntimeError("jac.toml not found");
    }
    
    # Read current content
    with open(jac_toml_path, "r") as f {
        content = f.read();
    }
    
    # Check if [desktop] section already exists
    if "[desktop]" in content {
        console.warning("  [desktop] section already exists in jac.toml. Skipping...");
        return;
    }
    
    # Append [desktop] section
    desktop_section = f'''

# Desktop target configuration (Tauri)
[desktop]
name = "{name}"
identifier = "{identifier}"
version = "{version}"

[desktop.window]
title = "{name}"
width = 1200
height = 800
min_width = 800
min_height = 600
resizable = true
fullscreen = false

[desktop.platforms]
windows = true
macos = true
linux = true

[desktop.features]
system_tray = false
auto_update = false
notifications = false
''';
    
    # Append the section
    with open(jac_toml_path, "a") as f {
        f.write(desktop_section);
    }
    console.print("  ✔ Added [desktop] section to jac.toml", style="success");
}

"""Check if Rust toolchain is installed."""
def _check_rust_toolchain() -> None {
    try {
        result = subprocess.run(
            ["rustc", "--version"],
            capture_output=True,
            text=True,
            timeout=5
        );
        if result.returncode == 0 {
            version = result.stdout.strip();
            console.print(f"  ✔ Rust toolchain found: {version}", style="success");
            return;
        }
    } except Exception {
        console.warning("  Rust toolchain not found");
        console.print("  Install Rust: https://rustup.rs/", style="muted");
        console.print("  Or run: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh", style="muted");
    }
}

"""Check if Linux system dependencies are installed (for Tauri on Linux)."""
def _check_linux_dependencies() -> None {
    import platform;
    if platform.system() != "Linux" {
        return;  # Only check on Linux
    }
    
    # Check pkg-config
    try {
        subprocess.run(["pkg-config", "--version"], capture_output=True, check=True, timeout=5);
        console.print("  ✔ pkg-config found", style="success");
    } except Exception {
        console.warning("  pkg-config not found");
        console.print("  Install system dependencies:", style="muted");
        console.print("    Ubuntu/Debian: sudo apt-get install libwebkit2gtk-4.1-dev build-essential curl wget libssl-dev libgtk-3-dev libayatana-appindicator3-dev librsvg2-dev", style="muted");
        console.print("    Fedora: sudo dnf install webkit2gtk3-devel.x86_64 openssl-devel curl wget libappindicator-gtk3 librsvg2-devel", style="muted");
        console.print("    Arch: sudo pacman -S webkit2gtk base-devel curl wget openssl appmenu-gtk-module gtk3 libappindicator-gtk3 librsvg libvips", style="muted");
        return;
    }
    
    # Check for GTK libraries (basic check)
    try {
        result = subprocess.run(
            ["pkg-config", "--exists", "webkit2gtk-4.1"],
            capture_output=True,
            timeout=5
        );
        if result.returncode == 0 {
            console.print("  ✔ GTK/WebKit libraries found", style="success");
        } else {
            console.warning("  GTK/WebKit libraries not found");
            console.print("  Install system dependencies:", style="muted");
            console.print("    Ubuntu/Debian: sudo apt-get install libwebkit2gtk-4.1-dev build-essential curl wget libssl-dev libgtk-3-dev libayatana-appindicator3-dev librsvg2-dev", style="muted");
        }
    } except Exception {
        console.warning("  Could not verify GTK libraries");
    }
}

"""Check if Tauri CLI is installed."""
def _check_tauri_cli() -> None {
    try {
        result = subprocess.run(
            ["npm", "list", "-g", "@tauri-apps/cli"],
            capture_output=True,
            text=True,
            timeout=5
        );
        if result.returncode == 0 {
            console.print("  ✔ Tauri CLI found", style="success");
            return;
        }
    } except Exception {    
        console.warning("  Tauri CLI not found globally");
        console.print("  It will be installed automatically when needed", style="muted");
        console.print("  Or install manually: npm install -g @tauri-apps/cli", style="muted");
    }
}

"""Build desktop app - build web bundle first, then wrap with Tauri."""
impl DesktopTarget.build(
    self: DesktopTarget,
    entry_file: Path,
    project_dir: Path,
    platform: Optional[str] = None
) -> Path {
    import from jac_client.plugin.src.targets.WebTarget { WebTarget }
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    
    console.print("\n🖥️  Building desktop app (Tauri)", style="bold");
    
    # Check if setup has been run
    tauri_dir = project_dir / "src-tauri";
    if not tauri_dir.exists() {
        raise RuntimeError("Desktop target not set up. Run 'jac setup desktop' first.");
    }
    
    # Step 1: Build web bundle first (reuse existing pipeline)
    console.print("  Step 1: Building web bundle...", style="muted");
    web_target = WebTarget();
    web_bundle_path = web_target.build(entry_file, project_dir, platform);
    console.print(f"  ✔ Web bundle built: {web_bundle_path}", style="success");
    
    # Step 2: Update tauri.conf.json to point to web bundle
    console.print("  Step 2: Updating Tauri configuration...", style="muted");
    _update_tauri_config_for_build(tauri_dir, project_dir, web_bundle_path);
    
    # Step 3: Run cargo tauri build
    console.print("  Step 3: Building Tauri app...", style="muted");
    bundle_path = _run_tauri_build(tauri_dir, platform);
    
    console.success(f"Desktop app built successfully!");
    console.print(f"  Output: {bundle_path}", style="muted");
    return bundle_path;
}

"""Update tauri.conf.json to point to the built web bundle."""
def _update_tauri_config_for_build(tauri_dir: Path, project_dir: Path, web_bundle_path: Path) -> None {
    import json;
    
    config_path = tauri_dir / "tauri.conf.json";
    if not config_path.exists() {
        raise RuntimeError("tauri.conf.json not found. Run 'jac setup desktop' first.");
    }
    
    # Read existing config
    with open(config_path, "r") as f {
        config = json.load(f);
    }
    
    # Calculate relative path from tauri_dir to dist directory (not the bundle file)
    # web_bundle_path is the JS file, but frontendDist needs the directory containing index.html
    dist_dir = web_bundle_path.parent;
    
    try {
        # Dist directory is typically in .jac/client/dist
        # Relative to src-tauri, that's ../.jac/client/dist
        dist_relative = dist_dir.relative_to(project_dir);
        dist_relative_str = "../" + str(dist_relative.as_posix());
    } except ValueError {
        # If paths don't share a common root, use absolute path
        dist_relative_str = str(dist_dir.as_posix());
    }
    
    # Update build config (Tauri v2 structure)
    if "build" not in config {
        config["build"] = {};
    }
    # Tauri v2 uses 'frontendDist' to point to the directory containing index.html
    config["build"]["frontendDist"] = dist_relative_str;
    # Remove devUrl and other invalid properties
    if "devUrl" in config["build"] {
        del config["build"]["devUrl"];
    }
    if "devPath" in config["build"] {
        del config["build"]["devPath"];
    }
    if "distDir" in config["build"] {
        del config["build"]["distDir"];
    }
    if "withGlobalTauri" in config["build"] {
        del config["build"]["withGlobalTauri"];
    }
    # Clean up null values
    if "beforeBuildCommand" in config["build"] and config["build"]["beforeBuildCommand"] is None {
        del config["build"]["beforeBuildCommand"];
    }
    
    # Write updated config
    with open(config_path, "w") as f {
        json.dump(config, f, indent=2);
    }
    
    console.print("  ✔ Updated tauri.conf.json", style="success");
}

"""Run cargo tauri build and return path to bundle."""
def _run_tauri_build(tauri_dir: Path, platform: Optional[str] = None) -> Path {
    import os;
    
    # Determine target based on platform
    target = None;
    if platform == "windows" {
        target = "x86_64-pc-windows-msvc";
    } elif platform == "macos" {
        # Try to detect architecture
        if platform.machine() == "arm64" {
            target = "aarch64-apple-darwin";
        } else {
            target = "x86_64-apple-darwin";
        }
    } elif platform == "linux" {
        target = "x86_64-unknown-linux-gnu";
    }
    
    # Build command
    build_cmd = ["npm", "run", "tauri", "build"];
    if target {
        build_cmd.extend(["--", "--target", target]);
    }
    
    # Check if package.json has tauri scripts, if not, use cargo directly
    package_json = tauri_dir.parent / "package.json";
    use_npm = False;
    if package_json.exists() {
        try {
            with open(package_json, "r") as f {
                package_data = json.load(f);
                scripts = package_data.get("scripts", {});
                if "tauri" in scripts or "tauri:build" in scripts {
                    use_npm = True;
                }
            }
        } except Exception {
            console.warning("  Failed to check package.json for tauri scripts");
        }
    }
    
    if not use_npm {
        # Use cargo tauri build directly
        build_cmd = ["cargo", "tauri", "build"];
        if target {
            build_cmd.extend(["--target", target]);
        }
    }
    
    # Change to tauri directory and run build
    original_cwd = os.getcwd();
    try {
        os.chdir(tauri_dir.parent);
        console.print(f"  Running: {' '.join(build_cmd)}", style="muted");
        
        result = subprocess.run(
            build_cmd,
            cwd=tauri_dir.parent,
            check=True,
            capture_output=False  # Show output to user
        );
    } finally {
        os.chdir(original_cwd);
    }
    
    # Find the bundle output
    # Tauri outputs to src-tauri/target/{target}/release/bundle/
    if target {
        bundle_dir = tauri_dir / "target" / target / "release" / "bundle";
    } else {
        bundle_dir = tauri_dir / "target" / "release" / "bundle";
    }
    
    if not bundle_dir.exists() {
        raise RuntimeError(f"Build completed but bundle not found at: {bundle_dir}");
    }
    
    # Find the actual bundle file (varies by platform)
    bundle_files = list(bundle_dir.rglob("*"));
    installers = [f for f in bundle_files if f.is_file() and f.suffix in [".exe", ".dmg", ".AppImage", ".deb", ".rpm", ".msi"]];
    
    if installers {
        return installers[0];
    }
    
    # Fallback: return the bundle directory
    return bundle_dir;
}

"""Start desktop dev server - start web dev server and launch tauri dev."""
impl DesktopTarget.dev(self: DesktopTarget, entry_file: Path, project_dir: Path) -> None {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    import signal;
    import sys;
    
    console.print("\n🖥️  Starting desktop dev server (Tauri)", style="bold");
    
    # Check if setup has been run
    tauri_dir = project_dir / "src-tauri";
    if not tauri_dir.exists() {
        raise RuntimeError("Desktop target not set up. Run 'jac setup desktop' first.");
    }
    
    # Step 1: Update tauri.conf.json for dev mode
    console.print("  Configuring Tauri for dev mode...", style="muted");
    _update_tauri_config_for_dev(tauri_dir);
    
    # Step 2: Start web dev server
    console.print("  Starting web dev server...", style="muted");
    vite_port = 5173;
    bundler = ViteBundler(
        project_dir=project_dir,
        output_dir=None,
        minify=False,
        config_path=None
    );
    
    # Create dev vite config
    dev_config_path = bundler.create_dev_vite_config(entry_file, api_port=8000);
    
    # Start Vite dev server
    vite_process = bundler.start_dev_server(port=vite_port);
    if not vite_process {
        raise RuntimeError("Failed to start Vite dev server");
    }
    console.print(f"  ✔ Web dev server running on http://localhost:{vite_port}", style="success");
    
    # Step 3: Launch tauri dev
    console.print("  Launching Tauri dev window...", style="muted");
    console.print("  (Press Ctrl+C to stop)", style="muted");
    
    # Setup signal handlers for cleanup
    def cleanup() -> None {
        console.print("\n  Stopping dev servers...", style="muted");
        if vite_process {
            try {
                vite_process.terminate();
                vite_process.wait(timeout=5);
            } except Exception {
                vite_process.kill();
            }
        }
        console.print("  ✔ Dev servers stopped", style="success");
    }
    
    def signal_handler(signum: int, frame: Any) -> None {
        cleanup();
        sys.exit(0);
    }
    
    signal.signal(signal.SIGINT, signal_handler);
    signal.signal(signal.SIGTERM, signal_handler);
    
    try {
        # Run tauri dev
        tauri_process = _run_tauri_dev(tauri_dir);
        
        # Wait for tauri process to finish
        tauri_process.wait();
    } except KeyboardInterrupt {
        console.print("\n  Keyboard interrupt detected. Stopping dev servers...", style="muted");
    } finally {
        cleanup();
    }
}

"""Update tauri.conf.json for dev mode (point to dev server)."""
def _update_tauri_config_for_dev(tauri_dir: Path) -> None {
    import json;
    
    config_path = tauri_dir / "tauri.conf.json";
    if not config_path.exists() {
        raise RuntimeError("tauri.conf.json not found. Run 'jac setup desktop' first.");
    }
    
    # Read existing config
    with open(config_path, "r") as f {
        config = json.load(f);
    }
    
    # Update build config for dev mode (Tauri v2 structure)
    if "build" not in config {
        config["build"] = {};
    }
    # Tauri v2 uses 'devUrl' instead of 'devPath'
    config["build"]["devUrl"] = "http://localhost:5173";
    # Remove distDir and other invalid properties
    if "distDir" in config["build"] {
        del config["build"]["distDir"];
    }
    if "devPath" in config["build"] {
        del config["build"]["devPath"];
    }
    if "withGlobalTauri" in config["build"] {
        del config["build"]["withGlobalTauri"];
    }
    # Keep only valid properties
    if "beforeDevCommand" in config["build"] and config["build"]["beforeDevCommand"] is None {
        del config["build"]["beforeDevCommand"];
    }
    if "beforeBuildCommand" in config["build"] and config["build"]["beforeBuildCommand"] is None {
        del config["build"]["beforeBuildCommand"];
    }
    
    # Write updated config
    with open(config_path, "w") as f {
        json.dump(config, f, indent=2);
    }
    
    console.print("  ✔ Updated tauri.conf.json for dev mode", style="success");
}

"""Run tauri dev command."""
def _run_tauri_dev(tauri_dir: Path) -> subprocess.Popen {
    # Check if cargo is available
    try {
        subprocess.run(["cargo", "--version"], capture_output=True, check=True, timeout=5);
    } except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired) {
        raise RuntimeError(
            "Rust/Cargo not found. Install Rust from https://rustup.rs/\n"
            "Or run: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        );
    }
    
    # Check if build tools (gcc/cc) are available
    try {
        subprocess.run(["cc", "--version"], capture_output=True, check=True, timeout=5);
    } except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired) {
        raise RuntimeError(
            "Build tools not found. Install build-essential:\n"
            "  Ubuntu/Debian: sudo apt-get install build-essential\n"
            "  Fedora: sudo dnf install gcc gcc-c++\n"
            "  Arch: sudo pacman -S base-devel"
        );
    }
    
    # Check if tauri CLI is available via cargo
    try {
        subprocess.run(["cargo", "tauri", "--version"], capture_output=True, check=True, timeout=5);
    } except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired) {
        console.warning("Tauri CLI not found.");
        console.print("  Install manually: cargo install tauri-cli", style="muted");
        console.print("  Or use npm: npm install -D @tauri-apps/cli", style="muted");
        raise RuntimeError(
            "Tauri CLI not installed. Install it first:\n"
            "  cargo install tauri-cli\n"
            "  Or: npm install -D @tauri-apps/cli"
        );
    }
    
    # Check if package.json has tauri scripts
    package_json = tauri_dir.parent / "package.json";
    use_npm = False;
    if package_json.exists() {
        try {
            with open(package_json, "r") as f {
                package_data = json.load(f);
                scripts = package_data.get("scripts", {});
                if "tauri" in scripts or "tauri:dev" in scripts {
                    use_npm = True;
                }
            }
        } except Exception {
        }
    }
    
    if use_npm {
        # Use npm run tauri dev
        dev_cmd = ["npm", "run", "tauri", "dev"];
    } else {
        # Use cargo tauri dev directly
        dev_cmd = ["cargo", "tauri", "dev"];
    }
    
    console.print(f"  Running: {' '.join(dev_cmd)}", style="muted");
    
    # Run tauri dev (this will open a window)
    process = subprocess.Popen(
        dev_cmd,
        cwd=tauri_dir.parent,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        bufsize=1
    );
    
    # Stream output
    import threading;
    def stream_output() -> None {
        if process.stdout {
            for line in process.stdout {
                console.print(f"  {line.rstrip()}", style="muted");
            }
        }
    };
    
    thread = threading.Thread(target=stream_output, daemon=True);
    thread.start();
    
    return process;
}

"""Start desktop app - build web bundle and launch Tauri with built bundle."""
impl DesktopTarget.start(self: DesktopTarget, entry_file: Path, project_dir: Path) -> None {
    import from jac_client.plugin.src.targets.WebTarget { WebTarget }
    import signal;
    import sys;
    
    console.print("\n🖥️  Starting desktop app (Tauri)", style="bold");
    
    # Check if setup has been run
    tauri_dir = project_dir / "src-tauri";
    if not tauri_dir.exists() {
        raise RuntimeError("Desktop target not set up. Run 'jac setup desktop' first.");
    }
    
    # Step 1: Build web bundle first
    console.print("  Step 1: Building web bundle...", style="muted");
    web_target = WebTarget();
    web_bundle_path = web_target.build(entry_file, project_dir, None);
    console.print(f"  ✔ Web bundle built: {web_bundle_path}", style="success");
    
    # Step 2: Update tauri.conf.json to point to web bundle
    console.print("  Step 2: Updating Tauri configuration...", style="muted");
    _update_tauri_config_for_build(tauri_dir, project_dir, web_bundle_path);
    
    # Step 3: Launch tauri dev (which will use the built bundle)
    console.print("  Step 3: Launching Tauri app...", style="muted");
    console.print("  (Press Ctrl+C to stop)", style="muted");
    
    # Setup signal handlers for cleanup
    def cleanup() -> None {
        console.print("\n  Stopping app...", style="muted");
        console.print("  ✔ App stopped", style="success");
    }
    
    def signal_handler(signum: int, frame: Any) -> None {
        cleanup();
        sys.exit(0);
    }
    
    signal.signal(signal.SIGINT, signal_handler);
    signal.signal(signal.SIGTERM, signal_handler);
    
    try {
        # Run tauri dev (it will use the built bundle from distDir)
        tauri_process = _run_tauri_dev(tauri_dir);
        
        # Wait for tauri process to finish
        tauri_process.wait();
    } except KeyboardInterrupt {
        console.print("\n  Keyboard interrupt detected. Stopping app...", style="muted");
    } finally {
        cleanup();
    }
}

