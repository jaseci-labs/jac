"""Implementation of the Jac-native desktop target."""
import os;
import shutil;
import json;
import subprocess;
import sysconfig;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }
import from jaclang.runtimelib.client.targets.desktop.plugin.webview_lib {
    libwebview_name
}
import from jaclang.runtimelib.client.targets.desktop.desktop_build {
    _find_webview_dir,
    _jac_bin,
    _jac_sdk_js,
    _loopback_serve_py,
    _plugin_bootstrap_py,
    _stage_oauth_broker,
    _stage_plugins,
}

"""Read lines from a file between start_marker and end_marker (exclusive).

Used to extract the bridge code from plugin_bridge.na.jac so that file is
the single source of truth — no hand-synced duplication."""
def _read_between(path: Path, start_marker: str, end_marker: str) -> str {
    lines = path.read_text().splitlines(True);
    capturing = False;
    result: list = [];
    for line in lines {
        if not capturing {
            if line.rstrip() == start_marker {
                capturing = True;
            }
        } elif line.rstrip() == end_marker {
            break;
        } else {
            result.append(line);
        }
    }
    return "".join(result);
}

"""Ensure the platform webview shared library exists beside the binding (build it on first use)."""
def _ensure_libwebview(webview_dir: Path) -> Path {
    lib = webview_dir / libwebview_name();
    if lib.exists() {
        return lib;
    }
    console.print(f"  Building {libwebview_name()} (one-time)...", style="muted");
    res = subprocess.run([str(webview_dir / "build_libwebview.sh")]);
    if res.returncode != 0 or not lib.exists() {
        raise RuntimeError(
            f"Failed to build {libwebview_name()} - is WebKitGTK + a C toolchain installed? "
            "See jaclang/runtimelib/client/targets/desktop/native/webview/README.md."
        );
    }
    return lib;
}

"""Generate the native host source: embed CPython, serve `dist/` (resolved next
to the running binary) on loopback through the OAuth/session broker,
and render it in the webview.

The loopback server is the `oauth_broker` module staged beside the binary, not a
bare SimpleHTTPRequestHandler: it serves the bundle AND exposes /__jac/* routes
that broker SSO logins through the system browser (see oauth_broker.py).

The server binds a *stable* loopback port derived deterministically from the app
name (with SO_REUSEADDR + a small fallback scan), so the webview origin -- and
therefore its localStorage partition -- is the same on every launch. WebKitGTK
persists localStorage per-origin to disk (`http_127.0.0.1_<port>.localstorage`),
so a stable origin makes login (and all other client state) survive a restart
without any token re-injection. A document-start bootstrap only flags desktop
mode + the broker prefix for the SPA."""
def _generate_host_source(
    libpy: str,
    title: str,
    width: int,
    height: int,
    app_name: str,
    plugin_configs: dict = {}
) -> str {
    # Embedded-CPython loopback server (shared with the CEF target). Binds the
    # stable per-app origin port, then splices in the plugin bootstrap so
    # _host/_dispatch_fn are available to the webview bind. The native target
    # serves single-threaded (no SSE push route); CEF passes threaded=True.
    serve_py = _loopback_serve_py(
        app_name, plugin_bootstrap=_plugin_bootstrap_py(plugin_configs), threaded=False
    );
    # --- JS SDK: window.__jac.invoke() + window.__jac.on() ---
    # Backward-compatible superset; also sets __JAC_DESKTOP__/__JAC_BROKER__.
    # Shared with the CEF target (desktop_build.jac).
    js_sdk = _jac_sdk_js();
    # --- Generated host source ---
    # The plugin bridge is extracted from plugin_bridge.na.jac between
    # BRIDGE START / BRIDGE END markers — that file is the single source.
    webview_dir = _find_webview_dir();
    bridge_src = _read_between(
        webview_dir.parent / "plugin_bridge.na.jac",
        "# --- BRIDGE START ---",
        "# --- BRIDGE END ---"
    );
    return (
        '"""Generated native desktop host - do not edit (jac-desktop)."""\n'
        "import from webview { def webview_create(debug: i32, window: int) -> int; }\n"
        "import from webview { Webview, respond, HINT_NONE, LAST_WEBVIEW_HANDLE, run_main_loop }\n"
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
        "    def PyGILState_Ensure() -> int;\n"
        "    def PyGILState_Release(state: int) -> None;\n"
        "    def PyObject_CallOneArg(fn: int, arg: int) -> int;\n"
        "    def PyUnicode_FromString(s: str) -> int;\n"
        "    def PyUnicode_AsUTF8(pyobj: int) -> str;\n"
        "    def Py_DecRef(pyobj: int) -> None;\n"
        "}\n"
        "glob PY_EVAL: i32 = 258;\n"
        f"glob SERVE_PY: str = {json.dumps(serve_py, ensure_ascii=False)};\n"
        f"glob BOOTSTRAP_JS: str = {json.dumps(
            js_sdk, ensure_ascii=False
        )};\n" + bridge_src + "with entry {\n"
        "    Py_Initialize();\n"
        "    PyRun_SimpleString(SERVE_PY);\n"
        "    main_mod = PyImport_AddModule(\"__main__\");\n"
        "    d = PyModule_GetDict(main_mod);\n"
        "    port = PyLong_AsLong(PyRun_String(\"_port\", PY_EVAL, d, d));\n"
        "    # Wire up plugin host dispatch pointer\n"
        "    _PH_DISPATCH = PyRun_String(\"_dispatch_fn\", PY_EVAL, d, d);\n"
        "    url = f\"http://127.0.0.1:{port}/\";\n"
        "    _wv_raw = webview_create(0, 0);\n"
        "    LAST_WEBVIEW_HANDLE = _wv_raw;\n"
        "    wv = Webview(handle=_wv_raw);\n"
        f"    wv.title({json.dumps(title, ensure_ascii=False)});\n"
        f"    wv.size({width}, {height}, HINT_NONE);\n"
        "    # Register the plugin IPC callback in the webview\n"
        "    wv.bind(\"__jac_invoke\", _jac_invoke_handler);\n"
        "    # Wire the live webview handle into CPython so plugins (e.g. WindowPlugin)\n"
        "    # can call back into libwebview. Must happen *after* webview creation but\n"
        "    # *before* run_main_loop().\n"
        "    _stash_wv_in_python(LAST_WEBVIEW_HANDLE);\n"
        "    wv.on_load(BOOTSTRAP_JS);\n"
        "    wv.navigate(url);\n"
        "    ts = PyEval_SaveThread();\n"
        "    run_main_loop();\n"
        "    PyEval_RestoreThread(ts);\n"
        "    Py_Finalize();\n"
        "}\n"
    );
}

