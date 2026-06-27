import os;
import json;
import hashlib;


def _scale_runtime_hook_py -> str {
    return (
        "_scale = os.environ.get('JAC_DESKTOP_SCALE_SRC')\n"
        "            sys.path.append(_d)\n"
    );
}


def _jacpyembed_import_block -> str {
    return ("import from jacpyembed {\n" "}\n");
}


def _make_plugin_bootstrap_py(plugin_configs: dict) -> str {
    py = (
        "import jaclang, os, sys\n"
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
    ) + _scale_runtime_hook_py() + (
        "from jaclang.runtimelib.client.targets.desktop.native import inprocess_dispatch\n"
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
        "socketserver.TCPServer.allow_reuse_address = True\n"
        f"_pref = {pref_port}\n"
        "_srv = None; _port = None\n"
        "print('JAC_DESKTOP_SERVING http://127.0.0.1:' + str(_port) + '/', flush=True)\n"
    );
    dispatch_py = _dispatch_boot_py(
        entry_rel, dispatch_timeout_s, dispatch_max_queue, dispatch_debug
    );
    _pc = plugin_configs if plugin_configs is not None else {};
    plugin_py = _make_plugin_bootstrap_py(_pc);
    bootstrap_js = "(function(){try{" "}catch(e){}})();";
    boot_error_html = (
        "<!doctype html><html><head><meta charset=\"utf-8\">" "</div></body></html>"
    );
    return (
        '"""Generated native desktop host - do not edit (jac-desktop)."""\n'
        "import from webview { Webview, respond, HINT_NONE, LAST_WEBVIEW_HANDLE, run_main_loop }\n" + _jacpyembed_import_block() + "glob PY_EVAL: i32 = 258;\n"
        f"glob SERVE_PY: str = {json.dumps(serve_py, ensure_ascii=False)};\n"
        f"glob PLUGIN_PY: str = {json.dumps(plugin_py, ensure_ascii=False)};\n"
        f"glob DISPATCH_PY: str = {json.dumps(dispatch_py, ensure_ascii=False)};\n"
        f"glob BOOTSTRAP_JS: str = {json.dumps(bootstrap_js, ensure_ascii=False)};\n"
        f"glob BOOT_ERROR_HTML: str = {json.dumps(
            boot_error_html, ensure_ascii=False
        )};\n"
        "    wv = Webview(handle=_wv_raw);\n"
        f"    wv.title({json.dumps(title, ensure_ascii=False)});\n"
        f"    wv.size({width}, {height}, HINT_NONE);\n"
        "    wv.on_load(BOOTSTRAP_JS);\n"
        "}\n"
    );
}
