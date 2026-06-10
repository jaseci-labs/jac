"""Implementation of the CEF-based desktop target.

Mirrors the pipeline in native_desktop_target.impl.jac with two divergences:
  - The host uses cef.na.jac (CEF Chromium) instead of webview.na.jac
  - The CEF runtime bundle is staged alongside dist/
Steps 1–4 (Vite build, config load, output dir prep, dist staging) are
shared with the native target and are reimplemented here inline to avoid
tight coupling between the two target implementations.
"""
import os;
import shutil;
import json;
import hashlib;
import subprocess;
import stat;
import sysconfig;
import from pathlib { Path }
import from typing { Optional }
import from jaclang.cli.console { console }

"""Locate the shipped native/cef assets (binding + fetch tooling).

native/cef lives inside this package, two dirs up from this targets module
(jac_desktop/targets/ -> jac_desktop/native/cef). Verified by the presence
of cef.na.jac; walks up as a fallback for unusual layouts.
"""
def _find_cef_dir -> Path {
    here = Path(os.path.abspath(__file__)).parent;
    candidates = [here.parent / "native" / "cef", here / "native" / "cef"];
    p = here;
    for _ in range(6) {
        candidates.append(p / "native" / "cef");
        p = p.parent;
    }
    for cand in candidates {
        if (cand / "cef.na.jac").exists() {
            return cand;
        }
    }
    raise RuntimeError("jac-desktop: native/cef assets not found in the package.");
}

"""Locate the shipped native/webview assets (for oauth_broker source).

The oauth_broker.jac is shared between both targets — it lives under
native/webview/ next to the native target's binding.
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

"""Resolve the jac CLI for nacompile."""
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

"""Ensure the CEF binary distribution is staged (fetch it on first use)."""
def _ensure_cef_dist(cef_dir: Path) -> Path {
    dist = cef_dir / "cef_dist";
    headers = cef_dir / "cef_headers" / "include" / "capi" / "cef_app_capi.h";
    if (dist / "libcef.so").exists() and headers.exists() {
        return dist;
    }
    console.print("  Fetching CEF binary distribution (one-time)...", style="muted");
    res = subprocess.run([str(cef_dir / "fetch_libcef.sh")]);
    if res.returncode != 0 or not (dist / "libcef.so").exists() {
        raise RuntimeError(
            "Failed to fetch CEF binary distribution. "
            "See jac_desktop/native/cef/README.md for prerequisites."
        );
    }
    if not headers.exists() {
        raise RuntimeError(
            "CEF SDK headers missing after fetch. "
            "Re-run jac_desktop/native/cef/fetch_libcef.sh."
        );
    }
    return dist;
}

"""Ensure libcef_shim.so exists beside the binding (build it on first use)."""
def _ensure_libcef_shim(cef_dir: Path) -> Path {
    lib = cef_dir / "libcef_shim.so";
    if lib.exists() {
        return lib;
    }
    _ensure_cef_dist(cef_dir);
    console.print("  Building libcef_shim.so (one-time)...", style="muted");
    res = subprocess.run([str(cef_dir / "build_cef_shim.sh")]);
    if res.returncode != 0 or not lib.exists() {
        raise RuntimeError(
            "Failed to build libcef_shim.so. "
            "See jac_desktop/native/cef/README.md for prerequisites."
        );
    }
    return lib;
}

"""Generate the CEF native host source (`host.na.jac`): embed CPython, serve
`dist/` on loopback through the OAuth/session broker, and render it in CEF.

Mirrors the native target host (`native_desktop_target.impl.jac`) but swaps
the renderer FFI for `cef_shim` and adds CEF subprocess handling.

Lifecycle order (must match `cef_shim.c`):
  1. jac_cef_execute_process() — exit early in CEF subprocesses
  2. Py_Initialize + loopback server (URL ready before CEF UI thread runs)
  3. jac_cef_create_browser() — queues pending browser
  4. jac_cef_initialize() — on_context_initialized creates the window
  5. jac_cef_run_message_loop() with GIL released

