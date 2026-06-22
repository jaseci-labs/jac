"""Shared build helpers for native and CEF desktop targets."""
import os;
import json;
import shutil;
import hashlib;
import subprocess;
import sys;
import sysconfig;
import from pathlib { Path }
import from jaclang.cli.console { console }

"""Locate a shipped native/ asset dir (webview, cef, …) inside jac_desktop."""
def _find_native_asset_dir(subdir: str, marker: str) -> Path {
    here = Path(os.path.abspath(__file__)).parent;
    candidates = [here.parent / "native" / subdir, here / "native" / subdir];
    p = here;
    for _ in range(6) {
        candidates.append(p / "native" / subdir);
        p = p.parent;
    }
    for cand in candidates {
        if (cand / marker).exists() {
            return cand;
        }
    }
    raise RuntimeError(
        f"jac-desktop: native/{subdir} assets not found in the package."
    );
}

def _find_webview_dir -> Path {
    return _find_native_asset_dir("webview", "webview.na.jac");
}

def _find_cef_dir -> Path {
    return _find_native_asset_dir("cef", "cef.na.jac");
}

"""Add $ORIGIN + libpython LIBDIR to the host ELF RUNPATH."""
def _patch_host_rpath(binary: Path) -> None {
    libdir = sysconfig.get_config_var("LIBDIR") or "";
    if not libdir {
        return;
    }
    patchelf = shutil.which("patchelf");
    if not patchelf {
        console.print(
            "  [yellow]patchelf not found; libpython must be on LD_LIBRARY_PATH at runtime[/yellow]"
        );
        return;
    }
    rpath = f"$ORIGIN:{libdir}";
    res = subprocess.run([patchelf, "--set-rpath", rpath, str(binary)]);
    if res.returncode != 0 {
        console.print(
            "  [yellow]patchelf rpath patch failed; rebuild on this machine if the binary won't start[/yellow]"
        );
    }
}

"""Resolve the jac CLI for nacompile."""
def _jac_bin -> str {
    cand = Path(os.path.dirname(os.sys.executable)) / "jac";
    if cand.exists() {
        return str(cand);
    }
    found = shutil.which("jac");
    if found {
        return found;
    }
    raise RuntimeError("jac CLI not found on PATH.");
}

"""Libpython soname for clib import in generated host.na.jac."""
def _libpython_soname -> str {
    return str(
        sysconfig.get_config_var("INSTSONAME")
        or f"libpython{sys.version_info.major}.{sys.version_info.minor}.so.1.0"
    );
}

"""Embedded-Python loopback server source (oauth_broker + stable origin port).

`plugin_bootstrap` (from `_plugin_bootstrap_py`) is spliced in after the broker
module loads but before `make_handler`, so it can define `_host`/`_dispatch_fn`.
When `dispatch_arg` is set (e.g. ", dispatch=_dispatch_fn") the broker server
routes `POST /__jac/invoke` straight into the plugin host -- the CEF target's
JS->plugin bridge, since CEF's render process cannot bind into the host
in-process the way the single-process webview target does."""
def _loopback_serve_py(
    app_name: str,
    plugin_bootstrap: str = "",
    dispatch_arg: str = "",
    threaded: bool = False
) -> str {
    pref_port = 49152 + (int(hashlib.sha1(app_name.encode()).hexdigest(), 16) % 16000);
    # The CEF target needs a threaded server: /__jac/events holds the SSE
    # connection open for its lifetime, which would otherwise block every other
    # request (including /__jac/invoke) on a single-threaded TCPServer.
    srv_setup = (
        "_S = socketserver.ThreadingTCPServer\n_S.daemon_threads = True\n"
            if threaded
            else "_S = socketserver.TCPServer\n"
    );
    return (
        "import os, sys, socketserver, threading, importlib.util\n" + srv_setup + "_exe = os.path.realpath('/proc/self/exe')\n"
        "_root = os.path.dirname(_exe)\n"
        "_dir = os.path.join(_root, 'dist')\n"
        "_spec = importlib.util.spec_from_file_location("
        "'oauth_broker', os.path.join(_root, 'oauth_broker.py'))\n"
        "_broker = importlib.util.module_from_spec(_spec)\n"
        "_spec.loader.exec_module(_broker)\n" + plugin_bootstrap + "_data = os.environ.get('JAC_DATA_PATH', _root)\n"
        "_store = _broker.SessionStore("
        "os.path.join(_data, '.jac', 'desktop', 'session.json'))\n" + "_H = _broker.make_handler(_dir, _store" + dispatch_arg + ")\n" + "_S.allow_reuse_address = True\n"
        f"_pref = {pref_port}\n"
        "_srv = None; _port = None\n"
        "for _i in range(64):\n"
        "    try:\n"
        "        _srv = _S(('127.0.0.1', _pref + _i), _H)\n"
        "        _port = _pref + _i; break\n"
        "    except OSError:\n"
        "        continue\n"
        "if _srv is None:\n"
        "    _srv = _S(('127.0.0.1', 0), _H)\n"
        "    _port = _srv.server_address[1]\n"
        "threading.Thread(target=_srv.serve_forever, daemon=True).start()\n"
        "print('JAC_DESKTOP_SERVING http://127.0.0.1:' + str(_port) + '/', flush=True)\n"
    );
}

