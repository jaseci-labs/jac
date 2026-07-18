"""Module-qualified type identity (A3) for the jac2c Emit leg.

`a3_col_main.jac` and `a3_col_lib.jac` BOTH declare an `obj Token`, with
different shapes and a `score()` method of different semantics. Before A3 the
shared TypeFacts/LayoutRegistry merged them first-wins by bare name, so one
module silently inherited the other's fields and ref-ness. jac2c now keys every
type by a module-qualified `tid`: same-named types across modules emit distinct
`a3_col_main__Token` / `a3_col_lib__Token` structs, constructors, and methods,
and each reference (local decl, import alias, cross-module return) resolves to
the right one. A type name that is unique across the program still keeps its
bare name, so single-module emission is byte-identical (guarded by the rest of
the emit-leg corpus).

The differential oracle (shared via `emit_support`) links the emitted TUs and
compares their runtime output against the stock interpreter, so the coexistence
is proven behaviorally, not just structurally.
"""

import from tests.compiler.c2jac.emit_support {
    cc,
    emit_units,
    unit_src,
    link_and_run,
    interpreter_run
}

glob MAIN: str = "a3_col_main.jac",
     LIB: str = "a3_col_lib.jac",
     CALLS: list[str] = ["run_local", "run_lib", "run_mixed"];


test "jac2c emits distinct module-qualified structs for same-named types" {
    main_c = unit_src(MAIN, MAIN);
    # Both Tokens coexist as distinct mangled structs -- the local one with
    # line/col, the imported one forward-declared with kind/weight.
    for needle in [
        "struct a3_col_main__Token {",
        "struct a3_col_lib__Token {",
        "int line;",
        "int kind;",
        "a3_col_main__Token__new(",
        "a3_col_lib__Token__new(",
        "a3_col_main__Token__score(",
        "a3_col_lib__Token__score(",
        "extern struct a3_col_lib__Token * lib_make("
    ] {
        assert needle in main_c , f"missing {needle!r} in:\n{main_c}";
    }
    # The bare name must NOT survive for a collided type: no unqualified
    # `struct Token` (word-boundary guarded by the trailing space/brace).
    assert "struct Token " not in main_c , f"bare colliding struct leaked:\n{main_c}";
    assert "unsupported" not in main_c , f"unsupported nodes remain:\n{main_c}";
}


test "jac2c name-collision linked binary matches the stock interpreter" {
    if cc() is None {
        return;
    }
    c_out = link_and_run(emit_units(MAIN), CALLS);
    py_out = interpreter_run([MAIN, LIB], MAIN, CALLS);
    assert c_out == py_out , f"collision emitted-C {c_out!r} != interpreter {py_out!r}";
}
