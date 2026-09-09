import os;
import shutil;
import json;
import subprocess;
import stat;
import from jaclang.toolchains.cef { ensure_cef }
import from pathlib { Path }
import from jaclang.cli.console { console }
import from jaclang.client.targets.desktop.desktop_build {
    stage_program,
    _find_cef_dir,
    _jac_bin,
    _jac_subprocess_env,
    _patch_host_rpath,
    _stage_fused_runtime,
    _bundle_runtime,
    build_cef_dispatch,
    build_cef_subprocess,
}
import from jaclang.client.targets.desktop._host_bootstrap {
    _host_boot_py,
    _fused_runtime_import_block
}
import from jaclang.client.targets.desktop._dev_launch {
    ensure_dev_build_env,
    desktop_app_runtime_env
}

def _is_stale(output: Path, inputs: list[Path]) -> bool {
    if not output.exists() {
        return True;
    }
    out_mtime = output.stat().st_mtime;
    for src in inputs {
        if src.exists() and src.stat().st_mtime > out_mtime {
            return True;
        }
    }
    return False;
}

def _ensure_libcef_dispatch(cef_dir: Path) -> Path {
    lib = cef_dir / "libcef_dispatch.so";
    src = cef_dir / "cef_dispatch.jac";
    stale = _is_stale(lib, [src, cef_dir / "cef_platform.jac"]);
    if not stale {
        return lib;
    }
    console.print(
        "  Building libcef_dispatch.so (jac build --native --lib)...", style="muted"
    );
    return build_cef_dispatch(cef_dir);
}

def _ensure_cef_subprocess(cef_dir: Path) -> Path {
    helper = cef_dir / "cef-subprocess";
    src = cef_dir / "cef_subprocess.jac";
    stale = _is_stale(helper, [src, cef_dir / "cef_platform.jac"]);
    if not stale {
        return helper;
    }
    console.print("  Building cef-subprocess (jac build --native)...", style="muted");
    return build_cef_subprocess(cef_dir);
}

def _generate_host_source(
    title: str,
    width: int,
    height: int,
    app_name: str,
    cache_path: str,
    plugin_configs: (dict | None) = None,
    program: (dict | None) = None,
    backend: str = "embedded",
    dispatch_timeout_s: float = 30.0,
    dispatch_max_queue: int = 128,
    dispatch_debug: bool = False,
) -> str {
    boot_py = _host_boot_py(
        app_name,
        "cef",
        program,
        backend,
        dispatch_timeout_s,
        dispatch_max_queue,
        dispatch_debug,
        plugin_configs
    );
    return (
        '"""Generated CEF desktop host - do not edit (jac-desktop)."""\n'
        "import sys;\n"
        "import from cef {\n"
        "    cef_execute_subprocess,\n"
        "    cef_startup,\n"
        "    cef_open_browser,\n"
        "    cef_run_loop,\n"
        "    cef_cleanup,\n"
        "}\n"
        + _fused_runtime_import_block()
        + "glob PY_EVAL: i32 = 258;\n"
        f"glob BOOT_PY: str = {json.dumps(boot_py, ensure_ascii=False)};\n"
        "with entry {\n"
        "    code: i32 = cef_execute_subprocess();\n"
        "    if code >= 0 {\n"
        "        sys.exit(code);\n"
        "    }\n"
        f"    rc: i32 = cef_startup({json.dumps(cache_path, ensure_ascii=False)}, 1);\n"
        "    if rc != 1 {\n"
        "        sys.exit(1);\n"
        "    }\n"
        "    api = engine_boot().api;\n"
        "    rc_py: i32 = api.PyRun_SimpleString(BOOT_PY);\n"
        "    if rc_py != 0 {\n"
        "        sys.exit(1);\n"
        "    }\n"
        '    main_mod = api.PyImport_AddModule("__main__");\n'
        "    d = api.PyModule_GetDict(main_mod);\n"
        '    port_obj: int = api.PyRun_String("_ctx.port", PY_EVAL, d, d);\n'
        "    if port_obj == 0 {\n"
        "        sys.exit(1);\n"
        "    }\n"
        "    port = api.PyLong_AsLong(port_obj);\n"
        "    url = f\"http://127.0.0.1:{port}/\";\n"
        "    cef_open_browser(\n"
        "        url,\n"
        f"        {json.dumps(title, ensure_ascii=False)},\n"
        f"        {width}, {height}\n"
        "    );\n"
        "    ts = api.PyEval_SaveThread();\n"
        "    cef_run_loop();\n"
        "    api.PyEval_RestoreThread(ts);\n"
        "    api.Py_Finalize();\n"
        "    cef_cleanup();\n"
        "}\n"
    );
}

