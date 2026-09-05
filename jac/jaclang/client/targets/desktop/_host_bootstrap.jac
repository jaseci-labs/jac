import json;


def _fused_runtime_import_block -> str {
    return (
        "import from fused.bringup { engine_boot }\n"
        "import from fused.embed { Embed }\n"
        "import from fused._libc { c_string }\n"
    );
}


def _host_boot_py(
    app_name: str,
    mode: str,
    program: (dict | None) = None,
    backend: str = "embedded",
    dispatch_timeout_s: float = 30.0,
    dispatch_max_queue: int = 128,
    dispatch_debug: bool = False,
    plugin_configs: (dict | None) = None
) -> str {
    config = {
        "app_name": app_name,
        "mode": mode,
        "program": dict(program or {}),
        "backend": backend or "embedded",
        "dispatch": {
            "timeout_s": dispatch_timeout_s,
            "max_queue": dispatch_max_queue,
            "debug": dispatch_debug
        },
        "plugins": plugin_configs if plugin_configs is not None else {}
    };
    config_literal = json.dumps(
        json.dumps(config, ensure_ascii=False), ensure_ascii=False
    );
    return (
        "from jaclang.client.targets.desktop.native import host_boot\n"
        f"_ctx = host_boot.boot({config_literal})\n"
    );
}


def _generate_host_source(
    title: str,
    width: int,
    height: int,
    app_name: str,
    program: (dict | None) = None,
    backend: str = "embedded",
    dispatch_timeout_s: float = 30.0,
    dispatch_max_queue: int = 128,
    dispatch_debug: bool = False,
    plugin_configs: (dict | None) = None
) -> str {
    boot_py = _host_boot_py(
        app_name,
        "webview",
        program,
        backend,
        dispatch_timeout_s,
        dispatch_max_queue,
        dispatch_debug,
        plugin_configs
    );

    bootstrap_js = (
        "(function(){try{"
        "var _l={};"
        "window.__jac={"
        "invoke:function(p,c,a){"
        "return fetch('/__jac/invoke',{method:'POST',"
        "headers:{'Content-Type':'application/json'},"
        "body:JSON.stringify([p,c,a||{}])})"
        ".then(function(r){return r.text();})"
        ".then(function(r){"
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
        "import from webview { Webview, HINT_NONE, LAST_WEBVIEW_HANDLE, run_main_loop }\n"
        + _fused_runtime_import_block()
        + "glob PY_EVAL: i32 = 258;\n"
        f"glob BOOT_PY: str = {json.dumps(boot_py, ensure_ascii=False)};\n"
        f"glob BOOTSTRAP_JS: str = {json.dumps(bootstrap_js, ensure_ascii=False)};\n"
        f"glob BOOT_ERROR_HTML: str = {json.dumps(
            boot_error_html, ensure_ascii=False
        )};\n"
        "glob _ENGINE: Embed = Embed();\n"
        "def _stash_wv_in_python(h: int) {\n"
        "    _ENGINE.api.PyRun_SimpleString(f\"_ctx.setup_webview({h})\");\n"
        "}\n"
        "with entry {\n"
        "    _ENGINE = engine_boot();\n"
        "    api = _ENGINE.api;\n"
        "    boot_rc: i32 = api.PyRun_SimpleString(BOOT_PY);\n"
        "    main_mod: int = 0;\n"
        "    d: int = 0;\n"
        "    url = \"\";\n"
        "    if boot_rc == 0 {\n"
        "        main_mod = api.PyImport_AddModule(\"__main__\");\n"
        "        d = api.PyModule_GetDict(main_mod);\n"
        "        port = api.PyLong_AsLong(api.PyRun_String(\"_ctx.port\", PY_EVAL, d, d));\n"
        "        dev_port = api.PyLong_AsLong(api.PyRun_String(\"_ctx.dev_port\", PY_EVAL, d, d));\n"
        "        target_port = dev_port if dev_port > 0 else port;\n"
        "        url = f\"http://127.0.0.1:{target_port}/\";\n"
        "    }\n"
        "    _wv_raw = webview_create(0, 0);\n"
        "    LAST_WEBVIEW_HANDLE = _wv_raw;\n"
        "    wv = Webview(handle=_wv_raw);\n"
        f"    wv.title({json.dumps(title, ensure_ascii=False)});\n"
        f"    wv.size({width}, {height}, HINT_NONE);\n"
        "    wv.on_load(BOOTSTRAP_JS);\n"
        "    healthy: bool = boot_rc == 0;\n"
        "    if healthy {\n"
        "        _stash_wv_in_python(_wv_raw);\n"
        "        wv.navigate(url);\n"
        "    } else {\n"
        "        wv.html(BOOT_ERROR_HTML);\n"
        "    }\n"
        "    ts = api.PyEval_SaveThread();\n"
        "    run_main_loop();\n"
        "    api.PyEval_RestoreThread(ts);\n"
        "    if healthy {\n"
        "        api.PyRun_SimpleString(\"_ctx.shutdown()\");\n"
        "    }\n"
        "    api.Py_Finalize();\n"
        "}\n"
    );
}
