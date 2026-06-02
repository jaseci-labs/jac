"""Implementation of PyTauriDesktopTarget methods.

Reuses the heavy lifting (sidecar bundling via PyInstaller, icon generation,
config loading, `_get_toml_api_base_url`, `_make_localhost_url`,
`_resolve_server_port`, `_start_backend_server`) by importing those
module-level helpers from `jac_desktop.helpers.desktop_helpers`
(Jac's annex pass exposes all `def`s on the parent module).

This target scaffolds `src-pytauri/` with `app.py` (Python entry using
pytauri-wheel) and a `capabilities/default.json` (required by pytauri's
context_factory). Build/dev/start drive Python via pytauri-wheel.
"""
import from pathlib { Path }
import from typing { Optional, Any }
import from jaclang.cli.console { console }
import from jaclang.project.config { JacConfig }
import from jac_client.plugin.src.config_loader { JacClientConfig }
import from jac_desktop.config_loader {
    get_desktop_config,
    DesktopIdentity,
    WindowConfig
}
import from jac_desktop.enums {
    parse_tauri_plugin_id,
    plugin_id_to_npm_package,
    permissions_for_plugin_ids
}
import from jac_client.plugin.src.vite_bundler { API_BASE_URL_ENV_VAR }
import from jac_desktop.helpers.desktop_helpers {
    _make_localhost_url,
    _get_toml_api_base_url,
    _generate_default_icons,
    _bundle_sidecar,
    _copy_assets_to_dist,
    _start_backend_server,
    _resolve_server_port,
    DEFAULT_VITE_PORT,
    DEFAULT_API_PORT,
    SUBPROCESS_TIMEOUT_SHORT,
    DEFAULT_PLUGIN_NPM_VERSION,
    APP_PY_STUB_MARKER,
    LEGACY_APP_PY_MARKER,
    APP_PY_STUB
}
import os;
import sys;
import json;
import subprocess;
import shutil;
import signal;
import platform as platform_mod;

# ===============================================================================
# Tauri plugin npm sync ([plugins.desktop].tauri_plugins -> [dependencies.npm])
# ===============================================================================
"""Infer default plugin npm version from existing @tauri-apps/api if possible."""
def _default_plugin_version_for_project(jac_config: JacConfig) -> str {
    npm_deps: dict = dict(jac_config.get_plugin_deps("npm"));
    api_ver = npm_deps.get("@tauri-apps/api", "");
    api_s = str(api_ver).strip();
    if api_s.startswith("^2") or api_s.startswith("~2") or api_s.startswith("2.") {
        return DEFAULT_PLUGIN_NPM_VERSION;
    }
    if api_s {
        if api_s.startswith("^") {
            return api_s;
        }
        return f"^{api_s}";
    }
    return DEFAULT_PLUGIN_NPM_VERSION;
}

"""Ensure npm packages for configured official Tauri plugins exist in jac.toml."""
def sync_tauri_plugin_npm_dependencies(project_dir: Path) -> None {
    desktop_cfg = get_desktop_config(project_dir);
    if not desktop_cfg.is_auto_tauri_plugin_npm_enabled() {
        return;
    }
    plugin_ids = desktop_cfg.get_tauri_plugins_config();
    if not plugin_ids {
        return;
    }
    client_cfg = JacClientConfig(project_dir);
    jac_config = client_cfg.get_jac_config();
    npm_deps: dict = dict(jac_config.get_plugin_deps("npm"));
    default_ver = _default_plugin_version_for_project(jac_config);
    added_any = False;
    any_official = False;
    for raw_pid in plugin_ids {
        typed_pid = parse_tauri_plugin_id(raw_pid);
        if typed_pid is None {
            console.warning(
                f"  [plugins.desktop].tauri_plugins: unknown or unsupported plugin id "
                f"'{raw_pid}' — skipping npm auto-sync (official ids only)."
            );
            continue;
        }
        npm_pkg = plugin_id_to_npm_package(typed_pid);
        any_official = True;
        if npm_pkg not in npm_deps {
            client_cfg.add_dependency(npm_pkg, default_ver, is_dev=False);
            npm_deps[npm_pkg] = default_ver;
            added_any = True;
            console.print(
                f"  ✔ Added {npm_pkg}@{default_ver} to [dependencies.npm] "
                f"(from [plugins.desktop].tauri_plugins)",
                style="success"
            );
        }
    }
    if any_official and "@tauri-apps/api" not in npm_deps {
        client_cfg.add_dependency("@tauri-apps/api", default_ver, is_dev=False);
        npm_deps["@tauri-apps/api"] = default_ver;
        added_any = True;
        console.print(
            f"  ✔ Added @tauri-apps/api@{default_ver} to [dependencies.npm] "
            f"(required for Tauri plugins)",
            style="success"
        );
    }
    if not added_any {
        return;
    }
    client_cfg.save();
    import from jac_client.plugin.plugin_config { regenerate_client_npm_install }
    regenerate_client_npm_install(project_dir);
}

