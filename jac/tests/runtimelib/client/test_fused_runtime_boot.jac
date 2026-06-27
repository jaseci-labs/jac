"""Tier-A end-to-end test: a minimal na host actually boots the fused runtime.

The codegen string tests prove what the host SOURCE contains; this proves the
whole chain RUNS in a real binary. Build a tiny na host that links the
libjacpyembed shim, bundle THIS jac's runtime trailer onto it, run it, and
confirm jac_engine_boot() materialized the trailer payload, dlopened the bundled
CPython, Py_Initialize()d it, and imported jaclang + oauth_broker straight from
the fused runtime -- with no webview, no display, and no system libpython (the
interpreter is the one bundled in the payload). Same chain a desktop host runs,
minus the window. Needs only the jac toolchain (`nacompile` + the shipped shim).
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

test "na host boots the fused runtime via libjacpyembed (no display)" {
    # A windowless host: bring up the fused runtime, import jaclang + a desktop
    # bootstrap module from it, print a marker, finalize. If boot fails the
    # interpreter is not up, so bail (sys.exit) before any Py_* call.
    host_src = (
        "import sys;\n"
        "import from jacpyembed {\n"
        "    def jac_engine_boot() -> i32;\n"
        "    def jpy_PyRun_SimpleString(cmd: str) -> i32;\n"
        "    def jpy_Py_Finalize() -> None;\n"
        "}\n"
        "with entry {\n"
        "    rc: i32 = jac_engine_boot();\n"
        "    if rc != 0 {\n"
        "        sys.exit(1);\n"
        "    }\n"
        "    jpy_PyRun_SimpleString(\"import jaclang; from jaclang.runtimelib.client.targets.desktop.native import oauth_broker; print('ENGINE_BOOT_OK', flush=True)\");\n"
        "    jpy_Py_Finalize();\n"
        "}\n"
    );
    jac = _jac_bin();
    tmp = tempfile.mkdtemp();
    try {
        out_dir = Path(tmp);
        # The shim must sit $ORIGIN-adjacent so the host's `import from jacpyembed`
        # resolves the sibling libjacpyembed at load (it ships in the fused runtime).
        _stage_pyembed_shim(out_dir);
        (out_dir / "host.na.jac").write_text(host_src);
        binary = out_dir / "engineboot";
        comp = subprocess.run(
            [jac, "nacompile", "host.na.jac", "-o", "engineboot"],
            cwd=tmp,
            capture_output=True,
            text=True,
            timeout=300
        );
        assert comp.returncode == 0 and binary.exists() , f"nacompile failed:\n{comp.stderr}";
        # Append this jac's [payload][trailer] so the host carries the fused runtime
        # and jac_engine_boot() can materialize it from /proc/self/exe at launch.
        _bundle_runtime(binary);
        run = subprocess.run(
            [str(binary)], cwd=tmp, capture_output=True, text=True, timeout=120
        );
        assert run.returncode == 0 , (
            f"engine-boot binary exited {run.returncode}\n"
            f"stdout:\n{run.stdout}\nstderr:\n{run.stderr}"
        );
        assert "ENGINE_BOOT_OK" in run.stdout , (
            f"fused-runtime boot marker missing\n"
            f"stdout:\n{run.stdout}\nstderr:\n{run.stderr}"
        );
    } finally {
        shutil.rmtree(tmp, ignore_errors=True);
    }
}
