import json;
import os;
import subprocess;
import from pathlib { Path }
import from typing { Optional }

glob JAC_RN_METRO_PORT_ENV: str = "JAC_RN_METRO_PORT",
     JAC_RN_DEV_HOST_ENV: str = "JAC_RN_DEV_HOST",
     JAC_RN_TUNNEL_ENV: str = "JAC_RN_TUNNEL",
     JAC_RN_API_PROXY_ENV: str = "JAC_RN_API_PROXY",
     METRO_API_PREFIX: str = "/__jac_api",
     DEFAULT_METRO_PORT: int = 8081;

def resolve_metro_port(cli_port: int = DEFAULT_METRO_PORT) -> int;

def setup_android_port_reverse(metro_port: int, api_port: int);

def inject_dev_api_base_url(rn_dir: Path, api_url: str) -> Optional[str];

def inject_metro_api_base(rn_dir: Path) -> Optional[str];

def restore_app_json(rn_dir: Path, original: Optional[str]) -> None;

def rn_hmr_on_jac_changed(
    event: FileChangeEvent,
    compiler: any,
    entry_file: Path,
    project_dir: Path,
    rn_dir: Path,
    entry_module: str
) -> None;

def build_expo_start_argv(
    rn_dir: Path,
    metro_port: int,
    clear_cache: bool = True,
    platform: str = "",
    tunnel: bool = False
) -> list[str];

def run_expo_start(
    rn_dir: Path,
    metro_port: int,
    clear_cache: bool = True,
    platform: str = "",
    tunnel: bool = False,
    packager_host: str = "",
    api_proxy: str = ""
) -> int;

impl resolve_metro_port(cli_port: int = DEFAULT_METRO_PORT) -> int {
    raw = os.environ.get(JAC_RN_METRO_PORT_ENV, "");
    if raw and str(raw).strip() {
        try {
            return int(str(raw).strip());
        } except Exception {
            return cli_port;
        }
    }
    return cli_port;
}

impl setup_android_port_reverse(metro_port: int, api_port: int) {
    ports = [metro_port];
    if api_port != metro_port {
        ports.append(api_port);
    }
    setup_android_port_reverse_common(ports);
}

impl inject_dev_api_base_url(rn_dir: Path, api_url: str) -> Optional[str] {
    config_path = rn_dir / "app.json";
    if not config_path.exists() {
        console.warning(
            f"  app.json not found at {config_path}; skipping API URL injection. "
            "Run `jac setup <app>` to regenerate the scaffold."
        );
        return None;
    }
    original = config_path.read_text(encoding="utf-8");
    try {
        cfg = json.loads(original);
    } except Exception as e {
        console.warning(f"  Could not parse app.json ({e}); skipping injection.");
        return None;
    }
    expo = cfg.get("expo", {});
    extra = expo.get("extra", {});
    extra["apiBaseUrl"] = api_url;
    expo["extra"] = extra;
    cfg["expo"] = expo;
    config_path.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8");

    write_api_base_shim(rn_dir, api_url);
    console.print(
        f"  ✔ app.json + __jacApiBase.js → apiBaseUrl = {api_url}", style="success"
    );
    return original;
}

impl inject_metro_api_base(rn_dir: Path) -> Optional[str] {
    config_path = rn_dir / "app.json";
    original: Optional[str] = None;
    if config_path.exists() {
        original = config_path.read_text(encoding="utf-8");
        try {
            cfg = json.loads(original);
            expo = cfg.get("expo", {});
            extra = expo.get("extra", {});
            extra["apiBaseUrl"] = "";
            expo["extra"] = extra;
            cfg["expo"] = expo;
            config_path.write_text(json.dumps(cfg, indent=2) + "\n", encoding="utf-8");
        } except Exception as e {
            console.warning(f"  Could not parse app.json ({e}); leaving it as is.");
            original = None;
        }
    }
    (rn_dir / "__jacApiBase.js").write_text(
        (
            "// Written by `jac run --tunnel <app>`: the API rides Metro's origin.\n"
            "import Constants from 'expo-constants';\n"
            "const __jacHost =\n"
            "  (Constants.expoConfig && Constants.expoConfig.hostUri) ||\n"
            "  (Constants.expoGoConfig && Constants.expoGoConfig.debuggerHost) ||\n"
            "  '';\n"
            "globalThis.__JAC_API_BASE_URL__ = __jacHost\n"
            f"  ? 'http://' + __jacHost + '{METRO_API_PREFIX}'\n"
            "  : '';\n"
        ),
        encoding="utf-8"
    );
    console.print(
        f"  ✔ __jacApiBase.js → apiBaseUrl = <Metro origin>{METRO_API_PREFIX}",
        style="success"
    );
    return original;
}

