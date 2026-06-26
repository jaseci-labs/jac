"""Pure-stdlib helpers that generate the CPython bootstrap source strings.

Separated from native_desktop_target so tests can import these functions
without pulling in jac_client (which the target interface requires for
WebTarget / TargetType).  No jac_client or jac_desktop dependencies here --
only os, json, hashlib, site, and sysconfig.
"""
import os;
import json;
import hashlib;
import site;
import sysconfig;


"""Site-package dirs from the interpreter running `jac build` (dev-only).

The desktop binary embeds a stock CPython whose own site-packages are usually
empty. jac-scale runtime deps (fastapi, starlette, ...) live in the *builder*
interpreter (uv tool install, venv, etc.). Those paths are baked into the dev
pin at build time so the embedded boot can import them without user-site hacks."""
def _builder_dep_site_dirs -> list[str] {
    dirs: list[str] = [];
    usp = site.getusersitepackages();
    if usp {
        dirs.append(usp);
    }
    plib = sysconfig.get_path("purelib");
    if plib and plib not in dirs {
        dirs.append(plib);
    }
    return dirs;
}


"""The dev-only runtime pin for this repo's multi-worktree box, or "" otherwise.

A normal/release build emits NOTHING here: the staged host uses the embedded
interpreter's own jaclang/jac-scale untouched, so no dev scaffolding ships in the
binary. Only when the BUILD environment carries JAC_DESKTOP_JAC_SRC / JAC_DESKTOP_SCALE_SRC
(i.e. a developer building on the worktree box) is the pin emitted -- and even
then it is read again at RUNTIME, so the one binary stays portable across
worktrees. The emitted block prepends the pinned tree, drops stale editable
finders, and evicts any pre-imported copy so the pin wins; absent the runtime
vars it self-disables.

Third-party jac-scale runtime deps (fastapi, starlette, ...) are appended from
(1) the builder interpreter's site dirs, baked in at `jac build` time,
(2) the embedded interpreter's user-site / site-packages, and
(3) optional runtime `JAC_DESKTOP_DEPS` (os.pathsep-separated). All are appended
(not prepended) so the pinned editable jac_scale tree keeps winning over the
pip-installed copy that also lives in site-packages. Release builds must not
depend on ambient site state, so this lives inside the dev-only branch."""
def _dev_runtime_pin_py -> str {
    if not (
        os.environ.get("JAC_DESKTOP_JAC_SRC") or os.environ.get("JAC_DESKTOP_SCALE_SRC")
    ) {
        return "";
    }
    baked_deps = json.dumps(_builder_dep_site_dirs(), ensure_ascii=False);
    return (
        f"_baked_dep_sites = {baked_deps}\n"
        "_dev = [p for p in (os.environ.get('JAC_DESKTOP_SCALE_SRC'),\n"
        "                    os.environ.get('JAC_DESKTOP_JAC_SRC')) if p]\n"
        "if _dev:\n"
        "    for _r in _dev:\n"
        "        if _r not in sys.path:\n"
        "            sys.path.insert(0, _r)\n"
        # Drop only the stale editable finder; keep JacMetaImporter so the pinned
        # .jac trees (jac_scale.inprocess, etc.) remain importable.
        "    sys.meta_path[:] = [f for f in sys.meta_path\n"
        "        if type(f).__name__ != '_EditableFinder']\n"
        "    for _k in [k for k in list(sys.modules)\n"
        "        if k.split('.')[0] in ('jaclang', 'jac_scale')]:\n"
        "        del sys.modules[_k]\n"
        # Append dep dirs for third-party packages. Prepending would let the pip
        # jac_scale copy shadow the pinned editable tree.
        "    import site\n"
        "    _dep_dirs = list(_baked_dep_sites)\n"
        "    _extra = os.environ.get('JAC_DESKTOP_DEPS', '')\n"
        "    if _extra:\n"
        "        for _d in _extra.split(os.pathsep):\n"
        "            if _d and _d not in _dep_dirs:\n"
        "                _dep_dirs.append(_d)\n"
        "    _usp = site.getusersitepackages()\n"
        "    if _usp and _usp not in _dep_dirs:\n"
        "        _dep_dirs.append(_usp)\n"
        "    _gs = getattr(site, 'getsitepackages', None)\n"
        "    if _gs:\n"
        "        for _sp in _gs():\n"
        "            if _sp and _sp not in _dep_dirs:\n"
        "                _dep_dirs.append(_sp)\n"
        "    for _d in _dep_dirs:\n"
        "        if _d not in sys.path:\n"
        "            sys.path.append(_d)\n"
    );
}