Bootstrap JS (window.__JAC_DESKTOP__, window.__JAC_BROKER__) is injected in
the shim's on_context_created handler, not in this host.
"""
def _generate_host_source(
    libpy: str, title: str, width: int, height: int, app_name: str, cache_path: str,
) -> str {
    pref_port = 49152 + (int(hashlib.sha1(app_name.encode()).hexdigest(), 16) % 16000);
    serve_py = (
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
    return (
        '"""Generated CEF desktop host - do not edit (jac-desktop)."""\n'
        "import sys;\n"
        "import from cef_shim {\n"
        "    def jac_cef_execute_process() -> i32;\n"
        "    def jac_cef_initialize(cache_path: str, no_sandbox: i32) -> i32;\n"
        "    def jac_cef_shutdown -> None;\n"
        "    def jac_cef_run_message_loop -> None;\n"
        "    def jac_cef_create_browser(\n"
        "        url: str, title: str, width: i32, height: i32\n"
        "    ) -> int;\n"
        "}\n"
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
        "}\n"
        "glob PY_EVAL: i32 = 258;\n"
        f"glob SERVE_PY: str = {json.dumps(serve_py, ensure_ascii=False)};\n"
        "with entry {\n"
        "    code: i32 = jac_cef_execute_process();\n"
        "    if code >= 0 {\n"
        "        sys.exit(code);\n"
        "    }\n"
        "    Py_Initialize();\n"
        "    PyRun_SimpleString(SERVE_PY);\n"
        '    main_mod = PyImport_AddModule("__main__");\n'
        "    d = PyModule_GetDict(main_mod);\n"
        '    port = PyLong_AsLong(PyRun_String("_port", PY_EVAL, d, d));\n'
        "    url = f\"http://127.0.0.1:{port}/\";\n"
        "    jac_cef_create_browser(\n"
        "        url,\n"
        f"        {json.dumps(title, ensure_ascii=False)},\n"
        f"        {width}, {height}\n"
        "    );\n"
        f"    rc: i32 = jac_cef_initialize({json.dumps(
            cache_path, ensure_ascii=False
        )}, 1);\n"
        "    if rc != 1 {\n"
        "        sys.exit(1);\n"
        "    }\n"
        "    ts = PyEval_SaveThread();\n"
        "    jac_cef_run_message_loop();\n"
        "    PyEval_RestoreThread(ts);\n"
        "    Py_Finalize();\n"
        "    jac_cef_shutdown();\n"
        "}\n"
    );
}

"""Stage the CEF runtime bundle alongside dist/ in the output directory.