"""Transpile oauth_broker.jac and stage oauth_broker.py beside the binary."""
def _stage_oauth_broker(out_dir: Path) {
    webview_dir = _find_webview_dir();
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
}

"""Build the embedded-CPython plugin bootstrap source.

Imports the plugin modules via importlib (in `_plugin_mods` load order), bakes
`plugin_configs`, then calls `registry.bootstrap_plugins(...)` to produce `_host`
and `_dispatch_fn`. Runs in the embedded interpreter with only the transpiled
plugin .py files on disk (no jaclang). Shared by both desktop targets.

`registry` imports every `built_in.*` plugin at module scope, so it MUST load
last: in the embedded CPython `built_in` is a bare ModuleType (not a real
package), so `from built_in.x import Y` only resolves once `built_in.x` is
already in sys.modules. This list owns the *module load order*; it cannot be
derived from registry.BUILTIN_PLUGINS (which is not importable yet), so every
`built_in.*` entry here must match a BUILTIN_PLUGINS entry by hand."""
def _plugin_bootstrap_py(plugin_configs: dict = {}) -> str {
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
    _pc = plugin_configs;  # baked at build time
    plugin_py += f"_pc = {repr(_pc)}\n";
    plugin_py += (
        "_host = sys.modules['registry'].bootstrap_plugins(_pc, sys.modules)\n"
        "_dispatch_fn = _host.dispatch\n"
    );
    return plugin_py;
}

"""JS SDK injected at document start: window.__jac.invoke()/on()/__emit__().

`invoke` delegates to the native `window.__jac_invoke(p,c,a)` primitive, which
each target provides differently (webview bind vs. CEF fetch shim) but with the
same contract: returns a promise of the dispatch JSON (string or object). Shared
by both targets so the SDK surface stays byte-identical.

NOTE: the CEF target cannot inject this at build time (its bootstrap is a
precompiled glob in cef_dispatch.na.jac); that copy must be kept in sync with
this one by hand."""
def _jac_sdk_js -> str {
    return (
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
}

"""Transpile every plugin/**/*.jac -> .py into out_dir for the embedded CPython.

Embedded CPython has no jaclang, so prefer jac0 (stdlib-only output) and fall
back to `jac jac2py`. Shared by both desktop targets."""
def _stage_plugins(out_dir: Path) {
    webview_dir = _find_webview_dir();
    plugin_src_dir = webview_dir.parent.parent / "plugin";
    if not plugin_src_dir.exists() {
        return;
    }
    console.print("  Transpiling plugin IPC modules...", style="muted");
    for jac_file in plugin_src_dir.rglob("*.jac") {
        # rglob("*.jac") also matches directories named ".jac" (build cache).
        if not jac_file.is_file() {
            continue;
        }
        rel = jac_file.relative_to(plugin_src_dir);
        py_name = str(rel.with_suffix(".py"));
        console.print(f"    {rel} -> {py_name}", style="muted");
        import jaclang.jac0 as jac0;
        res_stdout = "";
        try {
            res_stdout = jac0.compile_jac(jac_file.read_text());
            if not res_stdout or not res_stdout.strip() {
                raise RuntimeError("jac0 produced empty output");
            }
        } except Exception as jac0_err {
            res = subprocess.run(
                [_jac_bin(), "jac2py", str(jac_file)], capture_output=True, text=True
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
                f"    ⚠ jac0 failed for {rel}, using jac2py fallback", style="yellow"
            );
            res_stdout = res.stdout;
        }
        target = out_dir / py_name;
        target.parent.mkdir(parents=True, exist_ok=True);
        target.write_text(res_stdout);
    }
}
