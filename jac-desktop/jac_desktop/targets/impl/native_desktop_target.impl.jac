"""Implementation of the Jac-native desktop target."""
import os;
import shutil;
import json;
import subprocess;
import sysconfig;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }
import from jac_desktop.targets.desktop_build {
    _find_webview_dir,
    _jac_bin,
    _libpython_soname,
    _loopback_serve_py,
    _patch_host_rpath,
    _stage_oauth_broker,
}

"""Ensure libwebview.so exists beside the binding (build it on first use)."""
def _ensure_libwebview(webview_dir: Path) -> Path {
    lib = webview_dir / "libwebview.so";
    if lib.exists() {
        return lib;
    }
    console.print("  Building libwebview.so (one-time)...", style="muted");
    res = subprocess.run([str(webview_dir / "build_libwebview.sh")]);
    if res.returncode != 0 or not lib.exists() {
        raise RuntimeError(
            "Failed to build libwebview.so - is WebKitGTK + a C toolchain installed? "
            "See jac_desktop/native/webview/README.md."
        );
    }
    return lib;
}

"""Generate the native host source: embed CPython, serve `dist/` on loopback,
and render it in the webview."""
def _generate_host_source(
    libpy: str, title: str, width: int, height: int, app_name: str
) -> str {
    serve_py = _loopback_serve_py(app_name);
    bootstrap_js = (
        "(function(){try{"
        "window.__JAC_DESKTOP__=true;window.__JAC_BROKER__='/__jac';"
        "}catch(e){}})();"
    );
    return (
        '"""Generated native desktop host - do not edit (jac-desktop)."""\n'
        "import from webview { Webview, new_webview, HINT_NONE }\n"
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
        f"glob BOOTSTRAP_JS: str = {json.dumps(bootstrap_js, ensure_ascii=False)};\n"
        "with entry {\n"
        "    Py_Initialize();\n"
        "    PyRun_SimpleString(SERVE_PY);\n"
        '    main_mod = PyImport_AddModule("__main__");\n'
        "    d = PyModule_GetDict(main_mod);\n"
        '    port = PyLong_AsLong(PyRun_String("_port", PY_EVAL, d, d));\n'
        "    url = f\"http://127.0.0.1:{port}/\";\n"
        "    wv = new_webview(False);\n"
        f"    wv.title({json.dumps(title, ensure_ascii=False)});\n"
        f"    wv.size({width}, {height}, HINT_NONE);\n"
        "    wv.on_load(BOOTSTRAP_JS);\n"
        "    wv.navigate(url);\n"
        "    ts = PyEval_SaveThread();\n"
        "    wv.run();\n"
        "    PyEval_RestoreThread(ts);\n"
        "    Py_Finalize();\n"
        "}\n"
    );
}

impl NativeDesktopTarget.setup(project_dir: Path) -> None { }

impl NativeDesktopTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    import from jac_desktop.config_loader { get_desktop_config }

    console.print("\n🖥️  Building desktop app (Jac-native webview)", style="bold");
    web_bundle = super.build(entry_file, project_dir, platform);
    dist_dir = web_bundle.parent;

    cfg = get_desktop_config(project_dir);
    ident = cfg.get_identity();
    win = cfg.get_window_config();
    app_name = ident.name or "app";

    out_dir = project_dir / self.output_dir;
    if out_dir.exists() {
        shutil.rmtree(out_dir);
    }
    out_dir.mkdir(parents=True, exist_ok=True);

    shutil.copytree(dist_dir, out_dir / "dist");
    webview_dir = _find_webview_dir();
    lib = _ensure_libwebview(webview_dir);
    shutil.copy2(lib, out_dir / "libwebview.so");
    shutil.copy2(webview_dir / "webview.na.jac", out_dir / "webview.na.jac");
    _stage_oauth_broker(out_dir);

    host_src = _generate_host_source(
        _libpython_soname(), win.title or app_name, win.width, win.height, str(app_name)
    );
    (out_dir / "host.na.jac").write_text(host_src);

    console.print("  Compiling native host (jac nacompile)...", style="muted");
    res = subprocess.run(
        [_jac_bin(), "nacompile", "host.na.jac", "-o", app_name], cwd=str(out_dir)
    );
    if res.returncode != 0 {
        raise RuntimeError("Native host compilation failed.");
    }
    binary = out_dir / app_name;
    _patch_host_rpath(binary);
    console.print(f"\n✅ Desktop app built: {binary}", style="bold green");
    console.print(f"   run: (cd {out_dir} && ./{app_name})", style="muted");
    return binary;
}

impl NativeDesktopTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    binary = self.build(entry_file, project_dir, None);
    env = dict(os.environ);
    libdir = sysconfig.get_config_var("LIBDIR") or "";
    if libdir {
        prev = env.get("LD_LIBRARY_PATH", "");
        env["LD_LIBRARY_PATH"] = libdir if not prev else f"{libdir}:{prev}";
    }
    env.setdefault("GDK_BACKEND", "x11");
    env.setdefault("WEBKIT_DISABLE_DMABUF_RENDERER", "1");
    env.setdefault("WEBKIT_DISABLE_COMPOSITING_MODE", "1");
    console.print(f"\n🚀 Launching {binary.name}", style="bold green");
    try {
        subprocess.run([str(binary)], cwd=str(binary.parent), env=env);
    } except KeyboardInterrupt {
        console.print("\n  Closing desktop app...", style="muted");
    }
}

impl NativeDesktopTarget.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    console.print(
        "  desktop --dev: building and launching (HMR not yet wired)", style="muted"
    );
    self.start(entry_file, project_dir, api_port);
}
