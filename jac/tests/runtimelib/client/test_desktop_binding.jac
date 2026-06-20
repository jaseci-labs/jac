"""Dependency-free tests for the Jac-native webview binding.

Compile-only: these need ONLY the jac toolchain - no WebKitGTK, no libpython-dev,
no display. `jac nacompile` records the needed shared libraries (DT_NEEDED) and an
$ORIGIN runpath without dlopening them, so a host that binds libwebview.so (or
libpython) links cleanly with nothing installed. This catches binding-signature
drift, wrong/missing externs, wrong soname, and codegen regressions.
"""
import os;
import shutil;
import subprocess;
import sysconfig;
import tempfile;
import from pathlib { Path }

"""Locate the shipped webview binding (now under jaclang/runtimelib/client/)."""
def _webview_dir -> Path {
    here = Path(os.path.abspath(__file__)).parent;
    probe = here;
    for _ in range(8) {
        cand = probe / "jaclang" / "runtimelib" / "client" / "targets" / "desktop" / "native" / "webview";
        if (cand / "webview.na.jac").exists() {
            return cand;
        }
        probe = probe.parent;
    }
    raise RuntimeError(
        "jaclang/runtimelib/client/targets/desktop/native/webview/webview.na.jac not found from " + str(
            here
        )
    );
}

"""Locate the native plugin bridge (beside the webview, under .../desktop/native/)."""
def _native_dir -> Path {
    here = Path(os.path.abspath(__file__)).parent;
    probe = here;
    for _ in range(8) {
        cand = probe / "jaclang" / "runtimelib" / "client" / "targets" / "desktop" / "native";
        if (cand / "plugin_bridge.na.jac").exists() {
            return cand;
        }
        probe = probe.parent;
    }
    raise RuntimeError(
        "jaclang/runtimelib/client/targets/desktop/native/plugin_bridge.na.jac not found from " + str(
            here
        )
    );
}

