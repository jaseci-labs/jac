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
import stat;

"""Setup desktop target - scaffold Tauri project structure."""
impl DesktopTarget.setup(self: DesktopTarget, project_dir: Path) -> None {
    import from jac_client.plugin.src.desktop_config { DesktopConfig }
    
    console.print("\n🖥️  Setting up desktop target (Tauri)", style="bold");
    console.print(f"  Project directory: {project_dir}", style="muted");
    
    # Check if already set up
    tauri_dir = project_dir / "src-tauri";
    if tauri_dir.exists() {
        console.warning("Desktop target already set up. Skipping...");
        return;
    }
    
    # Load desktop config (will use defaults if [desktop] section doesn't exist)
    desktop_config = DesktopConfig(project_dir=project_dir);
    config_data = desktop_config.load();
    
    project_name = config_data.get('name', 'my-jac-app');
    project_version = config_data.get('version', '1.0.0');
    identifier = config_data.get('identifier', 'com.myapp');
    
    console.print(f"  Project name: {project_name}, version: {project_version}", style="muted");
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
    
    # Update tauri.conf.json to include icons
    try {
        config_path = tauri_dir / "tauri.conf.json";
        if config_path.exists() {
            with open(config_path, "r") as f {
                config = json.load(f);
            }
            _populate_icon_array(tauri_dir, config);
            with open(config_path, "w") as f {
                json.dump(config, f, indent=2);
            }
        }
    } except Exception as e {
        console.warning(f"  Failed to update icon array in tauri.conf.json: {e}");
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
    
    # Create a 1024x1024 PNG icon as placeholder (AppImage requires square icons, 1024x1024 recommended)
    # Try using PIL/Pillow first (most common), then fallback to subprocess with ImageMagick/convert,
    # finally use a simple Python-based PNG generator
    icon_path = icons_dir / "icon.png";
    
    # Method 1: Try using Python with PIL to generate icon
    try {
        import subprocess;
        # Use Python to create a 1024x1024 PNG using PIL if available
        python_code = '''
import sys
try:
    from PIL import Image, ImageDraw
    size = 1024
    img = Image.new("RGBA", (size, size), color=(66, 139, 202, 255))
    draw = ImageDraw.Draw(img)
    draw.rectangle([20, 20, size-20, size-20], outline=(255, 255, 255, 255), width=10)
    img.save(sys.argv[1], "PNG")
    sys.exit(0)
except ImportError:
    sys.exit(1)
''';
        result = subprocess.run(
            ["python3", "-c", python_code, str(icon_path)],
            capture_output=True,
            check=True,
            timeout=5
        );
        console.print("  ✔ Generated default icon (1024x1024)", style="success");
        console.warning("  Note: Replace icons/icon.png with your app icon (1024x1024 PNG recommended)");
        return;
    } except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired) {
        # PIL not available, try next method
    }
    
