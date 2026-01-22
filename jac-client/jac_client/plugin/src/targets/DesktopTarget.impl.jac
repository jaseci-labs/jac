"""Implementation of DesktopTarget methods."""
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }
import from jaclang.project.config { get_config }
import subprocess;
import json;
import shutil;

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
            "beforeDevCommand": None,
            "beforeBuildCommand": None,
            "devPath": "http://localhost:5173",
            "distDir": "../.jac/client/dist",
            "withGlobalTauri": False
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
tauri = {{ version = "2.0", features = ["shell-open"] }}
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

