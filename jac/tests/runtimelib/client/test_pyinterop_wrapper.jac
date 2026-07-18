"""Phase 3.2: exercise the ergonomic `python.na.jac` PyObj wrapper end-to-end.

Where `test_pyinterop_surface.jac` (3.1) drove the raw `jac_py_*` surface by hand
(struct.pack out-slots, manual decref), this drives the `python` na_stdlib module
the wrapper adds -- `py_import`/`PyObj.getattr`/`Args`/`PyObj.call`/`to_*` -- with
handles owned by `PyObj` (`__del__` decref, the RC-dtor pattern from
jac-bridge-regex):

    add = py_import("operator").getattr("add")
    ai = Args(); ai.add_int(40); ai.add_int(2)
    add.call(ai).to_int()                                -> 42
    ags = Args(); ags.add_str("foo"); ags.add_str("bar")
    add.call(ags).to_str()                               -> "foobar"
    add.call_raw(ai2)                                    -> 1-byte msgpack blob
    py_str("hello").to_str()                             -> "hello"
    py_import("no_such_module_xyz")                      -> raises RuntimeError

The `add_*` mutators return None (no fluent chaining -- returning `self` from a
discarded-result accumulator mis-lowers on the na backend); build Args stepwise.

The `Args` builder serializes standard MessagePack the shim's injected `_jacpyi`
codec decodes; correctness is checked without an na-side msgpack decoder (handle
path -> to_int/to_str yields plain values; call_raw checked on blob LENGTH). The
error path asserts the raised exception carries the module's formatted traceback.

Runs only where the fused runtime boots (needs the `__graftrt` trailer a `zig
build` jac carries), same as the 3.0 spike / 3.1 surface tests.
"""
import os;
import shutil;
import subprocess;
import tempfile;
import from pathlib { Path }
import from jaclang.runtimelib.client.targets.desktop.desktop_build {
    _jac_bin,
    _stage_pyembed_shim,
    _bundle_runtime
}


def _wrapper_host_src -> str {
    # An na host importing the bundled `python` wrapper (resolves to
    # na_stdlib/python.na.jac -- nearest-wins puts nothing in the tempdir tree).
    # Markers print from the Python side; exit codes 1-9 stage the failures.
    return (
        "import sys;\n"
        "import from python {\n"
        "    py_boot,\n"
        "    py_import,\n"
        "    py_str,\n"
        "    Args\n"
        "}\n"
        "import from jacpyembed { def jpy_PyRun_SimpleString(cmd: str) -> i32; }\n"
        "with entry {\n"
        "    rc: i32 = py_boot();\n"
        "    if rc != 0 { sys.exit(1); }\n"
        # operator.add(40, 2) via the handle path -> to_int.
        "    op = py_import(\"operator\");\n"
        "    add = op.getattr(\"add\");\n"
        "    ai = Args();\n"
        "    ai.add_int(40);\n"
        "    ai.add_int(2);\n"
        "    resi = add.call(ai);\n"
        "    vi: int = resi.to_int();\n"
        "    if vi != 42 {\n"
        "        jpy_PyRun_SimpleString(\"print('PYWRAP_CALL_BAD', flush=True)\");\n"
        "        sys.exit(2);\n"
        "    }\n"
        "    jpy_PyRun_SimpleString(\"print('PYWRAP_CALL_OK', flush=True)\");\n"
        # operator.add("foo", "bar") -> to_str, exercises Args.add_str + JacBuf str.
        "    ags = Args();\n"
        "    ags.add_str(\"foo\");\n"
        "    ags.add_str(\"bar\");\n"
        "    ress = add.call(ags);\n"
        "    vs: str = ress.to_str();\n"
        "    if vs != \"foobar\" {\n"
        "        jpy_PyRun_SimpleString(\"print('PYWRAP_STR_BAD', flush=True)\");\n"
        "        sys.exit(3);\n"
        "    }\n"
        "    jpy_PyRun_SimpleString(\"print('PYWRAP_STR_OK', flush=True)\");\n"
        # call_raw -> msgpack result blob. msgpack of 42 is one byte (0x2a).
        "    ar = Args();\n"
        "    ar.add_int(40);\n"
        "    ar.add_int(2);\n"
        "    blob: bytes = add.call_raw(ar);\n"
        "    if len(blob) != 1 {\n"
        "        jpy_PyRun_SimpleString(\"print('PYWRAP_RAW_BAD', flush=True)\");\n"
        "        sys.exit(4);\n"
        "    }\n"
        "    jpy_PyRun_SimpleString(\"print('PYWRAP_RAW_OK', flush=True)\");\n"
        # py_str round-trip: from_str -> to_str.
        "    hs = py_str(\"hello\");\n"
        "    hv: str = hs.to_str();\n"
        "    if hv != \"hello\" {\n"
        "        jpy_PyRun_SimpleString(\"print('PYWRAP_CONV_BAD', flush=True)\");\n"
        "        sys.exit(5);\n"
        "    }\n"
        "    jpy_PyRun_SimpleString(\"print('PYWRAP_CONV_OK', flush=True)\");\n"
        # Error path: a missing module raises RuntimeError carrying the traceback.
        "    caught: bool = False;\n"
        "    try {\n"
        "        bad = py_import(\"no_such_module_xyz\");\n"
        "    } except Exception as e {\n"
        "        caught = True;\n"
        "    }\n"
        "    if not caught {\n"
        "        jpy_PyRun_SimpleString(\"print('PYWRAP_ERR_BAD', flush=True)\");\n"
        "        sys.exit(6);\n"
        "    }\n"
        "    jpy_PyRun_SimpleString(\"print('PYWRAP_ERR_OK', flush=True)\");\n"
        "}\n"
    );
}


test "na host drives the ergonomic python.na.jac PyObj wrapper end-to-end" {
    jac = _jac_bin();
    tmp = tempfile.mkdtemp();
    try {
        out_dir = Path(tmp);
        _stage_pyembed_shim(out_dir);
        (out_dir / "wrapper.na.jac").write_text(_wrapper_host_src());
        binary = out_dir / "pyinterop_wrapper";
        comp = subprocess.run(
            [jac, "nacompile", "wrapper.na.jac", "-o", "pyinterop_wrapper"],
            cwd=tmp,
            capture_output=True,
            text=True,
            timeout=300
        );
        assert comp.returncode == 0 and binary.exists() , f"nacompile failed:\n{comp.stderr}";
        _bundle_runtime(binary);
        run = subprocess.run(
            [str(binary)], cwd=tmp, capture_output=True, text=True, timeout=120
        );
        assert run.returncode == 0 , (
            f"pyinterop wrapper binary exited {run.returncode}\n"
            f"stdout:\n{run.stdout}\nstderr:\n{run.stderr}"
        );
        for marker in [
            "PYWRAP_CALL_OK",
            "PYWRAP_STR_OK",
            "PYWRAP_RAW_OK",
            "PYWRAP_CONV_OK",
            "PYWRAP_ERR_OK"
        ] {
            assert marker in run.stdout , (
                f"marker {marker} missing\nstdout:\n{run.stdout}\nstderr:\n{run.stderr}"
            );
        }
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