    # Method 2: Try ImageMagick convert command
    try {
        import subprocess;
        # Create a 1024x1024 solid blue PNG with alpha channel using ImageMagick
        result = subprocess.run(
            ["convert", "-size", "1024x1024", "xc:#428BCA", "-alpha", "set", "-channel", "RGBA", str(icon_path)],
            capture_output=True,
            check=True,
            timeout=5
        );
        console.print("  ✔ Generated default icon (1024x1024)", style="success");
        console.warning("  Note: Replace icons/icon.png with your app icon (1024x1024 PNG recommended)");
        return;
    } except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired) {
        # ImageMagick not available, try next method
    }
    
    # Method 3: Fallback - create a minimal but valid 1024x1024 PNG using Python
    # This creates a simple solid color PNG
    import struct;
    import zlib;
    
    width = 1024;
    height = 1024;
    
    # PNG signature
    png = bytearray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    
    # IHDR chunk - RGBA, 8-bit per channel (color type 6 = RGBA)
    ihdr_data = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0);
    ihdr_crc = zlib.crc32(b"IHDR" + ihdr_data) & 0xffffffff;
    png.extend(struct.pack(">I", 13));
    png.extend(b"IHDR");
    png.extend(ihdr_data);
    png.extend(struct.pack(">I", ihdr_crc));
    
    # IDAT chunk - solid blue color with alpha (RGBA: 66, 139, 202, 255 = #428BCA)
    # PNG scanlines: each row is prefixed with filter byte (0 = none)
    row_size = width * 4;  # RGBA = 4 bytes per pixel
    scanline = bytes([0]) + bytes([66, 139, 202, 255]) * width;  # Filter byte + RGBA data
    image_data = scanline * height;
    
    # Compress
    compressed = zlib.compress(image_data, level=9);
    idat_crc = zlib.crc32(b"IDAT" + compressed) & 0xffffffff;
    png.extend(struct.pack(">I", len(compressed)));
    png.extend(b"IDAT");
    png.extend(compressed);
    png.extend(struct.pack(">I", idat_crc));
    
    # IEND chunk
    png.extend(struct.pack(">I", 0));
    png.extend(b"IEND");
    png.extend(struct.pack(">I", 0xAE426082));
    
    # Write icon.png
    with open(icon_path, "wb") as f {
        f.write(png);
    }
    
    console.print("  ✔ Generated default icon (1024x1024)", style="success");
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
    
    # Step 1.5: Bundle sidecar (optional - can be skipped if not needed)
    # This bundles the Jac backend as an executable for local use
    sidecar_bundled = False;
    try {
        console.print("  Step 1.5: Bundling sidecar (Jac backend)...", style="muted");
        sidecar_path = _bundle_sidecar(entry_file, project_dir, tauri_dir, platform);
        if sidecar_path and sidecar_path.exists() {
            console.print(f"  ✔ Sidecar bundled: {sidecar_path}", style="success");
            sidecar_bundled = True;
        }
    } except Exception as e {
        console.warning(f"  Sidecar bundling skipped: {e}");
        console.print("  Note: Desktop app will need external API server", style="muted");
        sidecar_bundled = False;
    }
    
    # Step 1.5: Check and regenerate icon if needed (AppImage requires square icons)
    icon_path = tauri_dir / "icons" / "icon.png";
    if icon_path.exists() {
        try {
            # Try to check icon size and squareness using PIL
            import subprocess;
            check_code = '''
import sys
from PIL import Image
try:
    img = Image.open(sys.argv[1])
    # AppImage requires square icons, and 1024x1024 is recommended
    if img.width != img.height or img.width < 512:
        sys.exit(1)  # Not square or too small
    # Verify it's RGBA format
    if img.mode != "RGBA":
        sys.exit(1)  # Not RGBA
    sys.exit(0)  # Icon OK
except:
    sys.exit(1)  # Error or invalid
''';
            result = subprocess.run(
                ["python3", "-c", check_code, str(icon_path)],
                capture_output=True,
                timeout=5
            );
            if result.returncode != 0 {
                console.warning("  Icon is invalid or too small for AppImage, regenerating...");
                # Delete old icon before regenerating
                if icon_path.exists() {
                    icon_path.unlink();
                }
                _generate_default_icons(tauri_dir);
            }
        } except Exception {
            # If check fails, try to regenerate anyway
            console.warning("  Could not verify icon, regenerating...");
            _generate_default_icons(tauri_dir);
        }
    } else {
        # Icon doesn't exist, generate it
        _generate_default_icons(tauri_dir);
    }
    
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

"""Add sidecar binary to tauri.conf.json if it exists."""
def _add_sidecar_to_config(tauri_dir: Path, config: dict) -> None {
    binaries_dir = tauri_dir / "binaries";
    if not binaries_dir.exists() {
        return;  # No binaries directory, skip
    }
    
    # Find sidecar wrapper script (must exist and be executable)
    sidecar_files = [];
    for pattern in ["jac-sidecar.sh", "jac-sidecar.bat", "jac-sidecar", "jac-sidecar.exe"] {
        found = list(binaries_dir.glob(pattern));
        for f in found {
            if f.is_file() and f.exists() {
                sidecar_files.append(f);
            }
        }
    }
    
    if not sidecar_files {
        # Remove sidecar from resources if it was previously added but no longer exists
        if "bundle" in config and "resources" in config["bundle"] {
            resources = config["bundle"]["resources"];
            # Remove any jac-sidecar entries
            config["bundle"]["resources"] = [
                r for r in resources if not ("jac-sidecar" in r or "binaries/jac-sidecar" in r)
            ];
        }
        return;  # No sidecar found, skip
    }
    
    # Tauri v2 uses "resources" in bundle section for sidecars
    if "bundle" not in config {
        config["bundle"] = {};
    }
    
    # Add resources array if it doesn't exist
    if "resources" not in config["bundle"] {
        config["bundle"]["resources"] = [];
    }
    
    # Add sidecar binary path (relative to tauri_dir)
    for sidecar_file in sidecar_files {
        rel_path = sidecar_file.relative_to(tauri_dir);
        rel_str = str(rel_path.as_posix());
        if rel_str not in config["bundle"]["resources"] {
            config["bundle"]["resources"].append(rel_str);
            console.print(f"  ✔ Added sidecar to config: {rel_str}", style="success");
        }
    }
}