# ===============================================================================
# Generators - tauri.conf.json, capabilities, app.py
# ===============================================================================
"""Generate src-pytauri/tauri.conf.json from desktop config."""
def _generate_pytauri_tauri_conf(
    pytauri_dir: Path, identity: DesktopIdentity, window: WindowConfig
) {
    config: dict = {
        "$schema": "https://schema.tauri.app/config/2",
        "productName": identity.name,
        "version": identity.version,
        "identifier": identity.identifier,
        "build": {"frontendDist": "../.jac/client/dist"},
        "app": {
            "withGlobalTauri": True,
            "windows": [
                {
                    "label": "main",
                    "title": window.title,
                    "width": window.width,
                    "height": window.height,
                    "minWidth": window.min_width,
                    "minHeight": window.min_height,
                    "resizable": window.resizable
                }
            ]
        },
        "bundle": {"active": False}
    };
    conf_path = pytauri_dir / "tauri.conf.json";
    with open(conf_path, "w") as f {
        f.write(json.dumps(config, indent=2));
    }
    console.print(f"  ✔ Generated src-pytauri/tauri.conf.json", style="success");
}

"""Generate src-pytauri/capabilities/default.json with the permissions pytauri needs.

`extra_permissions` is the list of additional permission identifiers requested
by user-declared tauri plugins (e.g. `["dialog:default", "fs:default"]`).
"""
def _generate_pytauri_capabilities(
    pytauri_dir: Path, extra_permissions: list[str] | None = None
) {
    cap_dir = pytauri_dir / "capabilities";
    cap_dir.mkdir(parents=True, exist_ok=True);
    perms: list = ["core:default"];
    if extra_permissions {
        for p in extra_permissions {
            if p and p not in perms {
                perms.append(p);
            }
        }
    }
    capabilities: dict = {
        "$schema": "../gen/schemas/desktop-schema.json",
        "identifier": "default",
        "description": "Default capabilities for pytauri-desktop",
        "windows": ["main"],
        "permissions": perms
    };
    cap_path = cap_dir / "default.json";
    with open(cap_path, "w") as f {
        f.write(json.dumps(capabilities, indent=2));
    }
    console.print(
        f"  ✔ Generated src-pytauri/capabilities/default.json", style="success"
    );
}

"""Sync `build.frontendDist` in src-pytauri/tauri.conf.json to the real Vite output.

PyTauri keeps declarative `[app.windows]` for window sizing in `jac_desktop.runtime`,
so we only patch `frontendDist` here.

Wrong `frontendDist` (for example `../dist` instead of `../.jac/client/dist`)
yields a missing index.html error because Jac client builds to `.jac/client/dist/`.
"""
def _patch_pytauri_frontend_dist(
    pytauri_dir: Path, project_dir: Path, web_bundle_path: Path
) {
    config_path = pytauri_dir / "tauri.conf.json";
    if not config_path.exists() {
        raise RuntimeError("tauri.conf.json not found. Run 'jac setup desktop' first.");
    }
    with open(config_path, "r") as f {
        config = json.load(f);
    }
    dist_dir = web_bundle_path.parent;
    try {
        dist_relative = dist_dir.relative_to(project_dir);
        dist_relative_str = "../" + str(dist_relative.as_posix());
    } except ValueError {
        dist_relative_str = str(dist_dir.as_posix());
    }
    if "build" not in config {
        config["build"] = {};
    }
    config["build"]["frontendDist"] = dist_relative_str;
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
    with open(config_path, "w") as f {
        json.dump(config, f, indent=2);
    }
    console.print(
        f"  ✔ Updated src-pytauri/tauri.conf.json → frontendDist: {dist_relative_str}",
        style="success"
    );
}