impl restore_app_json(rn_dir: Path, original: Optional[str]) -> None {
    if original is None {
        return;
    }
    config_path = rn_dir / "app.json";
    try {
        config_path.write_text(original, encoding="utf-8");
        console.print("  ✔ Restored app.json", style="muted");
    } except Exception as e {
        console.warning(f"  Failed to restore app.json: {e}");
    }
}

impl rn_hmr_on_jac_changed(
    event: FileChangeEvent,
    compiler: any,
    entry_file: Path,
    project_dir: Path,
    rn_dir: Path,
    entry_module: str
) -> None {
    try {
        pth = event.path or "";
        if not pth or not pth.endswith(".jac") {
            return;
        }
        try {
            Path(pth).resolve().relative_to(project_dir.resolve());
        } except ValueError {
            return;
        }
        invalidate_runtime_module_cache([pth, str(entry_file)]);
        compiler.compile(None, entry_file, native=True);
        compiled_dir = compiler.compiled_dir;
        if compiled_dir is not None {
            try {
                js_sources = read_user_js_sources(compiled_dir);
                lint_unmapped_tags(compiled_dir, sources=js_sources);
                lint_native_incompatible_usage(compiled_dir, sources=js_sources);
            } except Exception {}
            try {
                strip_css_imports(compiled_dir);
            } except Exception {}
            try {
                stage_compiled_entry(compiled_dir, rn_dir, entry_module);
            } except Exception as stage_err {
                console.error(f"  HMR stage failed: {stage_err}");
                return;
            }
            try {
                stage_native_image_assets(rn_dir / "jac-src", rn_dir);
            } except Exception as asset_err {
                console.warning(f"  HMR asset stage warning: {asset_err}");
            }
        }
        try {
            console.print(
                "  ✔ Native client recompiled — Metro will Fast Refresh",
                style="success"
            );
        } except Exception {}
    } except Exception as e {
        try {
            console.error(f"  HMR recompile failed: {e}");
        } except Exception {}
    }
}

impl build_expo_start_argv(
    rn_dir: Path,
    metro_port: int,
    clear_cache: bool = True,
    platform: str = "",
    tunnel: bool = False
) -> list[str] {
    argv: list[str] = resolve_node_tool(rn_dir, "expo")
        + ["start", "--port", str(metro_port)];
    if clear_cache {
        argv.append("--clear");
    }
    if platform in ("android", "ios") {
        argv.append(f"--{platform}");
    }
    if tunnel {
        argv.append("--tunnel");
    }
    return argv;
}

impl run_expo_start(
    rn_dir: Path,
    metro_port: int,
    clear_cache: bool = True,
    platform: str = "",
    tunnel: bool = False,
    packager_host: str = "",
    api_proxy: str = ""
) -> int {
    argv = build_expo_start_argv(
        rn_dir, metro_port, clear_cache=clear_cache, platform=platform, tunnel=tunnel
    );
    env = dict(os.environ);
    if packager_host {
        env["REACT_NATIVE_PACKAGER_HOSTNAME"] = packager_host;
    }
    if api_proxy {
        env[JAC_RN_API_PROXY_ENV] = api_proxy;
    } else {
        env.pop(JAC_RN_API_PROXY_ENV, None);
    }
    console.print(f"  Running: {' '.join(argv)}", style="muted");
    console.print("  (Press Ctrl+C to stop)\n", style="muted");
    result = subprocess.run(argv, cwd=str(rn_dir), check=False, env=env);
    return result.returncode;
}
