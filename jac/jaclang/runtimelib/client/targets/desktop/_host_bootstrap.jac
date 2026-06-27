"""Pure-stdlib helpers that generate the CPython bootstrap source strings.

Separated from native_desktop_target so tests can import these functions
without pulling in jac_client (which the target interface requires for
WebTarget / TargetType).  No jac_client or jac_desktop dependencies here --
only os, json, and hashlib.
"""
import os;
import json;
import hashlib;


"""Runtime-only sys.path hook for the in-process `sv` (jac-scale) backend.

The fused runtime the host now boots (libjacpyembed -> the bundled CPython +
jaclang) is self-contained for `cl` serving and the plugin host. `sv` dispatch
additionally needs jac-scale; until jac-scale is bundled into the fused runtime
(the immediate follow-up to this clean break), the host picks it up at RUNTIME
from two portable env seams -- nothing about the build machine is baked in:

  * JAC_DESKTOP_SCALE_SRC -- an editable jac-scale checkout (dev), prepended so
    it wins over any pip copy;
  * JAC_DESKTOP_DEPS -- os.pathsep-separated dirs holding jac-scale's third-party
    deps (fastapi, starlette, ...), appended.

Absent both, the block is inert and `sv` dispatch surfaces a clean boot error
(the documented "jac-scale not yet in the fused runtime" state) rather than a
hang. This deliberately replaces the old build-time `_builder_dep_site_dirs`
baking, which pinned non-portable builder paths into every binary."""
def _scale_runtime_hook_py -> str {
    return (
        "_scale = os.environ.get('JAC_DESKTOP_SCALE_SRC')\n"
        "if _scale and _scale not in sys.path:\n"
        "    sys.path.insert(0, _scale)\n"
        "_extra = os.environ.get('JAC_DESKTOP_DEPS', '')\n"
        "if _extra:\n"
        "    for _d in _extra.split(os.pathsep):\n"
        "        if _d and _d not in sys.path:\n"
        "            sys.path.append(_d)\n"
    );
}


"""The `import from jacpyembed` clib block, shared by the native + CEF host gens.

Imported by LOGICAL name so the native backend resolves the platform file
(libjacpyembed.so/.dylib/.dll) AND emits a $ORIGIN runpath -- the host finds the
sibling shim with no patchelf, the same way it binds webview. jac_engine_boot()
materializes the trailer payload, dlopens THIS binary's bundled CPython, and
Py_Initialize()s it; the rest are `jpy_`-prefixed forwarders onto that interpreter
(the prefix keeps the shim's exports from interposing libpython's own symbols
under Linux's flat namespace -- see launcher/pyembed.zig). No build-machine
libpython, no INSTSONAME, no LD_LIBRARY_PATH. The CEF host uses only a subset of
the calls; the extra declarations are harmless unused externs on the same shim."""
def _jacpyembed_import_block -> str {
    return (
        "import from jacpyembed {\n"
        "    def jac_engine_boot() -> i32;\n"
        "    def jpy_Py_Finalize() -> None;\n"
        "    def jpy_PyRun_SimpleString(cmd: str) -> i32;\n"
        "    def jpy_PyImport_AddModule(name: str) -> int;\n"
        "    def jpy_PyModule_GetDict(module: int) -> int;\n"
        "    def jpy_PyRun_String(s: str, start: i32, g: int, l: int) -> int;\n"
        "    def jpy_PyLong_AsLong(o: int) -> int;\n"
        "    def jpy_PyEval_SaveThread() -> int;\n"
        "    def jpy_PyEval_RestoreThread(s: int) -> None;\n"
        "    def jpy_PyGILState_Ensure() -> int;\n"
        "    def jpy_PyGILState_Release(state: int) -> None;\n"
        "    def jpy_PyObject_CallOneArg(fn: int, arg: int) -> int;\n"
        "    def jpy_PyUnicode_FromString(s: str) -> int;\n"
        "    def jpy_PyUnicode_AsUTF8(pyobj: int) -> str;\n"
        "    def jpy_Py_DecRef(pyobj: int) -> None;\n"
        "}\n"
    );
}


