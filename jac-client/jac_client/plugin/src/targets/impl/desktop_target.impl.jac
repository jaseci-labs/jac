"""Implementation of DesktopTarget methods."""
import from pathlib { Path }
import from typing { Optional, Any }
import from jaclang.cli.console { console }
import from jaclang.project.config { get_config }
import from jac_client.plugin.src.config_loader { JacClientConfig }
import from jac_client.plugin.src.vite_bundler { API_BASE_URL_ENV_VAR }
import subprocess;
import json;
import shutil;
import os;
import platform;
import stat;

# ===============================================================================
# Constants - Avoid magic numbers/strings throughout the module
# ===============================================================================
glob DEFAULT_API_PORT: int = 8000,
     DEFAULT_VITE_PORT: int = 5173,
     SUBPROCESS_TIMEOUT_SHORT: int = 5,
     SUBPROCESS_TIMEOUT_MEDIUM: int = 60,
     SUBPROCESS_TIMEOUT_LONG: int = 300,
     SUBPROCESS_TIMEOUT_BUILD: int = 600,
     DEFAULT_ICON_COLOR_RGB: tuple[int, int, int, int] = (66, 139, 202, 255),
     DEFAULT_ICON_SIZE: int = 1024,
     DEFAULT_WINDOW_WIDTH: int = 1200,
     DEFAULT_WINDOW_HEIGHT: int = 800,
     DEFAULT_MIN_WIDTH: int = 800,
     DEFAULT_MIN_HEIGHT: int = 600;

# ===============================================================================
# Helper Functions - Extracted to reduce duplication
# ===============================================================================
"""Check if a command is available and optionally return its version."""
def _check_command_available(
    cmd: list[str], timeout: int = SUBPROCESS_TIMEOUT_SHORT
) -> tuple[bool, str | None] {
    try {
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout);
        if result.returncode == 0 {
            return (True, result.stdout.strip());
        }
    } except Exception as e { }
    return (False, None);
}

"""Check if error message indicates FUSE-related issue."""
def _is_fuse_error(error_output: str) -> bool {
    error_lower = error_output.lower();
    return "fuse" in error_lower or "libfuse" in error_lower;
}

"""Get FUSE installation instructions."""
def _get_fuse_install_hint -> str {
    return "Install FUSE with: sudo apt-get install -y libfuse2";
}

def _make_localhost_url(port: int) -> str {
    return f"http://127.0.0.1:{port}";
}

"""Join path components into a Path object (type-safe alternative to / operator)."""
def _join_path(base: Path, *parts: str) -> Path {
    result: str = str(base);
    for part in parts {
        p: str = str(part);
        result = os.path.join(result, p);
    }
    return Path(result);
}

def _get_toml_api_base_url(project_dir: Path) -> str {
    config_loader = JacClientConfig(project_dir);
    api_config: dict = config_loader.get_api_config();
    base_url: str = api_config.get('base_url', '');
    return base_url;
}

# ===============================================================================
# Production Build Helpers - GLIBC compatibility
# ===============================================================================
"""Get the system GLIBC version on Linux. Returns version string or None."""
def _get_glibc_version -> str | None {
    if platform.system() != "Linux" {
        return None;
    }
    try {
        result = subprocess.run(
            ["ldd", "--version"],
            capture_output=True,
            text=True,
            timeout=SUBPROCESS_TIMEOUT_SHORT
        );
        if result.returncode == 0 {
            stdout_str: str = str(result.stdout);
            first_line: str = stdout_str.split("\n")[0];
            parts: list = first_line.split();
            for p in parts {
                part: str = str(p);
                if "." in part {
                    try {
                        segments: list = part.split(".");
                        if len(segments) >= 2 {
                            int(str(segments[0]));
                            int(str(segments[1]));
                            return part;
                        }
                    } except Exception { }
                }
            }
        }
    } except Exception { }
    return None;
}

"""Compare two version strings. Returns -1 if v1 < v2, 0 if equal, 1 if v1 > v2."""
def _compare_versions(v1: str, v2: str) -> int {
    parts1: list = [];
    for x in v1.split(".") {
        try {
            parts1.append(int(str(x)));
        } except Exception {
            parts1.append(0);
        }
    }
    parts2: list = [];
    for x in v2.split(".") {
        try {
            parts2.append(int(str(x)));
        } except Exception {
            parts2.append(0);
        }
    }
    while len(parts1) < len(parts2) {
        parts1.append(0);
    }
    while len(parts2) < len(parts1) {
        parts2.append(0);
    }
    for i in range(len(parts1)) {
        if parts1[i] < parts2[i] {
            return -1;
        }
        if parts1[i] > parts2[i] {
            return 1;
        }
    }
    return 0;
}

"""Check GLIBC compatibility for production builds. Returns (is_compatible, version, message)."""
def _check_glibc_compatibility -> tuple[bool, str | None, str] {
    if platform.system() != "Linux" {
        return (True, None, "");
    }
    glibc_version = _get_glibc_version();
    if not glibc_version {
        return (True, None, "Could not detect GLIBC version");
    }
    # GLIBC 2.35 is Ubuntu 22.04 - good target for compatibility
    if _compare_versions(glibc_version, "2.35") > 0 {
        msg = "WARNING: GLIBC " + glibc_version + " detected. For production builds targeting older systems, build on Ubuntu 22.04.";
        return (False, glibc_version, msg);
    }
    return (True, glibc_version, "GLIBC " + glibc_version + " OK");
}

"""Find the jaseci monorepo root directory by looking for jac-client."""
def _find_jaseci_root(start_dir: Path) -> Path | None {
    search_dir: Path = Path(str(start_dir.resolve()));
    for _ in range(10) {
        jac_client_path: Path = Path(str(search_dir) + "/jac-client");
        if jac_client_path.is_dir() {
            return search_dir;
        }
        parent: Path = search_dir.parent;
        if str(parent) == str(search_dir) {
            break;
        }
        search_dir = parent;
    }
    return None;
}

"""Check if running in production build mode (via env var)."""
def _is_production_build -> bool {
    return os.environ.get("JAC_PRODUCTION_BUILD", "").lower() in ("1", "true", "yes");
}