"""Write the stable app.py stub when missing, or migrate legacy generated app.py."""
def _ensure_app_py_stub(pytauri_dir: Path) {
    app_path = pytauri_dir / "app.py";
    if app_path.exists() {
        try {
            existing = app_path.read_text(encoding="utf-8");
        } except Exception {
            existing = "";
        }
        if APP_PY_STUB_MARKER in existing {
            return;
        }
        if LEGACY_APP_PY_MARKER not in existing {
            console.warning(
                "  src-pytauri/app.py exists but is not a Jac stub; leaving it unchanged"
            );
            return;
        }
        console.print(
            "  ↻ Migrating legacy generated app.py to stable stub", style="muted"
        );
    }
    with open(app_path, "w", encoding="utf-8") as f {
        f.write(APP_PY_STUB);
    }
    console.print(f"  ✔ Wrote stable src-pytauri/app.py stub", style="success");
}

"""Generate a tiny pyproject.toml so `uv sync` / `pip install -e .` work in src-pytauri."""
def _generate_pytauri_pyproject(pytauri_dir: Path, name: str, version: str) {
    cargo_name = name.lower().replace(" ", "-").replace("_", "-");
    cargo_name = "".join(c if c.isalnum() or c == "-" else "" for c in cargo_name);
    if not cargo_name {
        cargo_name = "my-jac-app";
    }
    pyproject = f'''[project]
name = "{cargo_name}-pytauri"
version = "{version}"
description = "PyTauri shell for {name} (generated by jac setup desktop)"
requires-python = ">=3.10"
dependencies = [
    "pytauri-wheel>=0.8",
    "anyio>=4",
    "jac-desktop>=0.1.0",
]

[project.scripts]
{cargo_name}-pytauri = "app:main"
''';
    p = pytauri_dir / "pyproject.toml";
    with open(p, "w") as f {
        f.write(pyproject);
    }
    console.print(f"  ✔ Generated src-pytauri/pyproject.toml", style="success");
}

# ===============================================================================
# Lifecycle: setup
# ===============================================================================
"""Setup pytauri desktop target — scaffold src-pytauri/ Python shell."""
impl PyTauriDesktopTarget.setup(project_dir: Path) -> None {
    pytauri_dir: Path = project_dir / "src-pytauri";

    console.print("\n🐍 Setting up desktop target (PyTauri)", style="bold");
    console.print(f"  Project directory: {project_dir}", style="muted");

    if pytauri_dir.exists() {
        console.warning("  PyTauri desktop target already set up. Skipping...");
        return;
    }

    if not project_dir.exists() {
        try {
            project_dir.mkdir(parents=True, exist_ok=True);
        } except Exception {
            raise RuntimeError("Failed to create project directory");
        }
    }

    console.print("  Creating src-pytauri/ directory structure...", style="muted");
    try {
        pytauri_dir.mkdir(parents=True, exist_ok=True);
        (pytauri_dir / "binaries").mkdir(exist_ok=True);
        (pytauri_dir / "icons").mkdir(exist_ok=True);
        console.print(f"  ✔ Created {pytauri_dir}", style="success");
    } except Exception {
        raise RuntimeError("Failed to create src-pytauri directory");
    }

    # Load [plugins.desktop] if present; otherwise use defaults.
    identity = DesktopIdentity(
        name="my-jac-app", identifier="com.myapp", version="1.0.0"
    );
    window = WindowConfig(title=identity.name);

    try {
        cfg = get_desktop_config(project_dir);
        identity = cfg.get_identity();
        window = cfg.get_window_config();
    } except Exception as e {
        console.warning(
            f"  Failed to load [plugins.desktop] config ({e}); using defaults"
        );
    }

    console.print(
        f"  Project: {identity.name} v{identity.version} ({identity.identifier})",
        style="muted"
    );

    # Resolve user-requested tauri plugins from [plugins.desktop.tauri_plugins].
    tauri_plugins: list[str] = [];
    try {
        cfg2 = get_desktop_config(project_dir);
        tauri_plugins = cfg2.get_tauri_plugins_config();
    } except Exception as e {
        console.warning(
            f"  Failed to load [plugins.desktop.tauri_plugins] ({e}); none registered"
        );
    }
    extra_perms = permissions_for_plugin_ids(tauri_plugins);

    _generate_pytauri_tauri_conf(pytauri_dir, identity, window);
    _generate_pytauri_capabilities(pytauri_dir, extra_permissions=extra_perms);
    _generate_pytauri_pyproject(pytauri_dir, identity.name, identity.version);