"""Generate the embedded CPython plugin bootstrap for the native desktop host.

Imports the desktop plugin modules straight from the fused runtime's jaclang
tree -- no transpiled .py staged beside the binary. Puts the plugin dir on
sys.path so the modules' bare cross-imports (`import from manifest`, `built_in.*`)
resolve and the jac meta-importer compiles them (precompiled to JIR in the
payload), then calls registry.bootstrap_plugins(...). `import registry` cascades
to every built_in.* plugin via its module-scope imports, so explicit per-plugin
loading + the synthetic `built_in` package the old staged path needed are gone.

Mirrors `_plugin_bootstrap_py` in desktop_build.jac; kept separate so this
module stays free of jac_desktop imports (testable in isolation)."""
def _make_plugin_bootstrap_py(plugin_configs: dict) -> str {
    py = (
        "import jaclang, os, sys\n"
        "_pdir = os.path.join(os.path.dirname(jaclang.__file__),\n"
        "    'runtimelib', 'client', 'targets', 'desktop', 'plugin')\n"
        "if _pdir not in sys.path:\n"
        "    sys.path.insert(0, _pdir)\n"
        "import manifest, desktop_plugin, webview_lib, plugin_host, registry\n"
    );
    py += f"_pc = {repr(plugin_configs)}\n";
    py += (
        "_host = registry.bootstrap_plugins(_pc, sys.modules)\n"
        "_dispatch_fn = _host.dispatch\n"
    );
    return py;
}


"""The CPython snippet that imports + boots `inprocess_dispatch` (Phase J4, #6596).

Single-sourced so both desktop hosts boot the in-process sv backend identically:
the webview host runs it as its own DISPATCH_PY (right after SERVE_PY), and the
CEF host splices it after its loopback server starts. The in-process backend boots
the jac-scale ASGI app over a Starlette TestClient (no socket, no remote server)
and replays the frozen {kind,name,node,fields,token} contract against it.

Built as: a fixed head (the entry-file constant) + the runtime jac-scale hook
(inert unless JAC_DESKTOP_SCALE_SRC / JAC_DESKTOP_DEPS are set -- see
_scale_runtime_hook_py) + a fixed tail that imports the staged inprocess_dispatch
module and boots it against a graph/persistence dir under the user data dir.

`_ENTRY_FILE` is resolved at RUNTIME relative to `_root` (the binary dir, set by
the caller from /proc/self/exe): the sv source tree is staged beside the binary
under `sv/` at build time, so the entry stays importable after the binary moves --
a baked-in absolute build-time path would point at nothing on the target machine.

COUPLING: this references `_root` and `_data` by bare name; the caller's serve
bootstrap must define both in the same `__main__` scope before this runs (the
webview SERVE_PY and CEF `_loopback_serve_py` both do). The per-call timeout,
bounded-queue depth, and debug flag from [plugins.desktop.dispatch] are baked in
here so the staged module needs no config access of its own at runtime (a bool
interpolates as Python `True`/`False`, valid in the PyRun'd source)."""
def _dispatch_boot_py(
    entry_rel: str = "",
    dispatch_timeout_s: float = 30.0,
    dispatch_max_queue: int = 128,
    dispatch_debug: bool = False
) -> str {
    return (
        "import sys, os\n"
        f"_ENTRY_REL = {json.dumps(entry_rel, ensure_ascii=False)}\n"
        "_ENTRY_FILE = os.path.join(_root, 'sv', _ENTRY_REL)\n"
    ) + _scale_runtime_hook_py() + (
        "from jaclang.runtimelib.client.targets.desktop.native import inprocess_dispatch\n"
        "inprocess_dispatch.boot(_ENTRY_FILE,\n"
        "    os.path.join(_data, '.jac', 'desktop', 'graph'),\n"
        f"    timeout_s={dispatch_timeout_s}, max_queue={dispatch_max_queue},\n"
        f"    debug={dispatch_debug})\n"
        # Bind a stable per-process alias for the hot dispatch callable. The per-call
        # jpy_PyRun_SimpleString then references only `_jac_dispatch` -- a name under this
        # codebase's control -- instead of `inprocess_dispatch.handle` (two coupled
        # string literals). A rename/move of the module or function now breaks loudly
        # at boot (DISPATCH_PY returns != 0 -> error page) rather than silently on
        # every invoke (rc != 0 with no traceback and a hung JS promise).
        "_jac_dispatch = inprocess_dispatch.handle\n"
    );
}