"""Populate icon array in tauri.conf.json from icons directory."""
def _populate_icon_array(tauri_dir: Path, config: dict) -> None {
    # Populate icon array if empty or missing
    if "bundle" not in config {
        config["bundle"] = {};
    }
    if "icon" not in config["bundle"] or not config["bundle"]["icon"] or len(config["bundle"]["icon"]) == 0 {
        # Scan icons directory for PNG files
        icons_dir = tauri_dir / "icons";
        icon_files = [];
        if icons_dir.exists() {
            for icon_file in icons_dir.iterdir() {
                if icon_file.is_file() and icon_file.suffix.lower() == ".png" {
                    # Path relative to tauri.conf.json (which is in tauri_dir)
                    # So icons/icon.png is the correct relative path
                    icon_rel_path = icon_file.relative_to(tauri_dir);
                    icon_files.append(str(icon_rel_path.as_posix()));
                }
            }
        }
        # Sort to ensure consistent ordering (icon.png first if it exists)
        icon_files.sort();
        config["bundle"]["icon"] = icon_files;
        if icon_files {
            console.print(f"  ✔ Populated icon array with {len(icon_files)} icon(s)", style="success");
        }
    }
}

"""Update tauri.conf.json to point to the built web bundle."""
def _update_tauri_config_for_build(tauri_dir: Path, project_dir: Path, web_bundle_path: Path, sidecar_bundled: bool = False) -> None {
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
    
    # Populate icon array if empty or missing
    _populate_icon_array(tauri_dir, config);
    
    # Add sidecar binary if it exists
    _add_sidecar_to_config(tauri_dir, config);
    
    # Write updated config
    with open(config_path, "w") as f {
        json.dump(config, f, indent=2);
    }
    
    console.print("  ✔ Updated tauri.conf.json", style="success");
}

"""Check if appimagetool is available and can run."""
def _check_appimagetool() -> tuple[bool, str | None] {
    # First check if the command exists
    try {
        result = subprocess.run(
            ["which", "appimagetool"],
            capture_output=True,
            timeout=2
        );
        if result.returncode != 0 {
            return (False, "appimagetool not found in PATH");
        }
    } except Exception {
        return (False, "Could not check for appimagetool");
    }
    
    # Try to run appimagetool to see if it works
    try {
        result = subprocess.run(
            ["appimagetool", "--version"],
            capture_output=True,
            timeout=5,
            text=True
        );
        if result.returncode == 0 {
            return (True, None);
        } else {
            # Check if it's a FUSE error
            error_output = result.stderr or result.stdout or "";
            if "fuse" in error_output.lower() or "libfuse" in error_output.lower() {
                return (False, "FUSE library not available. Install with: sudo apt-get install libfuse2");
            }
            return (False, f"appimagetool failed: {error_output[:100]}");
        }
    } except FileNotFoundError {
        return (False, "appimagetool not found");
    } except subprocess.TimeoutExpired {
        return (False, "appimagetool check timed out");
    } except Exception as e {
        return (False, f"Error checking appimagetool: {str(e)[:100]}");
    }
}