    # Reuse shared icon generation helper from desktop_helpers.
    try {
        _generate_default_icons(pytauri_dir);
    } except Exception as e {
        console.warning(f"  Icon generation failed: {e}");
    }

    _ensure_app_py_stub(pytauri_dir);

    if tauri_plugins {
        console.print(
            f"  ✔ Tauri plugins registered: {', '.join(tauri_plugins)}", style="success"
        );
    }

    # Lightweight dependency check: verify pytauri-wheel is importable.
    _check_pytauri_wheel();

    console.print("\n  PyTauri desktop target setup complete.", style="success");
    console.print(
        "  Next: `jac build --client desktop` or `jac start --client desktop --dev`",
        style="muted"
    );
}

"""Verify that pytauri-wheel is installed (no Rust toolchain needed)."""
def _check_pytauri_wheel -> None {
    try {
        result = subprocess.run(
            [sys.executable, "-c", "import pytauri_wheel.lib; print('ok')"],
            capture_output=True,
            text=True,
            timeout=SUBPROCESS_TIMEOUT_SHORT
        );
        if result.returncode == 0 and "ok" in result.stdout {
            console.print("  ✔ pytauri-wheel importable", style="success");
            return;
        }
    } except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e {
        console.warning(f"  pytauri-wheel check failed: {e}");
    }
    console.warning("  pytauri-wheel not importable in current interpreter.");
    console.print("  Install with: pip install pytauri-wheel", style="muted");
}

# ===============================================================================
# Lifecycle: build
# ===============================================================================
"""Build pytauri-desktop app — vite bundle, sidecar, stage everything under src-pytauri/dist."""
impl PyTauriDesktopTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    console.print("\n🐍 Building desktop app (PyTauri)", style="bold");

    pytauri_dir = project_dir / "src-pytauri";
    if not pytauri_dir.exists() {
        raise RuntimeError("Desktop target not set up. Run 'jac setup desktop' first.");
    }

    sync_tauri_plugin_npm_dependencies(project_dir);

    toml_base_url = _get_toml_api_base_url(project_dir);
    if toml_base_url {
        os.environ[API_BASE_URL_ENV_VAR] = toml_base_url;
    }

    # Step 1: build web bundle via inherited WebTarget.build().
    # This target extends WebTarget directly, so super.build() runs the
    # standard Jac web bundling pipeline.
    console.print("  Step 1: Building web bundle...", style="muted");
    os.environ["JAC_BUILD"] = "1";
    try {
        web_bundle_path = super.build(entry_file, project_dir, platform);
    } finally {
        os.environ.pop(API_BASE_URL_ENV_VAR, None);
        os.environ.pop("JAC_BUILD", None);
    }
    console.print(f"  ✔ Web bundle built: {web_bundle_path}", style="success");

    _copy_assets_to_dist(project_dir, web_bundle_path.parent);

    # Keep tauri.conf.json aligned with the actual bundle path.
    _patch_pytauri_frontend_dist(pytauri_dir, project_dir, web_bundle_path);

    # Step 2: migrate legacy app.py stub; shell config comes from jac.toml at runtime.
    _ensure_app_py_stub(pytauri_dir);

    # Keep capabilities/default.json in sync with the requested plugins.
    desktop_config = get_desktop_config(project_dir);
    tauri_plugins_b: list = [];
    try {
        tauri_plugins_b = desktop_config.get_tauri_plugins_config();
    } except Exception as e {
        console.warning(
            f"  Failed to load [plugins.desktop].tauri_plugins ({e}); using none"
        );
    }
    extra_perms_b = permissions_for_plugin_ids(tauri_plugins_b);
    _generate_pytauri_capabilities(pytauri_dir, extra_permissions=extra_perms_b);

    # Step 3: bundle sidecar via PyInstaller
    is_client_only = False;
    try {
        is_client_only = desktop_config.is_client_only();
    } except Exception as e {
        console.warning(
            f"  Failed to read client_only from desktop config ({e}); bundling sidecar"
        );
    }

    if is_client_only {
        if not toml_base_url {
            raise RuntimeError(
                "client_only mode requires [plugins.client.api] base_url in jac.toml."
            );
        }
        console.print(
            "  Step 2: Sidecar bundling skipped (client_only mode)", style="muted"
        );
    } else {
        plugins_config = None;
        try {
            plugins_config = desktop_config.get_sidecar_plugins_config();
        } except Exception as e {
            console.warning(
                f"  Failed to load sidecar plugin config ({e}); using defaults"
            );
        }
        try {
            console.print("  Step 2: Bundling sidecar (Jac backend)...", style="muted");
            sc = _bundle_sidecar(
                entry_file,
                project_dir,
                pytauri_dir,
                platform,
                plugins_config.to_dict() if plugins_config else None
            );
            if sc and sc.exists() {
                console.print(f"  ✔ Sidecar bundled: {sc}", style="success");
            }
        } except Exception as e {
            console.warning(f"  Sidecar bundling skipped: {e}");
        }
    }

    # Step 4: write a launcher script next to the served frontend bundle.
    # `frontendDist` in tauri.conf.json is refreshed above from the real Vite output.
    dist_dir = pytauri_dir / "dist";
    dist_dir.mkdir(parents=True, exist_ok=True);
    console.print(
        f"  ✔ Frontend served from: {web_bundle_path.parent}", style="success"
    );

    # Write a launcher script
    _write_launcher_script(dist_dir, pytauri_dir);

    console.success("PyTauri desktop app built successfully!");
    console.print(f"  Output: {dist_dir}", style="muted");
    console.print(
        "  Note: this stages a dev launcher (run.sh/run.bat) that runs `python app.py`. " + "The sidecar is standalone; the PyTauri shell still needs Python + pytauri-wheel " + "on the machine that launches the app. Full shell packaging is planned.",
        style="muted"
    );
    return dist_dir;
}