"""Generate the native host source: embed CPython, serve `dist/` (resolved next
to the binary via /proc/self/exe) on loopback through the OAuth/session broker,
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
    title: str,
    width: int,
    height: int,
    app_name: str,
    entry_rel: str = "",
    dispatch_timeout_s: float = 30.0,
    dispatch_max_queue: int = 128,
    dispatch_debug: bool = False,
    plugin_configs: dict = None
) -> str {
    # Deterministic per-app port in the dynamic/private range (49152-65215) so
    # the same app reuses the same origin across launches; computed at build
    # time so the host needs no hashing at runtime.
    pref_port = 49152 + (int(hashlib.sha1(app_name.encode()).hexdigest(), 16) % 16000);
    serve_py = (
        "import os\n"
        "_exe = os.path.realpath('/proc/self/exe')\n"
        "_root = os.path.dirname(_exe)\n"
        "_data = os.environ.get('JAC_DATA_PATH', _root)\n"
        "import socketserver, threading\n"
        "_dir = os.path.join(_root, 'dist')\n"
        "from jaclang.runtimelib.client.targets.desktop.native import oauth_broker as _broker\n"
        # Persist the session under the user data dir (JAC_DATA_PATH honored),
        # never inside the web-served dist/ tree.
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
    # Phase J4 (#6596): in-process sv walker/function dispatch. The boot snippet is
    # single-sourced in _dispatch_boot_py (shared with the CEF host); _on_invoke
    # (below) routes window.__jac_invoke calls to inprocess_dispatch.handle.
    #
    # COUPLING: DISPATCH_PY references `_root` and `_data` by bare name. Both are
    # defined in SERVE_PY (lines `_root = os.path.dirname(_exe)` and
    # `_data = os.environ.get('JAC_DATA_PATH', _root)`). jpy_PyRun_SimpleString runs
    # each string in the same `__main__` scope, so the names resolve -- but a
    # rename in SERVE_PY breaks boot silently at runtime (NameError swallowed as
    # boot_rc != 0). Keep these names in sync or hoist them to shared constants.
    dispatch_py = _dispatch_boot_py(
        entry_rel, dispatch_timeout_s, dispatch_max_queue, dispatch_debug
    );
    _pc = plugin_configs if plugin_configs is not None else {};
    plugin_py = _make_plugin_bootstrap_py(_pc);
    # Runs at document-start (before the SPA's own scripts) on every full load.
    # Just flags desktop mode + the broker prefix so the SPA can detect the shell
    # and drive /__jac/oauth/*. Token persistence is handled by the stable origin
    # (localStorage survives restarts), not by re-injection.
    bootstrap_js = (
        "(function(){try{"
        "window.__JAC_DESKTOP__=true;window.__JAC_BROKER__='/__jac';"
        "window.__JAC_NATIVE__=true;"
        "}catch(e){}})();"
    );
    # P1-B: deterministic native error page shown (via wv.html) when the
    # in-process backend fails to boot -- i.e. jpy_PyRun_SimpleString(DISPATCH_PY)
    # returns != 0 -- instead of navigating to a silently-broken app whose first
    # __jac_invoke would hang forever. The full traceback is on stderr/the log
    # (boot() writes it and jpy_PyRun_SimpleString prints the unhandled exception).
    boot_error_html = (
        "<!doctype html><html><head><meta charset=\"utf-8\">"
        "<title>Backend failed to start</title><style>"
        "body{font-family:system-ui,-apple-system,Segoe UI,sans-serif;margin:0;"
        "display:flex;align-items:center;justify-content:center;height:100vh;"
        "background:#0b0f17;color:#e6edf3}"
        ".card{max-width:34rem;padding:2rem;text-align:center}"
        "h1{font-size:1.3rem;margin:0 0 .75rem}"
        "p{color:#8b949e;line-height:1.55;margin:.5rem 0}"
        "code{color:#d29922;font-family:ui-monospace,monospace}"
        "</style></head><body><div class=\"card\">"
        "<h1>⚠️ The app backend failed to start</h1>"
        "<p>The in-process server could not be initialized, so the app cannot "
        "run. The full error was written to the terminal / log output.</p>"
        "<p>Resolve the reported issue and restart the app.</p>"
        "</div></body></html>"
    );
    return (
        '"""Generated native desktop host - do not edit (jac-desktop)."""\n'
        "import from webview { def webview_create(debug: i32, window: int) -> int; }\n"
        "import from webview { Webview, respond, HINT_NONE, LAST_WEBVIEW_HANDLE, run_main_loop }\n" + _jacpyembed_import_block() + "glob PY_EVAL: i32 = 258;\n"
        f"glob SERVE_PY: str = {json.dumps(serve_py, ensure_ascii=False)};\n"
        f"glob PLUGIN_PY: str = {json.dumps(plugin_py, ensure_ascii=False)};\n"
        f"glob DISPATCH_PY: str = {json.dumps(dispatch_py, ensure_ascii=False)};\n"
        f"glob BOOTSTRAP_JS: str = {json.dumps(bootstrap_js, ensure_ascii=False)};\n"
        f"glob BOOT_ERROR_HTML: str = {json.dumps(
            boot_error_html, ensure_ascii=False
        )};\n"
        # Plugin bridge inlined from plugin_bridge.na.jac (BRIDGE START/END).
        # Wires window.__jac_invoke → the Python plugin host via jpy_PyObject_CallOneArg
        # (_PH_DISPATCH is set by registry.bootstrap_plugins via _host.setup()).
        "glob _PH_DISPATCH: int = 0;\n"
        "def _jac_invoke_handler(id: int, req: int, wv_handle: int) {\n"
        "    gstate = jpy_PyGILState_Ensure();\n"
        "    py_req = jpy_PyUnicode_FromString(req as str);\n"
        "    py_result = jpy_PyObject_CallOneArg(_PH_DISPATCH, py_req);\n"
        "    if py_result == 0 {\n"
        "        jpy_Py_DecRef(py_req);\n"
        "        jpy_PyGILState_Release(gstate);\n"
        "        respond(\n"
        "            wv_handle, id, \"{\\\"ok\\\":false,\\\"error\\\":{\\\"code\\\":\\\"DISPATCH_CRASHED\\\"}}\"\n"
        "        );\n"
        "        return;\n"
        "    }\n"
        "    result_str = jpy_PyUnicode_AsUTF8(py_result);\n"
        "    jpy_Py_DecRef(py_req);\n"
        "    respond(wv_handle, id, result_str);\n"
        "    jpy_Py_DecRef(py_result);\n"
        "    jpy_PyGILState_Release(gstate);\n"
        "}\n"
        # nacompile cannot lower wv.get_handle() inside an f-string;
        # passing the int through a native helper works.
        "def _stash_wv_in_python(h: int) {\n"
        "    jpy_PyRun_SimpleString(f\"_wv_handle = {h}\");\n"
        "    jpy_PyRun_SimpleString(\"_host.setup(_wv_handle)\");\n"
        "}\n"
        "with entry {\n"
        "    engine_rc: i32 = jac_engine_boot();\n"
        "    serve_rc: i32 = -1;\n"
        "    plugin_rc: i32 = -1;\n"
        "    boot_rc: i32 = -1;\n"
        "    main_mod: int = 0;\n"
        "    d: int = 0;\n"
        "    if engine_rc == 0 {\n"
        "        serve_rc = jpy_PyRun_SimpleString(SERVE_PY);\n"
        "        plugin_rc = jpy_PyRun_SimpleString(PLUGIN_PY);\n"
        # P1-B: capture the boot return code. Non-zero means the in-process
        # backend raised during boot (import/syntax/boot() failure) -- show the
        # native error page below instead of navigating to a broken app.
        "        boot_rc = jpy_PyRun_SimpleString(DISPATCH_PY);\n"
        "        main_mod = jpy_PyImport_AddModule(\"__main__\");\n"
        "        d = jpy_PyModule_GetDict(main_mod);\n"
        "    }\n"
        # Guard port extraction: when serve_rc != 0, `_port` is undefined in __main__
        # so jpy_PyRun_String returns NULL (0). jpy_PyLong_AsLong(0) sets a CPython error that
        # survives into jpy_PyRun_SimpleString("...shutdown()"), causing it to return -1
        # without executing shutdown. Only evaluate _port when SERVE_PY succeeded.
        "    url = \"\";\n"
        "    if engine_rc == 0 and serve_rc == 0 {\n"
        "        port = jpy_PyLong_AsLong(jpy_PyRun_String(\"_port\", PY_EVAL, d, d));\n"
        "        url = f\"http://127.0.0.1:{port}/\";\n"
        "    }\n"
        "    _wv_raw = webview_create(0, 0);\n"
        "    LAST_WEBVIEW_HANDLE = _wv_raw;\n"
        "    wv = Webview(handle=_wv_raw);\n"
        f"    wv.title({json.dumps(title, ensure_ascii=False)});\n"
        f"    wv.size({width}, {height}, HINT_NONE);\n"
        "    wv.on_load(BOOTSTRAP_JS);\n"
        "    wv.bind(\"__jac_invoke\", _jac_invoke_handler);\n"
        "    healthy: bool = engine_rc == 0 and serve_rc == 0 and plugin_rc == 0 and boot_rc == 0;\n"
        "    if healthy {\n"
        "        _stash_wv_in_python(_wv_raw);\n"
        "        wv.navigate(url);\n"
        "    } else {\n"
        "        wv.html(BOOT_ERROR_HTML);\n"
        "    }\n"
        "    if engine_rc == 0 {\n"
        "        ts = jpy_PyEval_SaveThread();\n"
        "        run_main_loop();\n"
        "        jpy_PyEval_RestoreThread(ts);\n"
        # GIL must be held for shutdown (drain queue, join worker, close transport).
        "        jpy_PyRun_SimpleString(\"from jaclang.runtimelib.client.targets.desktop.native import inprocess_dispatch; inprocess_dispatch.shutdown()\");\n"
        "        jpy_Py_Finalize();\n"
        "    } else {\n"
        "        run_main_loop();\n"
        "    }\n"
        "}\n"
    );
}
