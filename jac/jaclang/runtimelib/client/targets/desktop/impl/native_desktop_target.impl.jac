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
import from jaclang.runtimelib.client.targets.desktop.plugin.webview_lib {
    libwebview_name
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

"""Locate the shipped native/webview assets (binding + build tooling).

native/webview lives inside this package, one dir up from this targets module
(targets/desktop/ -> targets/desktop/native/webview). Verified by the presence
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
    raise RuntimeError(
        "desktop target: native/webview assets not found in the package."
    );
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
    # registry.jac (BUILTIN_PLUGINS + bootstrap_plugins) owns *which plugins to
    # register and how*. This list owns the *module load order* for the embedded
    # importlib bootstrap, which runs before registry is importable, so it can't
    # be derived from BUILTIN_PLUGINS — it must be hand-kept in sync: every
    # `built_in.*` plugin module here must match a BUILTIN_PLUGINS entry.
    # Order is load order. `registry` imports every `built_in.*` plugin at
    # module scope, so it MUST come last: in the embedded CPython `built_in`
    # is a bare ModuleType (not a real package), so `from built_in.x import Y`
    # only resolves once `built_in.x` is already in sys.modules. Loading
    # registry before the built_in modules raises ModuleNotFoundError and
    # crashes the whole plugin bootstrap (dispatch then never gets defined).
    _plugin_mods = [
        "manifest",
        "desktop_plugin",
        "webview_lib",
        "plugin_host",
        "built_in.path_plugin",
        "built_in.window_plugin",
        "built_in.fs_plugin",
        "built_in.notification_plugin",
        "built_in.clipboard_plugin",
        "built_in.dialog_plugin",
        "built_in.shell_plugin",
        "registry"
    ];
    # Build plugin bootstrap as string concat (not Jac f-strings with nested
    # quotes — those lower to broken Python like
    # spec_from_file_location('mod, mod.py') with a null loader).
    plugin_py = (
        "import sys, importlib.util, types\n"
        "if _root not in sys.path:\n"
        "    sys.path.insert(0, _root)\n"
        "if 'built_in' not in sys.modules:\n"
        "    sys.modules['built_in'] = types.ModuleType('built_in')\n"
    );
    for _mod in _plugin_mods {
        _py_rel = _mod.replace(".", "/") + ".py";
        plugin_py += (
            "_spec = importlib.util.spec_from_file_location(\n" + json.dumps(_mod) + ", os.path.join(_root, " + json.dumps(
                _py_rel
            ) + "))\n" "_m = importlib.util.module_from_spec(_spec)\n" "sys.modules[" + json.dumps(
                _mod
            ) + "] = _m\n" "_spec.loader.exec_module(_m)\n"
        );
        if _mod.startswith("built_in.") {
            _child = _mod.split(".", 1)[1];
            plugin_py += (
                "setattr(sys.modules['built_in'], " + json.dumps(_child) + ", _m)\n"
            );
        }
    }
    # Build plugin host using registry bootstrap_plugins().
    # This replaces seven hand-written registration blocks with a single call.
    _pc = plugin_configs;  # baked at build time
    plugin_py += f"_pc = {repr(_pc)}\n";
    plugin_py += (
        "_host = sys.modules['registry'].bootstrap_plugins(_pc, sys.modules)\n"
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
        "return window.__jac_invoke(p,c,a||{}).then(function(r){"
        "if(typeof r==='string')r=JSON.parse(r);"
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
            # rglob("*.jac") also matches directories named ".jac" (build cache).
            if not jac_file.is_file() {
                continue;
            }
            rel = jac_file.relative_to(plugin_src_dir);
            py_name = str(rel.with_suffix(".py"));
            console.print(f"    {rel} -> {py_name}", style="muted");
            # Embedded CPython has no jaclang — prefer jac0 (stdlib-only output).
            import jaclang.jac0 as jac0;
            res_stdout = "";
            try {
                res_stdout = jac0.compile_jac(jac_file.read_text());
                if not res_stdout or not res_stdout.strip() {
                    raise RuntimeError("jac0 produced empty output");
                }
            } except Exception as jac0_err {
                res = subprocess.run(
                    [_jac_bin(), "jac2py", str(jac_file)],
                    capture_output=True,
                    text=True
                );
                if res.returncode != 0 or not res.stdout.strip() {
                    raise RuntimeError(
                        f"Plugin transpile failed: {rel} "
                        f"(jac0 and jac2py failed)\n"
                        f"jac0 error: {jac0_err}\n"
                        f"jac2py stderr: {res.stderr or '(empty)'}"
                    );
                }
                console.print(
                    f"    ⚠ jac0 failed for {rel}, using jac2py fallback",
                    style="yellow"
                );
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