"""Create AppImage from AppDir if appimagetool is available."""
def _create_appimage_from_appdir(appdir_path: Path) -> Path | None {
    if not appdir_path.exists() or not appdir_path.is_dir() {
        return None;
    }
    
    # Check if appimagetool is available and working
    (is_available, error_msg) = _check_appimagetool();
    if not is_available {
        console.warning("  appimagetool not available. AppImage will not be created.");
        if error_msg {
            console.print(f"  {error_msg}", style="muted");
        }
        # Provide installation instructions based on the error
        if error_msg and "fuse" in error_msg.lower() {
            console.print("  For WSL2, you may need to install FUSE:", style="muted");
            console.print("    sudo apt-get update && sudo apt-get install -y libfuse2", style="muted");
            console.print("  Or use --appimage-extract to extract appimagetool first", style="muted");
        } else {
            console.print("  Install it with:", style="muted");
            console.print("    wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage", style="muted");
            console.print("    chmod +x appimagetool-x86_64.AppImage", style="muted");
            console.print("    sudo mv appimagetool-x86_64.AppImage /usr/local/bin/appimagetool", style="muted");
        }
        return None;
    }
    
    # Determine AppImage filename from AppDir name
    appimage_name = f"{appdir_path.name}.AppImage";
    appimage_path = appdir_path.parent / appimage_name;
    
    # Skip if AppImage already exists and is newer than AppDir
    if appimage_path.exists() {
        appdir_mtime = appdir_path.stat().st_mtime;
        appimage_mtime = appimage_path.stat().st_mtime;
        if appimage_mtime >= appdir_mtime {
            console.print(f"  ✔ AppImage already exists: {appimage_path.name}", style="success");
            return appimage_path;
        }
    }
    
    try {
        console.print(f"  Creating AppImage from {appdir_path.name}...", style="muted");
        result = subprocess.run(
            ["appimagetool", str(appdir_path), str(appimage_path)],
            cwd=appdir_path.parent,
            check=False,  # Don't raise on error, we'll check manually
            capture_output=True,
            text=True,
            timeout=300  # 5 minute timeout
        );
        
        if result.returncode != 0 {
            error_output = result.stderr or result.stdout or "Unknown error";
            # Check for FUSE-related errors
            if "fuse" in error_output.lower() or "libfuse" in error_output.lower() or "FUSE" in error_output {
                console.warning("  Failed to create AppImage: FUSE library not available");
                console.print("  Install FUSE with: sudo apt-get install -y libfuse2", style="muted");
                console.print("  For WSL2, you may also need: sudo apt-get install -y fuse", style="muted");
            } else {
                console.warning(f"  Failed to create AppImage: {error_output[:200]}");
            }
            return None;
        }
        
        # Verify the AppImage was created
        if not appimage_path.exists() {
            console.warning("  AppImage creation reported success but file not found");
            return None;
        }
        
        # Make AppImage executable
        appimage_path.chmod(appimage_path.stat().st_mode | stat.S_IEXEC);
        
        console.print(f"  ✔ AppImage created: {appimage_path.name}", style="success");
        return appimage_path;
    } except subprocess.TimeoutExpired {
        console.warning("  AppImage creation timed out");
        return None;
    } except Exception as e {
        error_msg = str(e);
        if "fuse" in error_msg.lower() or "libfuse" in error_msg.lower() {
            console.warning("  FUSE library error. Install with: sudo apt-get install -y libfuse2");
        } else {
            console.warning(f"  Error creating AppImage: {error_msg[:200]}");
        }
        return None;
    }
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
    
    # For Linux: if no AppImage but AppDir exists, try to create AppImage
    is_linux_build = (platform == "linux") or (not platform and target and "linux" in target);
    if not installers and is_linux_build {
        appimage_dir = bundle_dir / "appimage";
        if appimage_dir.exists() {
            # Look for AppDir directories
            appdirs = [d for d in appimage_dir.iterdir() if d.is_dir() and d.name.endswith(".AppDir")];
            if appdirs {
                # Try to create AppImage from the first AppDir found
                appimage_path = _create_appimage_from_appdir(appdirs[0]);
                if appimage_path and appimage_path.exists() {
                    installers = [appimage_path];
                }
            }
        }
    }
    
    if installers {
        return installers[0];
    }
    
    # Fallback: return the bundle directory
    return bundle_dir;
}

"""Create Python-based sidecar wrapper script (no PyInstaller needed)."""
def _bundle_sidecar(
    entry_file: Path,
    project_dir: Path,
    tauri_dir: Path,
    platform: Optional[str] = None
) -> Path | None {
    import platform as platform_module;
    import stat;
    
    # Determine output directory
    binaries_dir = tauri_dir / "binaries";
    binaries_dir.mkdir(parents=True, exist_ok=True);
    
    # Determine script name based on platform
    if platform == "windows" or (platform is None and platform_module.system() == "Windows") {
        script_name = "jac-sidecar.bat";
        is_windows = True;
    } else {
        script_name = "jac-sidecar.sh";
        is_windows = False;
    }
    
    output_path = binaries_dir / script_name;
    
    # Create wrapper script that runs Python module
    # This approach avoids PyInstaller issues and is much simpler
    if is_windows {
        # Windows batch script
        script_content = f'''@echo off
REM Jac Sidecar Wrapper - Runs Jac backend using system Python
REM This requires Python and jaclang to be installed

python -m jac_client.plugin.src.targets.desktop.sidecar.main %*
''';
    } else {
        # Unix shell script
        script_content = '''#!/bin/bash
# Jac Sidecar Wrapper - Runs Jac backend using system Python
# This requires Python and jaclang to be installed

exec python -m jac_client.plugin.src.targets.desktop.sidecar.main "$@"
''';
    }
    
    # Write the wrapper script
    with open(output_path, "w") as f {
        f.write(script_content);
    }
    
    # Make executable on Unix systems
    if not is_windows {
        st = output_path.stat();
        output_path.chmod(st.st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH);
    }
    
    console.print(f"  ✔ Created sidecar wrapper: {script_name}", style="success");
    console.print(f"  Note: Requires Python and jaclang to be installed", style="muted");
    console.print(f"  Run: pip install jaclang", style="muted");
    
    return output_path;
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
    
    # Populate icon array if empty or missing
    _populate_icon_array(tauri_dir, config);
    
    # Add sidecar binary if it exists
    _add_sidecar_to_config(tauri_dir, config);
    
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

