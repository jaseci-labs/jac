import os;
import json;
import hashlib;


def _extra_deps_hook_py -> str {
    return (
        "_extra = os.environ.get('JAC_DESKTOP_DEPS', '')\n"
        "if _extra:\n"
        "    for _d in _extra.split(os.pathsep):\n"
        "        if _d and _d not in sys.path:\n"
        "            sys.path.append(_d)\n"
    );
}


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
    ) + _extra_deps_hook_py() + (
        "from jaclang.runtimelib.client.targets.desktop.native import inprocess_dispatch\n"
        "inprocess_dispatch.boot(_ENTRY_FILE,\n"
        "    os.path.join(_data, '.jac', 'desktop', 'graph'),\n"
        f"    timeout_s={dispatch_timeout_s}, max_queue={dispatch_max_queue},\n"
        f"    debug={dispatch_debug})\n"
        "_jac_dispatch = inprocess_dispatch.handle\n"
    );
}


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
    pref_port = 49152 + (int(hashlib.sha1(app_name.encode()).hexdigest(), 16) % 16000);
    serve_py = (
        "import os\n"
        "_exe = os.path.realpath('/proc/self/exe')\n"
        "_root = os.path.dirname(_exe)\n"
        "_data = os.environ.get('JAC_DATA_PATH', _root)\n"
        "import socketserver, threading\n"
        "_dir = os.path.join(_root, 'dist')\n"
        "from jaclang.runtimelib.client.targets.desktop.native import oauth_broker as _broker\n"
        "_store = _broker.SessionStore("
        "os.path.join(_data, '.jac', 'desktop', 'session.json'))\n"
        "_H = _broker.make_handler(_dir, _store)\n"
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

    dispatch_py = _dispatch_boot_py(
        entry_rel, dispatch_timeout_s, dispatch_max_queue, dispatch_debug
    );
    _pc = plugin_configs if plugin_configs is not None else {};
    plugin_py = _make_plugin_bootstrap_py(_pc);

    bootstrap_js = (
        "(function(){try{"
        "window.__JAC_DESKTOP__=true;window.__JAC_BROKER__='/__jac';"
        "window.__JAC_NATIVE__=true;"
        "}catch(e){}})();"
    );

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
        "        boot_rc = jpy_PyRun_SimpleString(DISPATCH_PY);\n"
        "        main_mod = jpy_PyImport_AddModule(\"__main__\");\n"
        "        d = jpy_PyModule_GetDict(main_mod);\n"
        "    }\n"
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
        "        jpy_PyRun_SimpleString(\"from jaclang.runtimelib.client.targets.desktop.native import inprocess_dispatch; inprocess_dispatch.shutdown()\");\n"
        "        jpy_Py_Finalize();\n"
        "    } else {\n"
        "        run_main_loop();\n"
        "    }\n"
        "}\n"
    );
}
