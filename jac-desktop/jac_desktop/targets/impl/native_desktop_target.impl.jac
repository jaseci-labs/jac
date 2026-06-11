"""Implementation of the Jac-native desktop target."""
import os;
import shutil;
import json;
import hashlib;
import subprocess;
import sysconfig;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }
import from jac_desktop.plugin.webview_lib { libwebview_name }

"""Locate the shipped native/webview assets (binding + build tooling).

native/webview lives inside this package, two dirs up from this targets module
(jac_desktop/targets/ -> jac_desktop/native/webview). Verified by the presence
of webview.na.jac; walks up as a fallback for unusual layouts.
"""
def _find_webview_dir -> Path {
    here = Path(os.path.abspath(__file__)).parent;
    candidates = [here.parent / "native" / "webview", here / "native" / "webview"];
    p = here;
    for _ in range(6) {
        candidates.append(p / "native" / "webview");
        p = p.parent;
    }
    for cand in candidates {
        if (cand / "webview.na.jac").exists() {
            return cand;
        }
    }
    raise RuntimeError("jac-desktop: native/webview assets not found in the package.");
}

"""Resolve the jac CLI for nacompile (we're running under it)."""
def _jac_bin -> str {
    found = shutil.which("jac");
    if found {
        return found;
    }
    cand = Path(os.path.dirname(os.sys.executable)) / "jac";
    if cand.exists() {
        return str(cand);
    }
    raise RuntimeError("jac CLI not found on PATH.");
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
    # Deterministic per-app port in the dynamic/private range (49152-65215) so
    # the same app reuses the same origin across launches; computed at build
    # time so the host needs no hashing at runtime.
    pref_port = 49152 + (int(hashlib.sha1(app_name.encode()).hexdigest(), 16) % 16000);
    serve_py = (
        "import os, sys, socketserver, threading, importlib.util\n"
        "if os.path.isfile('/proc/self/exe'):\n"
        "    _exe = os.path.realpath('/proc/self/exe')\n"
        "else:\n"
        "    _exe = os.path.abspath(sys.argv[0])\n"
        "_root = os.path.dirname(_exe)\n"
        "_dir = os.path.join(_root, 'dist')\n"
        "_spec = importlib.util.spec_from_file_location("
        "'oauth_broker', os.path.join(_root, 'oauth_broker.py'))\n"
        "_broker = importlib.util.module_from_spec(_spec)\n"
        "_spec.loader.exec_module(_broker)\n"
        # Persist the session under the user data dir (JAC_DATA_PATH honored),
        # never inside the web-served dist/ tree.
        "_data = os.environ.get('JAC_DATA_PATH', _root)\n"
        "_store = _broker.SessionStore("
        "os.path.join(_data, '.jac', 'desktop', 'session.json'))\n"
        "_H = _broker.make_handler(_dir, _store)\n"
        # Stable origin: rebind the same deterministic port each launch
        # (SO_REUSEADDR clears TIME_WAIT); fall back through a small scan, then
        # to an ephemeral port only if the whole range is contended.
        "socketserver.TCPServer.allow_reuse_address = True\n"
        f"_pref = {pref_port}\n"
        "_srv = None; _port = None\n"
        "for _i in range(64):\n"
        "    try:\n"
        "        _srv = socketserver.TCPServer(('127.0.0.1', _pref + _i), _H)\n"
        "        _port = _pref + _i; break\n"
        "    except OSError:\n"
        "        continue\n"
        "if _srv is None:\n"
        "    _srv = socketserver.TCPServer(('127.0.0.1', 0), _H)\n"
        "    _port = _srv.server_address[1]\n"
        "threading.Thread(target=_srv.serve_forever, daemon=True).start()\n"
        "print('JAC_DESKTOP_SERVING http://127.0.0.1:' + str(_port) + '/', flush=True)\n"
    );
    # --- Plugin IPC bootstrap (embedded CPython) ---
    # Import plugin modules, register enabled plugins, expose dispatch.
    # Plugin configs are baked at build time as Python literals.
    _plugin_mods = [
        "desktop_plugin",
        "plugin_host",
        "built_in.path_plugin",
        "built_in.window_plugin",
        "built_in.fs_plugin",
        "built_in.notification_plugin",
        "built_in.clipboard_plugin",
        "built_in.dialog_plugin",
        "built_in.shell_plugin"
    ];
    plugin_py = "import sys, importlib.util\n";
    for _mod in _plugin_mods {
        _mod_path = _mod.replace(".", "/");
        plugin_py += (
            f"_spec = importlib.util.spec_from_file_location(\n"
            f"    '{_mod}', '{_mod_path}.py')\n"
            f"_m = importlib.util.module_from_spec(_spec)\n"
            f"_spec.loader.exec_module(_m)\n"
            f"sys.modules['{_mod}'] = _m\n"
        );
    }
    # Build plugin host + register enabled plugins
    _pc = plugin_configs;  # baked at build time
    plugin_py += (
        "_DP = sys.modules['desktop_plugin']\n"
        "_PH = sys.modules['plugin_host']\n"
        "_host = _PH.PluginHost()\n"
        "_path = sys.modules['built_in.path_plugin'].PathPlugin()\n"
    );
    # Register plugins based on config (baked literals)
    plugin_py += f"_pc = {repr(_pc)}\n";
    plugin_py += (
        "if _pc.get('path', False):\n" "    _host.register('jac.path', _path)\n"
    );
    plugin_py += (
        "if _pc.get('window', False):\n"
        "    _wp = sys.modules['built_in.window_plugin'].WindowPlugin(0, None)\n"
        "    _host.register('jac.window', _wp)\n"
    );
    plugin_py += (
        "if _pc.get('fs', False):\n"
        "    _fs_cfg = _pc['fs'] if isinstance(_pc['fs'], dict) else True\n"
        "    _fp = sys.modules['built_in.fs_plugin'].FsPlugin(_fs_cfg, _path)\n"
        "    _host.register('jac.fs', _fp)\n"
    );
    plugin_py += (
        "if _pc.get('notification', False):\n"
        "    _np = sys.modules['built_in.notification_plugin'].NotificationPlugin(_pc['notification'])\n"
        "    _host.register('jac.notification', _np)\n"
    );
    plugin_py += (
        "if _pc.get('clipboard', False):\n"
        "    _cb_cfg = _pc['clipboard'] if isinstance(_pc['clipboard'], dict) else True\n"
        "    _cp = sys.modules['built_in.clipboard_plugin'].ClipboardPlugin(_cb_cfg)\n"
        "    _host.register('jac.clipboard', _cp)\n"
    );
    plugin_py += (
        "if _pc.get('dialog', False):\n"
        "    _dp = sys.modules['built_in.dialog_plugin'].DialogPlugin(_pc['dialog'])\n"
        "    _host.register('jac.dialog', _dp)\n"
    );
    plugin_py += (
        "if _pc.get('shell', False):\n"
        "    _sh_cfg = _pc['shell'] if isinstance(_pc['shell'], dict) else True\n"
        "    _sp = sys.modules['built_in.shell_plugin'].ShellPlugin(_sh_cfg)\n"
        "    _host.register('jac.shell', _sp)\n"
    );
    plugin_py += (
        "# Expose dispatch callable and plugin host for the native shim\n"
        "_dispatch_fn = _host.dispatch\n"
    );
    serve_py = serve_py + "\n" + plugin_py;
    # --- JS SDK: window.__jac.invoke() + window.__jac.on() ---
    # Replaces the existing bootstrap with a backward-compatible superset.
    # Sets __JAC_DESKTOP__ and __JAC_BROKER__ for backward compat.
    js_sdk = (
        "(function(){"
        "var _l={};"
        "window.__jac={"
        "invoke:function(p,c,a){"
        "return window.__jac_invoke(JSON.stringify({"
        "plugin:p,command:c,args:a||{}})"
        ").then(function(j){"
        "var r=JSON.parse(j);"
        "if(r.ok)return r.data;"
        "var e=new Error(r.error.message);"
        "e.code=r.error.code;throw e;"
        "});"
        "},"
        "on:function(ev,cb){"
        "(_l[ev]=_l[ev]||[]).push(cb);"
        "return function(){var a=_l[ev]||[];var i=a.indexOf(cb);"
        "if(i!==-1)a.splice(i,1);};"
        "},"
        "__emit__:function(ev,p){"
        "(_l[ev]||[]).forEach(function(h){try{h(p);}catch(_){}});"
        "}"
        "};"
        "window.__JAC_DESKTOP__=true;"
        "window.__JAC_BROKER__='/__jac';"
        "})();"
    );
    # --- Generated host source ---
    # The plugin bridge is inlined directly into the host (nacompile does not
    # support string-literal imports between .na.jac files). The ~20-line bridge
    # handles: inttoptr coercion, GIL management, CPython dispatch, webview_return.
    return (
        '"""Generated native desktop host - do not edit (jac-desktop)."""\n'
        "import from webview { Webview, new_webview, respond, HINT_NONE }\n"
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
        f"glob BOOTSTRAP_JS: str = {json.dumps(js_sdk, ensure_ascii=False)};\n"
        # --- Inlined plugin bridge (see native/plugin_bridge.na.jac for docs) ---
        "glob _PH_DISPATCH: int = 0;\n"
        "def _jac_invoke_handler(id: int, req: int, wv_handle: int) -> None {\n"
        "    req_str: str = req;\n"
        "    gstate = PyGILState_Ensure();\n"
        "    py_req = PyUnicode_FromString(req_str);\n"
        "    py_result = PyObject_CallOneArg(_PH_DISPATCH, py_req);\n"
        "    if py_result == 0 {\n"
        "        Py_DecRef(py_req);\n"
        "        PyGILState_Release(gstate);\n"
        '        respond(wv_handle, id, "{\\"ok\\":false,\\"error\\":{\\"code\\":\\"DISPATCH_CRASHED\\"}}");\n'
        "        return;\n"
        "    }\n"
        "    result_str = PyUnicode_AsUTF8(py_result);\n"
        "    Py_DecRef(py_req);\n"
        "    Py_DecRef(py_result);\n"
        "    PyGILState_Release(gstate);\n"
        "    respond(wv_handle, id, result_str);\n"
        "}\n"
        # --- End inlined plugin bridge ---
        "with entry {\n"
        "    Py_Initialize();\n"
        "    PyRun_SimpleString(SERVE_PY);\n"
        "    main_mod = PyImport_AddModule(\"__main__\");\n"
        "    d = PyModule_GetDict(main_mod);\n"
        "    port = PyLong_AsLong(PyRun_String(\"_port\", PY_EVAL, d, d));\n"
        "    # Wire up plugin host dispatch pointer\n"
        "    _PH_DISPATCH = PyRun_String(\"_dispatch_fn\", PY_EVAL, d, d);\n"
        "    url = f\"http://127.0.0.1:{port}/\";\n"
        "    wv = new_webview(False);\n"
        f"    wv.title({json.dumps(title, ensure_ascii=False)});\n"
        f"    wv.size({width}, {height}, HINT_NONE);\n"
        "    # Register the plugin IPC callback in the webview\n"
        "    wv.bind(\"__jac_invoke\", _jac_invoke_handler);\n"
        "    # Wire the live webview handle into CPython so plugins (e.g. WindowPlugin)\n"
        "    # can call back into libwebview. Must happen *after* webview creation but\n"
        "    # *before* wv.run().\n"
        "    PyRun_SimpleString(f\"_wv_handle = {wv.handle}\");\n"
        "    PyRun_SimpleString(\"_host.setup(_wv_handle)\");\n"
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

    # 1. Build the cl bundle with the standard Vite pipeline (WebTarget).
    console.print("\n🖥️  Building desktop app (Jac-native webview)", style="bold");
    web_bundle = super.build(entry_file, project_dir, platform);
    dist_dir = web_bundle.parent;  # .jac/client/dist

    # 2. Desktop window config from [plugins.desktop].
    cfg = get_desktop_config(project_dir);
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

    # 5. Transpile oauth_broker.jac -> .py (unchanged from before).
    broker_src = webview_dir.parent / "oauth_broker.jac";
    console.print(
        "  Transpiling oauth_broker.jac -> oauth_broker.py...", style="muted"
    );
    broker_res = subprocess.run(
        [_jac_bin(), "jac2py", str(broker_src)], capture_output=True, text=True
    );
    if broker_res.returncode != 0 {
        raise RuntimeError("oauth_broker transpile failed:\n" + broker_res.stderr);
    }
    (out_dir / "oauth_broker.py").write_text(broker_res.stdout);

    # 6. Transpile all plugin .jac -> .py for the embedded CPython.
    plugin_src_dir = webview_dir.parent.parent / "plugin";
    if plugin_src_dir.exists() {
        console.print("  Transpiling plugin IPC modules...", style="muted");
        for jac_file in plugin_src_dir.rglob("*.jac") {
            rel = jac_file.relative_to(plugin_src_dir);
            py_name = str(rel.with_suffix(".py"));
            console.print(f"    {rel} -> {py_name}", style="muted");
            res = subprocess.run(
                [_jac_bin(), "jac2py", str(jac_file)], capture_output=True, text=True
            );
            if res.returncode != 0 or not res.stdout.strip() {
                # jac2py can fail on some files (e.g. JoinedStr ValueError
                # from pyast_gen_pass — tracked in jaseci-labs/jaseci#6564).
                # Safe fallback: jac0.compile_jac() uses a simpler transpilation
                # path that handles these cases correctly. Once the upstream
                # JoinedStr bug is fixed, this fallback can be removed.
                import jaclang.jac0 as jac0;
                console.print(
                    f"    ⚠ jac2py failed for {rel}, trying jac0 fallback",
                    style="yellow"
                );
                try {
                    res_stdout = jac0.compile_jac(jac_file.read_text());
                    if not res_stdout or not res_stdout.strip() {
                        raise RuntimeError("jac0 produced empty output");
                    }
                } except Exception as e {
                    raise RuntimeError(
                        f"Plugin transpile failed: {rel} "
                        f"(both jac2py and jac0 failed)\n"
                        f"jac2py stderr: {res.stderr or '(empty)'}\n"
                        f"jac0 error: {e}"
                    );
                }
            } else {
                res_stdout = res.stdout;
            }
            target = out_dir / py_name;
            target.parent.mkdir(parents=True, exist_ok=True);
            target.write_text(res_stdout);
        }
    }

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
    console.print(f"\n✅ Desktop app built: {binary}", style="bold green");
    console.print(f"   run: (cd {out_dir} && ./{app_name})", style="muted");
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
