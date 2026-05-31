"""Shared helpers for PyTauri desktop (sidecar bundling, icons, ports)."""
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }
import from jac_client.plugin.src.config_loader { JacClientConfig }
import subprocess;
import json;
import shutil;
import os;
import platform;
import stat;

# ===============================================================================
# Helper Functions - Extracted to reduce duplication
# ===============================================================================
"""Check if a command is available and optionally return its version."""
def _check_command_available(
    cmd: list[str], timeout: int | None = None
) -> tuple[bool, str | None] {
    effective_timeout = timeout if timeout is not None else SUBPROCESS_TIMEOUT_SHORT;
    try {
        result = subprocess.run(
            cmd, capture_output=True, text=True, timeout=effective_timeout
        );
        if result.returncode == 0 {
            return (True, result.stdout.strip());
        }
    } except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e {
        console.print(f"  Command check failed ({cmd[0]}): {e}", style="muted");
    }
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

"""Resolve jac CLI argv: prefer ``jac`` on PATH, else ``python -m jaclang``."""
def get_jac_command -> list[str] {
    import sys;
    jac_path = shutil.which("jac");
    if jac_path {
        # Always absolute so subprocess works after os.chdir into temp dirs.
        return [str(Path(jac_path).resolve())];
    }
    return [sys.executable, "-m", "jaclang"];
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
# Auto-generated by jac-desktop

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
for pkg in ['jaclang', 'jac_client', 'jac_desktop', 'setuptools', 'appdirs', 'packaging']:
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
EXCLUDE_DIRS = ['src-pytauri', 'node_modules', '__pycache__', '.git', 'dist', '__jac_gen__', '.jac']
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
    from importlib.metadata import distribution, PackageNotFoundError
    with open(jac_toml, 'rb') as f:
        toml_data = tomllib.load(f)
    # Get [dependencies] section (Python packages)
    python_deps = toml_data.get('dependencies', {{}})

    def _resolve_top_level(dist_name):
        # Distribution name != module name in general. Read top_level.txt
        # from the installed dist; fall back to the dash-to-underscore
        # heuristic only when metadata is missing.
        try:
            dist = distribution(dist_name)
            top_level = dist.read_text('top_level.txt')
            if top_level:
                names = [n.strip() for n in top_level.splitlines() if n.strip()]
                if names:
                    return names
        except PackageNotFoundError:
            pass
        return [dist_name.replace('-', '_')]

    for dep_name, dep_version in python_deps.items():
        # Skip sub-tables like npm, git, etc.
        if isinstance(dep_version, str):
            for module_name in _resolve_top_level(dep_name):
                hiddenimports.append(module_name)
                try:
                    hiddenimports += collect_submodules(module_name)
                except Exception:
                    pass
                # Pull data files too so .jac sources ship alongside .py
                try:
                    datas += collect_data_files(module_name)
                except Exception:
                    pass
    print(f"Added {{len([d for d in python_deps.values() if isinstance(d, str)])}} Python dependencies from jac.toml")

    # Read [plugins.desktop.bundle] extra_data glob patterns from jac.toml and bundle
    # every matching file into the sidecar. Paths are glob patterns rooted at
    # project_dir; matches are placed at the same relative path inside the
    # frozen bundle so `Path(__file__).parent / "some/file"` still resolves
    # at runtime.
    plugins_section = toml_data.get('plugins', {{}})
    desktop_cfg = plugins_section.get('desktop', {{}}) if isinstance(plugins_section, dict) else {{}}
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
            print(f"Added {{extra_count}} extra data file(s) from [plugins.desktop.bundle] extra_data")
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

def _start_backend_server(entry_file: Path, project_dir: Path, port: int) -> any {
    import subprocess;
    jac_cmd = get_jac_command();
    server_process = subprocess.Popen(
        [*jac_cmd, "start", str(entry_file), "--port", str(port), "--no_client"],
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
