"""Implementation of the CEF-based desktop target.

Mirrors the pipeline in native_desktop_target.impl.jac with two divergences:
  - The host uses cef.na.jac (CEF Chromium) instead of webview.na.jac
  - The CEF runtime bundle is staged alongside dist/
Shared build steps live in desktop_build.jac.
"""
import os;
import shutil;
import json;
import subprocess;
import stat;
import sysconfig;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.client.targets.desktop.desktop_build {
    _find_cef_dir,
    _jac_bin,
    _libpython_soname,
    _loopback_serve_py,
    _patch_host_rpath,
    _plugin_bootstrap_py,
    _stage_oauth_broker,
    _stage_plugins,
    build_cef_dispatch,
    build_cef_subprocess,
    fetch_cef_dist,
}

"""Ensure the CEF binary distribution is staged (fetch it on first use)."""
def _ensure_cef_dist(cef_dir: Path) -> Path {
    dist = cef_dir / "cef_dist";
    headers = cef_dir / "cef_headers" / "include" / "capi" / "cef_app_capi.h";
    if (dist / "libcef.so").exists() and headers.exists() {
        return dist;
    }
    console.print("  Fetching CEF binary distribution (one-time)...", style="muted");
    fetch_cef_dist(cef_dir);
    if not (dist / "libcef.so").exists() {
        raise RuntimeError(
            "Failed to fetch CEF binary distribution. "
            "See targets/desktop/native/cef/README.md for prerequisites."
        );
    }
    if not headers.exists() {
        raise RuntimeError(
            "CEF SDK headers missing after fetch (re-run the cef build)."
        );
    }
    return dist;
}

"""Return true when an output is missing or older than any source input."""
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

"""Ensure libcef_dispatch.so exists beside the binding (build it on first use)."""
def _ensure_libcef_dispatch(cef_dir: Path) -> Path {
    lib = cef_dir / "libcef_dispatch.so";
    src = cef_dir / "cef_dispatch.na.jac";
    stale = _is_stale(lib, [src, cef_dir / "cef_platform.na.jac"]);
    if not stale {
        return lib;
    }
    console.print(
        "  Building libcef_dispatch.so (jac nacompile --shared)...", style="muted"
    );
    return build_cef_dispatch(cef_dir);
}

"""Ensure cef-subprocess helper exists (jac nacompile binary for CEF browser subprocesses)."""
def _ensure_cef_subprocess(cef_dir: Path) -> Path {
    helper = cef_dir / "cef-subprocess";
    src = cef_dir / "cef_subprocess.na.jac";
    stale = _is_stale(helper, [src, cef_dir / "cef_platform.na.jac"]);
    if not stale {
        return helper;
    }
    console.print("  Building cef-subprocess (jac nacompile)...", style="muted");
    return build_cef_subprocess(cef_dir);
}

"""Generate the CEF native host source (`host.na.jac`).

Bootstrap JS (window.__JAC_DESKTOP__, window.__JAC_BROKER__) is injected in
cef_dispatch.na.jac's on_context_created handler, not in this host.
"""
def _generate_host_source(
    libpy: str,
    title: str,
    width: int,
    height: int,
    app_name: str,
    cache_path: str,
    plugin_configs: dict = {},
) -> str {
    # Splice the plugin host into the loopback server: it builds _host/_dispatch_fn,
    # switches the host to the SSE push transport (setup_cef), routes POST
    # /__jac/invoke into dispatch, and exposes the host on GET /__jac/events for
    # emit()/eval_js(). JS reaches invoke via the fetch shim and on()/__emit__ via
    # the EventSource in cef_dispatch.na.jac's BOOTSTRAP_JS (CEF's render process
    # can't bind into the host in-process the way the single-process webview
    # target does). Threaded server: the SSE stream blocks for its lifetime.
    serve_py = _loopback_serve_py(
        app_name,
        _plugin_bootstrap_py(plugin_configs) + "_host.setup_cef()\n",
        ", dispatch=_dispatch_fn, events=_host",
        True
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
        f'import from "{libpy}" {{\n'
        "    def Py_Initialize() -> None;\n"
        "    def Py_Finalize() -> None;\n"
        "    def PyRun_SimpleString(cmd: str) -> i32;\n"
        "    def PyImport_AddModule(name: str) -> int;\n"
        "    def PyModule_GetDict(module: int) -> int;\n"
        "    def PyRun_String(s: str, start: i32, g: int, l: int) -> int;\n"
        "    def PyLong_AsLong(o: int) -> int;\n"
        "    def PyEval_SaveThread() -> int;\n"
        "    def PyEval_RestoreThread(s: int) -> None;\n"
        "}\n"
        "glob PY_EVAL: i32 = 258;\n"
        f"glob SERVE_PY: str = {json.dumps(serve_py, ensure_ascii=False)};\n"
        "with entry {\n"
        "    code: i32 = cef_execute_subprocess();\n"
        "    if code >= 0 {\n"
        "        sys.exit(code);\n"
        "    }\n"
        f"    rc: i32 = cef_startup({json.dumps(cache_path, ensure_ascii=False)}, 1);\n"
        "    if rc != 1 {\n"
        "        sys.exit(1);\n"
        "    }\n"
        "    Py_Initialize();\n"
        "    rc_py: i32 = PyRun_SimpleString(SERVE_PY);\n"
        "    if rc_py != 0 {\n"
        "        sys.exit(1);\n"
        "    }\n"
        '    main_mod = PyImport_AddModule("__main__");\n'
        "    d = PyModule_GetDict(main_mod);\n"
        '    port_obj: int = PyRun_String("_port", PY_EVAL, d, d);\n'
        "    if port_obj == 0 {\n"
        "        sys.exit(1);\n"
        "    }\n"
        "    port = PyLong_AsLong(port_obj);\n"
        "    url = f\"http://127.0.0.1:{port}/\";\n"
        "    cef_open_browser(\n"
        "        url,\n"
        f"        {json.dumps(title, ensure_ascii=False)},\n"
        f"        {width}, {height}\n"
        "    );\n"
        "    ts = PyEval_SaveThread();\n"
        "    cef_run_loop();\n"
        "    PyEval_RestoreThread(ts);\n"
        "    Py_Finalize();\n"
        "    cef_cleanup();\n"
        "}\n"
    );
}

