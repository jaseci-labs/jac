"""Degradation path: with the LLVM shim unavailable, programs must still
compile cleanly into the server codespace with zero scheduling errors.

The shim is present in every environment the suite runs in, so the child
process makes the artifact router find none: every tier of the `llvm-shim`
artifact probes as missing, which is the same signal the native scheduling
gate sees when the shared object is genuinely absent. This is the suite
home of what used to be ci.yml's `test-no-llvm` job.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { cache_env }
import from tests.support { JAC_ROOT }

glob PROG = (
         "def mul(a: int, b: int) -> int {\n"
         "    return a * b;\n"
         "}\n\n"
         "with entry {\n"
         "    print(mul(6, 7));\n"
         "}\n"
     );


def _run_no_llvm(
    argv: list[str], work: str, probe: str = "Probe.missing()"
) -> tuple[int, str] {
    argv_repr = repr(["jac"] + argv);
    script = f"""
import sys, runpy
sys.path.insert(0, {JAC_ROOT!r})
from unittest.mock import patch
from jaclang.artifacts.model import Probe
from jaclang.compiler.backends.native.llvm.shim_path import ShimArtifact
for probe in ('probe_sealed', 'probe_checkout', 'probe_kit'):
    patch.object(ShimArtifact, probe, return_value={probe}).start()
sys.argv = {argv_repr}
try:
    runpy.run_module('jaclang', run_name='__main__', alter_sys=True)
except SystemExit as exc:
    raise SystemExit(int(exc.code) if isinstance(exc.code, int) else 1)
""";
    env: dict[str, str] = dict(os.environ);
    env["HOME"] = work;
    env.update(cache_env(os.path.join(work, "cache")));
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
        assert rc == 0 , f"jac run failed without an LLVM shim:\n{out}";
        assert "42" in out.splitlines() or "42" in out , out;
        assert "scheduling error" not in out , out;
        assert "preferred native but did not lower" not in out , out;
    }
}


test "native availability probes do not load code generators or LLVM bindings" {
    script = """
import sys
from unittest.mock import patch
from jaclang.artifacts import router
from jaclang.artifacts.model import Probe, Source
from jaclang.compiler.backends.native.llvm.shim_path import ShimArtifact
from jaclang.compiler.driver.toolchain import native_pipeline_available, _native_env_memo
heavy = ('jaclang.compiler.backends.native.na_ir_gen_pass',
         'jaclang.compiler.backends.native.na_compile_pass',
         'jaclang.compiler.backends.native.llvm.binding')
for probe, expected in [(Probe.missing(), False), (Probe.hit(Source.CHECKOUT, '/probe-shim', {}), True)]:
    with patch.object(ShimArtifact, 'probe_sealed', return_value=None), \
         patch.object(ShimArtifact, 'probe_checkout', return_value=probe), \
         patch.object(ShimArtifact, 'probe_kit', return_value=Probe.missing()):
        router.forget()
        _native_env_memo.clear()
        available, reason = native_pipeline_available()
        assert available is expected, (available, reason)
        loaded = [name for name in sys.modules if name.startswith(heavy)]
        assert not loaded, f'availability probe imported compiler backends: {loaded}'
""";
    proc = subprocess.run(
        [sys.executable, "-c", script], capture_output=True, text=True, timeout=600
    );
    assert proc.returncode == 0 , proc.stdout + proc.stderr;
}


glob STALE = "Probe.stale(['the shim predates its sources'])";


test "the LLVM binding imports with a stale shim and only its calls raise" {
    script = f"""
import sys
sys.path.insert(0, {JAC_ROOT!r})
from unittest.mock import patch
from jaclang.artifacts.model import ArtifactUnavailable, Probe
from jaclang.compiler.backends.native.llvm.shim_path import ShimArtifact
for probe in ('probe_sealed', 'probe_checkout', 'probe_kit'):
    patch.object(ShimArtifact, probe, return_value={STALE}).start()
from jaclang.compiler.backends.native.llvm.binding import initfini, targets, executionengine
try:
    targets.get_default_triple()
except ArtifactUnavailable:
    pass
else:
    raise AssertionError('a binding call succeeded with no usable shim')