Copies libcef.so, companion GPU libs, ICU data, V8 snapshot, .pak files,
locales/, and chrome-sandbox. Warns if chrome-sandbox lacks setuid root.
"""
def _stage_cef_runtime(cef_dist: Path, out_dir: Path) {
    # Core library.
    shutil.copy2(cef_dist / "libcef.so", out_dir / "libcef.so");

    # Companion GPU libraries (SwiftShader needed for software Vulkan fallback).
    for name in [
        "libEGL.so",
        "libGLESv2.so",
        "libvk_swiftshader.so",
        "vk_swiftshader_icd.json"
    ] {
        src = cef_dist / name;
        if src.exists() {
            shutil.copy2(src, out_dir / name);
        }
    }

    # Data files.
    for name in ["icudtl.dat", "v8_context_snapshot.bin"] {
        src = cef_dist / name;
        if src.exists() {
            shutil.copy2(src, out_dir / name);
        }
    }

    # .pak resource files.
    for pak in cef_dist.glob("*.pak") {
        shutil.copy2(pak, out_dir / pak.name);
    }

    # Locales directory.
    locales_src = cef_dist / "locales";
    if locales_src.exists() {
        shutil.copytree(locales_src, out_dir / "locales");
    }

    # chrome-sandbox (setuid helper).
    sandbox_src = cef_dist / "chrome-sandbox";
    if sandbox_src.exists() {
        shutil.copy2(sandbox_src, out_dir / "chrome-sandbox");
        # Check for setuid root.
        mode = os.stat(out_dir / "chrome-sandbox").st_mode;
        if not (mode & stat.S_ISUID) {
            console.print(
                "  [yellow]⚠  chrome-sandbox lacks setuid root. "
                "CEF will use --no-sandbox (less secure).[/yellow]"
            );
            console.print(
                "     Fix: sudo chown root:root chrome-sandbox && "
                "sudo chmod 4755 chrome-sandbox",
                style="muted"
            );
        }
    }
}

impl CefDesktopTarget.setup(project_dir: Path) -> None { }

impl CefDesktopTarget.build(
    entry_file: Path, project_dir: Path, platform: Optional[str] = None
) -> Path {
    import from jac_desktop.config_loader { get_desktop_config }

    # 1. Build the cl bundle with the standard Vite pipeline (WebTarget).
    console.print("\n🖥️  Building CEF desktop app (Chromium)", style="bold");
    web_bundle = super.build(entry_file, project_dir, platform);
    dist_dir = web_bundle.parent;

    # 2. Desktop window config from [plugins.desktop].
    cfg = get_desktop_config(project_dir);
    ident = cfg.get_identity();
    win = cfg.get_window_config();
    app_name = ident.name or "app";

    # 3. Prepare a clean output dir.
    out_dir = project_dir / self.output_dir;
    if out_dir.exists() {
        shutil.rmtree(out_dir);
    }
    out_dir.mkdir(parents=True, exist_ok=True);

    # 4. Stage the served bundle + the CEF binding + the CEF runtime.
    shutil.copytree(dist_dir, out_dir / "dist");

    # CEF shim (built on first use against the staged CEF dist).
    cef_dir = _find_cef_dir();
    cef_dist = _ensure_cef_dist(cef_dir);
    libcef_shim = _ensure_libcef_shim(cef_dir);
    shutil.copy2(libcef_shim, out_dir / "libcef_shim.so");

    # CEF runtime bundle (libcef.so + resources).
    _stage_cef_runtime(cef_dist, out_dir);

    # Transpile the shared oauth_broker (same as native target).
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

    # 5. Generate + compile the CEF native host (jac nacompile, same as native target).
    libpy = sysconfig.get_config_var("INSTSONAME") or "libpython3.12.so.1.0";
    cache_path = str(project_dir / ".jac" / "desktop" / "cef-cache" / str(app_name));
    host_src = _generate_host_source(
        libpy, win.title or app_name, win.width, win.height, str(app_name), cache_path,
    );
    (out_dir / "host.na.jac").write_text(host_src);

    console.print("  Compiling CEF native host (jac nacompile)...", style="muted");
    res = subprocess.run(
        [_jac_bin(), "nacompile", "host.na.jac", "-o", app_name], cwd=str(out_dir)
    );
    if res.returncode != 0 {
        raise RuntimeError("CEF native host compilation failed.");
    }
    binary = out_dir / app_name;
    console.print(f"\n✅ CEF desktop app built: {binary}", style="bold green");
    console.print(f"   run: (cd {out_dir} && ./{app_name})", style="muted");
    return binary;
}

impl CefDesktopTarget.start(
    entry_file: Path, project_dir: Path, api_port: int = 8000
) -> None {
    binary = self.build(entry_file, project_dir, None);
    env = dict(os.environ);
    # CEF on Linux: force X11 + Mesa software GL when GPU drivers fail.
    env.setdefault("DISPLAY", ":0");
    env.setdefault("OZONE_PLATFORM", "x11");
    env.setdefault("LIBGL_ALWAYS_SOFTWARE", "1");
    env.setdefault("GALLIUM_DRIVER", "llvmpipe");
    console.print(f"\n🚀 Launching CEF desktop app: {binary.name}", style="bold green");
    try {
        subprocess.run([str(binary)], cwd=str(binary.parent), env=env);
    } except KeyboardInterrupt {
        console.print("\n  Closing CEF desktop app...", style="muted");
    }
}

impl CefDesktopTarget.dev(
    entry_file: Path, project_dir: Path, port: int = 8000, api_port: int = 0
) -> None {
    console.print(
        "  desktop-cef --dev: building and launching (HMR not yet wired)", style="muted"
    );
    self.start(entry_file, project_dir, api_port);
}