"""Setup desktop target - scaffold Tauri project structure."""
impl DesktopTarget.setup(project_dir: Path) -> None {
    # Define tauri_dir early so we can use it in error handling
    tauri_dir: Path = _join_path(project_dir, "src-tauri");
    # Create src-tauri directory structure FIRST (before ANY other operations)
    # This ensures the directory exists even if later steps fail
    console.print("\n🖥️  Setting up desktop target (Tauri)", style="bold");
    console.print(f"  Project directory: {project_dir}", style="muted");
    # Check if already set up
    if tauri_dir.exists() {
        console.warning("Desktop target already set up. Skipping...");
        return;
    }
    # Ensure project directory exists
    if not project_dir.exists() {
        try {
            project_dir.mkdir(parents=True, exist_ok=True);
        } except Exception {
            raise RuntimeError(f"Failed to create project directory");
        }
    }
    # Create src-tauri directory structure IMMEDIATELY (before imports or any other operations)
    console.print("  Creating src-tauri/ directory structure...", style="muted");
    try {
        tauri_dir.mkdir(parents=True, exist_ok=True);
        _join_path(tauri_dir, "src").mkdir(exist_ok=True);
        _join_path(tauri_dir, "binaries").mkdir(exist_ok=True);
        console.print(f"  ✔ Created {tauri_dir}", style="success");
    } except Exception {
        raise RuntimeError(f"Failed to create src-tauri directory");
    }
    # Wrap rest of setup in try-finally to ensure directory exists even if exceptions occur
    try {
        # Now import and do other operations (directory already exists, so if these fail, directory is still there)
        import from jac_client.plugin.src.desktop_config { DesktopConfig }

        # Load desktop config (will use defaults if [desktop] section doesn't exist)
        # Wrap in try-except to handle config loading errors gracefully
        try {
            desktop_config = DesktopConfig(project_dir=project_dir);
            config_data = desktop_config.load();

            project_name = config_data.get('name', 'my-jac-app');
            project_version = config_data.get('version', '1.0.0');
            identifier = config_data.get('identifier', 'com.myapp');
        } except Exception as e {
            console.warning(f"  Failed to load desktop config: {e}, using defaults");
            project_name = 'my-jac-app';
            project_version = '1.0.0';
            identifier = 'com.myapp';
        }

        console.print(
            f"  Project name: {project_name}, version: {project_version}", style="muted"
        );
        console.print(f"  Identifier: {identifier}", style="muted");

        # Generate tauri.conf.json (don't fail setup if this fails)
        try {
            _generate_tauri_config(
                tauri_dir, project_name, identifier, project_version
            );
        } except Exception as e {
            console.warning(f"  Failed to generate tauri.conf.json: {e}");
            console.print(
                "  Setup will continue, but tauri.conf.json may be missing.",
                style="muted"
            );
        }

        # Generate Cargo.toml (don't fail setup if this fails)
        try {
            _generate_cargo_toml(tauri_dir, project_name, identifier);
        } except Exception as e {
            console.warning(f"  Failed to generate Cargo.toml: {e}");
            console.print(
                "  Setup will continue, but Cargo.toml may be missing.", style="muted"
            );
        }

        # Generate build.rs (don't fail setup if this fails)
        try {
            _generate_build_rs(tauri_dir);
        } except Exception as e {
            console.warning(f"  Failed to generate build.rs: {e}");
            console.print(
                "  Setup will continue, but build.rs may be missing.", style="muted"
            );
        }

        # Generate icons (don't fail setup if this fails)
        try {
            _generate_default_icons(tauri_dir);
        } except Exception as e {
            console.warning(f"  Failed to generate icons: {e}");
            console.print(
                "  Setup will continue, but icons may be missing.", style="muted"
            );
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

        # Generate main.rs (don't fail setup if this fails)
        try {
            _generate_main_rs(tauri_dir);
        } except Exception as e {
            console.warning(f"  Failed to generate main.rs: {e}");
            console.print(
                "  Setup will continue, but main.rs may be missing.", style="muted"
            );
        }

        # Add [desktop] section to jac.toml (don't fail setup if this fails)
        try {
            _add_desktop_config(project_dir, project_name, identifier, project_version);
        } except Exception as e {
            console.warning(f"  Failed to add [desktop] section to jac.toml: {e}");
            console.print(
                "  Setup will continue, but jac.toml may not be updated.", style="muted"
            );
        }

        console.print("\n📦 Checking required dependencies...", style="bold");
        try {
            _check_dependencies();
        } except Exception as e {
            console.warning(f"  Dependency check encountered an issue: {e}");
            console.print(
                "  Setup will continue, but some dependencies may be missing.",
                style="muted"
            );
        }

        # Verify essential files exist, recreate if missing
        essential_files = {
            "tauri.conf.json": lambda :
                _generate_tauri_config(
                    tauri_dir, project_name, identifier, project_version
                ),
            "Cargo.toml": lambda :
                _generate_cargo_toml(tauri_dir, project_name, identifier),
            "build.rs": lambda : _generate_build_rs(tauri_dir),
            "src/main.rs": lambda : _generate_main_rs(tauri_dir)
        };

        for file_path in essential_files {
            full_path = tauri_dir / file_path;
            if not full_path.exists() {
                console.warning(f"  {file_path} not found, regenerating...");
                try {
                    generator = essential_files[file_path];
                    generator();
                } except Exception as e {
                    console.warning(f"  Failed to regenerate {file_path}: {e}");
                }
            }
        }

        console.success("Desktop target setup complete!");
        console.print("\nNext steps:", style="bold");
        console.print("  1. Dev:   jac start main.jac --client desktop");
        console.print("  2. Build: jac build main.jac --client desktop");
        console.print("\nBuild options:", style="bold");
        console.print("  --platform <windows|macos|linux|all>  Target platform");
    } finally {
        # ABSOLUTE GUARANTEE: Ensure src-tauri directory exists no matter what
        if not tauri_dir.exists() {
            try {
                tauri_dir.mkdir(parents=True, exist_ok=True);
                (tauri_dir / "src").mkdir(exist_ok=True);
                (tauri_dir / "binaries").mkdir(exist_ok=True);
                console.print(f"  ✔ Ensured {tauri_dir} exists", style="success");
            } except Exception as e {
                console.error(f"  CRITICAL: Could not create src-tauri directory: {e}");
            }
        }
    }
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
def _generate_tauri_config(tauri_dir: Path, name: str, identifier: str, version: str) {
    config = {
        "productName": name,
        "version": version,
        "identifier": identifier,
        "build": {
            "devUrl": "http://localhost:5173",
            "frontendDist": "../.jac/client/dist"
        },
        "app": {"withGlobalTauri": True, "windows": [], "security": {"csp": None}},
        "bundle": {"active": True, "targets": "all", "icon": []},
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
def _generate_cargo_toml(tauri_dir: Path, name: str, identifier: str) {
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
tauri = {{ version = "2.0", features = ["devtools"] }}
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
def _generate_build_rs(tauri_dir: Path) {
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
def _generate_default_icons(tauri_dir: Path) {
    icons_dir = tauri_dir / "icons";
    icons_dir.mkdir(exist_ok=True);
    icon_path = icons_dir / "icon.png";

    # Try Pillow in-process first (best quality, no subprocess overhead).
    try {
        import from PIL { Image, ImageDraw }
        size = 1024;
        img = Image.new("RGBA", (size, size), color=(66, 139, 202, 255));
        draw = ImageDraw.Draw(img);
        draw.rectangle(
            [20, 20, size - 20, size - 20], outline=(255, 255, 255, 255), width=10
        );
        img.save(str(icon_path), "PNG");
        console.print("  ✔ Generated default icon (1024x1024)", style="success");
    } except ImportError {
        # Pillow not installed; use hand-crafted PNG as fallback.
        _generate_fallback_png(icon_path);
        console.print(
            "  ✔ Generated default icon (1024x1024, fallback)", style="success"
        );
    } except Exception as e {
        _generate_fallback_png(icon_path);
        console.warning(f"  Pillow icon generation failed ({e}), used fallback");
    }

    console.warning(
        "  Note: Replace icons/icon.png with your app icon (1024x1024 PNG recommended)"
    );

    # Always generate platform-specific derivatives from whatever icon.png
    # was created. Tauri requires .ico (Windows), .icns (macOS), and
    # multiple PNG sizes (Linux).
    _generate_platform_icons(icons_dir);
}


"""Create a minimal valid 1024x1024 RGBA PNG without any dependencies."""
def _generate_fallback_png(icon_path: Path) {
    import struct;
    import zlib;

    width = 1024;
    height = 1024;

    png = bytearray([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

    ihdr_data = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0);
    ihdr_crc = zlib.crc32(b"IHDR" + ihdr_data) & 0xffffffff;
    png.extend(struct.pack(">I", 13));
    png.extend(b"IHDR");
    png.extend(ihdr_data);
    png.extend(struct.pack(">I", ihdr_crc));

    scanline = bytes([0]) + bytes([66, 139, 202, 255]) * width;
    image_data = scanline * height;
    compressed = zlib.compress(image_data, level=9);
    idat_crc = zlib.crc32(b"IDAT" + compressed) & 0xffffffff;
    png.extend(struct.pack(">I", len(compressed)));
    png.extend(b"IDAT");
    png.extend(compressed);
    png.extend(struct.pack(">I", idat_crc));

    png.extend(struct.pack(">I", 0));
    png.extend(b"IEND");
    png.extend(struct.pack(">I", 0xAE426082));

    with open(icon_path, "wb") as f {
        f.write(png);
    }
}


"""Generate all platform icon formats from icon.png.

Produces:
  - icon.ico   (Windows NSIS/MSI bundler)
  - icon.icns  (macOS .app bundler)
  - 32x32.png, 128x128.png, 128x128@2x.png (Tauri standard sizes)

Uses Pillow in-process first. Falls back to a subprocess invocation so a
Pillow install in a different Python environment still works. If Pillow
is completely unavailable, warns the user.
"""
def _generate_platform_icons(icons_dir: Path) -> None {
    import sys;
    png_path = icons_dir / "icon.png";

    if not png_path.exists() {
        return;
    }

    # Try Pillow in-process first (fast, best error messages).
    try {
        import from PIL { Image }
        _generate_icons_with_pillow(icons_dir, Image);
        return;
    } except ImportError {
    # Pillow not in this process; try subprocess fallback.
    } except Exception as e {
        console.warning(f"  Icon generation error: {e}");
    }

    # Subprocess fallback: call Python with Pillow from PATH.
    try {
        python_cmd = "python" if sys.platform == "win32" else "python3";
        python_code = '''
import sys, os
try:
    from PIL import Image
    icons_dir = sys.argv[1]
    png_path = os.path.join(icons_dir, "icon.png")
    img = Image.open(png_path).convert("RGBA")

    # ICO (Windows)
    ico_sizes = [(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)]
    img.save(os.path.join(icons_dir, "icon.ico"), format="ICO", sizes=ico_sizes)

    # ICNS (macOS)
    try:
        img.save(os.path.join(icons_dir, "icon.icns"), format="ICNS")
    except Exception:
        pass  # ICNS support is optional in some Pillow builds

    # Tauri standard PNG sizes
    for size in [32, 128, 256]:
        resized = img.resize((size, size), Image.LANCZOS)
        resized.save(os.path.join(icons_dir, f"{size}x{size}.png"))
    # 128x128@2x is 256x256 pixels
    img.resize((256, 256), Image.LANCZOS).save(
        os.path.join(icons_dir, "128x128@2x.png")
    )

    sys.exit(0)
except Exception as e:
    print(str(e), file=sys.stderr)
    sys.exit(1)
''';
        result = subprocess.run(
            [python_cmd, "-c", python_code, str(icons_dir)],
            capture_output=True,
            text=True,
            timeout=SUBPROCESS_TIMEOUT_SHORT
        );
        if result.returncode == 0 {
            console.print(
                "  ✔ Generated platform icons (ico, icns, png sizes)", style="success"
            );
            return;
        } else {
            console.warning(f"  Icon generation failed: {result.stderr}");
        }
    } except Exception as e {
        console.warning(f"  Icon generation error: {e}");
    }

    console.warning(
        "  Could not generate platform icons. Install Pillow: pip install Pillow"
    );
}


"""Generate all icon formats using Pillow (in-process)."""
def _generate_icons_with_pillow(icons_dir: Path, Image: type) {
    png_path = icons_dir / "icon.png";
    img = Image.open(str(png_path)).convert("RGBA");

    # ICO (Windows) -- multiple sizes embedded in one file
    ico_sizes = [(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)];
    img.save(str(icons_dir / "icon.ico"), format="ICO", sizes=ico_sizes);
    console.print("  ✔ Generated icon.ico (Windows)", style="success");

    # ICNS (macOS) -- Pillow handles the internal size table
    try {
        img.save(str(icons_dir / "icon.icns"), format="ICNS");
        console.print("  ✔ Generated icon.icns (macOS)", style="success");
    } except Exception as e {
        # Some Pillow builds lack ICNS write support; not fatal.
        console.warning(f"  Could not generate icon.icns: {e}");
    }

    # Tauri standard PNG sizes for Linux and general use
    for size in [32, 128, 256] {
        resized = img.resize((size, size), Image.LANCZOS);
        resized.save(str(icons_dir / f"{size}x{size}.png"));
    }
    # 128x128@2x is a 256px image with @2x naming convention
    img.resize((256, 256), Image.LANCZOS).save(str(icons_dir / "128x128@2x.png"));
    console.print("  ✔ Generated PNG sizes (32, 128, 256, 128@2x)", style="success");
}


"""Generate main.rs.

api_base_url: embed this URL and skip sidecar port discovery.
    Empty string means dynamic discovery at runtime.
"""
def _generate_main_rs(tauri_dir: Path, api_base_url: str = "") {
    import json;

    # Read window config from tauri.conf.json (before we clear windows array)
    config_path = tauri_dir / "tauri.conf.json";
    win_title = "Jac App";
    win_width = 1200;
    win_height = 800;
    win_min_width = 800;
    win_min_height = 600;
    win_resizable = "true";

    if config_path.exists() {
        with open(config_path, "r") as f {
            config = json.load(f);
        }
        windows = config.get("app", {}).get("windows", []);
        if windows {
            win = windows[0];
            win_title = win.get("title", win_title);
            win_width = win.get("width", win_width);
            win_height = win.get("height", win_height);
            win_min_width = win.get("minWidth", win_min_width);
            win_min_height = win.get("minHeight", win_min_height);
            win_resizable = "true" if win.get("resizable", True) else "false";
        } else {
            # No windows in config — fall back to productName for title
            win_title = config.get("productName", win_title);
        }
    }

    main_rs = f'''// Prevents additional console window on Windows in release, DO NOT REMOVE!!
#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::io::{{BufRead, BufReader}};
use std::process::{{Command, Child, Stdio}};
use std::sync::Mutex;
use tauri::Manager;

// Global storage for sidecar process
static SIDECAR_PROCESS: Mutex<Option<Child>> = Mutex::new(None);
static API_BASE_URL: Mutex<Option<String>> = Mutex::new(None);

/// User-configured base URL from jac.toml (empty = dynamic discovery)
const CONFIGURED_BASE_URL: &str = "{api_base_url}";

fn find_and_start_sidecar(app: &tauri::AppHandle) -> Result<(), Box<dyn std::error::Error>> {{
    // Skip sidecar launch — user manages their own backend
    if !CONFIGURED_BASE_URL.is_empty() {{
        let mut url = API_BASE_URL.lock().unwrap();
        *url = Some(CONFIGURED_BASE_URL.to_string());
        eprintln!("Using configured API base URL: {{}}", CONFIGURED_BASE_URL);
        return Ok(());
    }}

    // Try to find the sidecar in bundled resources
    let resource_dir = app.path().resource_dir()?;

    // Possible sidecar names (onedir paths first, then onefile/wrapper fallbacks)
    let sidecar_names = if cfg!(windows) {{
        vec![
            "binaries/jac-sidecar/jac-sidecar.exe",  // onedir mode
            "binaries/jac-sidecar.exe",               // onefile fallback
            "binaries/jac-sidecar.bat",               // wrapper fallback
        ]
    }} else {{
        vec![
            "binaries/jac-sidecar/jac-sidecar",       // onedir mode
            "binaries/jac-sidecar",                    // onefile fallback
            "binaries/jac-sidecar.sh",                 // wrapper fallback
        ]
    }};

    let mut sidecar_path = None;
    for name in &sidecar_names {{
        let path = resource_dir.join(name);
        if path.exists() {{
            sidecar_path = Some(path);
            break;
        }}
    }}

    // If not found in resources, try relative to executable
    if sidecar_path.is_none() {{
        if let Ok(exe_path) = std::env::current_exe() {{
            if let Some(exe_dir) = exe_path.parent() {{
                let exe_dir = exe_dir.to_path_buf();
                for name in &sidecar_names {{
                    let path = exe_dir.join(name);
                    if path.exists() {{
                        sidecar_path = Some(path);
                        break;
                    }}
                }}
            }}
        }}
    }}

    if let Some(sidecar_path) = sidecar_path {{
        // Determine module path - check bundled resources first, then parent directories
        let module_path = {{
            // First, check in bundled resources (for AppImage/packaged builds)
            let bundled_main = resource_dir.join("jac").join("main.jac");
            if bundled_main.exists() {{
                Some(bundled_main)
            }} else {{
                // Fall back to checking parent directories (for dev builds)
                if let Ok(exe_path) = std::env::current_exe() {{
                    if let Some(exe_dir) = exe_path.parent() {{
                        let mut current = exe_dir.to_path_buf();
                        loop {{
                            let main_jac = current.join("main.jac");
                            if main_jac.exists() {{
                                break Some(main_jac);
                            }}
                            if !current.pop() {{
                                break None;
                            }}
                        }}
                    }} else {{
                        None
                    }}
                }} else {{
                    None
                }}
            }}
        }};

        // Build command to start sidecar
        let mut cmd = if cfg!(windows) {{
            if sidecar_path.extension().and_then(|s| s.to_str()) == Some("bat") {{
                let mut c = Command::new("cmd");
                c.arg("/C");
                c.arg(&sidecar_path);
                c
            }} else {{
                Command::new(&sidecar_path)
            }}
        }} else {{
            if sidecar_path.extension().and_then(|s| s.to_str()) == Some("sh") {{
                let mut c = Command::new("sh");
                c.arg(&sidecar_path);
                c
            }} else {{
                Command::new(&sidecar_path)
            }}
        }};

        // Add arguments
        if let Some(ref mp) = module_path {{
            cmd.arg("--module-path").arg(mp);
            // Also set base-path to the module's parent directory (bundled jac files location)
            if let Some(parent) = mp.parent() {{
                cmd.arg("--base-path").arg(parent);
            }}
        }} else {{
            cmd.arg("--module-path").arg("main.jac");
        }}
        cmd.arg("--port").arg("0"); // OS assigns free port
        cmd.arg("--host").arg("127.0.0.1");

        // Compute writable data path for runtime data (database, etc.)
        // AppImage bundles are read-only, so we need a writable location
        #[cfg(windows)]
        {{
            // Windows: prefer LOCALAPPDATA, fall back to USERPROFILE\AppData\Local
            if let Some(local_app_data) = std::env::var_os("LOCALAPPDATA") {{
                let data_path = std::path::Path::new(&local_app_data).join("jac-app");
                cmd.arg("--data-path").arg(data_path);
            }} else if let Some(user_profile) = std::env::var_os("USERPROFILE") {{
                let data_path = std::path::Path::new(&user_profile)
                    .join("AppData")
                    .join("Local")
                    .join("jac-app");
                cmd.arg("--data-path").arg(data_path);
            }}
        }}
        #[cfg(not(windows))]
        {{
            // Unix: HOME/.local/share/jac-app
            if let Some(home) = std::env::var_os("HOME") {{
                let data_path = std::path::Path::new(&home)
                    .join(".local")
                    .join("share")
                    .join("jac-app");
                cmd.arg("--data-path").arg(data_path);
            }}
        }}

        // Remove AppImage-injected Python environment variables that break system Python
        cmd.env_remove("PYTHONHOME");
        cmd.env_remove("PYTHONPATH");
        cmd.env_remove("PYTHONDONTWRITEBYTECODE");

        cmd.stdout(Stdio::piped());
        cmd.stderr(Stdio::inherit());

        match cmd.spawn() {{
            Ok(mut child) => {{
                let mut discovered_port: Option<u16> = None;
                if let Some(stdout) = child.stdout.take() {{
                    let reader = BufReader::new(stdout);
                    for line in reader.lines() {{
                        match line {{
                            Ok(line) => {{
                                eprintln!("[sidecar] {{}}", line);
                                if let Some(port_str) = line.strip_prefix("JAC_SIDECAR_PORT=") {{
                                    if let Ok(port) = port_str.trim().parse::<u16>() {{
                                        discovered_port = Some(port);
                                        break;
                                    }}
                                }}
                            }}
                            Err(_) => break,
                        }}
                    }}
                }}

                let mut process = SIDECAR_PROCESS.lock().unwrap();
                *process = Some(child);

                if let Some(port) = discovered_port {{
                    let base_url = format!("http://127.0.0.1:{{}}", port);
                    eprintln!("Sidecar started on {{}}", base_url);
                    let mut url = API_BASE_URL.lock().unwrap();
                    *url = Some(base_url);
                }} else {{
                    eprintln!("Error: Sidecar started but did not report its port.");
                    eprintln!("       Expected JAC_SIDECAR_PORT=<port> on stdout.");
                    return Err("Sidecar port discovery failed".into());
                }}
                Ok(())
            }}
            Err(e) => {{
                eprintln!("Failed to start sidecar: {{}}", e);
                Err(Box::new(e))
            }}
        }}
    }} else {{
        eprintln!("Sidecar not found in resources, skipping auto-start");
        Ok(())
    }}
}}

fn stop_sidecar() {{
    let mut process = SIDECAR_PROCESS.lock().unwrap();
    if let Some(mut child) = process.take() {{
        let _ = child.kill();
        let _ = child.wait();
        eprintln!("Sidecar stopped");
    }}
}}

/// Tauri command to get the API base URL (fallback if initialization_script timing fails)
#[tauri::command]
fn get_api_url() -> Option<String> {{
    API_BASE_URL.lock().unwrap().clone()
}}

fn main() {{
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![get_api_url])
        .setup(|app| {{
            // Start sidecar to discover dynamic port
            if let Err(e) = find_and_start_sidecar(app.handle()) {{
                eprintln!("Warning: Could not start sidecar: {{}}", e);
            }}

            // Build initialization script with API base URL
            let init_js = {{
                let url = API_BASE_URL.lock().unwrap();
                match *url {{
                    Some(ref base_url) => {{
                        eprintln!("Injecting API base URL: {{}}", base_url);
                        format!(
                            "globalThis.__JAC_API_BASE_URL__ = '{{}}';",
                            base_url
                        )
                    }}
                    None => String::new(),
                }}
            }};

            // Create window with initialization_script (runs BEFORE page JS)
            let mut builder = tauri::WebviewWindowBuilder::new(
                app,
                "main",
                tauri::WebviewUrl::App("index.html".into())
            )
            .title("{win_title}")
            .inner_size({win_width}.0, {win_height}.0)
            .min_inner_size({win_min_width}.0, {win_min_height}.0)
            .resizable({win_resizable});

            if !init_js.is_empty() {{
                builder = builder.initialization_script(&init_js);
            }}

            builder.build()?;

            Ok(())
        }})
        .on_window_event(|_window, event| {{
            // Clean up sidecar when last window closes
            if matches!(event, tauri::WindowEvent::CloseRequested {{ .. }}) {{
                stop_sidecar();
            }}
        }})
        .run(tauri::generate_context!())
        .expect("error while running tauri application");

    // Ensure sidecar is stopped on exit
    stop_sidecar();
}}
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
def _add_desktop_config(
    project_dir: Path, name: str, identifier: str, version: str
) -> None {
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

# Jac plugins to bundle (set to false to exclude from build)
[desktop.plugins]
jac_scale = true   # FastAPI server, auth, scaling features
byllm = true       # LLM providers integration (litellm)
jac_coder = true   # AI coding assistant
jac_mcp = true     # MCP server integration
# jac_client is always bundled (core sidecar dependency)
''';

    # Append the section
    with open(jac_toml_path, "a") as f {
        f.write(desktop_section);
    }
    console.print("  ✔ Added [desktop] section to jac.toml", style="success");
}

"""Check all required dependencies; print platform-specific install hints for any that are missing."""
def _check_dependencies {
    import platform as platform_module;
    import sys;

    system = platform_module.system();

    # Check Rust toolchain
    rust_installed = _check_rust();

    # Check build tools
    build_tools_installed = _check_build_tools(system);

    # Check system dependencies (Linux only)
    if system == "Linux" {
        _check_linux_dependencies();
    } elif system == "Darwin" {
        _check_macos_dependencies();
    } elif system == "Windows" {
        _check_windows_dependencies();
    }

    # Check Tauri CLI
    _check_and_install_tauri_cli();

    # Check Python and jaclang (required for sidecar)
    _check_python_and_jaclang();

    # Summary
    console.print("\n  Dependency check complete!", style="success");
    if not rust_installed {
        console.warning(
            "  Rust is required but not installed. Follow the instructions above."
        );
    }
    if not build_tools_installed {
        console.warning(
            "  Build tools are required but not installed. Follow the instructions above."
        );
    }
}

"""Check for the Rust toolchain; print install instructions if missing."""
def _check_rust -> bool {
    try {
        result = subprocess.run(
            ["rustc", "--version"],
            capture_output=True,
            text=True,
            timeout=SUBPROCESS_TIMEOUT_SHORT
        );
        if result.returncode == 0 {
            version = result.stdout.strip();
            console.print(f"  ✔ Rust toolchain found: {version}", style="success");
            return True;
        }
    } except Exception as e { }

    console.warning("  Rust toolchain not found");
    console.print(
        "  Rust is required for building desktop applications with Tauri.",
        style="muted"
    );
    console.print("  Install Rust: https://rustup.rs/", style="muted");
    console.print(
        "    Unix/macOS: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh",
        style="muted"
    );
    console.print(
        "    Windows:    winget install Rustlang.Rustup  (or download from https://rustup.rs/)",
        style="muted"
    );
    console.print(
        "  Re-run `jac setup desktop` after the toolchain is on PATH.", style="muted"
    );
    return False;
}

"""Check for platform build tools; print install command if missing."""
def _check_build_tools(system: str) -> bool {
    if system == "Linux" {
        # Check for gcc/cc
        try {
            subprocess.run(
                ["gcc", "--version"],
                capture_output=True,
                check=True,
                timeout=SUBPROCESS_TIMEOUT_SHORT
            );
            console.print("  ✔ Build tools (gcc) found", style="success");
            return True;
        } except Exception as e {
            console.warning("  Build tools (gcc) not found");
            _print_linux_build_tools_instructions();
            return False;
        }
    } elif system == "Darwin" {
        # Check for Xcode Command Line Tools
        try {
            result = subprocess.run(
                ["xcode-select", "-p"],
                capture_output=True,
                text=True,
                timeout=SUBPROCESS_TIMEOUT_SHORT
            );
            if result.returncode == 0 {
                console.print("  ✔ Xcode Command Line Tools found", style="success");
                return True;
            }
        } except Exception as e { }
        console.warning("  Xcode Command Line Tools not found");
        console.print("  Install with: xcode-select --install", style="muted");
        console.print(
            "  Complete the Apple installer dialog, then re-run `jac setup desktop`.",
            style="muted"
        );
        return False;
    } elif system == "Windows" {
        console.warning("  Windows build tools check not implemented");
        console.print(
            "  Install Visual Studio Build Tools (C++ workload):", style="muted"
        );
        console.print(
            "    winget install Microsoft.VisualStudio.2022.BuildTools --override \"--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended\"",
            style="muted"
        );
        console.print(
            "    (Or download from https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022)",
            style="muted"
        );
        return False;
    }
    return False;
}

"""Print the command that installs build tools on the detected Linux distro."""
def _print_linux_build_tools_instructions {
    distro = _detect_linux_distro();
    console.print("  Install build tools manually:", style="muted");
    if distro in ("ubuntu", "debian") {
        console.print(
            "    sudo apt-get update && sudo apt-get install -y build-essential",
            style="muted"
        );
    } elif distro == "fedora" {
        console.print("    sudo dnf install -y gcc gcc-c++", style="muted");
    } elif distro == "arch" {
        console.print("    sudo pacman -S --noconfirm base-devel", style="muted");
    } else {
        console.print(
            "    Ubuntu/Debian: sudo apt-get install -y build-essential", style="muted"
        );
        console.print(
            "    Fedora:        sudo dnf install -y gcc gcc-c++", style="muted"
        );
        console.print(
            "    Arch:          sudo pacman -S --noconfirm base-devel", style="muted"
        );
    }
    console.print("  Re-run `jac setup desktop` after installation.", style="muted");
}

"""Detect Linux distribution."""
def _detect_linux_distro -> str | None {
    try {
        # Check /etc/os-release
        if os.path.exists("/etc/os-release") {
            with open("/etc/os-release", "r") as f {
                content = f.read().lower();
                if "ubuntu" in content or "debian" in content {
                    if "ubuntu" in content {
                        return "ubuntu";
                    }
                    return "debian";
                } elif "fedora" in content {
                    return "fedora";
                } elif "arch" in content or "manjaro" in content {
                    return "arch";
                }
            }
        }
    } except Exception as e {
        return None;
    }
}

"""Check pkg-config + webkit2gtk; print distro install command if missing."""
def _check_linux_dependencies -> None {
    # Check pkg-config
    pkg_config_ok = False;
    try {
        subprocess.run(
            ["pkg-config", "--version"],
            capture_output=True,
            check=True,
            timeout=SUBPROCESS_TIMEOUT_SHORT
        );
        console.print("  ✔ pkg-config found", style="success");
        pkg_config_ok = True;
    } except Exception as e {
        console.warning("  pkg-config not found");
    }

    # Check for GTK/WebKit libraries
    webkit_ok = False;
    try {
        result = subprocess.run(
            ["pkg-config", "--exists", "webkit2gtk-4.1"],
            capture_output=True,
            timeout=SUBPROCESS_TIMEOUT_SHORT
        );
        if result.returncode == 0 {
            console.print("  ✔ GTK/WebKit libraries found", style="success");
            webkit_ok = True;
        }
    } except Exception as e {
        console.warning("  GTK/WebKit libraries not found");
    }

    if pkg_config_ok and webkit_ok {
        return;
    }

    console.warning("  Some Linux system dependencies are missing");
    distro = _detect_linux_distro();
    if distro {
        console.print(f"  Detected: {distro}", style="muted");
    }
    _print_manual_install_instructions(distro);
}

"""Print manual installation instructions."""
def _print_manual_install_instructions(distro: str | None) {
    console.print("  Install system dependencies manually:", style="muted");
    if distro in ("ubuntu", "debian") {
        console.print(
            "    sudo apt-get install libwebkit2gtk-4.1-dev build-essential curl wget libssl-dev libgtk-3-dev libayatana-appindicator3-dev librsvg2-dev",
            style="muted"
        );
    } elif distro == "fedora" {
        console.print(
            "    sudo dnf install webkit2gtk3-devel.x86_64 openssl-devel curl wget libappindicator-gtk3 librsvg2-devel",
            style="muted"
        );
    } elif distro == "arch" {
        console.print(
            "    sudo pacman -S webkit2gtk base-devel curl wget openssl appmenu-gtk-module gtk3 libappindicator-gtk3 librsvg libvips",
            style="muted"
        );
    } else {
        console.print(
            "    Ubuntu/Debian: sudo apt-get install libwebkit2gtk-4.1-dev build-essential curl wget libssl-dev libgtk-3-dev libayatana-appindicator3-dev librsvg2-dev",
            style="muted"
        );
        console.print(
            "    Fedora: sudo dnf install webkit2gtk3-devel.x86_64 openssl-devel curl wget libappindicator-gtk3 librsvg2-devel",
            style="muted"
        );
        console.print(
            "    Arch: sudo pacman -S webkit2gtk base-devel curl wget openssl appmenu-gtk-module gtk3 libappindicator-gtk3 librsvg libvips",
            style="muted"
        );
    }
    console.print("  Re-run `jac setup desktop` after installation.", style="muted");
}

"""Check macOS dependencies."""
def _check_macos_dependencies {
    # macOS dependencies are typically handled by Xcode Command Line Tools
    # which is checked in _check_build_tools
    console.print(
        "  ✔ macOS dependencies (handled by Xcode Command Line Tools)", style="success"
    );
}

"""Check Windows dependencies."""
def _check_windows_dependencies {
    console.warning("  Windows dependencies check not fully implemented");
    console.print(
        "  Please ensure Visual Studio Build Tools are installed:", style="muted"
    );
    console.print(
        "    https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022",
        style="muted"
    );
}

"""Check Python and jaclang (required for sidecar functionality)."""
def _check_python_and_jaclang -> None {
    # Check Python - try python3 first, then python
    python_ok = False;
    python_cmd = None;
    python_version = None;

    try {
        result = subprocess.run(
            ["python3", "--version"],
            capture_output=True,
            text=True,
            timeout=SUBPROCESS_TIMEOUT_SHORT
        );
        if result.returncode == 0 {
            python_version = result.stdout.strip();
            console.print(f"  ✔ Python found: {python_version}", style="success");
            python_ok = True;
            python_cmd = "python3";
        }
    } except Exception as e { }

    # Try python command as fallback if python3 not found
    if not python_ok {
        try {
            result = subprocess.run(
                ["python", "--version"],
                capture_output=True,
                text=True,
                timeout=SUBPROCESS_TIMEOUT_SHORT
            );
            if result.returncode == 0 {
                python_version = result.stdout.strip();
                console.print(f"  ✔ Python found: {python_version}", style="success");
                python_ok = True;
                python_cmd = "python";
            }
        } except Exception as e { }
    }

    if not python_ok {
        console.warning("  Python not found");
        console.print(
            "  Python is required for sidecar functionality (Jac backend).",
            style="muted"
        );
        console.print(
            "  Install Python: https://www.python.org/downloads/", style="muted"
        );
        return;
    }

    # Check jaclang using the detected python command
    jaclang_ok = False;
    try {
        result = subprocess.run(
            [python_cmd, "-m", "jaclang", "--version"],
            capture_output=True,
            text=True,
            timeout=SUBPROCESS_TIMEOUT_SHORT
        );
        if result.returncode == 0 {
            version = result.stdout.strip();
            console.print(f"  ✔ jaclang found: {version}", style="success");
            jaclang_ok = True;
        }
    } except Exception as e { }

    if not jaclang_ok {
        console.warning("  jaclang not found");
        console.print(
            "  jaclang is required for sidecar functionality (Jac backend).",
            style="muted"
        );
        console.print("\n  Would you like to install jaclang?", style="info");
        response = input("  Install jaclang? [Y/n]: ").strip().lower();
        if not response or response in ('y', 'yes') {
            console.print("  Installing jaclang...", style="muted");
            try {
                result = subprocess.run(
                    [python_cmd, "-m", "pip", "install", "jaclang"],
                    check=False,
                    timeout=SUBPROCESS_TIMEOUT_LONG,
                    capture_output=False  # Show output
                );
                if result.returncode == 0 {
                    console.print("  ✔ jaclang installed", style="success");
                } else {
                    console.warning("  Failed to install jaclang");
                    console.print(
                        "  Please install manually: pip install jaclang", style="muted"
                    );
                }
            } except Exception as e {
                console.warning(f"  Error installing jaclang: {e}");
                console.print(
                    "  Please install manually: pip install jaclang", style="muted"
                );
            }
        } else {
            console.print("  Skipping jaclang installation.", style="muted");
            console.print(
                "  Sidecar will not work without jaclang. Install with: pip install jaclang",
                style="muted"
            );
        }
    }

    # Check for PyInstaller (optional, for standalone builds)
    pyinstaller_ok = False;
    try {
        result = subprocess.run(
            [python_cmd, "-m", "PyInstaller", "--version"],
            capture_output=True,
            text=True,
            timeout=SUBPROCESS_TIMEOUT_SHORT
        );
        if result.returncode == 0 {
            version = result.stdout.strip();
            console.print(
                f"  ✔ PyInstaller found: {version} (standalone builds available)",
                style="success"
            );
            pyinstaller_ok = True;
        }
    } except Exception as e { }

    if not pyinstaller_ok {
        console.print(
            "  ⚠ PyInstaller not found - required for standalone builds",
            style="warning"
        );
        console.print("  Install with: pip install pyinstaller", style="muted");
        console.print(
            "  Without PyInstaller, builds will fall back to wrapper mode (requires Python on user machine)",
            style="muted"
        );
    }
}

"""Check and install Tauri CLI if needed."""
def _check_and_install_tauri_cli -> None {
    # Check if cargo tauri is available (preferred method)
    cargo_tauri_ok = False;
    try {
        result = subprocess.run(
            ["cargo", "tauri", "--version"],
            capture_output=True,
            text=True,
            timeout=SUBPROCESS_TIMEOUT_SHORT
        );
        if result.returncode == 0 {
            version = result.stdout.strip();
            console.print(f"  ✔ Tauri CLI found (cargo): {version}", style="success");
            return;
        }
    } except Exception as e { }

    # Check if bun tauri CLI is available (global install)
    import from jac_client.plugin.utils { get_bun }
    bun_tauri_ok = False;
    bun_path = get_bun();
    if bun_path {
        try {
            result = subprocess.run(
                [bun_path, "pm", "ls", "-g"],
                capture_output=True,
                text=True,
                timeout=SUBPROCESS_TIMEOUT_SHORT
            );
            if result.returncode == 0 and "@tauri-apps/cli" in result.stdout {
                console.print("  ✔ Tauri CLI found (bun)", style="success");
                return;
            }
        } except Exception { }
    }

    # Tauri CLI not found
    console.warning("  Tauri CLI not found");
    console.print(
        "  Tauri CLI is required for building desktop applications.", style="muted"
    );

    # Check if Rust/Cargo is available (required for cargo install)
    cargo_available = False;
    try {
        subprocess.run(
            ["cargo", "--version"],
            capture_output=True,
            check=True,
            timeout=SUBPROCESS_TIMEOUT_SHORT
        );
        cargo_available = True;
    } except Exception as e { }

    # Check if bun is available
    bun_available = bun_path is not None;

    if not cargo_available and not bun_available {
        console.print(
            "  Neither cargo nor bun is available. Cannot install Tauri CLI automatically.",
            style="muted"
        );
        console.print(
            "  Please install Rust (for cargo) or Bun (https://bun.sh) first.",
            style="muted"
        );
        return;
    }

    # Offer to install
    console.print("\n  Would you like to install Tauri CLI?", style="info");
    response = input("  Install Tauri CLI? [Y/n]: ").strip().lower();
    if not response or response in ('y', 'yes') {
        if cargo_available {
            console.print("  Installing Tauri CLI via cargo...", style="muted");
            try {
                result = subprocess.run(
                    ["cargo", "install", "tauri-cli"],
                    check=False,
                    timeout=SUBPROCESS_TIMEOUT_BUILD,
                    capture_output=False  # Show output
                );
                if result.returncode == 0 {
                    console.print("  ✔ Tauri CLI installed", style="success");
                    return;
                } else {
                    console.warning("  Failed to install via cargo. Trying npm...");
                }
            } except Exception as e {
                console.warning(f"  Error installing via cargo: {e}");
            }
        }
        if bun_available and bun_path {
            console.print("  Installing Tauri CLI via bun...", style="muted");
            try {
                result = subprocess.run(
                    [bun_path, "add", "-g", "@tauri-apps/cli"],
                    check=False,
                    timeout=SUBPROCESS_TIMEOUT_LONG,
                    capture_output=False  # Show output
                );
                if result.returncode == 0 {
                    console.print("  ✔ Tauri CLI installed", style="success");
                    return;
                } else {
                    console.warning("  Failed to install via bun");
                }
            } except Exception as e {
                console.warning(f"  Error installing via bun: {e}");
            }
        }
        console.print("  Please install manually:", style="muted");
        if cargo_available {
            console.print("    cargo install tauri-cli", style="muted");
        }
        if bun_available {
            console.print("    bun add -g @tauri-apps/cli", style="muted");
        }
    } else {
        console.print("  Skipping Tauri CLI installation.", style="muted");
        console.print(
            "  It will be needed when building. Install with:", style="muted"
        );
        if cargo_available {
            console.print("    cargo install tauri-cli", style="muted");
        }
        if bun_available {
            console.print("    bun add -g @tauri-apps/cli", style="muted");
        }
    }
}

"""Build desktop app - build web bundle first, then wrap with Tauri.

Uses super().build() to get the web bundle, then adds sidecar and Tauri wrapping.
"""
impl DesktopTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    import platform as platform_mod;
    console.print("\n🖥️  Building desktop app (Tauri)", style="bold");
    # Check if setup has been run
    tauri_dir = project_dir / "src-tauri";
    if not tauri_dir.exists() {
        raise RuntimeError("Desktop target not set up. Run 'jac setup desktop' first.");
    }
    # Check GLIBC compatibility for Linux production builds
    if platform_mod.system() == "Linux" {
        glibc_check = _check_glibc_compatibility();
        is_compatible = glibc_check[0];
        glibc_msg = glibc_check[2];
        if not is_compatible {
            console.warning(glibc_msg);
        } elif glibc_msg {
            console.print(f"  {glibc_msg}", style="muted");
        }
    }
    # Bake TOML base_url into the bundle; otherwise sidecar discovers port at runtime.
    toml_base_url = _get_toml_api_base_url(project_dir);
    if toml_base_url {
        os.environ[API_BASE_URL_ENV_VAR] = toml_base_url;
    }
    # Step 1: Build web bundle first using inherited WebTarget.build() via super()
    console.print("  Step 1: Building web bundle...", style="muted");
    os.environ["JAC_BUILD"] = "1";
    try {
        web_bundle_path = super.build(entry_file, project_dir, platform);
    } finally {
        os.environ.pop(API_BASE_URL_ENV_VAR, None);
        os.environ.pop("JAC_BUILD", None);
    }
    console.print(f"  ✔ Web bundle built: {web_bundle_path}", style="success");
    # Step 1.1: Copy assets to dist for desktop builds (Tauri serves from dist directly)
    _copy_assets_to_dist(project_dir, web_bundle_path.parent);
    # Regenerate main.rs with latest TOML config (base_url may have changed since setup)
    _generate_main_rs(tauri_dir, api_base_url=toml_base_url);
    # Load desktop config
    import from jac_client.plugin.src.desktop_config { DesktopConfig }
    desktop_config = DesktopConfig(project_dir=project_dir);
    is_client_only = desktop_config.is_client_only();
    # Step 1.5: Bundle sidecar (skipped in client_only mode)
    sidecar_bundled = False;
    if is_client_only {
        if not toml_base_url {
            raise RuntimeError(
                "client_only mode requires [plugins.client.api] base_url in jac.toml. "
                "Set it to your remote server URL."
            );
        }
        console.print(
            "  Step 1.5: Sidecar bundling skipped (client_only mode)", style="muted"
        );
        console.print(f"  Using remote backend: {toml_base_url}", style="muted");
    } else {
        try {
            console.print(
                "  Step 1.5: Bundling sidecar (Jac backend)...", style="muted"
            );
            plugins_config = None;
            try {
                plugins_config = desktop_config.get_plugins_config();
                if plugins_config {
                    console.print(f"  Plugins config: {plugins_config}", style="muted");
                }
            } except Exception as config_err {
                console.warning(
                    f"  Could not load plugins config: {config_err}, using defaults"
                );
            }
            sidecar_path = _bundle_sidecar(
                entry_file, project_dir, tauri_dir, platform, plugins_config
            );
            if sidecar_path and sidecar_path.exists() {
                console.print(f"  ✔ Sidecar bundled: {sidecar_path}", style="success");
                sidecar_bundled = True;
            }
        } except Exception as e {
            console.warning(f"  Sidecar bundling skipped: {e}");
            console.print(
                "  Note: Desktop app will need external API server", style="muted"
            );
            sidecar_bundled = False;
        }
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
                timeout=SUBPROCESS_TIMEOUT_SHORT
            );
            if result.returncode != 0 {
                console.warning(
                    "  Icon is invalid or too small for AppImage, regenerating..."
                );
                # Delete old icon before regenerating
                if icon_path.exists() {
                    icon_path.unlink();
                }
                _generate_default_icons(tauri_dir);
            }
        } except Exception as e {
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

    # Onedir output ships the sidecar as a directory (binaries/jac-sidecar/
    # containing the exe plus DLLs and data). When present, we bundle the
    # whole folder via a glob so every file is packaged.
    onedir_folder = binaries_dir / "jac-sidecar";
    has_onedir = onedir_folder.exists() and onedir_folder.is_dir();

    # Also look for onefile / wrapper scripts sitting directly in binaries_dir
    # (fallback modes when onedir bundling is disabled or unavailable).
    sidecar_files = [];
    for pattern in [
        "jac-sidecar.sh",
        "jac-sidecar.bat",
        "jac-sidecar",
        "jac-sidecar.exe"
    ] {
        found = list(binaries_dir.glob(pattern));
        for f in found {
            if f.is_file() and f.exists() {
                sidecar_files.append(f);
            }
        }
    }

    if not sidecar_files and not has_onedir {
        # Remove sidecar from resources if it was previously added but no longer exists
        if "bundle" in config and "resources" in config["bundle"] {
            resources = config["bundle"]["resources"];
            # Remove any jac-sidecar entries
            config["bundle"]["resources"] = [
                r
                for r in resources
                if not ("jac-sidecar" in r or "binaries/jac-sidecar" in r)
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

    # Add onedir folder glob (captures exe + DLLs + runtime data files)
    if has_onedir {
        onedir_resource = "binaries/jac-sidecar/**/*";
        if onedir_resource not in config["bundle"]["resources"] {
            config["bundle"]["resources"].append(onedir_resource);
            console.print(
                f"  ✔ Added sidecar folder to config: {onedir_resource}",
                style="success"
            );
        }
    }

    # Add sidecar binary path (relative to tauri_dir) for fallback modes
    for sidecar_file in sidecar_files {
        rel_path = sidecar_file.relative_to(tauri_dir);
        rel_str = str(rel_path.as_posix());
        if rel_str not in config["bundle"]["resources"] {
            config["bundle"]["resources"].append(rel_str);
            console.print(f"  ✔ Added sidecar to config: {rel_str}", style="success");
        }
    }
}

"""Bundle jac source files for desktop build."""
def _bundle_jac_sources(project_dir: Path, tauri_dir: Path, config: dict) -> None {
    jac_dir = tauri_dir / "jac";
    jac_dir.mkdir(parents=True, exist_ok=True);

    # Collect all .jac files from project (excluding .jac hidden directories)
    jac_files = [];
    for jac_file in project_dir.rglob("*.jac") {
        # Skip hidden directories and generated files
        parts = jac_file.relative_to(project_dir).parts;
        if any(p.startswith(".") for p in parts) {
            continue;
        }
        if "src-tauri" in parts {
            continue;
        }
        jac_files.append(jac_file);
    }

    if not jac_files {
        return;
    }

    # Copy jac files preserving directory structure
    for jac_file in jac_files {
        rel_path = jac_file.relative_to(project_dir);
        dest = jac_dir / rel_path;
        dest.parent.mkdir(parents=True, exist_ok=True);
        shutil.copy2(jac_file, dest);
    }

    console.print(
        f"  ✔ Bundled {len(jac_files)} .jac file(s) for desktop", style="success"
    );

    # Copy jac.toml to the jac directory (required for config discovery in bundled app)
    jac_toml = project_dir / "jac.toml";
    if jac_toml.exists() {
        shutil.copy2(jac_toml, jac_dir / "jac.toml");
        console.print("  ✔ Bundled jac.toml for desktop", style="success");
    }

    # Copy assets directory to jac directory (for static asset serving by sidecar)
    assets_dir = project_dir / "assets";
    jac_assets_dir = jac_dir / "assets";
    if assets_dir.exists() and assets_dir.is_dir() {
        if jac_assets_dir.exists() {
            shutil.rmtree(jac_assets_dir);
        }
        shutil.copytree(assets_dir, jac_assets_dir);
        console.print("  ✔ Bundled assets/ for desktop", style="success");
    }

    # Add jac/* to bundle resources
    if "bundle" not in config {
        config["bundle"] = {};
    }
    if "resources" not in config["bundle"] {
        config["bundle"]["resources"] = [];
    }

    # Add jac directory pattern if not already present
    jac_resource = "jac/**/*";
    if jac_resource not in config["bundle"]["resources"] {
        config["bundle"]["resources"].append(jac_resource);
    }
}

"""Populate icon array in tauri.conf.json from icons directory."""
def _populate_icon_array(tauri_dir: Path, config: dict) {
    # Populate icon array if empty or missing
    if "bundle" not in config {
        config["bundle"] = {};
    }
    if "icon" not in config["bundle"]
    or not config["bundle"]["icon"]
    or len(config["bundle"]["icon"]) == 0 {
        # Scan icons directory for PNG files
        icons_dir = tauri_dir / "icons";
        icon_files = [];
        if icons_dir.exists() {
            for icon_file in icons_dir.iterdir() {
                if icon_file.is_file()
                and icon_file.suffix.lower() in (".png", ".ico", ".icns") {
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
            console.print(
                f"  ✔ Populated icon array with {len(icon_files)} icon(s)",
                style="success"
            );
        }
    }
}

"""Copy assets from compiled/assets to dist/static/assets for desktop builds.

Desktop builds (Tauri) serve files directly from the dist folder,
not via the Jac server. Assets are referenced with /static/assets/ URLs
so we need to mirror that path structure in the dist folder.
"""
def _copy_assets_to_dist(project_dir: Path, dist_dir: Path) -> None {
    client_dir = project_dir / '.jac' / 'client';
    compiled_assets = client_dir / 'compiled' / 'assets';
    # Mirror the /static/assets/ URL structure in dist
    dist_static = dist_dir / 'static';
    dist_assets = dist_static / 'assets';

    if not compiled_assets.exists() {
        return;  # No assets to copy
    }

    # Create static directory and copy assets
    dist_static.mkdir(parents=True, exist_ok=True);
    if dist_assets.exists() {
        shutil.rmtree(dist_assets);
    }
    shutil.copytree(compiled_assets, dist_assets);

    # Also copy styles.css to static/ if it exists in dist
    dist_styles = dist_dir / 'styles.css';
    if dist_styles.exists() {
        shutil.copy2(dist_styles, dist_static / 'styles.css');
    }

    console.print("  ✔ Copied assets to dist/static/assets/", style="success");
}

"""Update tauri.conf.json to point to the built web bundle."""
def _update_tauri_config_for_build(
    tauri_dir: Path,
    project_dir: Path,
    web_bundle_path: Path,
    sidecar_bundled: bool = False
) {
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
    if "beforeBuildCommand" in config["build"]
    and config["build"]["beforeBuildCommand"] is None {
        del config["build"]["beforeBuildCommand"];
    }

    # main.rs creates the window via WebviewWindowBuilder (for initialization_script)
    config.setdefault("app", {})["windows"] = [];

    # Populate icon array if empty or missing
    _populate_icon_array(tauri_dir, config);

    # Bundle jac source files for desktop build
    _bundle_jac_sources(project_dir, tauri_dir, config);

    # Add sidecar binary if it exists
    _add_sidecar_to_config(tauri_dir, config);

    # Write updated config
    with open(config_path, "w") as f {
        json.dump(config, f, indent=2);
    }

    console.print("  ✔ Updated tauri.conf.json", style="success");
}

"""Check if appimagetool is available and can run."""
def _check_appimagetool -> tuple[bool, str | None] {
    # First check if the command exists
    (exists, _) = _check_command_available(["which", "appimagetool"], timeout=2);
    if not exists {
        return (False, "appimagetool not found in PATH");
    }

    # Try to run appimagetool to see if it works
    try {
        result = subprocess.run(
            ["appimagetool", "--version"],
            capture_output=True,
            timeout=SUBPROCESS_TIMEOUT_SHORT,
            text=True
        );
        if result.returncode == 0 {
            return (True, None);
        }
        # Check if it's a FUSE error
        error_output = result.stderr or result.stdout or "";
        if _is_fuse_error(error_output) {
            return (False, _get_fuse_install_hint());
        }
        return (False, f"appimagetool failed: {error_output[:100]}");
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
            console.print(
                "    sudo apt-get update && sudo apt-get install -y libfuse2",
                style="muted"
            );
            console.print(
                "  Or use --appimage-extract to extract appimagetool first",
                style="muted"
            );
        } else {
            console.print("  Install it with:", style="muted");
            console.print(
                "    wget https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage",
                style="muted"
            );
            console.print("    chmod +x appimagetool-x86_64.AppImage", style="muted");
            console.print(
                "    sudo mv appimagetool-x86_64.AppImage /usr/local/bin/appimagetool",
                style="muted"
            );
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
            console.print(
                f"  ✔ AppImage already exists: {appimage_path.name}", style="success"
            );
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
            timeout=SUBPROCESS_TIMEOUT_LONG
        );

        if result.returncode != 0 {
            error_output = result.stderr or result.stdout or "Unknown error";
            if _is_fuse_error(error_output) {
                console.warning(
                    "  Failed to create AppImage: FUSE library not available"
                );
                console.print(f"  {_get_fuse_install_hint()}", style="muted");
                console.print(
                    "  For WSL2, you may also need: sudo apt-get install -y fuse",
                    style="muted"
                );
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
        if _is_fuse_error(error_msg) {
            console.warning(f"  FUSE library error. {_get_fuse_install_hint()}");
        } else {
            console.warning(f"  Error creating AppImage: {error_msg[:200]}");
        }
        return None;
    }
}

"""Run cargo tauri build and return path to bundle."""
def _run_tauri_build(tauri_dir: Path, target_platform: Optional[str] = None) -> Path {
    import platform as platform_mod;
    # Determine target based on platform
    target = None;
    if target_platform == "windows" {
        target = "x86_64-pc-windows-msvc";
    } elif target_platform == "macos" {
        # Try to detect architecture
        if platform_mod.machine() == "arm64" {
            target = "aarch64-apple-darwin";
        } else {
            target = "x86_64-apple-darwin";
        }
    } elif target_platform == "linux" {
        target = "x86_64-unknown-linux-gnu";
    }

    # Build command - prefer cargo tauri build, fallback to bun if package.json has tauri scripts
    build_cmd = ["cargo", "tauri", "build"];
    if target {
        build_cmd.extend(["--target", target]);
    }

    # Check if package.json has tauri scripts, use bun run if so
    package_json = tauri_dir.parent / "package.json";
    use_bun = False;
    if package_json.exists() {
        try {
            with open(package_json, "r") as f {
                package_data = json.load(f);
                scripts = package_data.get("scripts", {});
                if "tauri" in scripts or "tauri:build" in scripts {
                    use_bun = True;
                }
            }
        } except Exception as e {
            console.warning("  Failed to check package.json for tauri scripts");
        }
    }

    if use_bun {
        # Resolve bun binary (system PATH → .jac/bin/ → auto-download)
        import from jac_client.plugin.utils { get_bun }
        bun = get_bun();
        if not bun {
            console.error(
                "Bun is required for this project but could not be found or installed. "
                "Install manually: https://bun.sh"
            );
            raise RuntimeError("Bun is required") from None;
        }
        # Use bun run tauri build
        build_cmd = [bun, "run", "tauri", "build"];
        if target {
            build_cmd.extend(["--", "--target", target]);
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
    installers = [
        f
        for f in bundle_files
        if f.is_file()
        and f.suffix in [".exe", ".dmg", ".AppImage", ".deb", ".rpm", ".msi"]
    ];

    # For Linux: if no AppImage but AppDir exists, try to create AppImage
    is_linux_build = (target_platform == "linux")
    or (not target_platform and target and "linux" in target);
    if not installers and is_linux_build {
        appimage_dir = bundle_dir / "appimage";
        if appimage_dir.exists() {
            # Look for AppDir directories
            appdirs = [
                d
                for d in appimage_dir.iterdir()
                if d.is_dir() and d.name.endswith(".AppDir")
            ];
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

"""Bundle sidecar for desktop distribution.

By default, uses PyInstaller to create a standalone binary with Python + jaclang bundled.
If PyInstaller fails or is unavailable, falls back to wrapper script that requires system Python.

Set JAC_SIDECAR_STANDALONE=0 to skip PyInstaller and use wrapper script.
"""
def _bundle_sidecar(
    entry_file: Path,
    project_dir: Path,
    tauri_dir: Path,
    target_platform: Optional[str] = None,
    plugins_config: dict | None = None
) -> Path | None {
    import platform as platform_module;

    # Determine output directory
    binaries_dir = tauri_dir / "binaries";
    binaries_dir.mkdir(parents=True, exist_ok=True);

    # Determine platform
    is_windows = target_platform == "windows"
    or (target_platform is None and platform_module.system() == "Windows");

    # Use PyInstaller by default for standalone distribution (no Python required on user machine)
    # Set JAC_SIDECAR_STANDALONE=0 to use wrapper script instead (requires Python + jaclang)
    use_pyinstaller = os.environ.get("JAC_SIDECAR_STANDALONE", "1") != "0";

    if use_pyinstaller {
        result = _bundle_sidecar_pyinstaller(
            entry_file, project_dir, tauri_dir, binaries_dir, is_windows, plugins_config
        );
        if result {
            return result;
        }
        console.warning("PyInstaller bundling failed, falling back to wrapper script");
    }

    # Fallback: Create wrapper script
    return _create_sidecar_wrapper(binaries_dir, is_windows);
}

"""Bundle sidecar using PyInstaller for standalone distribution."""
def _bundle_sidecar_pyinstaller(
    entry_file: Path,
    project_dir: Path,
    tauri_dir: Path,
    binaries_dir: Path,
    is_windows: bool,
    plugins_config: dict | None = None
) -> Path | None {
    import sys;
    import shutil;

    # Check if PyInstaller is available
    try {
        result = subprocess.run(
            [sys.executable, "-m", "PyInstaller", "--version"],
            capture_output=True,
            text=True,
            timeout=10
        );
        if result.returncode != 0 {
            console.warning(
                "PyInstaller not installed. Install with: pip install pyinstaller"
            );
            return None;
        }
        pyinstaller_version = result.stdout.strip();
        console.print(f"  Using PyInstaller {pyinstaller_version}", style="muted");
    } except Exception as e {
        console.warning(f"PyInstaller check failed: {e}");
        return None;
    }

    # Determine output binary name
    binary_name = "jac-sidecar.exe" if is_windows else "jac-sidecar";

    # Create entry script for PyInstaller (can't use -m syntax in spec)
    entry_script = tauri_dir / "sidecar_entry.py";
    with open(entry_script, "w") as f {
        f.write(
            '''#!/usr/bin/env python3
# Entry point for PyInstaller-bundled sidecar
# Plugin registration for frozen apps is handled in sidecar/main.py
import os
import sys

# Force UTF-8 mode on Windows to avoid charmap codec errors when the
# console code page is not cp65001. Complemented by rthook_utf8.py.
os.environ["PYTHONUTF8"] = "1"

# Windows multiprocessing freeze support - MUST be called before any other
# imports that may start child processes. Required for PyInstaller apps that
# use multiprocessing on Windows (spawn start method re-executes the frozen
# binary and needs this guard to avoid re-entering main()).
if sys.platform == "win32":
    import multiprocessing
    multiprocessing.freeze_support()

from jac_client.plugin.src.targets.desktop.sidecar.main import main
if __name__ == "__main__":
    main()
'''
        );
    }

    # Create runtime hook to force UTF-8 mode (fixes charmap codec errors on
    # Windows where the default console code page is not UTF-8). PyInstaller
    # runs runtime hooks before user code, ensuring PYTHONUTF8 takes effect
    # before any stdlib module is imported.
    runtime_hook = tauri_dir / "rthook_utf8.py";
    with open(runtime_hook, "w") as f {
        f.write("import os; os.environ['PYTHONUTF8'] = '1'\n");
    }

    # Auto-install Python dependencies from jac.toml before bundling
    jac_toml_path = project_dir / "jac.toml";
    if jac_toml_path.exists() {
        try {
            import tomllib;
            with open(jac_toml_path, "rb") as f {
                toml_data = tomllib.load(f);
            }
            python_deps = toml_data.get("dependencies", {});

            # Count valid dependencies first
            dep_count = 0;
            for (name, version) in python_deps.items() {
                if isinstance(version, str) {
                    dep_count += 1;
                }
            }

            if dep_count > 0 {
                console.print(
                    f"  Installing {dep_count} Python dependencies from jac.toml...",
                    style="muted"
                );

                # Install each dependency
                for (name, version) in python_deps.items() {
                    # Skip sub-tables (npm, git, etc.) - only process string values
                    if not isinstance(version, str) {
                        continue;
                    }

                    # Build pip install spec
                    if version and not version.startswith("*") {
                        dep_spec = f"{name}{version}";
                    } else {
                        dep_spec = name;
                    }

                    try {
                        result = subprocess.run(
                            [sys.executable, "-m", "pip", "install", dep_spec, "-q"],
                            capture_output=True,
                            text=True,
                            timeout=120
                        );
                        if result.returncode == 0 {
                            console.print(f"    ✔ {dep_spec}", style="success");
                        } else {
                            console.warning(
                                f"    ✖ Failed to install {dep_spec}: {result.stderr.strip()}"
                            );
                        }
                    } except Exception as e {
                        console.warning(f"    ✖ Failed to install {dep_spec}: {e}");
                    }
                }
            }
        } except Exception as e {
            console.warning(f"  Could not read dependencies from jac.toml: {e}");
        }
    }

    # Create PyInstaller spec file
    spec_path = tauri_dir / "jac-sidecar.spec";
    spec_content = _generate_pyinstaller_spec(
        entry_script, project_dir, binary_name, plugins_config
    );
    with open(spec_path, "w") as f {
        f.write(spec_content);
    }
    console.print(f"  Generated PyInstaller spec: {spec_path.name}", style="muted");

    # Run PyInstaller
    console.print(
        "  Bundling sidecar with PyInstaller (this may take a while)...", style="muted"
    );
    dist_dir = tauri_dir / "dist";
    build_dir = tauri_dir / "build";

    try {
        result = subprocess.run(
            [
                sys.executable,
                "-m",
                "PyInstaller",
                "--noconfirm",
                "--distpath",
                str(dist_dir),
                "--workpath",
                str(build_dir),
                str(spec_path)
            ],
            capture_output=True,
            text=True,
            timeout=SUBPROCESS_TIMEOUT_BUILD,
            cwd=str(project_dir)
        );

        if result.returncode != 0 {
            console.warning(f"PyInstaller failed:\n{result.stderr}");
            return None;
        }

        # Find the bundled binary. With onedir mode the output is
        # dist/jac-sidecar/<binary>; with onefile fallback it is dist/<binary>.
        bundled_dir = dist_dir / "jac-sidecar";
        bundled_binary = bundled_dir / binary_name;

        if bundled_binary.exists() {
            # Onedir mode - copy the entire jac-sidecar folder to binaries/
            # so DLLs and runtime data ship alongside the exe.
            output_dir = binaries_dir / "jac-sidecar";
            if output_dir.exists() {
                shutil.rmtree(output_dir);
            }
            shutil.copytree(bundled_dir, output_dir);
            output_path = output_dir / binary_name;
        } else {
            # Fallback: onefile mode (dist/<binary>)
            bundled_binary = dist_dir / binary_name;
            if not bundled_binary.exists() {
                console.warning(f"Bundled binary not found at {bundled_binary}");
                return None;
            }
            output_path = binaries_dir / binary_name;
            shutil.copy2(bundled_binary, output_path);
        }

        # Cleanup build artifacts
        if build_dir.exists() {
            shutil.rmtree(build_dir);
        }

        console.print(
            f"  ✔ Bundled standalone sidecar: {output_path.name}", style="success"
        );
        console.print(
            f"  Size: {output_path.stat().st_size / 1024 / 1024:.1f} MB", style="muted"
        );
        return output_path;
    } except subprocess.TimeoutExpired {
        console.warning("PyInstaller timed out after 10 minutes");
        return None;
    } except Exception as e {
        console.warning(f"PyInstaller error: {e}");
        return None;
    }
}

"""Generate PyInstaller spec file for sidecar bundling."""
def _generate_pyinstaller_spec(
    entry_script: Path,
    project_dir: Path,
    binary_name: str,
    plugins_config: dict | None = None
) -> str {
    # Default plugins config - all enabled
    if plugins_config is None {
        plugins_config = {
            'jac_scale': True,
            'byllm': True,
            'jac_coder': True,
            'jac_mcp': True
        };
    }

    # Convert plugins config to Python code string for the spec file
    plugins_config_str = str(plugins_config);

    # entry_script is the actual Python file to bundle (sidecar_entry.py)
    return f'''# -*- mode: python ; coding: utf-8 -*-
# PyInstaller spec for Jac Sidecar
# Auto-generated by jac-client desktop build

import sys
from pathlib import Path

# Plugin configuration from [desktop.plugins] in jac.toml
PLUGINS_CONFIG = {plugins_config_str}

# Manual hidden imports - only for stdlib and PyInstaller runtime deps
# (pip packages like jaclang, jac_client, websockets are handled by collect_all() below)
hiddenimports = [
    # Python stdlib modules (can't be collected via collect_all)
    'sqlite3', 'hashlib', 'secrets', 'http.server', 'json',
    'asyncio', 'inspect', 'typing', 'pathlib',
    'pdb', 'bdb', 'cmd', 'code', 'codeop', 'readline',
    # Windows multiprocessing support (required for frozen apps; spawn start
    # method re-executes the frozen binary and needs these modules bundled)
    'multiprocessing', 'multiprocessing.pool', 'multiprocessing.process',
    'multiprocessing.spawn', 'multiprocessing.popen_spawn_win32',
    # PyInstaller runtime deps - use importlib.metadata instead of pkg_resources
    'appdirs', 'setuptools',
    'packaging', 'packaging.version', 'packaging.specifiers', 'packaging.requirements',
    'importlib.metadata', 'importlib.resources',
    # jaraco packages (setuptools deps for Python 3.12+)
    'jaraco', 'jaraco.functools', 'jaraco.context', 'jaraco.text',
]

# Check plugin availability (collect_all() below handles the actual bundling)
print("\\n[Checking plugins...]")
if PLUGINS_CONFIG.get('jac_scale', True):
    try:
        import jac_scale
        print("  jac_scale: available")
    except ImportError:
        print("  jac_scale: not installed")
else:
    print("  jac_scale: disabled in config")

if PLUGINS_CONFIG.get('byllm', True):
    try:
        import byllm
        print("  byllm: available")
    except ImportError:
        print("  byllm: not installed")
else:
    print("  byllm: disabled in config")

if PLUGINS_CONFIG.get('jac_coder', True):
    try:
        import jac_coder
        print("  jac_coder: available")
    except ImportError:
        print("  jac_coder: not installed")
else:
    print("  jac_coder: disabled in config")

if PLUGINS_CONFIG.get('jac_mcp', True):
    try:
        import jac_mcp
        print("  jac_mcp: available")
    except ImportError:
        print("  jac_mcp: not installed")
else:
    print("  jac_mcp: disabled in config")

# jac_client is always bundled (core dependency for sidecar entry point)
try:
    import jac_client
    print("  jac_client: available (core)")
except ImportError:
    print("  jac_client: NOT INSTALLED - sidecar will fail!")

# Use collect_all() for comprehensive package bundling (scalable approach)
from PyInstaller.utils.hooks import collect_all, collect_data_files, collect_submodules, copy_metadata

datas = []
binaries = []
all_hiddenimports = []

def safe_collect_all(pkg_name):
    """Safely collect all data, binaries, and imports for a package."""
    try:
        d, b, h = collect_all(pkg_name)
        print(f"  collect_all('{{pkg_name}}'): {{len(d)}} datas, {{len(b)}} binaries, {{len(h)}} imports")
        return d, b, h
    except Exception as e:
        print(f"  collect_all('{{pkg_name}}'): skipped - {{e}}")
        return [], [], []

def get_package_deps(pkg_name):
    """Get direct dependencies of a package from its metadata."""
    try:
        from importlib.metadata import requires
        reqs = requires(pkg_name) or []
        deps = []
        for req in reqs:
            # Parse requirement string (e.g., "litellm>=1.81.15,<1.83.0" -> "litellm")
            dep_name = req.split('[')[0].split('>')[0].split('<')[0].split('=')[0].split('!')[0].split(';')[0].strip()
            if dep_name:
                # Convert package name to module name
                module_name = dep_name.replace('-', '_')
                deps.append(module_name)
        return deps
    except Exception:
        return []

def collect_with_deps(pkg_name, collected=None):
    """Collect a package and its dependencies recursively."""
    if collected is None:
        collected = set()
    if pkg_name in collected:
        return [], [], []
    collected.add(pkg_name)

    all_d, all_b, all_h = safe_collect_all(pkg_name)

    # Also collect direct dependencies
    for dep in get_package_deps(pkg_name):
        if dep not in collected:
            d, b, h = safe_collect_all(dep)
            all_d += d
            all_b += b
            all_h += h
            collected.add(dep)

    return all_d, all_b, all_h

# Track collected packages to avoid duplicates
collected_packages = set()

# Core packages - always bundle completely (with their dependencies)
print("\\n[Collecting core packages...]")
for pkg in ['jaclang', 'jac_client', 'setuptools', 'appdirs', 'packaging']:
    d, b, h = collect_with_deps(pkg, collected_packages)
    datas += d
    binaries += b
    all_hiddenimports += h

# Plugin packages - bundle based on config (with their dependencies)
print("\\n[Collecting plugin packages...]")
if PLUGINS_CONFIG.get('jac_scale', True):
    d, b, h = collect_with_deps('jac_scale', collected_packages)
    datas += d
    binaries += b
    all_hiddenimports += h

if PLUGINS_CONFIG.get('byllm', True):
    d, b, h = collect_with_deps('byllm', collected_packages)
    datas += d
    binaries += b
    all_hiddenimports += h

if PLUGINS_CONFIG.get('jac_coder', True):
    d, b, h = collect_with_deps('jac_coder', collected_packages)
    datas += d
    binaries += b
    all_hiddenimports += h

if PLUGINS_CONFIG.get('jac_mcp', True):
    d, b, h = collect_with_deps('jac_mcp', collected_packages)
    datas += d
    binaries += b
    all_hiddenimports += h

# jac_client is always bundled as a core package (sidecar entry point depends on it)
# No need to gate it behind PLUGINS_CONFIG

# Merge collected imports with manual hiddenimports
hiddenimports.extend(all_hiddenimports)

# Add project .jac files (exclude build artifacts to avoid recursive nesting)
project_dir = Path(r'{project_dir}')
EXCLUDE_DIRS = ['src-tauri', 'node_modules', '__pycache__', '.git', 'dist', '__jac_gen__', '.jac']
for jac_file in project_dir.rglob('*.jac'):
    # Skip files inside excluded directories
    if any(part in EXCLUDE_DIRS for part in jac_file.relative_to(project_dir).parts):
        continue
    rel_path = jac_file.relative_to(project_dir)
    datas.append((str(jac_file), str(rel_path.parent) or '.'))

# Add jac.toml if exists
jac_toml = project_dir / 'jac.toml'
if jac_toml.exists():
    datas.append((str(jac_toml), '.'))

# Read Python dependencies from jac.toml and add to hiddenimports
try:
    import tomllib
    with open(jac_toml, 'rb') as f:
        toml_data = tomllib.load(f)
    # Get [dependencies] section (Python packages)
    python_deps = toml_data.get('dependencies', {{}})
    for dep_name, dep_version in python_deps.items():
        # Skip sub-tables like npm, git, etc.
        if isinstance(dep_version, str):
            # Convert package name to module name (e.g., jac-scale -> jac_scale)
            module_name = dep_name.replace('-', '_')
            hiddenimports.append(module_name)
            try:
                hiddenimports += collect_submodules(module_name)
            except Exception:
                pass
    print(f"Added {{len([d for d in python_deps.values() if isinstance(d, str)])}} Python dependencies from jac.toml")

    # Read [desktop.bundle] extra_data glob patterns from jac.toml and bundle
    # every matching file into the sidecar. Paths are glob patterns rooted at
    # project_dir; matches are placed at the same relative path inside the
    # frozen bundle so `Path(__file__).parent / "some/file"` still resolves
    # at runtime.
    desktop_cfg = toml_data.get('desktop', {{}})
    bundle_cfg = desktop_cfg.get('bundle', {{}}) if isinstance(desktop_cfg, dict) else {{}}
    extra_data_patterns = bundle_cfg.get('extra_data', []) if isinstance(bundle_cfg, dict) else []
    if extra_data_patterns:
        extra_count = 0
        for pattern in extra_data_patterns:
            if isinstance(pattern, str):
                for match in project_dir.glob(pattern):
                    if match.is_file():
                        rel = match.relative_to(project_dir)
                        datas.append((str(match), str(rel.parent) or '.'))
                        extra_count += 1
        if extra_count:
            print(f"Added {{extra_count}} extra data file(s) from [desktop.bundle] extra_data")
except Exception as e:
    print(f"Warning: Could not read Python dependencies from jac.toml: {{e}}")

# Note: collect_all() already handles submodules, data files, and binaries
# No need for separate collect_submodules() calls

# Drop bundled test/benchmark data that bloats the sidecar and can push
# nested paths past Windows MAX_PATH (260 chars). The litellm package
# ships benchmark JSONs at e.g.
#   litellm/proxy/guardrails/guardrail_hooks/<provider>/guardrail_benchmarks/results/<long-name>.json
# which combined with the runner checkout root and Tauri's binaries staging
# directory exceed MAX_PATH and break NSIS/WiX bundling on Windows.
# Match against the dest path; substring check, case-insensitive, slash-normalized.
EXCLUDE_DATA_PATTERNS = [
    'guardrail_benchmarks',          # litellm benchmark JSONs (causes Windows bundle failure)
    'litellm/tests',                 # tests, runtime-irrelevant
    'litellm/proxy/tests',
    'litellm/proxy/example_config_yaml',
]

def _should_exclude(dest):
    if not dest:
        return False
    # chr(92) is backslash; avoids brittle escape-counting through the jac
    # template string into the generated spec.
    norm = dest.replace(chr(92), '/').lower()
    return any(pat in norm for pat in EXCLUDE_DATA_PATTERNS)

_pre_d = len(datas)
datas = [(s, d) for s, d in datas if not _should_exclude(d)]
_pre_b = len(binaries)
binaries = [(s, d) for s, d in binaries if not _should_exclude(d)]
print(f"\\n[Excluded {{_pre_d - len(datas)}} data files, {{_pre_b - len(binaries)}} binaries from sidecar (MAX_PATH/bloat protection)]")

a = Analysis(
    [r'{entry_script}'],
    pathex=[str(project_dir)],
    binaries=binaries,
    datas=datas,
    hiddenimports=list(set(hiddenimports)),  # deduplicate
    hookspath=[],
    hooksconfig={{}},
    runtime_hooks=[str(Path(r'{entry_script}').parent / 'rthook_utf8.py')],
    excludes=['tkinter', 'matplotlib', 'numpy', 'pandas', 'scipy', 'pkg_resources'],
    noarchive=False,
)

pyz = PYZ(a.pure)

# Use onedir mode (EXE + COLLECT) instead of onefile. On Windows + Python 3.13
# onefile builds hang on startup due to temp-directory extraction issues;
# onedir ships DLLs alongside the exe and skips extraction entirely. On other
# platforms onedir is also faster to start, so we use it uniformly.
exe = EXE(
    pyz,
    a.scripts,
    [],
    exclude_binaries=True,
    name='{binary_name.replace(
        ".exe", ""
    )}',
    debug=False,
    bootloader_ignore_signals=False,
    strip=False,
    upx=True,
    console=True,
    disable_windowed_traceback=False,
    argv_emulation=False,
    target_arch=None,
    codesign_identity=None,
    entitlements_file=None,
)

coll = COLLECT(
    exe,
    a.binaries,
    a.datas,
    strip=False,
    upx=True,
    upx_exclude=[],
    name='jac-sidecar',
)
''';
}

"""Create wrapper script for sidecar (requires system Python)."""
def _create_sidecar_wrapper(binaries_dir: Path, is_windows: bool) -> Path {
    import stat;

    if is_windows {
        script_name = "jac-sidecar.bat";
        script_content = '''@echo off
REM Jac Sidecar Wrapper - Runs Jac backend using system Python
REM This requires Python and jaclang to be installed

python -m jac_client.plugin.src.targets.desktop.sidecar.main %*
''';
    } else {
        script_name = "jac-sidecar.sh";
        script_content = '''#!/bin/bash
# Jac Sidecar Wrapper - Runs Jac backend using system Python
# This requires Python and jaclang to be installed

exec python3 -m jac_client.plugin.src.targets.desktop.sidecar.main "$@"
''';
    }

    output_path = binaries_dir / script_name;
    with open(output_path, "w") as f {
        f.write(script_content);
    }

    # Make executable on Unix systems
    if not is_windows {
        st = output_path.stat();
        output_path.chmod(st.st_mode | stat.S_IEXEC | stat.S_IXGRP | stat.S_IXOTH);
    }

    console.print(f"  ✔ Created sidecar wrapper: {script_name}", style="success");
    console.print(
        f"  Note: Wrapper mode - requires Python and jaclang on user machine",
        style="muted"
    );
    console.print(f"  Run: pip install jaclang jac-scale", style="muted");
    console.print(
        f"  This is fallback mode. For standalone build, ensure PyInstaller succeeds.",
        style="muted"
    );

    return output_path;
}

"""Start desktop dev server - start web dev server and launch tauri dev."""
impl DesktopTarget.dev(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
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
    # Step 1.5: Prepare package.json and get compiler
    # We need compiled/_entry.js and compiled/main.js to exist before Vite can serve them
    console.print("  Preparing compilation setup...", style="muted");
    vite_port = 5173;
    bundler = ViteBundler(
        project_dir=project_dir, output_dir=None, minify=False, config_path=None
    );
    # Ensure package.json exists (needed for ViteCompiler)
    package_json_path = bundler._get_client_dir() / 'configs' / 'package.json';
    if not package_json_path.exists() {
        bundler.create_package_json();
    }
    # Get the compiler via JacClient (this provides all the compile functions)
    import from jac_client.plugin.client { JacClient }
    builder = JacClient.get_client_bundle_builder();
    # Set the package.json path if not already set
    if not builder.vite_package_json or not builder.vite_package_json.exists() {
        builder.vite_package_json = package_json_path;
    }
    compiler = builder._get_compiler();
    # Ensure compiled directory exists
    compiler.compiled_dir.mkdir(parents=True, exist_ok=True);
    # Compile runtime utils (creates client_runtime.js)
    compiler.compile_runtime_utils();
    # Compile the module to create compiled/main.js (or whatever the module name is)
    (module_js, mod, module_manifest) = compiler.jac_compiler.compile_module(
        entry_file
    );
    # Write the compiled module to compiled directory
    module_name = entry_file.stem;
    compiled_module_path = compiler.compiled_dir / f"{module_name}.js";
    compiled_module_path.write_text(module_js, encoding='utf-8');
    # Create the entry file (this will be used by Vite dev server)
    compiler.create_entry_file(entry_file);
    console.print("  ✔ Module compiled for dev mode", style="success");
    # Step 2: Start web dev server
    console.print("  Starting web dev server...", style="muted");
    # Desktop webview needs an explicit backend URL (same-origin doesn't work)
    dev_config_path = bundler.create_vite_config(
        entry_file,
        api_base_url_override=_make_localhost_url(api_port),
        is_dev=True,
        api_port=api_port
    );
    # Start Vite dev server (suppress initial output for cleaner startup)
    vite_process = bundler.start_dev_server(
        port=vite_port, suppress_initial_output=True
    );
    if not vite_process {
        raise RuntimeError("Failed to start Vite dev server");
    }
    console.print(
        f"  ✔ Web dev server running on http://localhost:{vite_port}", style="success"
    );
    # Step 3: Start backend API server
    toml_base_url = _get_toml_api_base_url(project_dir);
    server_port = _resolve_server_port(toml_base_url, api_port);
    # Regenerate main.rs with the actual backend URL so sidecar is skipped
    _generate_main_rs(
        tauri_dir, api_base_url=toml_base_url or _make_localhost_url(server_port)
    );
    console.print(
        f"  Step 3: Starting backend server on port {server_port}...", style="muted"
    );
    server_process = _start_backend_server(entry_file, project_dir, server_port);
    console.print(
        f"  ✔ Backend server starting on port {server_port}", style="success"
    );
    # Step 4: Launch tauri dev
    console.print("  Step 4: Launching Tauri dev window...", style="muted");
    console.print("  (Press Ctrl+C to stop)", style="muted");
    # Setup signal handlers for cleanup
    def cleanup {
        console.print("\n  Stopping dev servers...", style="muted");
        if vite_process {
            try {
                vite_process.terminate();
                vite_process.wait(timeout=SUBPROCESS_TIMEOUT_SHORT);
            } except Exception as e {
                vite_process.kill();
            }
        }
        if server_process {
            try {
                server_process.terminate();
                server_process.wait(timeout=SUBPROCESS_TIMEOUT_SHORT);
            } except Exception as e {
                server_process.kill();
            }
        }
        console.print("  ✔ Dev servers stopped", style="success");
    }
    def signal_handler(signum: int, frame: Any) {
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
        console.print(
            "\n  Keyboard interrupt detected. Stopping dev servers...", style="muted"
        );
    } finally {
        cleanup();
    }
}

"""Update tauri.conf.json for dev mode (point to dev server)."""
def _update_tauri_config_for_dev(tauri_dir: Path) {
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
    if "beforeDevCommand" in config["build"]
    and config["build"]["beforeDevCommand"] is None {
        del config["build"]["beforeDevCommand"];
    }
    if "beforeBuildCommand" in config["build"]
    and config["build"]["beforeBuildCommand"] is None {
        del config["build"]["beforeBuildCommand"];
    }

    # main.rs creates the window via WebviewWindowBuilder (for initialization_script)
    config.setdefault("app", {})["windows"] = [];

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
    import sys;
    # Check if cargo is available
    try {
        subprocess.run(
            ["cargo", "--version"],
            capture_output=True,
            check=True,
            timeout=SUBPROCESS_TIMEOUT_SHORT
        );
    } except (
        subprocess.CalledProcessError,
        FileNotFoundError,
        subprocess.TimeoutExpired
    ) {
        raise RuntimeError(
            "Rust/Cargo not found. Install Rust from https://rustup.rs/\n"
            "Or run: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        );
    }

    # Check if build tools (gcc/cc) are available.
    # Skipped on Windows: MSVC (from VS Build Tools) handles native compilation
    # there, and `cc` is not a standard command on Windows so this check would
    # raise even on correctly configured machines.
    if sys.platform != "win32" {
        try {
            subprocess.run(
                ["cc", "--version"],
                capture_output=True,
                check=True,
                timeout=SUBPROCESS_TIMEOUT_SHORT
            );
        } except (
            subprocess.CalledProcessError,
            FileNotFoundError,
            subprocess.TimeoutExpired
        ) {
            raise RuntimeError(
                "Build tools not found. Install build-essential:\n"
                "  Ubuntu/Debian: sudo apt-get install build-essential\n"
                "  Fedora: sudo dnf install gcc gcc-c++\n"
                "  Arch: sudo pacman -S base-devel"
            );
        }
    }

    # Check if tauri CLI is available via cargo
    try {
        subprocess.run(
            ["cargo", "tauri", "--version"],
            capture_output=True,
            check=True,
            timeout=SUBPROCESS_TIMEOUT_SHORT
        );
    } except (
        subprocess.CalledProcessError,
        FileNotFoundError,
        subprocess.TimeoutExpired
    ) {
        console.warning("Tauri CLI not found.");
        console.print("  Install manually: cargo install tauri-cli", style="muted");
        console.print("  Or use bun: bun add -g @tauri-apps/cli", style="muted");
        raise RuntimeError(
            "Tauri CLI not installed. Install it first:\n"
            "  cargo install tauri-cli\n"
            "  Or: bun add -g @tauri-apps/cli"
        );
    }

    # Check if package.json has tauri scripts
    package_json = tauri_dir.parent / "package.json";
    use_bun = False;
    if package_json.exists() {
        try {
            with open(package_json, "r") as f {
                package_data = json.load(f);
                scripts = package_data.get("scripts", {});
                if "tauri" in scripts or "tauri:dev" in scripts {
                    use_bun = True;
                }
            }
        } except Exception as e { }
    }

    if use_bun {
        # Resolve bun binary (system PATH → .jac/bin/ → auto-download)
        import from jac_client.plugin.utils { get_bun }
        bun = get_bun();
        if not bun {
            console.error(
                "Bun is required for this project but could not be found or installed. "
                "Install manually: https://bun.sh"
            );
            raise RuntimeError("Bun is required") from None;
        }
        # Use bun run tauri dev
        dev_cmd = [bun, "run", "tauri", "dev"];
    } else {
        # Use cargo tauri dev directly
        dev_cmd = ["cargo", "tauri", "dev"];
    }

    console.print(f"  Running: {' '.join(dev_cmd)}", style="muted");

    # Run tauri dev (this will open a window)
    # Use None for stdout/stderr to show output directly in terminal
    try {
        process = subprocess.Popen(
            dev_cmd,
            cwd=tauri_dir.parent,
            stdout=None,  # Show output directly
            stderr=None,  # Show errors directly
            text=True
        );
        return process;
    } except Exception as e {
        console.error(f"  Failed to start Tauri: {e}");
        raise;
    }
}

"""Start backend API server as a subprocess, returning the Popen handle."""
def _start_backend_server(entry_file: Path, project_dir: Path, port: int) -> Any {
    import subprocess;
    import sys;
    server_process = subprocess.Popen(
        [
            sys.executable,
            "-m",
            "jaclang",
            "start",
            str(entry_file),
            "--port",
            str(port),
            "--no_client"
        ],
        cwd=str(project_dir),
        stdout=None,
        stderr=None
    );
    return server_process;
}

"""Resolve the API server port from toml_base_url or fall back to api_port."""
def _resolve_server_port(toml_base_url: str, api_port: int) -> int {
    if toml_base_url {
        import from urllib.parse { urlparse }
        parsed = urlparse(toml_base_url);
        return parsed.port or api_port;
    }
    return api_port;
}

"""Start desktop app - build web bundle and launch Tauri with built bundle."""
impl DesktopTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    import from jac_client.plugin.src.targets.web_target { WebTarget }
    import signal;
    import sys;
    console.print("\n🖥️  Starting desktop app (Tauri)", style="bold");
    # Check if setup has been run
    tauri_dir = project_dir / "src-tauri";
    if not tauri_dir.exists() {
        raise RuntimeError("Desktop target not set up. Run 'jac setup desktop' first.");
    }
    # Step 1: Build web bundle with explicit backend URL for desktop webview.
    toml_base_url = _get_toml_api_base_url(project_dir);
    if not toml_base_url {
        os.environ[API_BASE_URL_ENV_VAR] = _make_localhost_url(api_port);
    }
    console.print("  Step 1: Building web bundle...", style="muted");
    web_target = WebTarget();
    try {
        web_bundle_path = web_target.build(entry_file, project_dir, None);
    } finally {
        os.environ.pop(API_BASE_URL_ENV_VAR, None);
    }
    console.print(f"  ✔ Web bundle built: {web_bundle_path}", style="success");
    # Step 1.5: Copy assets to dist for desktop (Tauri serves from dist directly)
    _copy_assets_to_dist(project_dir, web_bundle_path.parent);
    # Step 2: Update tauri.conf.json to point to web bundle
    console.print("  Step 2: Updating Tauri configuration...", style="muted");
    _update_tauri_config_for_build(tauri_dir, project_dir, web_bundle_path);
    # Step 3: Start backend API server
    server_port = _resolve_server_port(toml_base_url, api_port);
    # Regenerate main.rs with the actual backend URL so sidecar is skipped
    _generate_main_rs(
        tauri_dir, api_base_url=toml_base_url or _make_localhost_url(server_port)
    );
    console.print(
        f"  Step 3: Starting backend server on port {server_port}...", style="muted"
    );
    server_process = _start_backend_server(entry_file, project_dir, server_port);
    console.print(
        f"  ✔ Backend server starting on port {server_port}", style="success"
    );
    # Step 4: Launch tauri dev (which will use the built bundle)
    console.print("  Step 4: Launching Tauri app...", style="muted");
    console.print("  (Press Ctrl+C to stop)", style="muted");
    # Setup signal handlers for cleanup
    tauri_process = None;
    def cleanup {
        console.print("\n  Stopping app...", style="muted");
        if tauri_process {
            try {
                tauri_process.terminate();
                tauri_process.wait(timeout=SUBPROCESS_TIMEOUT_SHORT);
            } except Exception as e {
                tauri_process.kill();
            }
        }
        if server_process {
            try {
                server_process.terminate();
                server_process.wait(timeout=SUBPROCESS_TIMEOUT_SHORT);
            } except Exception as e {
                server_process.kill();
            }
        }
        console.print("  ✔ App stopped", style="success");
    }
    def signal_handler(signum: int, frame: Any) {
        cleanup();
        sys.exit(0);
    }
    signal.signal(signal.SIGINT, signal_handler);
    signal.signal(signal.SIGTERM, signal_handler);
    try {
        # Run tauri dev (it will use the built bundle from distDir)
        tauri_process = _run_tauri_dev(tauri_dir);

        if not tauri_process {
            console.error("  Failed to start Tauri process");
            return;
        }

        # Wait for tauri process to finish
        return_code = tauri_process.wait();
        if return_code != 0 {
            console.warning(f"  Tauri process exited with code {return_code}");
        }
    } except KeyboardInterrupt as e {
        console.print(
            "\n  Keyboard interrupt detected. Stopping app...", style="muted"
        );
    } except Exception as e {
        console.error(f"  Error starting desktop app: {e}");
        import traceback;
        console.print(traceback.format_exc(), style="muted");
    } finally {
        cleanup();
    }
}