""";
    proc = subprocess.run(
        [sys.executable, "-c", script], capture_output=True, text=True, timeout=600
    );
    assert proc.returncode == 0 , proc.stdout + proc.stderr;
}


test "jac native status reports a stale shim instead of crashing" {
    with tempfile.TemporaryDirectory() as work {
        (rc, out) = _run_no_llvm(["native", "status", "llvm-shim"], work, STALE);
        assert rc == 0 , out;
        assert "Traceback" not in out , out;
        assert "the shim predates its sources" in out , out;
    }
}


test "native lowering products take the native toolchain verdict from the host" {
    script = f"""
import sys
sys.path.insert(0, {JAC_ROOT!r})
from jaclang.compiler.frontend.host import NeutralHost, active_host, install_host
from jaclang.compiler.driver.pipeline import resolve, unavailable
from jaclang.compiler.driver.pipeline_types import CompilationProduct

class StaleShimHost(NeutralHost):
    def native_pipeline_available(self):
        return (False, 'native pipeline unavailable: the LLVM shim is stale')

previous = active_host()
install_host(StaleShimHost())
try:
    for product in (CompilationProduct.NATIVE_LOWER, CompilationProduct.NATIVE_IR):
        assert unavailable(product) == 'native pipeline unavailable: the LLVM shim is stale', product
        assert resolve(product)[0] is None, product
finally:
    install_host(previous)
""";
    proc = subprocess.run(
        [sys.executable, "-c", script], capture_output=True, text=True, timeout=600
    );
    assert proc.returncode == 0 , proc.stdout + proc.stderr;
}


"""Importing the LLVM bindings must not call into the shim. `initfini` used to
ask the shim for its version at import time, so a stale or missing shim broke
every import of the `native` command, including `jac native build llvm-shim`,
the command that repairs it. The child makes every shim lookup raise
`ArtifactUnavailable`, the error a stale or missing shim produces, then imports
that command module."""
test "native command module imports while the LLVM shim is unavailable" {
    script = f"""
import sys
sys.path.insert(0, {JAC_ROOT!r})
import jaclang
from jaclang.artifacts import router
from jaclang.artifacts.model import ArtifactUnavailable
assert not [m for m in sys.modules if ".llvm." in m], "LLVM bindings loaded before the patch"
_real_require = router.require

def _require(name, *args, **kwargs):
    if name == "llvm-shim":
        raise ArtifactUnavailable("stale: simulated by the test")
    return _real_require(name, *args, **kwargs)

router.require = _require
import jaclang.cli.commands.native
print("IMPORTED")
""";
    with tempfile.TemporaryDirectory() as work {
        env: dict[str, str] = dict(os.environ);
        env["HOME"] = work;
        env.update(cache_env(os.path.join(work, "cache")));
        proc = subprocess.run(
            [sys.executable, "-c", script],
            cwd=JAC_ROOT,
            capture_output=True,
            text=True,
            env=env,
            timeout=600,
        );
        out = proc.stdout + proc.stderr;
        assert proc.returncode == 0 and "IMPORTED" in out , out;
    }
}


"""A module that asks codegen for native lowering may be the first to need the
native verdict, for example a module pinned native in a project that places
nothing native by inference, so no placement probe has consulted the shim yet.
That verdict must come from the shim before the codegen schedule starts
loading: inside the loading window the host defers to an optimistic answer and
`NaIRGenPass` would be scheduled against a stale shim."""
test "a native codegen request in a fresh process takes the shim's verdict" {
    script = f"""
import sys
sys.path.insert(0, {JAC_ROOT!r})
from unittest.mock import patch
from jaclang.artifacts.model import Probe
from jaclang.compiler.backends.native.llvm.shim_path import ShimArtifact
for probe in ('probe_sealed', 'probe_checkout', 'probe_kit'):
    patch.object(ShimArtifact, probe, return_value={STALE}).start()
import jaclang
from jaclang.compiler.driver.pipeline import resolve
from jaclang.compiler.driver.pipeline_types import CompilationProduct, ProductRequest
from jaclang.compiler.driver.toolchain import _native_env_memo
assert not _native_env_memo, _native_env_memo
schedule = resolve(CompilationProduct.CODEGEN, ProductRequest(native=True))[0]
names = [p.__name__ for p in schedule or []]
assert 'NaIRGenPass' not in names, names
assert 'EsastGenPass' in names, names
""";
    proc = subprocess.run(
        [sys.executable, "-c", script],
        cwd=JAC_ROOT,
        capture_output=True,
        text=True,
        timeout=900
    );
    assert proc.returncode == 0 , proc.stdout + proc.stderr;
}
