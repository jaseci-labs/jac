"""Shared build helpers for native and CEF desktop targets."""
import os;
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
    return (
        sysconfig.get_config_var("INSTSONAME")
        or f"libpython{sys.version_info.major}.{sys.version_info.minor}.so.1.0"
    );
}

"""Embedded-Python loopback server source (oauth_broker + stable origin port)."""
def _loopback_serve_py(app_name: str) -> str {
    pref_port = 49152 + (int(hashlib.sha1(app_name.encode()).hexdigest(), 16) % 16000);
    return (
        "import os, socketserver, threading, importlib.util\n"
        "_exe = os.path.realpath('/proc/self/exe')\n"
        "_root = os.path.dirname(_exe)\n"
        "_dir = os.path.join(_root, 'dist')\n"
        "_spec = importlib.util.spec_from_file_location("
        "'oauth_broker', os.path.join(_root, 'oauth_broker.py'))\n"
        "_broker = importlib.util.module_from_spec(_spec)\n"
        "_spec.loader.exec_module(_broker)\n"
        "_data = os.environ.get('JAC_DATA_PATH', _root)\n"
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
