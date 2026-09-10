"""The AOT lane fails out loud, or it does not fail at all.

A dropped comma in `esast_gen_pass.jac` once made `get_py_code_gen` swallow the
ImportError that source raised and hand back the Python-only schedule. A
natively-decided program then compiled with no native passes in it: no LLVM IR,
no alert in the ledger, and a bare "Native compilation produced no LLVM IR" from
`jac build --native`, while `jac check` and `jac run` stayed green because the run
lane simply used the Python bytecode. These tests pin both halves of the
contract. The schedule really carries the native passes, and an AOT compile that
ends with no IR names the module and the reason rather than going quiet. The
end-to-end guardrail compiles the multi-module chess example to a real binary
and plays a game with it, so the AOT lane can never regress behind a green run
lane again.
"""

import os;
import subprocess;
import sys;
import tempfile;
import from tests.support { JAC_ROOT, TESTS_DIR }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.schedules {
    get_analysis_sched,
    get_boundary_analysis_sched,
    get_ir_gen_sched,
    get_py_code_gen,
    providers_of
}
import from jaclang.compiler.driver.program { JacProgram }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     ),
     CHESS = os.path.join(JAC_ROOT, "examples", "chess", "chess.jac");


test "the native codegen schedule carries the native passes" {
    import from jaclang.compiler.backends.native.na_ir_gen_pass { NaIRGenPass }
    import from jaclang.compiler.backends.native.na_compile_pass { NativeCompilePass }
    # Codegen runs after the analysis stage in the single pipeline, so the
    # standalone schedule is constructed against its provides.
    sched = get_py_code_gen(
        native=True,
        provided=providers_of(
            get_ir_gen_sched() + get_analysis_sched() + get_boundary_analysis_sched()
        )
    );
    names = [p.__name__ for p in sched];
    assert NaIRGenPass in sched , (
        f"native codegen schedule lost NaIRGenPass: {names}"
    );
    assert NativeCompilePass in sched , (
        f"native codegen schedule lost NativeCompilePass: {names}"
    );
}


test "an AOT compile that lowers nothing names the module" {
    prog = JacProgram();
    ir = prog.compile(
        file_path=os.path.join(FIXTURES, "aot_no_lowerable_code.jac"),
        options=CompileOptions(aot_mode=True, force_codespace='native')
    );
    assert ir.gen.llvm_ir is None , "the fixture is not supposed to lower";
    assert prog.errors_had , (
        "an AOT compile produced no native IR and no diagnostic to explain it"
    );
    codes = [
        e.code.code
        for e in prog.errors_had
        if e.code is not None
    ];
    assert "E5092" in codes , f"expected an E5092 refusal, got: {codes}";
    said = "\n".join([e.pretty_print() for e in prog.errors_had]);
    assert "aot_no_lowerable_code" in said , (
        f"the refusal must name the module it refused: {said}"
    );
}


test "the chess example compiles to a binary that plays a game" {
    with tempfile.TemporaryDirectory() as tmp {
        out_bin = os.path.join(tmp, "chess");
        comp = subprocess.run(
            [
                sys.executable,
                "-m",
                "jaclang",
                "build",
                "--native",
                CHESS,
                "-o",
                out_bin
            ],
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
