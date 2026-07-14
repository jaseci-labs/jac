import json;
import os;
import subprocess;
import from pathlib { Path }
import from typing { Any, Optional, cast }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.watcher { FileChangeEvent }
import from jaclang.runtimelib.client.targets.react_native.common {
    resolve_node_runner
}
import from jaclang.runtimelib.client.targets.react_native.build {
    lint_native_incompatible_usage,
    lint_unmapped_tags,
    read_user_js_sources,
    stage_native_image_assets,
    stage_compiled_entry,
    strip_css_imports
}
import from jaclang.runtimelib.client.targets.client_dev_common {
    invalidate_runtime_module_cache,
    setup_android_port_reverse_common
}

glob JAC_RN_METRO_PORT_ENV: str = "JAC_RN_METRO_PORT",
     JAC_RN_DEV_HOST_ENV: str = "JAC_RN_DEV_HOST",
     DEFAULT_METRO_PORT: int = 8081;

def resolve_metro_port(cli_port: int = DEFAULT_METRO_PORT) -> int {
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

def setup_android_port_reverse(metro_port: int, api_port: int) {
    ports = [metro_port];
    if api_port != metro_port {
        ports.append(api_port);
    }
    setup_android_port_reverse_common(ports);
}

def inject_dev_api_base_url(rn_dir: Path, api_url: str) -> Optional[str] {
    config_path = rn_dir / "app.json";
    if not config_path.exists() {
        console.warning(
            f"  app.json not found at {config_path}; skipping API URL injection. "
            "Run `jac setup react-native` to regenerate the scaffold."
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
    console.print(f"  ✔ app.json → expo.extra.apiBaseUrl = {api_url}", style="success");
    return original;
}

def restore_app_json(rn_dir: Path, original: Optional[str]) -> None {
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

def rn_hmr_on_jac_changed(
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
        compile_out = cast(Any, compiler.jac_compiler.compile_module(entry_file));
        mod2 = compile_out[1];
        if not mod2 {
            return;
        }
        compiler.compile(mod2, entry_file, target_name="react-native");
        compiled_dir = compiler.compiled_dir;
        if compiled_dir is not None {
            try {
                js_sources = read_user_js_sources(compiled_dir);
                lint_unmapped_tags(compiled_dir, sources=js_sources);
                lint_native_incompatible_usage(compiled_dir, sources=js_sources);
            } except Exception { }
            try {
                strip_css_imports(compiled_dir);
            } except Exception { }
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
        } except Exception { }
    } except Exception as e {
        try {
            console.error(f"  HMR recompile failed: {e}");
        } except Exception { }
    }
}

def build_expo_start_argv(metro_port: int, clear_cache: bool = True) -> list[str] {
    argv: list[str] = resolve_node_runner() + [
        "expo",
        "start",
        "--port",
        str(metro_port)
    ];
    if clear_cache {
        argv.append("--clear");
    }
    return argv;
}

def run_expo_start(rn_dir: Path, metro_port: int, clear_cache: bool = True) -> int {
    argv = build_expo_start_argv(metro_port, clear_cache=clear_cache);
    console.print(f"  Running: {' '.join(argv)}", style="muted");
    console.print("  (Press Ctrl+C to stop)\n", style="muted");
    result = subprocess.run(argv, cwd=str(rn_dir), check=False);
    return result.returncode;
}
