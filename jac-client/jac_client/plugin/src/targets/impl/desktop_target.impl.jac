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

def _make_localhost_url(port: int) -> str {
    return f"http://127.0.0.1:{port}";
}

def _get_toml_api_base_url(project_dir: Path) -> str {
    config_loader = JacClientConfig(project_dir);
    return config_loader.get_api_config().get('base_url', '');
}

"""Setup desktop target - scaffold Tauri project structure."""
impl DesktopTarget.setup(self: DesktopTarget, project_dir: Path) -> None {
    # Define tauri_dir early so we can use it in error handling
    tauri_dir = project_dir / "src-tauri";
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
        } except Exception as e {
            raise RuntimeError(f"Failed to create project directory: {e}") ;
        }
    }
    # Create src-tauri directory structure IMMEDIATELY (before imports or any other operations)
    console.print("  Creating src-tauri/ directory structure...", style="muted");
    try {
        tauri_dir.mkdir(parents=True, exist_ok=True);
        (tauri_dir / "src").mkdir(exist_ok=True);
        (tauri_dir / "binaries").mkdir(exist_ok=True);
        console.print(f"  ✔ Created {tauri_dir}", style="success");
    } except Exception as e {
        raise RuntimeError(f"Failed to create src-tauri directory: {e}") ;
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
            f"  Project name: {project_name}, version: {project_version}",
            style="muted"
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
                "  Setup will continue, but jac.toml may not be updated.",
                style="muted"
            );
        }

        # Check and install required dependencies (wrap in try-except to not fail setup)
        console.print("\n📦 Checking required dependencies...", style="bold");
        try {
            _check_and_install_dependencies();
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
        console.print("  1. Build: jac build main.jac --client desktop");
        console.print("  2. Dev:   jac start main.jac --client desktop");
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
def _generate_tauri_config(
    tauri_dir: Path, name: str, identifier: str, version: str
) -> None {
    config = {
        "productName": name,
        "version": version,
        "identifier": identifier,
        "build": {
            "devUrl": "http://localhost:5173",
            "frontendDist": "../.jac/client/dist"
        },
        "app": {"windows": [], "security": {"csp": None}},
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
        console.warning(
            "  Note: Replace icons/icon.png with your app icon (1024x1024 PNG recommended)"
        );
        return;
    } except (
        subprocess.CalledProcessError,
        FileNotFoundError,
        subprocess.TimeoutExpired
    ) {
    # PIL not available, try next method
    }

    # Method 2: Try ImageMagick convert command
    try {
        import subprocess;
        # Create a 1024x1024 solid blue PNG with alpha channel using ImageMagick
        result = subprocess.run(
            [
                "convert",
                "-size",
                "1024x1024",
                "xc:#428BCA",
                "-alpha",
                "set",
                "-channel",
                "RGBA",
                str(icon_path)
            ],
            capture_output=True,
            check=True,
            timeout=5
        );
        console.print("  ✔ Generated default icon (1024x1024)", style="success");
        console.warning(
            "  Note: Replace icons/icon.png with your app icon (1024x1024 PNG recommended)"
        );
        return;
    } except (
        subprocess.CalledProcessError,
        FileNotFoundError,
        subprocess.TimeoutExpired
    ) {
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
    console.warning(
        "  Note: Replace icons/icon.png with your app icon (1024x1024 PNG recommended)"
    );
}

"""Generate main.rs.

api_base_url: embed this URL and skip sidecar port discovery.
    Empty string means dynamic discovery at runtime.
"""
def _generate_main_rs(tauri_dir: Path, api_base_url: str = "") -> None {
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

    // Possible sidecar names
    let sidecar_names = if cfg!(windows) {{
        vec!["binaries/jac-sidecar.exe", "binaries/jac-sidecar.bat"]
    }} else {{
        vec!["binaries/jac-sidecar", "binaries/jac-sidecar.sh"]
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
        // Determine module path (try to find main.jac relative to app)
        let module_path = if let Ok(exe_path) = std::env::current_exe() {{
            if let Some(exe_dir) = exe_path.parent() {{
                // Look for main.jac in parent directories
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
        }} else {{
            cmd.arg("--module-path").arg("main.jac");
        }}
        cmd.arg("--port").arg("0"); // OS assigns free port
        cmd.arg("--host").arg("127.0.0.1");

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

fn main() {{
    tauri::Builder::default()
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
        raise RuntimeError("jac.toml not found") ;
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

"""Check and install all required dependencies for desktop target."""
def _check_and_install_dependencies -> None {
    import platform as platform_module;
    import sys;

    system = platform_module.system();

    # Check Rust toolchain
    rust_installed = _check_and_install_rust();

    # Check build tools
    build_tools_installed = _check_and_install_build_tools(system);

    # Check system dependencies (Linux only)
    if system == "Linux" {
        _check_and_install_linux_dependencies();
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
            "  Rust is required but not installed. Please install it manually."
        );
    }
    if not build_tools_installed {
        console.warning(
            "  Build tools are required but not installed. Please install them manually."
        );
    }
}

"""Check if Rust toolchain is installed, and offer to install if missing."""
def _check_and_install_rust -> bool {
    try {
        result = subprocess.run(
            ["rustc", "--version"], capture_output=True, text=True, timeout=5
        );
        if result.returncode == 0 {
            version = result.stdout.strip();
            console.print(f"  ✔ Rust toolchain found: {version}", style="success");
            return True;
        }
    } except Exception { }

    # Rust not found
    console.warning("  Rust toolchain not found");
    console.print(
        "  Rust is required for building desktop applications with Tauri.",
        style="muted"
    );
    console.print("  Install Rust: https://rustup.rs/", style="muted");

    # Try to detect if we can install automatically
    try {
        # Check if curl is available
        subprocess.run(
            ["curl", "--version"], capture_output=True, check=True, timeout=2
        );
        console.print(
            "\n  Would you like to install Rust automatically using rustup?",
            style="info"
        );
        response = input("  Install Rust? [Y/n]: ").strip().lower();
        if not response or response in ('y', 'yes') {
            console.print("  Installing Rust...", style="muted");
            console.print("  This may take a few minutes...", style="muted");
            try {
                # Run rustup installer directly via curl pipe
                result = subprocess.run(
                    [
                        "sh",
                        "-c",
                        "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y"
                    ],
                    timeout=600,  # 10 minute timeout
                    check=False
                );
                if result.returncode == 0 {
                    console.print("  ✔ Rust installed successfully!", style="success");
                    console.print(
                        "  Note: You may need to restart your terminal or run: source $HOME/.cargo/env",
                        style="muted"
                    );
                    # Try to source cargo env and verify
                    import os;
                    cargo_bin = os.path.expanduser("~/.cargo/bin");
                    if os.path.exists(cargo_bin) {
                        # Add to PATH for current session
                        current_path = os.environ.get("PATH", "");
                        os.environ["PATH"] = f"{cargo_bin}:{current_path}";
                        # Verify installation
                        try {
                            verify_result = subprocess.run(
                                ["rustc", "--version"],
                                capture_output=True,
                                text=True,
                                timeout=5
                            );
                            if verify_result.returncode == 0 {
                                version = verify_result.stdout.strip();
                                console.print(
                                    f"  ✔ Verified: {version}", style="success"
                                );
                                return True;
                            }
                        } except Exception { }
                        return True;
                    } else {
                        console.warning(
                            "  Rust installation failed. Please install manually."
                        );
                    }
                }
            } except Exception as e {
                error_str = str(e);
                if "TimeoutExpired" in error_str or "timeout" in error_str.lower() {
                    console.warning(
                        "  Rust installation timed out. Please install manually."
                    );
                } else {
                    console.warning(f"  Failed to install Rust automatically: {e}");
                    console.print(
                        "  Please install manually: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh",
                        style="muted"
                    );
                }
            }
        } else {
            console.print(
                "  Skipping Rust installation. Please install manually.", style="muted"
            );
        }
    } except Exception {
        console.print(
            "  curl not found. Cannot install Rust automatically.", style="muted"
        );
        console.print(
            "  Please install manually: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh",
            style="muted"
        );
    }

    return False;
}

"""Check and install build tools based on OS."""
def _check_and_install_build_tools(system: str) -> bool {
    if system == "Linux" {
        # Check for gcc/cc
        try {
            subprocess.run(
                ["gcc", "--version"], capture_output=True, check=True, timeout=5
            );
            console.print("  ✔ Build tools (gcc) found", style="success");
            return True;
        } except Exception {
            console.warning("  Build tools (gcc) not found");
            _try_install_linux_build_tools();
            return False;
        }
    } elif system == "Darwin" {
        # Check for Xcode Command Line Tools
        try {
            result = subprocess.run(
                ["xcode-select", "-p"], capture_output=True, text=True, timeout=5
            );
            if result.returncode == 0 {
                console.print("  ✔ Xcode Command Line Tools found", style="success");
                return True;
            }
        } except Exception { }
        console.warning("  Xcode Command Line Tools not found");
        console.print("  Install with: xcode-select --install", style="muted");
        console.print("\n  Would you like to open the installer?", style="info");
        response = input("  Open installer? [Y/n]: ").strip().lower();
        if not response or response in ('y', 'yes') {
            try {
                subprocess.run(["xcode-select", "--install"], check=False);
                console.print(
                    "  ✔ Installer opened. Please complete the installation.",
                    style="success"
                );
            } except Exception {
                console.warning(
                    "  Failed to open installer. Please run: xcode-select --install"
                );
            }
        }
        return False;
    } elif system == "Windows" {
        # Check for Visual Studio Build Tools
        console.warning("  Build tools check not implemented for Windows");
        console.print(
            "  Please install Visual Studio Build Tools manually:", style="muted"
        );
        console.print(
            "    https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022",
            style="muted"
        );
        return False;
    }
    return False;
}

"""Try to install Linux build tools."""
def _try_install_linux_build_tools -> None {
    import platform as platform_module;
    import os;

    # Detect Linux distribution
    distro = _detect_linux_distro();

    if not distro {
        console.print(
            "  Could not detect Linux distribution. Please install build tools manually.",
            style="muted"
        );
        return;
    }

    console.print(f"  Detected: {distro}", style="muted");
    console.print(
        "\n  Would you like to install build tools automatically?", style="info"
    );
    response = input("  Install build tools? [Y/n]: ").strip().lower();
    if not response or response in ('y', 'yes') {
        try {
            if distro in ("ubuntu", "debian") {
                console.print("  Installing build-essential...", style="muted");
                result = subprocess.run(
                    ["sudo", "apt-get", "update"], check=False, timeout=60
                );
                if result.returncode == 0 {
                    result = subprocess.run(
                        ["sudo", "apt-get", "install", "-y", "build-essential"],
                        check=False,
                        timeout=300
                    );
                    if result.returncode == 0 {
                        console.print("  ✔ Build tools installed", style="success");
                        return;
                    }
                }
            } elif distro == "fedora" {
                console.print("  Installing gcc gcc-c++...", style="muted");
                result = subprocess.run(
                    ["sudo", "dnf", "install", "-y", "gcc", "gcc-c++"],
                    check=False,
                    timeout=300
                );
                if result.returncode == 0 {
                    console.print("  ✔ Build tools installed", style="success");
                    return;
                }
            } elif distro == "arch" {
                console.print("  Installing base-devel...", style="muted");
                result = subprocess.run(
                    ["sudo", "pacman", "-S", "--noconfirm", "base-devel"],
                    check=False,
                    timeout=300
                );
                if result.returncode == 0 {
                    console.print("  ✔ Build tools installed", style="success");
                    return;
                }
            }
            console.warning("  Failed to install build tools automatically");
        } except Exception as e {
            console.warning(f"  Error installing build tools: {e}");
        }
    }
}

"""Detect Linux distribution."""
def _detect_linux_distro -> str | None {
    import os;
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
    } except Exception {
        return None;
    }
}

"""Check and install Linux system dependencies."""
def _check_and_install_linux_dependencies -> None {
    # Check pkg-config
    pkg_config_ok = False;
    try {
        subprocess.run(
            ["pkg-config", "--version"], capture_output=True, check=True, timeout=5
        );
        console.print("  ✔ pkg-config found", style="success");
        pkg_config_ok = True;
    } except Exception {
        console.warning("  pkg-config not found");
    }

    # Check for GTK/WebKit libraries
    webkit_ok = False;
    try {
        result = subprocess.run(
            ["pkg-config", "--exists", "webkit2gtk-4.1"],
            capture_output=True,
            timeout=5
        );
        if result.returncode == 0 {
            console.print("  ✔ GTK/WebKit libraries found", style="success");
            webkit_ok = True;
        }
    } except Exception {
        console.warning("  GTK/WebKit libraries not found");
    }

    if pkg_config_ok and webkit_ok {
        return;  # All dependencies satisfied

    }

    # Missing dependencies
    console.warning("  Some Linux system dependencies are missing");
    distro = _detect_linux_distro();

    if distro {
        console.print(f"  Detected: {distro}", style="muted");
        console.print(
            "\n  Would you like to install missing dependencies automatically?",
            style="info"
        );
        response = input("  Install dependencies? [Y/n]: ").strip().lower();
        if not response or response in ('y', 'yes') {
            _try_install_linux_system_deps(distro);
        } else {
            _print_manual_install_instructions(distro);
        }
    } else {
        _print_manual_install_instructions(None);
    }
}

"""Try to install Linux system dependencies."""
def _try_install_linux_system_deps(distro: str) -> None {
    try {
        if distro in ("ubuntu", "debian") {
            deps = [
                "libwebkit2gtk-4.1-dev",
                "build-essential",
                "curl",
                "wget",
                "libssl-dev",
                "libgtk-3-dev",
                "libayatana-appindicator3-dev",
                "librsvg2-dev"
            ];
            console.print("  Installing dependencies...", style="muted");
            result = subprocess.run(
                ["sudo", "apt-get", "update"], check=False, timeout=60
            );
            if result.returncode == 0 {
                result = subprocess.run(
                    ["sudo", "apt-get", "install", "-y"] + deps,
                    check=False,
                    timeout=600
                );
                if result.returncode == 0 {
                    console.print("  ✔ Dependencies installed", style="success");
                    return;
                }
            }
        } elif distro == "fedora" {
            deps = [
                "webkit2gtk3-devel.x86_64",
                "openssl-devel",
                "curl",
                "wget",
                "libappindicator-gtk3",
                "librsvg2-devel"
            ];
            console.print("  Installing dependencies...", style="muted");
            result = subprocess.run(
                ["sudo", "dnf", "install", "-y"] + deps, check=False, timeout=600
            );
            if result.returncode == 0 {
                console.print("  ✔ Dependencies installed", style="success");
                return;
            }
        } elif distro == "arch" {
            deps = [
                "webkit2gtk",
                "base-devel",
                "curl",
                "wget",
                "openssl",
                "appmenu-gtk-module",
                "gtk3",
                "libappindicator-gtk3",
                "librsvg",
                "libvips"
            ];
            console.print("  Installing dependencies...", style="muted");
            result = subprocess.run(
                ["sudo", "pacman", "-S", "--noconfirm"] + deps,
                check=False,
                timeout=600
            );
            if result.returncode == 0 {
                console.print("  ✔ Dependencies installed", style="success");
                return;
            }
        }
        console.warning("  Failed to install dependencies automatically");
        _print_manual_install_instructions(distro);
    } except Exception as e {
        console.warning(f"  Error installing dependencies: {e}");
        _print_manual_install_instructions(distro);
    }
}

"""Print manual installation instructions."""
def _print_manual_install_instructions(distro: str | None) -> None {
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
}

"""Check macOS dependencies."""
def _check_macos_dependencies -> None {
    # macOS dependencies are typically handled by Xcode Command Line Tools
    # which is checked in _check_and_install_build_tools
    console.print(
        "  ✔ macOS dependencies (handled by Xcode Command Line Tools)", style="success"
    );
}

"""Check Windows dependencies."""
def _check_windows_dependencies -> None {
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
            ["python3", "--version"], capture_output=True, text=True, timeout=5
        );
        if result.returncode == 0 {
            python_version = result.stdout.strip();
            console.print(f"  ✔ Python found: {python_version}", style="success");
            python_ok = True;
            python_cmd = "python3";
        }
    } except Exception { }

    # Try python command as fallback if python3 not found
    if not python_ok {
        try {
            result = subprocess.run(
                ["python", "--version"], capture_output=True, text=True, timeout=5
            );
            if result.returncode == 0 {
                python_version = result.stdout.strip();
                console.print(f"  ✔ Python found: {python_version}", style="success");
                python_ok = True;
                python_cmd = "python";
            }
        } except Exception { }
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
            timeout=5
        );
        if result.returncode == 0 {
            version = result.stdout.strip();
            console.print(f"  ✔ jaclang found: {version}", style="success");
            jaclang_ok = True;
        }
    } except Exception { }

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
                    timeout=300,
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
}

"""Check and install Tauri CLI if needed."""
def _check_and_install_tauri_cli -> None {
    # Check if cargo tauri is available (preferred method)
    cargo_tauri_ok = False;
    try {
        result = subprocess.run(
            ["cargo", "tauri", "--version"], capture_output=True, text=True, timeout=5
        );
        if result.returncode == 0 {
            version = result.stdout.strip();
            console.print(f"  ✔ Tauri CLI found (cargo): {version}", style="success");
            return;
        }
    } except Exception { }

    # Check if bun tauri CLI is available (global install)
    bun_tauri_ok = False;
    try {
        result = subprocess.run(
            ["bun", "pm", "ls", "-g"], capture_output=True, text=True, timeout=5
        );
        if result.returncode == 0 and "@tauri-apps/cli" in result.stdout {
            console.print("  ✔ Tauri CLI found (bun)", style="success");
            return;
        }
    } except Exception { }

    # Tauri CLI not found
    console.warning("  Tauri CLI not found");
    console.print(
        "  Tauri CLI is required for building desktop applications.", style="muted"
    );

    # Check if Rust/Cargo is available (required for cargo install)
    cargo_available = False;
    try {
        subprocess.run(
            ["cargo", "--version"], capture_output=True, check=True, timeout=5
        );
        cargo_available = True;
    } except Exception { }

    # Check if bun is available
    bun_available = False;
    try {
        subprocess.run(
            ["bun", "--version"], capture_output=True, check=True, timeout=5
        );
        bun_available = True;
    } except Exception { }

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
                    timeout=600,
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
        if bun_available {
            console.print("  Installing Tauri CLI via bun...", style="muted");
            try {
                result = subprocess.run(
                    ["bun", "add", "-g", "@tauri-apps/cli"],
                    check=False,
                    timeout=300,
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

"""Build desktop app - build web bundle first, then wrap with Tauri."""
impl DesktopTarget.build(
    self: DesktopTarget,
    entry_file: Path,
    project_dir: Path,
    platform: Optional[str] = None
) -> Path {
    import from jac_client.plugin.src.targets.web_target { WebTarget }
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    console.print("\n🖥️  Building desktop app (Tauri)", style="bold");
    # Check if setup has been run
    tauri_dir = project_dir / "src-tauri";
    if not tauri_dir.exists() {
        raise RuntimeError("Desktop target not set up. Run 'jac setup desktop' first.") ;
    }
    # Bake TOML base_url into the bundle; otherwise sidecar discovers port at runtime.
    toml_base_url = _get_toml_api_base_url(project_dir);
    if toml_base_url {
        os.environ[API_BASE_URL_ENV_VAR] = toml_base_url;
    }
    # Step 1: Build web bundle first (reuse existing pipeline)
    console.print("  Step 1: Building web bundle...", style="muted");
    web_target = WebTarget();
    try {
        web_bundle_path = web_target.build(entry_file, project_dir, platform);
    } finally {
        os.environ.pop(API_BASE_URL_ENV_VAR, None);
    }
    console.print(f"  ✔ Web bundle built: {web_bundle_path}", style="success");
    # Regenerate main.rs with latest TOML config (base_url may have changed since setup)
    _generate_main_rs(tauri_dir, api_base_url=toml_base_url);
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
        console.print(
            "  Note: Desktop app will need external API server", style="muted"
        );
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
                console.warning(
                    "  Icon is invalid or too small for AppImage, regenerating..."
                );
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

    if not sidecar_files {
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
    if "icon" not in config["bundle"]
    or not config["bundle"]["icon"]
    or len(config["bundle"]["icon"]) == 0 {
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
            console.print(
                f"  ✔ Populated icon array with {len(icon_files)} icon(s)",
                style="success"
            );
        }
    }
}

"""Update tauri.conf.json to point to the built web bundle."""
def _update_tauri_config_for_build(
    tauri_dir: Path,
    project_dir: Path,
    web_bundle_path: Path,
    sidecar_bundled: bool = False
) -> None {
    import json;

    config_path = tauri_dir / "tauri.conf.json";
    if not config_path.exists() {
        raise RuntimeError("tauri.conf.json not found. Run 'jac setup desktop' first.") ;
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
    try {
        result = subprocess.run(
            ["which", "appimagetool"], capture_output=True, timeout=2
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
            ["appimagetool", "--version"], capture_output=True, timeout=5, text=True
        );
        if result.returncode == 0 {
            return (True, None);
        } else {
            # Check if it's a FUSE error
            error_output = result.stderr or result.stdout or "";
            if "fuse" in error_output.lower() or "libfuse" in error_output.lower() {
                return (
                    False,
                    "FUSE library not available. Install with: sudo apt-get install libfuse2"
                );
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
            timeout=300  # 5 minute timeout
        );

        if result.returncode != 0 {
            error_output = result.stderr or result.stdout or "Unknown error";
            # Check for FUSE-related errors
            if "fuse" in error_output.lower()
            or "libfuse" in error_output.lower()
            or "FUSE" in error_output {
                console.warning(
                    "  Failed to create AppImage: FUSE library not available"
                );
                console.print(
                    "  Install FUSE with: sudo apt-get install -y libfuse2",
                    style="muted"
                );
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
        if "fuse" in error_msg.lower() or "libfuse" in error_msg.lower() {
            console.warning(
                "  FUSE library error. Install with: sudo apt-get install -y libfuse2"
            );
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
        } except Exception {
            console.warning("  Failed to check package.json for tauri scripts");
        }
    }

    if use_bun {
        # Ensure bun is available
        import from jac_client.plugin.utils { ensure_bun_available }
        if not ensure_bun_available() {
            console.error(
                "Bun is required for this project. Install manually: https://bun.sh"
            );
            raise RuntimeError("Bun is required") from None ;
        }
        # Use bun run tauri build
        build_cmd = ["bun", "run", "tauri", "build"];
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
        raise RuntimeError(f"Build completed but bundle not found at: {bundle_dir}") ;
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
    is_linux_build = (platform == "linux")
    or (not platform and target and "linux" in target);
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
    if platform == "windows"
    or (platform is None and platform_module.system() == "Windows") {
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
    console.print(
        f"  Note: Requires Python and jaclang to be installed", style="muted"
    );
    console.print(f"  Run: pip install jaclang", style="muted");

    return output_path;
}

"""Start desktop dev server - start web dev server and launch tauri dev."""
impl DesktopTarget.dev(
    self: DesktopTarget, entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }
    import signal;
    import sys;
    console.print("\n🖥️  Starting desktop dev server (Tauri)", style="bold");
    # Check if setup has been run
    tauri_dir = project_dir / "src-tauri";
    if not tauri_dir.exists() {
        raise RuntimeError("Desktop target not set up. Run 'jac setup desktop' first.") ;
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
    dev_config_path = bundler.create_dev_vite_config(
        entry_file,
        api_port=api_port,
        api_base_url_override=_make_localhost_url(api_port)
    );
    # Start Vite dev server
    vite_process = bundler.start_dev_server(port=vite_port);
    if not vite_process {
        raise RuntimeError("Failed to start Vite dev server") ;
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
    def cleanup -> None {
        console.print("\n  Stopping dev servers...", style="muted");
        if vite_process {
            try {
                vite_process.terminate();
                vite_process.wait(timeout=5);
            } except Exception {
                vite_process.kill();
            }
        }
        if server_process {
            try {
                server_process.terminate();
                server_process.wait(timeout=5);
            } except Exception {
                server_process.kill();
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
        console.print(
            "\n  Keyboard interrupt detected. Stopping dev servers...", style="muted"
        );
    } finally {
        cleanup();
    }
}

"""Update tauri.conf.json for dev mode (point to dev server)."""
def _update_tauri_config_for_dev(tauri_dir: Path) -> None {
    import json;

    config_path = tauri_dir / "tauri.conf.json";
    if not config_path.exists() {
        raise RuntimeError("tauri.conf.json not found. Run 'jac setup desktop' first.") ;
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
    # Check if cargo is available
    try {
        subprocess.run(
            ["cargo", "--version"], capture_output=True, check=True, timeout=5
        );
    } except (
        subprocess.CalledProcessError,
        FileNotFoundError,
        subprocess.TimeoutExpired
    ) {
        raise RuntimeError(
            "Rust/Cargo not found. Install Rust from https://rustup.rs/\n"
            "Or run: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        ) ;
    }

    # Check if build tools (gcc/cc) are available
    try {
        subprocess.run(["cc", "--version"], capture_output=True, check=True, timeout=5);
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
        ) ;
    }

    # Check if tauri CLI is available via cargo
    try {
        subprocess.run(
            ["cargo", "tauri", "--version"], capture_output=True, check=True, timeout=5
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
        ) ;
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
        } except Exception { }
    }

    if use_bun {
        # Ensure bun is available
        import from jac_client.plugin.utils { ensure_bun_available }
        if not ensure_bun_available() {
            console.error(
                "Bun is required for this project. Install manually: https://bun.sh"
            );
            raise RuntimeError("Bun is required") from None ;
        }
        # Use bun run tauri dev
        dev_cmd = ["bun", "run", "tauri", "dev"];
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
        raise ;
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
    self: DesktopTarget, entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    import from jac_client.plugin.src.targets.web_target { WebTarget }
    import signal;
    import sys;
    import os;
    console.print("\n🖥️  Starting desktop app (Tauri)", style="bold");
    # Check if setup has been run
    tauri_dir = project_dir / "src-tauri";
    if not tauri_dir.exists() {
        raise RuntimeError("Desktop target not set up. Run 'jac setup desktop' first.") ;
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
    def cleanup -> None {
        console.print("\n  Stopping app...", style="muted");
        if tauri_process {
            try {
                tauri_process.terminate();
                tauri_process.wait(timeout=5);
            } except Exception {
                tauri_process.kill();
            }
        }
        if server_process {
            try {
                server_process.terminate();
                server_process.wait(timeout=5);
            } except Exception {
                server_process.kill();
            }
        }
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

        if not tauri_process {
            console.error("  Failed to start Tauri process");
            return;
        }

        # Wait for tauri process to finish
        return_code = tauri_process.wait();
        if return_code != 0 {
            console.warning(f"  Tauri process exited with code {return_code}");
        }
    } except KeyboardInterrupt {
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
