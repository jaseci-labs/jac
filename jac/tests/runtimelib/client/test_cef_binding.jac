"""Dependency-free tests for the Jac-native CEF binding.

Compile-only: these need ONLY the jac toolchain - no CEF runtime, no
libpython-dev, no display. `jac nacompile` records the needed shared libraries
(DT_NEEDED) and an $ORIGIN runpath without dlopening them, so a host that binds
libcef_dispatch.so (or libpython) links cleanly with nothing installed. This
catches binding-signature drift, wrong/missing externs, wrong soname, and
codegen regressions. The webview binding has a sibling suite in
`test_desktop_binding.jac`.
"""
import os;
import shutil;
import subprocess;
import sysconfig;
import tempfile;
import from pathlib { Path }

"""Locate the shipped CEF binding (under jaclang/runtimelib/client/)."""
def _cef_dir -> Path {
    here = Path(os.path.abspath(__file__)).parent;
    probe = here;
    for _ in range(8) {
        cand = probe / "jaclang" / "runtimelib" / "client" / "targets" / "desktop" / "native" / "cef";
        if (cand / "cef.na.jac").exists() {
            return cand;
        }
        probe = probe.parent;
    }
    raise RuntimeError(
        "jaclang/runtimelib/client/targets/desktop/native/cef/cef.na.jac not found from " + str(
            here
        )
    );
}

"""Compile a CEF host with the binding staged beside it.

Returns (returncode, stderr, binary_bytes). binary_bytes is empty on failure.
"""
def _compile_cef_host(host_src: str) -> tuple {
    jac = shutil.which("jac") or "jac";
    tmp = tempfile.mkdtemp();
    try {
        shutil.copy2(str(_cef_dir() / "cef.na.jac"), os.path.join(tmp, "cef.na.jac"));
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

"""The embedded-CPython CEF host (desktop-cef runtime model) links both libs."""
test "cef embedded-python host compiles and links libcef_dispatch and libpython" {
    soname = sysconfig.get_config_var("INSTSONAME") or "libpython3.12.so.1.0";
    stem = soname.split(".so")[0].encode();
    src = (
        "import sys;\n"
        "import from cef {\n"
        "    cef_execute_subprocess,\n"
        "    cef_queue_browser,\n"
        "    cef_startup,\n"
        "    cef_cleanup,\n"
        "}\n"
        f'import from "{soname}" {{\n'
        "    def Py_Initialize() -> None;\n"
        "    def Py_Finalize() -> None;\n"
        "    def PyRun_SimpleString(cmd: str) -> i32;\n"
        "}\n"
        "with entry {\n"
        "    code: i32 = cef_execute_subprocess();\n"
        "    if code >= 0 { sys.exit(code); }\n"
        "    Py_Initialize();\n"
        "    PyRun_SimpleString(\"pass\");\n"
        "    cef_queue_browser(\"about:blank\", \"t\", 640, 480);\n"
        '    rc: i32 = cef_startup("", 1);\n'
        "    if rc != 1 { sys.exit(1); }\n"
        "    Py_Finalize();\n"
        "    cef_cleanup();\n"
        "}\n"
    );
    (rc, err, data) = _compile_cef_host(src);
    assert rc == 0 , f"cef embedded-python host failed to compile:\n{err}";
    assert data[:4] == b"\x7fELF" , "output is not an ELF executable";
    assert b"libcef_dispatch.so" in data , "binary must link libcef_dispatch.so";
    assert stem in data , "binary must link the libpython soname";
    assert b"$ORIGIN" in data , "binary must carry an $ORIGIN runpath";
}

"""A host that uses the CefBrowser API links libcef_dispatch.so via $ORIGIN."""
test "cef binding host compiles and links libcef_dispatch.so" {
    src = (
        "import from cef { CefBrowser, new_cef_browser, cef_cleanup }\n"
        "with entry {\n"
        "    browser = new_cef_browser(\"about:blank\", \"t\", 640, 480);\n"
        "    if browser.browser_handle != 0 {\n"
        "        browser.run();\n"
        "        cef_cleanup();\n"
        "    }\n"
        "}\n"
    );
    (rc, err, data) = _compile_cef_host(src);
    assert rc == 0 , f"cef binding host failed to compile:\n{err}";
    assert data[:4] == b"\x7fELF" , "output is not an ELF executable";
    assert b"libcef_dispatch.so" in data , "binary must link libcef_dispatch.so";
    assert b"$ORIGIN" in data , "binary must carry an $ORIGIN runpath";
}
