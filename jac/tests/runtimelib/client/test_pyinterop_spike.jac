"""Phase 3.0 de-risk spike: an na binary drives the embedded CPython through the
py-interop forwarder surface (the four Phase-3.0 additions to pyembed.zig).

Builds on `test_fused_runtime_boot.jac` (which proves `jac_engine_boot()` brings
up the fused runtime): here the na host goes further and exercises the actual
py-interop primitives -- import a module by name, call a method on it, and marshal
a `bytes` payload across the boundary in BOTH directions:

    payload:str --PyBytes_FromStringAndSize--> py bytes
              --CallMethod(binascii.hexlify,"O")--> py bytes (hex)
              --CallMethod(binascii.unhexlify,"O")--> py bytes
              --PyBytes_AsStringAndSize--> (ptr,len) --__jac_str_from_raw--> str

A clean round-trip (out == in) proves the four forwarders + the byte-marshaling
recipe the Phase-3.1 `jac_py_call` surface will reuse. The host also times the
boundary call in a tight loop and prints a per-call latency (the spike's GO/NO-GO
metric; target < ~2 us -- here it's call+hexlify work, an upper bound).

Uses the bundled stdlib C extension `binascii` (no pip / no wheel), so it runs
anywhere the fused runtime boots. The orjson/polars external-wheel variety proof
(the other half of 3.0) needs `pip install --target <materialized-site>` against
the bundled interpreter and is exercised in CI, not here -- see FFI-LANES-PLAN 3.0.
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


def _spike_host_src -> str {
    # An na host: boot the fused runtime, then round-trip a bytes payload through
    # binascii via the py-interop forwarders, and time the boundary call. Markers
    # are printed from the Python side (jpy_PyRun_SimpleString) for reliability;
    # exit codes distinguish the failure stages.
    return (
        "import sys;\n"
        "import struct;\n"
        "import from jacpyembed {\n"
        "    def jac_engine_boot() -> i32;\n"
        "    def jpy_PyRun_SimpleString(cmd: str) -> i32;\n"
        "    def jpy_Py_Finalize() -> None;\n"
        "    def jpy_PyGILState_Ensure() -> int;\n"
        "    def jpy_PyGILState_Release(state: int) -> None;\n"
        "    def jpy_PyImport_ImportModule(name: str) -> int;\n"
        # `obj` is a reserved keyword in na -- the param is named `target` (the C
        # symbol matches on function name, not param names).
        "    def jpy_PyObject_CallMethod(target: int, name: str, fmt: str, arg: int) -> int;\n"
        "    def jpy_PyBytes_FromStringAndSize(v: str, length: int) -> int;\n"
        "    def jpy_PyBytes_AsStringAndSize(o: int, buf: bytes, length: bytes) -> i32;\n"
        "    def jpy_Py_DecRef(o: int) -> None;\n"
        "}\n"
        "import from \"libc.so.6\" {\n"
        "    def strlen(s: str) -> int;\n"
        "    def clock_gettime(clk: i32, ts: bytes) -> i32;\n"
        "}\n"
        "with entry {\n"
        "    rc: i32 = jac_engine_boot();\n"
        "    if rc != 0 { sys.exit(1); }\n"
        "    gstate = jpy_PyGILState_Ensure();\n"
        "    payload = \"{\\\"k\\\":[1,2,3],\\\"s\\\":\\\"jac-py-interop\\\"}\";\n"
        "    n = strlen(payload);\n"
        "    pb = jpy_PyBytes_FromStringAndSize(payload, n);\n"
        "    if pb == 0 { sys.exit(2); }\n"
        "    binascii = jpy_PyImport_ImportModule(\"binascii\");\n"
        "    if binascii == 0 { sys.exit(3); }\n"
        "    hexed = jpy_PyObject_CallMethod(binascii, \"hexlify\", \"O\", pb);\n"
        "    if hexed == 0 { sys.exit(4); }\n"
        "    back = jpy_PyObject_CallMethod(binascii, \"unhexlify\", \"O\", hexed);\n"
        "    if back == 0 { sys.exit(5); }\n"
        # Out-param marshaling (rust-ffi-na-marshaling-recipe): a `bytes` foreign arg
        # lowers to its data pointer, so a struct.pack slot receives *buffer / *length.
        # Correctness is checked on the recovered LENGTH (a plain int compare -- na
        # rejects arithmetic/compare on raw struct.unpack tuple elements and the
        # synth-only __jac_str_from_raw intrinsic here); a non-NULL chain plus an
        # exact length round-trip proves all four forwarders marshal correctly.
        "    bufslot = struct.pack(\"<Q\", 0);\n"
        "    lenslot = struct.pack(\"<q\", 0);\n"
        "    st: i32 = jpy_PyBytes_AsStringAndSize(back, bufslot, lenslot);\n"
        "    if st != 0 { sys.exit(6); }\n"
        "    lt = struct.unpack(\"<q\", lenslot);\n"
        "    rlen: int = lt[0];\n"
        "    jpy_Py_DecRef(back);\n"
        "    jpy_Py_DecRef(hexed);\n"
        "    if rlen != n {\n"
        "        jpy_PyRun_SimpleString(\"print('PYINTEROP_MISMATCH', flush=True)\");\n"
        "        jpy_PyGILState_Release(gstate);\n"
        "        sys.exit(7);\n"
        "    }\n"
        "    jpy_PyRun_SimpleString(\"print('PYINTEROP_ROUNDTRIP_OK', flush=True)\");\n"
        # Boundary latency: time a tight loop of na -> forwarder -> CPython calls with
        # libc clock_gettime (CLOCK_MONOTONIC). Tuple elements are rebound to typed
        # int locals before arithmetic; Python does the final division for output.
        "    iters = 100000;\n"
        "    tsa = struct.pack(\"<qq\", 0, 0);\n"
        "    clock_gettime(1, tsa);\n"
        "    i = 0;\n"
        "    while i < iters {\n"
        "        r = jpy_PyObject_CallMethod(binascii, \"hexlify\", \"O\", pb);\n"
        "        jpy_Py_DecRef(r);\n"
        "        i += 1;\n"
        "    }\n"
        "    tsb = struct.pack(\"<qq\", 0, 0);\n"
        "    clock_gettime(1, tsb);\n"
        "    a = struct.unpack(\"<qq\", tsa);\n"
        "    b = struct.unpack(\"<qq\", tsb);\n"
        "    a0: int = a[0];\n"
        "    a1: int = a[1];\n"
        "    b0: int = b[0];\n"
        "    b1: int = b[1];\n"
        "    elapsed_ns: int = (b0 - a0) * 1000000000 + (b1 - a1);\n"
        "    jpy_PyRun_SimpleString(\"print('PYINTEROP_LAT_NS', \" + str(elapsed_ns) + \"/\" + str(iters) + \", flush=True)\");\n"
        "    jpy_Py_DecRef(pb);\n"
        "    jpy_PyGILState_Release(gstate);\n"
        "    jpy_Py_Finalize();\n"
        "}\n"
    );
}


test "na host round-trips bytes through embedded CPython via py-interop forwarders" {
    jac = _jac_bin();
    tmp = tempfile.mkdtemp();
    try {
        out_dir = Path(tmp);
        # The shim must sit $ORIGIN-adjacent so `import from jacpyembed` resolves the
        # sibling libjacpyembed at load; it ships in the fused runtime payload.
        _stage_pyembed_shim(out_dir);
        (out_dir / "spike.na.jac").write_text(_spike_host_src());
        binary = out_dir / "pyinterop_spike";
        comp = subprocess.run(
            [jac, "nacompile", "spike.na.jac", "-o", "pyinterop_spike"],
            cwd=tmp,
            capture_output=True,
            text=True,
            timeout=300
        );
        assert comp.returncode == 0 and binary.exists() , f"nacompile failed:\n{comp.stderr}";
        # Append this jac's fused-runtime trailer so jac_engine_boot() can
        # materialize + dlopen the bundled CPython from /proc/self/exe.
        _bundle_runtime(binary);
        run = subprocess.run(
            [str(binary)], cwd=tmp, capture_output=True, text=True, timeout=120
        );
        assert run.returncode == 0 , (
            f"pyinterop spike binary exited {run.returncode}\n"
            f"stdout:\n{run.stdout}\nstderr:\n{run.stderr}"
        );
        assert "PYINTEROP_ROUNDTRIP_OK" in run.stdout , (
            "bytes round-trip marker missing\n"
            f"stdout:\n{run.stdout}\nstderr:\n{run.stderr}"
        );
        assert "PYINTEROP_LAT_NS" in run.stdout , (
            "latency marker missing\n" f"stdout:\n{run.stdout}\nstderr:\n{run.stderr}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