impl NativeDesktopTarget.setup(project_dir: Path) -> None { }

impl NativeDesktopTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    import from jaclang.runtimelib.client.desktop_config { get_desktop_config }

    # 1. Build the cl bundle with the standard Vite pipeline (WebTarget).
    console.print("\n🖥️  Building desktop app (Jac-native webview)", style="bold");
    web_bundle = super.build(entry_file, project_dir, platform);
    dist_dir = web_bundle.parent;  # .jac/client/dist

    # 2. Desktop window config from [plugins.desktop].
    cfg = get_desktop_config(project_dir);
    # Fail the build on a bad config (geometry, unknown plugin/option keys)
    # instead of silently shipping a misconfigured app.
    cfg.validate();
    ident = cfg.get_identity();
    win = cfg.get_window_config();
    plugin_configs = cfg.get_plugin_configs();
    app_name = ident.name or "app";

    # 3. Prepare a clean output dir beside the dist.
    out_dir = project_dir / self.output_dir;
    if out_dir.exists() {
        shutil.rmtree(out_dir);
    }
    out_dir.mkdir(parents=True, exist_ok=True);

    # 4. Stage the served bundle + the native engine wrapper.
    shutil.copytree(dist_dir, out_dir / "dist");
    webview_dir = _find_webview_dir();
    lib = _ensure_libwebview(webview_dir);
    out_lib_name = libwebview_name();
    shutil.copy2(lib, out_dir / out_lib_name);
    shutil.copy2(webview_dir / "webview.na.jac", out_dir / "webview.na.jac");

    # 5. Transpile oauth_broker.jac -> .py beside the binary.
    _stage_oauth_broker(out_dir);

    # 6. Transpile all plugin .jac -> .py for the embedded CPython (shared with
    # the CEF target).
    _stage_plugins(out_dir);

    # 7. The plugin bridge is inlined into the generated host source
    # (nacompile does not support string-literal imports between .na.jac files).
    # The standalone plugin_bridge.na.jac is kept for documentation only.

    # 8. Generate + compile the native host into the output dir.
    libpy = str(sysconfig.get_config_var("INSTSONAME") or "libpython3.12.so.1.0");
    host_src = _generate_host_source(
        libpy,
        win.title or app_name,
        win.width,
        win.height,
        str(app_name),
        plugin_configs
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
    launcher = out_dir / f"{app_name}-launch.sh";
    launcher.write_text(
        "#!/bin/sh\n"
        "cd \"$(dirname \"$0\")\" || exit 1\n"
        "export GDK_BACKEND=\"${GDK_BACKEND:-x11}\"\n"
        "export WEBKIT_DISABLE_DMABUF_RENDERER=\"${WEBKIT_DISABLE_DMABUF_RENDERER:-1}\"\n"
        "export WEBKIT_DISABLE_COMPOSITING_MODE=\"${WEBKIT_DISABLE_COMPOSITING_MODE:-1}\"\n"
        f"exec ./{app_name} \"$@\"\n"
    );
    os.chmod(launcher, 0o755);
    console.print(f"\n✅ Desktop app built: {binary}", style="bold green");
    console.print(
        f"   run: (cd {out_dir} && ./{launcher.name})  # or jac start --client desktop",
        style="muted"
    );
    return binary;
}

impl NativeDesktopTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    binary = self.build(entry_file, project_dir, None);
    env = dict(os.environ);
    # WebKitGTK on WSL/headless-ish setups: prefer X11 + software paths.
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
    # MVP: build + run (no HMR yet). HMR dev (native window -> Vite dev server)
    # is a follow-up.
    console.print(
        "  desktop --dev: building and launching (HMR not yet wired)", style="muted"
    );
    self.start(entry_file, project_dir, api_port);
}
