"""A finished compilation is collectable.

The type evaluator takes a back-pointer to the running `TypeCheckPass` so it
can emit diagnostics through it. That pointer is a re-entrancy stack: each
pass saves its predecessor and restores it on the way out. The outermost pass
has no predecessor, so a restore guarded on "a predecessor exists" leaves the
evaluator holding the last pass forever -- and through it the pass's program,
that program's compiler, and every module the compiler ever loaded.

The cost is not a slow drip. One native fixture compile pins its whole unit,
so a long-lived process (the test pool's fork workers, a language server)
carries every AST and every LLVM IR object it ever built.
"""

import gc;
import os;
import weakref;
import from tests.support { TESTS_DIR }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.pass_driver { run_pass }
import from jaclang.compiler.passes.type_checker_pass { TypeCheckPass }
import from jaclang.compiler.passes.transform { Transform }
import from unittest.mock { patch }

glob VIRTUAL_PATH: str = os.path.join(
         TESTS_DIR, "compiler", "fixtures", "_lifetime_probe.jac"
     ),
     SOURCE: str = (
         "obj Point {\n"
         "    has x: int = 0,\n"
         "        y: int = 0;\n"
         "}\n"
         "\n"
         "def total(p: Point) -> int {\n"
         "    return p.x + p.y;\n"
         "}\n"
         "\n"
         "with entry {\n"
         "    print(total(Point(x=1, y=2)));\n"
         "}\n"
     );

def compile_once -> JacProgram {
    prog = JacProgram();
    prog.compile(
        file_path=VIRTUAL_PATH,
        use_str=SOURCE,
        options=CompileOptions(no_cgen=True, force_target_program=True)
    );
    return prog;
}

test "a compiled program is released once its owner drops it" {
    holder: list = [compile_once()];
    ref = weakref.ref(holder[0]);
    holder.clear();
    gc.collect();
    assert ref() is None , (
        "the compiled JacProgram outlived its only owner: something long-lived "
        "still holds the compilation unit, so every AST and IR object it built "
        "stays resident for the life of the process"
    );
}

test "the evaluator does not hold the pass that ran over it" {
    prog = compile_once();
    evaluator = prog.get_type_evaluator();
    held = evaluator._pass;
    assert held is None , (
        f"type evaluator still points at {type(held).__name__} after the pass "
        "finished; that back-pointer pins the pass's whole program graph"
    );
}

test "failed checker phases restore the enclosing diagnostic context" {
    prog = compile_once();
    mod = prog.mod.main_mod;
    assert mod is not None;
    evaluator = prog.get_type_evaluator();
    enclosing = Transform(ir_in=mod);
    evaluator._pass = enclosing;
    evaluator.ct_quiet = True;
    try {
        for phase in ["_insert_builtin_symbols", "traverse", "_stamp_fixed_width"] {
            failed = False;
            with patch.object(
                TypeCheckPass, phase, side_effect=RuntimeError("phase failure")
            ) {
                try {
                    run_pass(TypeCheckPass, mod, prog=prog);
                } except RuntimeError as error {
                    assert str(error) == "phase failure";
                    failed = True;
                }
            }
            assert failed , phase;
            assert evaluator._pass is enclosing , phase;
            assert evaluator.ct_quiet , phase;
        }
    } finally {
        evaluator._pass = None;
    }
}
