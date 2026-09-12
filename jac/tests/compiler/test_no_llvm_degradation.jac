"""Degradation path: with the LLVM shim unavailable, programs must still
compile cleanly into the server codespace with zero scheduling errors.

The shim is present in every environment the suite runs in, so the disable
knob (`JAC_LLVM_SHIM=none`) stands in for a missing shim: `_find_shim`
refuses before probing the filesystem, which is the same signal the native
scheduling gate sees when the shared object is genuinely absent. This is
the suite home of what used to be ci.yml's `test-no-llvm` job.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { JAC_ROOT }

glob PROG = (
         "def mul(a: int, b: int) -> int {\n"
         "    return a * b;\n"
         "}\n\n"
         "with entry {\n"
         "    print(mul(6, 7));\n"
         "}\n"
     );


def _run_no_llvm(argv: list[str], work: str) -> tuple[int, str] {
    argv_repr = repr(["jac"] + argv);
    script = f"""
import sys, runpy
sys.path.insert(0, {JAC_ROOT!r})
sys.argv = {argv_repr}
try:
    runpy.run_module('jaclang', run_name='__main__', alter_sys=True)
except SystemExit as exc:
    raise SystemExit(int(exc.code) if isinstance(exc.code, int) else 1)
""";
    env = dict(os.environ);
    env["JAC_LLVM_SHIM"] = "none";
    env["HOME"] = work;
    env["XDG_CACHE_HOME"] = os.path.join(work, "cache");
    proc = subprocess.run(
        [sys.executable, "-c", script],
        cwd=JAC_ROOT,
        capture_output=True,
        text=True,
        env=env,
        timeout=600,
    );
    return (proc.returncode, proc.stdout + proc.stderr);
}


test "no-llvm run degrades to the server codespace and still executes" {
    with tempfile.TemporaryDirectory() as work {
        prog = os.path.join(work, "prog.jac");
        with open(prog, "w") as f {
            f.write(PROG);
        }
        (rc, out) = _run_no_llvm(["run", prog], work);
        assert rc == 0 , f"jac run failed under JAC_LLVM_SHIM=none:\n{out}";
        assert "42" in out.splitlines() or "42" in out , out;
        assert "scheduling error" not in out , out;
        assert "preferred native but did not lower" not in out , out;
    }
}


test "native availability probes do not load code generators or LLVM bindings" {
    script = """
import os, sys, tempfile
from pathlib import Path
from jaclang.compiler.driver.pipeline import native_pipeline_available, _native_env_memo
heavy = ('jaclang.compiler.backends.native.na_ir_gen_pass',
         'jaclang.compiler.backends.native.na_compile_pass',
         'jaclang.compiler.backends.native.llvm.binding')
with tempfile.TemporaryDirectory() as directory:
    shim = Path(directory) / 'probe-shim'
    shim.touch()
    for setting, expected in [('none', False), (str(shim), True)]:
        os.environ['JAC_LLVM_SHIM'] = setting
        _native_env_memo.clear()
        available, reason = native_pipeline_available()
        assert available is expected, (available, reason)
        loaded = [name for name in sys.modules if name.startswith(heavy)]
        assert not loaded, f'availability probe imported compiler backends: {loaded}'
""";
    proc = subprocess.run(
        [sys.executable, "-c", script],
        capture_output=True, text=True, timeout=600
    );
    assert proc.returncode == 0 , proc.stdout + proc.stderr;
}
