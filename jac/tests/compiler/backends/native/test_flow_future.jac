"""General parallel flow calls (#7870 item 4d): the outlining
machinery generalizes from flow for to arbitrary direct calls, with a
heap future record joining at `wait`. Parallel in enforced zero-RC and
atomic-rc builds; cycles, wasm, rc-debug, and any handle whose uses
are not exactly `wait` keep the sequential erasure."""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURE = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures", "flow_future.jac"
     ),
     EXPECTED = "940251\n6.0\nend\n",
     MODE_FLAGS = {
         "none": ["--memory", "nogc"],
         "rc": ["--memory", "rc"],
         "cycles": ["--memory", "managed"]
     };

def _compile_ir(gc_mode: str, enforce: bool) -> str {
    prog = JacProgram();
    ir = prog.compile(
        file_path=FIXTURE,
        options=CompileOptions(
            aot_mode=True, na_gc_mode=gc_mode, nogc_enforce_all=enforce
        )
    );
    assert not prog.errors_had , [e.pretty_print() for e in prog.errors_had];
    return str(ir.gen.llvm_ir);
}

test "flow calls outline into future tasks in parallel-capable builds" {
    for (mode, enforce) in (("none", True), ("rc", False)) {
        text = _compile_ir(mode, enforce);
        assert "__jac_flow_task" in text , f"{mode}: no outlined future task";
        assert "pthread_create" in text , f"{mode}: no spawn";
        assert "pthread_join" in text , f"{mode}: no join";
    }
    seq = _compile_ir("cycles", False);
    assert "__jac_flow_task" not in seq , "cycles build must stay sequential";
}

test "future output is byte-identical across gc modes" {
    with tempfile.TemporaryDirectory() as tmp {
        for mode in ("none", "rc", "cycles") {
            out_bin = os.path.join(tmp, f"fut_{mode}");
            res = subprocess.run(
                [sys.executable, "-m", "jaclang", "build", "--native", FIXTURE]
                    + MODE_FLAGS[mode]
                    + ["-o", out_bin],
                capture_output=True,
                text=True
            );
            assert res.returncode == 0 , f"{mode}: {res.stderr}";
            ran = subprocess.run([out_bin], capture_output=True, text=True);
            assert ran.returncode == 0 , f"{mode}: {ran.stderr}";
            assert ran.stdout == EXPECTED , f"{mode}: {ran.stdout}";
        }
    }
}
