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

"""Locate the shipped webview binding (this file is tests/<x> beside it)."""
def _webview_dir -> Path {
    here = Path(os.path.abspath(__file__)).parent;
    probe = here;
    for _ in range(6) {
        cand = probe / "native" / "webview";
        if (cand / "webview.na.jac").exists() {
            return cand;
        }
        probe = probe.parent;
    }
    raise RuntimeError("native/webview/webview.na.jac not found from " + str(here));
}

"""Compile a generated host (with the binding staged beside it) to a native ELF.

Returns (returncode, stderr, binary_bytes). binary_bytes is empty on failure.
"""
def _compile_host(host_src: str) -> tuple {
    jac = shutil.which("jac") or "jac";
    tmp = tempfile.mkdtemp();
    try {
        shutil.copy2(
            str(_webview_dir() / "webview.na.jac"), os.path.join(tmp, "webview.na.jac")
        );
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
        "import from webview { Webview, new_webview, respond, HINT_NONE }\n"
        "def on_call(id: int, req: int, arg: int) -> None { respond(arg, id, \"1\"); }\n"
        "with entry {\n"
        "    wv = new_webview(False);\n"
        "    wv.title(\"t\");\n"
        "    wv.size(640, 480, HINT_NONE);\n"
        "    wv.bind(\"ping\", on_call);\n"
        "    wv.html(\"<h1>hi</h1>\");\n"
        "    wv.run();\n"
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