"""The CPython snippet that imports + boots `inprocess_dispatch` (Phase J4, #6596).

Single-sourced so both desktop hosts boot the in-process sv backend identically:
the webview host runs it as its own DISPATCH_PY (right after SERVE_PY), and the
CEF host splices it after its loopback server starts. The in-process backend boots
the jac-scale ASGI app over a Starlette TestClient (no socket, no remote server)
and replays the frozen {kind,name,node,fields,token} contract against it.

Built as: a fixed head (the entry-file constant) + the dev-only runtime pin (empty
in release builds; includes sys.path fixup + user-site for dev installs -- see
_dev_runtime_pin_py) + a fixed tail that imports the staged inprocess_dispatch
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
    ) + _dev_runtime_pin_py() + (
        "if _root not in sys.path:\n"
        "    sys.path.insert(0, _root)\n"
        # inprocess_dispatch is a pre-transpiled .py file staged beside the binary;
        # importing it needs no JacMetaImporter. boot()/_boot_impl() re-register the
        # importer and evict any pip-resident jac_scale before loading the pinned tree.
        "import inprocess_dispatch\n"
        "inprocess_dispatch.boot(_ENTRY_FILE,\n"
        "    os.path.join(_data, '.jac', 'desktop', 'graph'),\n"
        f"    timeout_s={dispatch_timeout_s}, max_queue={dispatch_max_queue},\n"
        f"    debug={dispatch_debug})\n"
        # Bind a stable per-process alias for the hot dispatch callable. The per-call
        # PyRun_SimpleString then references only `_jac_dispatch` -- a name under this
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
    libpy: str,
    title: str,
    width: int,
    height: int,
    app_name: str,
    entry_rel: str = "",
    dispatch_timeout_s: float = 30.0,
    dispatch_max_queue: int = 128,
    dispatch_debug: bool = False
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
        "import socketserver, threading, importlib.util\n"
        "_dir = os.path.join(_root, 'dist')\n"
        "_spec = importlib.util.spec_from_file_location("
        "'oauth_broker', os.path.join(_root, 'oauth_broker.py'))\n"
        "_broker = importlib.util.module_from_spec(_spec)\n"
        "_spec.loader.exec_module(_broker)\n"
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
    # `_data = os.environ.get('JAC_DATA_PATH', _root)`). PyRun_SimpleString runs
    # each string in the same `__main__` scope, so the names resolve -- but a
    # rename in SERVE_PY breaks boot silently at runtime (NameError swallowed as
    # boot_rc != 0). Keep these names in sync or hoist them to shared constants.
    dispatch_py = _dispatch_boot_py(
        entry_rel, dispatch_timeout_s, dispatch_max_queue, dispatch_debug
    );
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
    # in-process backend fails to boot -- i.e. PyRun_SimpleString(DISPATCH_PY)
    # returns != 0 -- instead of navigating to a silently-broken app whose first
    # __jac_invoke would hang forever. The full traceback is on stderr/the log
    # (boot() writes it and PyRun_SimpleString prints the unhandled exception).
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
        "    def PyGILState_Ensure() -> int;\n"
        "    def PyGILState_Release(state: int) -> None;\n"
        "}\n"
        "glob PY_EVAL: i32 = 258;\n"
        f"glob SERVE_PY: str = {json.dumps(serve_py, ensure_ascii=False)};\n"
        f"glob DISPATCH_PY: str = {json.dumps(dispatch_py, ensure_ascii=False)};\n"
        f"glob BOOTSTRAP_JS: str = {json.dumps(bootstrap_js, ensure_ascii=False)};\n"
        f"glob BOOT_ERROR_HTML: str = {json.dumps(
            boot_error_html, ensure_ascii=False
        )};\n"
        # window.__jac_invoke handler. Fires on the UI thread, where the host has
        # released the GIL via PyEval_SaveThread() before wv.run(); reacquire it
        # around the Python call with PyGILState_Ensure/Release. id/req/arg are raw
        # C pointers carried as int; _jac_dispatch (= inprocess_dispatch.handle,
        # bound once in DISPATCH_PY at boot) decodes them.
        #
        # NOTE: each invoke still executes a fresh Python source string via
        # PyRun_SimpleString. The `_jac_dispatch` alias decouples the per-call string
        # from the module/function name: a rename now fails loudly at boot (rc != 0 ->
        # error page) rather than silently on every invoke.
        # TODO: replace PyRun_SimpleString per-invoke with PyObject_GetAttrString +
        # PyObject_Call (resolve the callable once at boot, call via pointer each time).
        # Blocked on NA gaining a PyObject * type binding.
        "def _on_invoke(id: int, req: int, arg: int) -> None {\n"
        "    g = PyGILState_Ensure();\n"
        "    # Layer B insurance: handle() has a last-resort try/except that replies\n"
        "    # with NATIVE_INVOKE_ERROR before returning, so rc != 0 should be rare\n"
        "    # (syntax/import failure, or a bug escaping the guard). Log if it happens.\n"
        "    rc = PyRun_SimpleString(f\"_jac_dispatch({id}, {req}, {arg})\");\n"
        "    if rc != 0 {\n"
        "        PyRun_SimpleString(\n"
        "            f\"import sys; sys.stderr.write('inprocess_dispatch: invoke rc={rc}\\n')\"\n"
        "        );\n"
        "    }\n"
        "    PyGILState_Release(g);\n"
        "}\n"
        "with entry {\n"
        "    Py_Initialize();\n"
        "    serve_rc = PyRun_SimpleString(SERVE_PY);\n"
        # P1-B: capture the boot return code. Non-zero means the in-process
        # backend raised during boot (import/syntax/boot() failure) -- show the
        # native error page below instead of navigating to a broken app.
        "    boot_rc = PyRun_SimpleString(DISPATCH_PY);\n"
        "    main_mod = PyImport_AddModule(\"__main__\");\n"
        "    d = PyModule_GetDict(main_mod);\n"
        # Guard port extraction: when serve_rc != 0, `_port` is undefined in __main__
        # so PyRun_String returns NULL (0). PyLong_AsLong(0) sets a CPython error that
        # survives into PyRun_SimpleString("...shutdown()"), causing it to return -1
        # without executing shutdown. Only evaluate _port when SERVE_PY succeeded.
        "    url = \"\";\n"
        "    if serve_rc == 0 {\n"
        "        port = PyLong_AsLong(PyRun_String(\"_port\", PY_EVAL, d, d));\n"
        "        url = f\"http://127.0.0.1:{port}/\";\n"
        "    }\n"
        "    wv = new_webview(False);\n"
        f"    wv.title({json.dumps(title, ensure_ascii=False)});\n"
        f"    wv.size({width}, {height}, HINT_NONE);\n"
        "    wv.on_load(BOOTSTRAP_JS);\n"
        "    wv.bind(\"__jac_invoke\", _on_invoke);\n"
        "    if serve_rc == 0 and boot_rc == 0 {\n"
        "        wv.navigate(url);\n"
        "    } else {\n"
        "        wv.html(BOOT_ERROR_HTML);\n"
        "    }\n"
        "    ts = PyEval_SaveThread();\n"
        "    wv.run();\n"
        "    PyEval_RestoreThread(ts);\n"
        # GIL must be held for shutdown (drain queue, join worker, close transport).
        "    PyRun_SimpleString(\"import inprocess_dispatch; inprocess_dispatch.shutdown()\");\n"
        "    Py_Finalize();\n"
        "}\n"
    );
}