"""Stage the CEF runtime bundle alongside dist/ in the output directory."""
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
    for pak in cef_dist.glob("*.pak") {
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

impl CefDesktopTarget.setup(project_dir: Path) -> None { }

impl CefDesktopTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    import from jaclang.runtimelib.client.desktop_config { get_desktop_config }

    console.print("\n🖥️  Building CEF desktop app (Chromium)", style="bold");
    web_bundle = super.build(entry_file, project_dir, platform);
    dist_dir = web_bundle.parent;

    cfg = get_desktop_config(project_dir);
    # Fail the build on a bad config instead of silently shipping it (mirrors
    # the native target).
    cfg.validate();
    ident = cfg.get_identity();
    win = cfg.get_window_config();
    plugin_configs = cfg.get_plugin_configs();
    app_name = ident.name or "app";

    out_dir = project_dir / self.output_dir;
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
    cef_dist = _ensure_cef_dist(cef_dir);
    libcef_dispatch = _ensure_libcef_dispatch(cef_dir);
    cef_subprocess = _ensure_cef_subprocess(cef_dir);
    shutil.copy2(libcef_dispatch, out_dir / "libcef_dispatch.so");
    shutil.copy2(cef_subprocess, out_dir / "cef-subprocess");
    (out_dir / "cef-subprocess").chmod(0o755);
    shutil.copy2(cef_dir / "cef.na.jac", out_dir / "cef.na.jac");
    _stage_cef_runtime(cef_dist, out_dir);
    _stage_oauth_broker(out_dir);
    # Transpile plugin .jac -> .py for the embedded CPython (same as native).
    _stage_plugins(out_dir);

    cache_path = str(project_dir / ".jac" / "desktop" / "cef-cache" / str(app_name));
    host_src = _generate_host_source(
        _libpython_soname(),
        win.title or app_name,
        win.width,
        win.height,
        str(app_name),
        cache_path,
        plugin_configs,
    );
    (out_dir / "host.na.jac").write_text(host_src);

    console.print("  Compiling CEF native host (jac nacompile)...", style="muted");
    res = subprocess.run(
        [_jac_bin(), "nacompile", "host.na.jac", "-o", app_name], cwd=str(out_dir),
    );
    if res.returncode != 0 {
        raise RuntimeError("CEF native host compilation failed.");
    }
    binary = out_dir / app_name;
    _patch_host_rpath(binary);
    console.print(f"\n✅ CEF desktop app built: {binary}", style="bold green");
    console.print(f"   run: (cd {out_dir} && ./{app_name})", style="muted");
    return binary;
}

impl CefDesktopTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    binary = self.build(entry_file, project_dir, None);
    env = dict(os.environ);
    libdir = sysconfig.get_config_var("LIBDIR") or "";
    if libdir {
        prev = env.get("LD_LIBRARY_PATH", "");
        env["LD_LIBRARY_PATH"] = libdir if not prev else f"{libdir}:{prev}";
    }
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

impl CefDesktopTarget.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    console.print(
        "  cef --dev: building and launching (HMR not yet wired)", style="muted"
    );
    self.start(entry_file, project_dir, api_port);
}