"""Compile a generated host (with the binding staged beside it) to a native ELF.

Returns (returncode, stderr, binary_bytes). binary_bytes is empty on failure.
"""
def _compile_host(host_src: str, extra_files: dict[str, str] = None) -> tuple {
    jac = shutil.which("jac") or "jac";
    tmp = tempfile.mkdtemp();
    try {
        shutil.copy2(
            str(_webview_dir() / "webview.na.jac"), os.path.join(tmp, "webview.na.jac")
        );
        if extra_files is not None {
            for (name, content) in extra_files.items() {
                fpath = os.path.join(tmp, name);
                os.makedirs(os.path.dirname(fpath), exist_ok=True);
                with open(fpath, "w") as ef {
                    ef.write(content);
                }
            }
        }
        with open(os.path.join(tmp, "host.na.jac"), "w") as f {
            f.write(host_src);
        }
        result = subprocess.run(
            [jac, "nacompile", "host.na.jac", "-o", "out"],
            cwd=tmp,
            capture_output=True,
            text=True,
            timeout=300
        );
        out = os.path.join(tmp, "out");
        data = b"";
        if os.path.exists(out) {
            with open(out, "rb") as bf {
                data = bf.read();
            }
        }
        return (result.returncode, result.stderr, data);
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}

"""A host that uses the obj:pub Webview API links libwebview.so via $ORIGIN."""
test "webview binding host compiles and links libwebview.so" {
    src = (
        "import from webview { Webview, new_webview, respond, HINT_NONE, run_main_loop }\n"
        "def on_call(id: int, req: int, arg: int) -> None { respond(arg, id, \"1\"); }\n"
        "with entry {\n"
        "    wv = new_webview(False);\n"
        "    wv.title(\"t\");\n"
        "    wv.size(640, 480, HINT_NONE);\n"
        "    wv.bind(\"ping\", on_call);\n"
        "    wv.html(\"<h1>hi</h1>\");\n"
        "    run_main_loop();\n"
        "}\n"
    );
    (rc, err, data) = _compile_host(src);
    assert rc == 0 , f"binding host failed to compile:\n{err}";
    assert data[:4] == b"\x7fELF" , "output is not an ELF executable";
    assert b"libwebview.so" in data , "binary must link libwebview.so";
    assert b"$ORIGIN" in data , "binary must carry an $ORIGIN runpath";
}

"""The embedded-CPython host (the desktop runtime model) links libpython."""
test "embedded-python host compiles and links libpython" {
    soname = sysconfig.get_config_var("INSTSONAME") or "libpython3.12.so.1.0";
    stem = soname.split(".so")[0].encode();  # e.g. b"libpython3.12"
    src = (
        f'import from "{soname}" {{\n'
        "    def Py_Initialize() -> None;\n"
        "    def Py_Finalize() -> None;\n"
        "    def PyRun_SimpleString(cmd: str) -> i32;\n"
        "}\n"
        "with entry { Py_Initialize(); PyRun_SimpleString(\"pass\"); Py_Finalize(); }\n"
    );
    (rc, err, data) = _compile_host(src);
    assert rc == 0 , f"embedded-python host failed to compile:\n{err}";
    assert data[:4] == b"\x7fELF" , "output is not an ELF executable";
    assert stem in data , "binary must link the libpython soname";
}

"""Locate the native plugin bridge file for tests."""
def _bridge_src -> str {
    bridge = _native_dir() / "plugin_bridge.na.jac";
    return bridge.read_text();
}

"""Entry-level webview_create + LAST_WEBVIEW_HANDLE is the desktop host pattern."""
test "entry-level webview handle wires run_main_loop" {
    src = (
        "import from webview { def webview_create(debug: i32, window: int) -> int; }\n"
        "import from webview { Webview, HINT_NONE, LAST_WEBVIEW_HANDLE, run_main_loop }\n"
        "with entry {\n"
        "    _wv_raw = webview_create(0, 0);\n"
        "    LAST_WEBVIEW_HANDLE = _wv_raw;\n"
        "    wv = Webview(handle=_wv_raw);\n"
        "    wv.title(\"t\");\n"
        "    wv.size(640, 480, HINT_NONE);\n"
        "    wv.html(\"<h1>hi</h1>\");\n"
        "    run_main_loop();\n"
        "}\n"
    );
    (rc, err, data) = _compile_host(src);
    assert rc == 0 , f"get_handle host failed to compile:\n{err}";
    assert data[:4] == b"\x7fELF" , "output is not an ELF executable";
}

"""The plugin bridge + embedded-CPython + webview host compiles as a unit.

This validates the full native stack: the bridge code is inlined directly
into the host source (nacompile does not support string-literal imports
between .na.jac files). The bridge handles GIL management,
PyObject_CallOneArg, and inttoptr coercion.
"""
test "plugin bridge host compiles with webview + libpython" {
    soname = sysconfig.get_config_var("INSTSONAME") or "libpython3.12.so.1.0";
    # The host inlines the bridge code (same pattern as _generate_host_source)
    src = (
        f'import from "{soname}" {{\n'
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
        "glob _PH_DISPATCH: int = 0;\n"
        "def _jac_invoke_handler(id: int, req: int, wv_handle: int) -> None {\n"
        "    gstate = PyGILState_Ensure();\n"
        "    py_req = PyUnicode_FromString(req as str);\n"
        "    py_result = PyObject_CallOneArg(_PH_DISPATCH, py_req);\n"
        "    if py_result == 0 {\n"
        "        Py_DecRef(py_req);\n"
        "        PyGILState_Release(gstate);\n"
        '        respond(wv_handle, id, "{\\"ok\\":false,\\"error\\":{\\"code\\":\\"DISPATCH_CRASHED\\"}}");\n'
        "        return;\n"
        "    }\n"
        "    result_str = PyUnicode_AsUTF8(py_result);\n"
        "    Py_DecRef(py_req);\n"
        "    Py_DecRef(py_result);\n"
        "    PyGILState_Release(gstate);\n"
        "    respond(wv_handle, id, result_str);\n"
        "}\n"
        "import from webview { Webview, new_webview, respond, HINT_NONE, run_main_loop }\n"
        "with entry {\n"
        "    Py_Initialize();\n"
        "    wv = new_webview(False);\n"
        '    wv.title("test");\n'
        "    wv.size(640, 480, HINT_NONE);\n"
        '    wv.bind("__jac_invoke", _jac_invoke_handler);\n'
        '    wv.html("<h1>test</h1>");\n'
        "    ts = PyEval_SaveThread();\n"
        "    run_main_loop();\n"
        "    PyEval_RestoreThread(ts);\n"
        "    Py_Finalize();\n"
        "}\n"
    );
    (rc, err, data) = _compile_host(src);
    assert rc == 0 , f"plugin bridge host failed to compile:\n{err}";
    assert data[:4] == b"\x7fELF" , "output is not an ELF executable";
    assert b"libwebview.so" in data , "binary must link libwebview.so";
    assert b"libpython" in data , "binary must link libpython";
}