"""Write a small shell/.bat launcher that runs `python app.py` in the right cwd."""
def _write_launcher_script(dist_dir: Path, pytauri_dir: Path) {
    if platform_mod.system() == "Windows" {
        launcher = dist_dir / "run.bat";
        content = (
            "@echo off\r\n" + f"cd /d \"{pytauri_dir}\"\r\n" + "python app.py %*\r\n"
        );
        launcher.write_text(content, encoding="utf-8");
    } else {
        launcher = dist_dir / "run.sh";
        content = (
            "#!/usr/bin/env sh\n" + f"cd \"{pytauri_dir}\"\n" + "exec python3 app.py \"$@\"\n"
        );
        launcher.write_text(content, encoding="utf-8");
        try {
            launcher.chmod(0o755);
        } except OSError as e {
            console.warning(f"  Could not mark launcher executable: {e}");
        }
    }
    console.print(f"  ✔ Wrote launcher: {launcher}", style="success");
}

# ===============================================================================
# Lifecycle: dev / start
# ===============================================================================
"""Start desktop dev server: vite dev + sidecar + python app.py with DEV_SERVER set."""
impl PyTauriDesktopTarget.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    import from jac_client.plugin.src.vite_bundler { ViteBundler }

    console.print("\n🐍 Starting desktop dev", style="bold");

    pytauri_dir = project_dir / "src-pytauri";
    if not pytauri_dir.exists() {
        raise RuntimeError("Desktop target not set up. Run 'jac setup desktop' first.");
    }

    sync_tauri_plugin_npm_dependencies(project_dir);

    # Step 1: prepare compilation (same pattern as desktop build flow)
    console.print("  Preparing compilation...", style="muted");
    bundler = ViteBundler(
        project_dir=project_dir, output_dir=None, minify=False, config_path=None
    );
    package_json_path = bundler._get_client_dir() / 'configs' / 'package.json';
    if not package_json_path.exists() {
        bundler.create_package_json();
    }

    import from jac_client.plugin.client { JacClient }
    builder = JacClient.get_client_bundle_builder();
    if not builder.vite_package_json or not builder.vite_package_json.exists() {
        builder.vite_package_json = package_json_path;
    }
    compiler = builder._get_compiler();
    compiler.compiled_dir.mkdir(parents=True, exist_ok=True);
    compiler.compile_runtime_utils();
    # Compile full client graph (entry + imports) through compiler.compile so
    # each generated JS module gets runtime helpers injected
    # (e.g. __jacJsx / __jacSpawn).
    (_, mod, _) = compiler.jac_compiler.compile_module(entry_file);
    if not mod {
        raise RuntimeError(f"Failed to compile client entry module: {entry_file}");
    }
    compiler.compile(mod, entry_file);
    console.print("  ✔ Client modules compiled for dev", style="success");

    # Step 2: vite dev server
    vite_port = port if port > 0 else DEFAULT_VITE_PORT;
    bundler.create_vite_config(
        entry_file,
        api_base_url_override=_make_localhost_url(api_port),
        is_dev=True,
        api_port=api_port
    );
    vite_proc = bundler.start_dev_server(port=vite_port, suppress_initial_output=True);
    if not vite_proc {
        raise RuntimeError("Failed to start Vite dev server");
    }
    console.print(
        f"  ✔ Vite dev server: http://localhost:{vite_port}", style="success"
    );

    # Step 3: backend
    toml_base_url = _get_toml_api_base_url(project_dir);
    effective_api_port = api_port if api_port > 0 else DEFAULT_API_PORT;
    server_port = _resolve_server_port(toml_base_url, effective_api_port);
    api_base = toml_base_url or _make_localhost_url(server_port);

    # Pull tauri plugins so capabilities stay aligned with jac.toml.
    tauri_plugins_d: list = [];
    try {
        cfg_d = get_desktop_config(project_dir);
        tauri_plugins_d = cfg_d.get_tauri_plugins_config();
    } except Exception as e {
        console.warning(
            f"  Failed to load [plugins.desktop].tauri_plugins ({e}); using none"
        );
    }
    _ensure_app_py_stub(pytauri_dir);
    extra_perms_d = permissions_for_plugin_ids(tauri_plugins_d);
    _generate_pytauri_capabilities(pytauri_dir, extra_permissions=extra_perms_d);

    server_proc = None;
    if not toml_base_url {
        console.print(
            f"  Starting backend server on port {server_port}...", style="muted"
        );
        server_proc = _start_backend_server(entry_file, project_dir, server_port);
    } else {
        console.print(f"  Using configured backend: {toml_base_url}", style="muted");
    }

    # Step 4: launch python app.py with DEV_SERVER pointing at vite
    console.print("  Launching pytauri shell (python app.py)...", style="muted");
    console.print("  (Press Ctrl+C to stop)", style="muted");
    env = os.environ.copy();
    env["DEV_SERVER"] = f"http://localhost:{vite_port}";
    if api_base {
        env["JAC_PYTAURI_API_BASE_URL"] = api_base;
    }
    py_cmd = [sys.executable, str(pytauri_dir / "app.py")];
    py_proc = subprocess.Popen(py_cmd, env=env, cwd=str(pytauri_dir));

    def cleanup {
        console.print("\n  Stopping dev processes...", style="muted");
        for p in (py_proc, vite_proc, server_proc) {
            if p is None {
                continue;
            }
            try {
                p.terminate();
                p.wait(timeout=SUBPROCESS_TIMEOUT_SHORT);
            } except (OSError, subprocess.TimeoutExpired) as e {
                console.print(f"  Process stop failed ({p.pid}): {e}", style="muted");
                try {
                    p.kill();
                } except OSError as kill_err {
                    console.print(
                        f"  Process kill failed ({p.pid}): {kill_err}", style="muted"
                    );
                }
            }
        }
        console.print("  ✔ Dev processes stopped", style="success");
    }

    def signal_handler(signum: int, frame: Any) {
        cleanup();
        sys.exit(0);
    }
    signal.signal(int(signal.SIGINT), signal_handler);
    signal.signal(int(signal.SIGTERM), signal_handler);

    try {
        py_proc.wait();
    } except KeyboardInterrupt {
        console.print("\n  Keyboard interrupt detected.", style="muted");
    } finally {
        cleanup();
    }
}

"""Production start: build the bundle and run python app.py against the built dist."""
impl PyTauriDesktopTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    console.print("\n🐍 Starting desktop app (PyTauri)", style="bold");

    pytauri_dir = project_dir / "src-pytauri";
    if not pytauri_dir.exists() {
        raise RuntimeError("Desktop target not set up. Run 'jac setup desktop' first.");
    }

    # Build the bundle if the actual served frontend isn't there yet.
    # `frontendDist` in tauri.conf.json points at `../.jac/client/dist`,
    # so that's where we look.
    served_index = project_dir / ".jac" / "client" / "dist" / "index.html";
    if not served_index.exists() {
        console.print("  No prebuilt bundle found; building...", style="muted");
        self.build(entry_file, project_dir, None);
    }

    console.print("  Launching pytauri shell (python app.py)...", style="muted");
    py_cmd = [sys.executable, str(pytauri_dir / "app.py")];
    rc = subprocess.call(py_cmd, cwd=str(pytauri_dir));
    sys.exit(rc);
}
