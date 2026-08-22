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
    entry_rel: str = "",
    dispatch_timeout_s: float = 30.0,
    dispatch_max_queue: int = 128,
    dispatch_debug: bool = False,
    plugin_configs: dict = None,
    http_config: dict = None
) -> str {
    config = {
        "app_name": app_name,
        "mode": mode,
        "entry_rel": entry_rel,
        "dispatch": {
            "timeout_s": dispatch_timeout_s,
            "max_queue": dispatch_max_queue,
            "debug": dispatch_debug
        },
        "plugins": plugin_configs if plugin_configs is not None else {},
        "http": http_config if http_config is not None else {}
    };
    config_literal = json.dumps(
        json.dumps(config, ensure_ascii=False), ensure_ascii=False
    );
    return (
        "from jaclang.runtimelib.client.targets.desktop.native import host_boot\n"
        f"_ctx = host_boot.boot({config_literal})\n"
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
    plugin_configs: dict = None,
    http_config: dict = None
) -> str {
    boot_py = _host_boot_py(
        app_name,
        "webview",
        entry_rel,
        dispatch_timeout_s,
        dispatch_max_queue,
        dispatch_debug,
        plugin_configs,
        http_config
    );

    bootstrap_js = (
        "(function(){var _l={},_streams={};"
        "function _pushStream(p){"
        "var s=_streams[p.stream_id]||(_streams[p.stream_id]={q:[],r:[]});"
        "if(s.r.length)s.r.shift()(p);else s.q.push(p);}"
        "function _ackStream(id,n){"
        "try{window.__jac_invoke(JSON.stringify({__jac_stream_ctl:'ack',stream_id:id,n:n}),0,{})"
        ".then(function(){},function(){});}catch(_){}}"
        "window.__jac={"
        "invoke:function(p,c,a){"
        "return window.__jac_invoke(p,c,a||{}).then(function(r){"
        "if(typeof r==='string')r=JSON.parse(r);"
        "if(r.ok)return r.data;"
        "var e=new Error((r.error&&r.error.message)||'invoke failed');"
        "e.code=r.error&&r.error.code;throw e;});},"
        "on:function(ev,cb){(_l[ev]=_l[ev]||[]).push(cb);"
        "return function(){var a=_l[ev]||[];var i=a.indexOf(cb);"
        "if(i!==-1)a.splice(i,1);};},"
        "__emit__:function(ev,p){"
        "if(ev==='__jac_stream'&&p&&p.stream_id)_pushStream(p);"
        "(_l[ev]||[]).forEach(function(h){try{h(p);}catch(_){}});},"
        "__stream_next__:function(id){"
        "var s=_streams[id]||(_streams[id]={q:[],r:[]});"
        "if(s.q.length){_ackStream(id,1);return Promise.resolve(s.q.shift());}"
        "return new Promise(function(res){s.r.push(function(p){_ackStream(id,1);res(p);});});}"
        "};"
        "window.__JAC_DESKTOP__=true;window.__JAC_BROKER__='/__jac';"
        "window.__JAC_NATIVE__=true;"
        "})();"
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
        "import from webview { Webview, respond, HINT_NONE, LAST_WEBVIEW_HANDLE, run_main_loop }\n"
        + _fused_runtime_import_block()
        + "glob PY_EVAL: i32 = 258;\n"
        f"glob BOOT_PY: str = {json.dumps(boot_py, ensure_ascii=False)};\n"
        f"glob BOOTSTRAP_JS: str = {json.dumps(bootstrap_js, ensure_ascii=False)};\n"
        f"glob BOOT_ERROR_HTML: str = {json.dumps(
            boot_error_html, ensure_ascii=False
        )};\n"
        "glob _PH_DISPATCH: int = 0;\n"
        "glob _ENGINE: Embed = Embed();\n"
        "def _jac_invoke_handler(id: int, req: int, wv_handle: int) {\n"
        "    api = _ENGINE.api;\n"
        "    gstate = api.PyGILState_Ensure();\n"
        "    py_req = api.PyUnicode_FromString(c_string(req));\n"
        "    py_result = api.PyObject_CallOneArg(_PH_DISPATCH, py_req);\n"
        "    if py_result == 0 {\n"
        "        api.Py_DecRef(py_req);\n"
        "        api.PyGILState_Release(gstate);\n"
        "        respond(\n"
        "            wv_handle, id, \"{\\\"ok\\\":false,\\\"error\\\":{\\\"code\\\":\\\"DISPATCH_CRASHED\\\"}}\"\n"
        "        );\n"
        "        return;\n"
        "    }\n"
        "    result_str = c_string(api.PyUnicode_AsUTF8(py_result));\n"
        "    api.Py_DecRef(py_req);\n"
        "    respond(wv_handle, id, result_str);\n"
        "    api.Py_DecRef(py_result);\n"
        "    api.PyGILState_Release(gstate);\n"
        "}\n"
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
        "    http_js = \"\";\n"
        "    if boot_rc == 0 {\n"
        "        main_mod = api.PyImport_AddModule(\"__main__\");\n"
        "        d = api.PyModule_GetDict(main_mod);\n"
        "        _PH_DISPATCH = api.PyRun_String(\"_ctx.dispatch\", PY_EVAL, d, d);\n"
        "        port = api.PyLong_AsLong(api.PyRun_String(\"_ctx.port\", PY_EVAL, d, d));\n"
        "        dev_port = api.PyLong_AsLong(api.PyRun_String(\"_ctx.dev_port\", PY_EVAL, d, d));\n"
        "        target_port = dev_port if dev_port > 0 else port;\n"
        "        url = f\"http://127.0.0.1:{target_port}/\";\n"
        "        http_js = c_string(api.PyUnicode_AsUTF8(api.PyRun_String(\"_ctx.http_bootstrap_js()\", PY_EVAL, d, d)));\n"
        "    }\n"
        "    _wv_raw = webview_create(0, 0);\n"
        "    LAST_WEBVIEW_HANDLE = _wv_raw;\n"
        "    wv = Webview(handle=_wv_raw);\n"
        f"    wv.title({json.dumps(title, ensure_ascii=False)});\n"
        f"    wv.size({width}, {height}, HINT_NONE);\n"
        "    wv.on_load(BOOTSTRAP_JS);\n"
        "    wv.bind(\"__jac_invoke\", _jac_invoke_handler);\n"
        "    healthy: bool = boot_rc == 0;\n"
        "    if healthy {\n"
        "        _stash_wv_in_python(_wv_raw);\n"
        "        if http_js != \"\" {\n"
        "            wv.on_load(http_js);\n"
        "        }\n"
        "        wv.navigate(url);\n"
        "    } else {\n"
        "        wv.html(BOOT_ERROR_HTML);\n"
        "    }\n"
        "    ts = api.PyEval_SaveThread();\n"
        "    run_main_loop();\n"
        "    api.PyEval_RestoreThread(ts);\n"
        "    api.PyRun_SimpleString(\"getattr(_ctx, 'close_http', lambda: None)(); from jaclang.runtimelib.client.targets.desktop.native import inprocess_dispatch; inprocess_dispatch.shutdown()\");\n"
        "    api.Py_Finalize();\n"
        "}\n"
    );
}
