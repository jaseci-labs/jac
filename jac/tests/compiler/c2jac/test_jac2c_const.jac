"""Module-constant emit conformance for the jac2c Emit leg of #7145.

`const_main.jac` imports a module-level constant `LIMIT` from `const_lib.jac`
and references it across the module boundary. jac2c must carry an imported
module's module-level constants into the generated translation unit: the
defining TU emits `LIMIT` with external linkage and the importing TU `extern`s
it, so `return LIMIT;` resolves to the same symbol instead of an undefined one.
The importing module's own constant `LOCAL_MAX` is emitted as a file-scope
definition in its own TU.

Differential oracle (shared with the other emit-leg tests via `emit_support`):
the emitted translation units are linked with jacrt and a generated driver, and
their runtime output is compared against the stock Jac interpreter running the
same importing module. The expected output is derived from one shared `CALLS`
list on both sides, so nothing is hand-asserted.
"""

import from tests.compiler.c2jac.emit_support {
    cc,
    emit_units,
    unit_src,
    link_and_run,
    interpreter_run
}

glob MAIN: str = "const_main.jac",
     LIB: str = "const_lib.jac",
     CALLS: list[str] = ["run_local", "run_import", "run_call"];


test "jac2c externs an imported module-level constant and defines its own" {
    main_c = unit_src(MAIN, MAIN);
    # The importing TU externs the imported constant and defines its own.
    for needle in [
        "extern int LIMIT;",
        "int LOCAL_MAX = 7;",
        "return LIMIT;",
        "return LOCAL_MAX;",
        "scale(LIMIT)"
    ] {
        assert needle in main_c , f"missing {needle!r} in:\n{main_c}";
    }
    assert "unsupported" not in main_c , f"unsupported nodes remain:\n{main_c}";
    # The defining TU gives the constant external linkage (no `static`).
    lib_c = unit_src(MAIN, LIB);
    assert "int LIMIT = 100;" in lib_c , f"missing definition in:\n{lib_c}";
}


test "jac2c module-constant linked binary matches the stock interpreter" {
    if cc() is None {
        return;
    }
    c_out = link_and_run(emit_units(MAIN), CALLS);
    py_out = interpreter_run([MAIN, LIB], MAIN, CALLS);
    assert c_out == py_out , f"module-constant emitted-C {c_out!r} != interpreter {py_out!r}";
}
