"""Phase 3.1: exercise the high-level `jac_py_*` py-interop surface end-to-end.

Where `test_pyinterop_spike.jac` (3.0) drove the raw `jpy_` C-API forwarders by
hand, this test drives the ERGONOMIC surface `pyinterop.zig` adds -- the fixed set
of `jac_py_*` calls the na `python.na.jac` wrapper (3.2) will bind, following the
Rust bridges' status-code + JacBuf conventions:

    import("operator") --getattr("add")--> callable handle
    jac_py_call_h(add, msgpack([40, 2]))  --> result handle --to_int--> 42
    jac_py_call(add, msgpack([40, 2]))    --> msgpack result blob (one byte: 0x2a)
    jac_py_import("no_such_module_xyz")   --> ERR status + populated out_err

The arg blob is standard MessagePack (`[40, 2]` == 0x92 0x28 0x02), decoded by the
shim's injected `_jacpyi` codec (differential-tested against the `msgpack` package
on CPython 3.14). Correctness is checked WITHOUT an na-side msgpack decoder: the
handle path (`call_h` -> `to_int`) yields a plain int to compare, and the scalar
path (`call`) is checked on the result blob's LENGTH (msgpack of 42 is exactly one
byte). The error path asserts a non-zero status with a non-empty `out_err`.

Runs only where the fused runtime boots (needs the `__graftrt` trailer a `zig
build` jac carries -- the local dev launcher has none), same as the 3.0 spike.
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


def _surface_host_src -> str {
    # An na host binding the high-level surface. Handles are na `int`; every
    # fallible call takes a caller-owned out-slot (`struct.pack`) plus an out_err
    # JacBuf ("<QII" = ptr,len,cap). Markers print from the Python side for
    # reliability; exit codes 1-9 stage the failures.
    return (
        "import sys;\n"
        "import struct;\n"
        "import from jacpyembed {\n"
        "    def jac_engine_boot() -> i32;\n"
        "    def jpy_PyRun_SimpleString(cmd: str) -> i32;\n"
        "    def jac_py_import(name: str, out_handle: bytes, out_err: bytes) -> i32;\n"
        "    def jac_py_getattr(target: int, name: str, out_handle: bytes, out_err: bytes) -> i32;\n"
        "    def jac_py_call(fnh: int, args_ptr: bytes, args_len: int, out_val: bytes, out_err: bytes) -> i32;\n"
        "    def jac_py_call_h(fnh: int, args_ptr: bytes, args_len: int, out_handle: bytes, out_err: bytes) -> i32;\n"
        "    def jac_py_to_int(target: int, out_val: bytes, out_err: bytes) -> i32;\n"
        "    def jac_py_decref(target: int) -> None;\n"
        "    def jac_py_free_buf(ptr: int) -> None;\n"
        "}\n"
        "with entry {\n"
        "    rc: i32 = jac_engine_boot();\n"
        "    if rc != 0 { sys.exit(1); }\n"
        # import operator, getattr add -> a callable handle.
        "    oh = struct.pack(\"<Q\", 0);\n"
        "    oe = struct.pack(\"<QII\", 0, 0, 0);\n"
        "    ist: i32 = jac_py_import(\"operator\", oh, oe);\n"
        "    if ist != 0 { sys.exit(2); }\n"
        "    mt = struct.unpack(\"<Q\", oh);\n"
        "    modh: int = mt[0];\n"
        "    ah = struct.pack(\"<Q\", 0);\n"
        "    ae = struct.pack(\"<QII\", 0, 0, 0);\n"
        "    gst: i32 = jac_py_getattr(modh, \"add\", ah, ae);\n"
        "    if gst != 0 { sys.exit(3); }\n"
        "    at = struct.unpack(\"<Q\", ah);\n"
        "    addh: int = at[0];\n"
        # msgpack([40, 2]) = 0x92 (fixarray-2), 0x28 (40), 0x02.
        "    blob = struct.pack(\"<BBB\", 146, 40, 2);\n"
        # Handle path: call_h -> to_int, a plain int to compare (no na msgpack decode).
        "    hh = struct.pack(\"<Q\", 0);\n"
        "    he = struct.pack(\"<QII\", 0, 0, 0);\n"
        "    cst: i32 = jac_py_call_h(addh, blob, 3, hh, he);\n"
        "    if cst != 0 { sys.exit(4); }\n"
        "    ht = struct.unpack(\"<Q\", hh);\n"
        "    resh: int = ht[0];\n"
        "    iv = struct.pack(\"<q\", 0);\n"
        "    ie = struct.pack(\"<QII\", 0, 0, 0);\n"
        "    tst: i32 = jac_py_to_int(resh, iv, ie);\n"
        "    if tst != 0 { sys.exit(5); }\n"
        "    ivt = struct.unpack(\"<q\", iv);\n"
        "    val: int = ivt[0];\n"
        "    jac_py_decref(resh);\n"
        "    if val != 42 {\n"
        "        jpy_PyRun_SimpleString(\"print('PYSURFACE_CALL_BAD', flush=True)\");\n"
        "        sys.exit(6);\n"
        "    }\n"
        "    jpy_PyRun_SimpleString(\"print('PYSURFACE_CALL_OK', flush=True)\");\n"
        # Scalar path: call -> msgpack result blob. msgpack of 42 is one byte (0x2a),
        # so a correct round-trip yields a JacBuf of len 1 (a plain int compare on
        # the JacBuf len field -- no na-side msgpack decoder needed).
        "    rv = struct.pack(\"<QII\", 0, 0, 0);\n"
        "    re = struct.pack(\"<QII\", 0, 0, 0);\n"
        "    sst: i32 = jac_py_call(addh, blob, 3, rv, re);\n"
        "    if sst != 0 { sys.exit(7); }\n"
        "    rvt = struct.unpack(\"<QII\", rv);\n"
        "    rvptr: int = rvt[0];\n"
        "    rvlen: int = rvt[1];\n"
        "    jac_py_free_buf(rvptr);\n"
        "    if rvlen != 1 {\n"
        "        jpy_PyRun_SimpleString(\"print('PYSURFACE_MSGPACK_BAD', flush=True)\");\n"
        "        sys.exit(8);\n"
        "    }\n"
        "    jpy_PyRun_SimpleString(\"print('PYSURFACE_MSGPACK_OK', flush=True)\");\n"
        # Error path: importing a missing module returns a non-zero status and a
        # populated out_err JacBuf (len > 0 = the formatted exception text).
        "    bh = struct.pack(\"<Q\", 0);\n"
        "    be = struct.pack(\"<QII\", 0, 0, 0);\n"
        "    est: i32 = jac_py_import(\"no_such_module_xyz\", bh, be);\n"
        "    bet = struct.unpack(\"<QII\", be);\n"
        "    errptr: int = bet[0];\n"
        "    errlen: int = bet[1];\n"
        "    jac_py_free_buf(errptr);\n"
        "    if est == 0 {\n"
        "        jpy_PyRun_SimpleString(\"print('PYSURFACE_ERR_BAD', flush=True)\");\n"
        "        sys.exit(9);\n"
        "    }\n"
        "    if errlen > 0 {\n"
        "        jpy_PyRun_SimpleString(\"print('PYSURFACE_ERR_OK', flush=True)\");\n"
        "    }\n"
        "    jac_py_decref(addh);\n"
        "    jac_py_decref(modh);\n"
        "}\n"
    );
}


test "na host drives the high-level jac_py_* surface end-to-end" {
    jac = _jac_bin();
    tmp = tempfile.mkdtemp();
    try {
        out_dir = Path(tmp);
        _stage_pyembed_shim(out_dir);
        (out_dir / "surface.na.jac").write_text(_surface_host_src());
        binary = out_dir / "pyinterop_surface";
        comp = subprocess.run(
            [jac, "nacompile", "surface.na.jac", "-o", "pyinterop_surface"],
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
            f"pyinterop surface binary exited {run.returncode}\n"
            f"stdout:\n{run.stdout}\nstderr:\n{run.stderr}"
        );
        assert "PYSURFACE_CALL_OK" in run.stdout , (
            "jac_py_call_h -> jac_py_to_int round-trip marker missing\n"
            f"stdout:\n{run.stdout}\nstderr:\n{run.stderr}"
        );
        assert "PYSURFACE_MSGPACK_OK" in run.stdout , (
            "jac_py_call msgpack-result marker missing\n"
            f"stdout:\n{run.stdout}\nstderr:\n{run.stderr}"
        );
        assert "PYSURFACE_ERR_OK" in run.stdout , (
            "error-path marker missing\n"
            f"stdout:\n{run.stdout}\nstderr:\n{run.stderr}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
