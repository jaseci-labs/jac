"""The AOT lane fails out loud, or it does not fail at all.

A dropped comma in `esast_gen_pass.jac` once made the codegen schedule swallow the
ImportError that source raised and hand back the Python-only schedule. A
natively-decided program then compiled with no native passes in it: no LLVM IR,
no alert in the ledger, and a bare "Native compilation produced no LLVM IR" from
`jac build --native`, while `jac check` and `jac run` stayed green because the run
lane simply used the Python bytecode. These tests pin that the schedule really
carries the native backend (the MIR pass), and the end-to-end guardrail compiles
the multi-module chess example to a real binary and plays a game with it, so the
AOT lane can never regress behind a green run lane again.
"""

import os;
import subprocess;
import tempfile;
import from tests.support { jac_command, JAC_ROOT }
import from jaclang.compiler.driver.pipeline { product_passes }
import from jaclang.compiler.driver.pipeline_types {
    CompilationProduct,
    ProductRequest
}

"""The passes a module's codegen requests, in order: the shared lowering, the Python IR, the structure freeze."""
def codegen_lane(native: bool) -> list[type] {
    lane: list[type] = [];
    for product in (
        CompilationProduct.CODEGEN,
        CompilationProduct.PY_IR,
        CompilationProduct.FROZEN
    ) {
        lane.extend(product_passes(product, ProductRequest(native=native)));
    }
    return lane;
}

glob CHESS = os.path.join(JAC_ROOT, "examples", "chess", "chess.jac");


test "the native codegen schedule carries the native passes" {
    import from jaclang.compiler.backends.native.mir.backend { MirNativePass }
    import from jaclang.compiler.backends.native.na_compile_pass { NativeCompilePass }
    sched = codegen_lane(True);
    names = [p.__name__ for p in sched];
    assert MirNativePass in sched , (
        f"native codegen schedule lost MirNativePass: {names}"
    );
    assert NativeCompilePass not in sched , (
        f"machine code is the host's assembly step, not a scheduled pass: {names}"
    );
}


test "the chess example compiles to a binary that plays a game" {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "chess");
        comp = subprocess.run(
            jac_command("build", "--native", CHESS, "-o", out_bin),
            capture_output=True,
            text=True,
            timeout=1800
        );
        assert comp.returncode == 0 , (
            f"nacompile of the chess example failed: exit={comp.returncode}\n"
            f"{((comp.stdout or '') + (comp.stderr or ''))[-1200:]}"
        );
        assert os.path.exists(out_bin) , f"no binary at {out_bin}";
        proc = subprocess.run(
            [out_bin, "-b", "1"], capture_output=True, text=True, timeout=300
        );
        assert proc.returncode == 0 , (
            f"the chess binary exited {proc.returncode}: "
            f"{(proc.stderr or '')[-800:]}"
        );
        assert "--- Results (1 games) ---" in proc.stdout , (
            f"the chess binary did not play a game: {proc.stdout[-800:]}"
        );
        assert "Draws:" in proc.stdout , (
            f"the chess binary printed no result tally: {proc.stdout[-800:]}"
        );
    }
}