def _stage_cef_runtime(cef_dist: Path, out_dir: Path) {
    shutil.copy2(cef_dist / "libcef.so", out_dir / "libcef.so");
    for name in [
        "libEGL.so",
        "libGLESv2.so",
        "libvk_swiftshader.so",
        "vk_swiftshader_icd.json"
    ] {
        src = cef_dist / name;
        if src.exists() {
            shutil.copy2(src, out_dir / name);
        }
    }
    for name in ["icudtl.dat", "v8_context_snapshot.bin"] {
        src = cef_dist / name;
        if src.exists() {
            shutil.copy2(src, out_dir / name);
        }
    }
    for pak in cef_dist.`glob("*.pak") {
        shutil.copy2(pak, out_dir / pak.name);
    }
    locales_src = cef_dist / "locales";
    if locales_src.exists() {
        shutil.copytree(locales_src, out_dir / "locales");
    }
    sandbox_src = cef_dist / "chrome-sandbox";
    if sandbox_src.exists() {
        shutil.copy2(sandbox_src, out_dir / "chrome-sandbox");
        mode = int(os.stat(out_dir / "chrome-sandbox").st_mode);
        if not (mode & int(stat.S_ISUID)) {
            console.print(
                "  [yellow]⚠  chrome-sandbox lacks setuid root. "
                "CEF will use --no-sandbox (less secure).[/yellow]"
            );
            console.print(
                "     Fix: sudo chown root:root chrome-sandbox && "
                "sudo chmod 4755 chrome-sandbox",
                style="muted"
            );
        }
    }
}

def cef_build(
    entry_file: Path, project_dir: Path, out_dir: Path, web_bundle: Path
) -> Path {
    import from jaclang.client.desktop_config { get_desktop_config }

    ensure_dev_build_env();

    console.print("\n🖥️  Building CEF desktop app (Chromium)", style="bold");
    dist_dir = web_bundle.parent;

    cfg = get_desktop_config(project_dir);

    cfg.validate();
    ident = cfg.get_identity();
    win = cfg.get_window_config();
    dispatch = cfg.get_dispatch_config();
    plugin_configs = cfg.get_plugin_configs();
    app_name = ident.name or "app";

    if out_dir.exists() {
        shutil.rmtree(out_dir);
    }
    out_dir.mkdir(parents=True, exist_ok=True);

    shutil.copytree(dist_dir, out_dir / "dist");

    cef_dir = _find_cef_dir();
    fonts_conf = cef_dir / "minimal-fonts.conf";
    if fonts_conf.exists() {
        shutil.copy2(fonts_conf, out_dir / "minimal-fonts.conf");
    }
    cef_dist = ensure_cef(cef_dir);
    libcef_dispatch = _ensure_libcef_dispatch(cef_dir);
    cef_subprocess = _ensure_cef_subprocess(cef_dir);
    shutil.copy2(libcef_dispatch, out_dir / "libcef_dispatch.so");
    shutil.copy2(cef_subprocess, out_dir / "cef-subprocess");
    (out_dir / "cef-subprocess").chmod(0o755);
    shutil.copy2(cef_dir / "cef.jac", out_dir / "cef.jac");
    _stage_cef_runtime(cef_dist, out_dir);

    backend = cfg.get_backend();
    program = stage_program(entry_file, project_dir, out_dir, backend, dist_dir);
    _stage_fused_runtime(out_dir);
    cache_path = str(project_dir / ".jac" / "desktop" / "cef-cache" / str(app_name));
    host_src = _generate_host_source(
        win.title or app_name,
        win.width,
        win.height,
        str(app_name),
        cache_path,
        plugin_configs,
        program,
        backend,
        dispatch.timeout_s,
        dispatch.max_queue,
        dispatch.debug,
    );
    (out_dir / "host.jac").write_text(host_src);

    console.print("  Compiling CEF native host (jac build --native)...", style="muted");
    res = subprocess.run(
        [_jac_bin(), "build", "--native", "host.jac", "-o", app_name],
        cwd=str(out_dir),
        env=_jac_subprocess_env(),
    );
    if res.returncode != 0 {
        raise RuntimeError("CEF native host compilation failed.");
    }
    binary = out_dir / app_name;

    _patch_host_rpath(binary);
    _bundle_runtime(binary);
    console.print(f"\n✅ CEF desktop app built: {binary}", style="bold green");
    console.print(f"   run: (cd {out_dir} && ./{app_name})", style="muted");
    return binary;
}

def cef_start(binary: Path) {
    env = desktop_app_runtime_env();
    env.setdefault("LIBGL_ALWAYS_SOFTWARE", "1");
    env.setdefault("GALLIUM_DRIVER", "llvmpipe");
    fonts_conf = binary.parent / "minimal-fonts.conf";
    if fonts_conf.exists() {
        env.setdefault("FONTCONFIG_FILE", str(fonts_conf));
    }
    console.print(f"\n🚀 Launching CEF desktop app: {binary.name}", style="bold green");
    try {
        subprocess.run([str(binary)], cwd=str(binary.parent), env=env);
    } except KeyboardInterrupt {
        console.print("\n  Closing CEF desktop app...", style="muted");
    }
}

def cef_dev_unsupported {
    raise RuntimeError(
        "CEF desktop HMR is not supported yet. CEF routes RPC through the "
        "loopback broker, so a Vite dev origin breaks the app. Set "
        "[desktop] engine = \"native\" for HMR, or run without --dev."
    );
}
