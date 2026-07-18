"""Multi-module emit conformance for the jac2c Emit leg of #7145.

`mod_main.jac` imports a ref-type `Counter` and a free function `add` from
`mod_lib.jac` and uses them across the module boundary. jac2c must emit each
module as its own C translation unit: the importing unit forward-declares the
imported struct and `extern`s its constructor, methods, and the free function,
then resolves every cross-module `Counter(...)` / `c.bump()` / `c.get()` /
`add(...)` to the same mangled `Counter__new` / `Counter__bump` / `Counter__get`
/ `add` symbols the defining unit emits.

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

glob MAIN: str = "mod_main.jac",
     LIB: str = "mod_lib.jac",
     CALLS: list[str] = ["run_cross", "run_get"];


test "jac2c cross-module emission resolves imported types and functions" {
    main_c = unit_src(MAIN, MAIN);
    # The importing TU forward-declares the imported struct and externs its
    # constructor, methods, and the free function, then calls the mangled
    # cross-module symbols rather than emitting raw Jac names.
    for needle in [
        "struct Counter {",
        "extern struct Counter *Counter__new(int start);",
        "extern int Counter__bump(struct Counter *self);",
        "extern int add(int x, int y);",
        "Counter__new(10)",
        "Counter__bump(",
        "add("
    ] {
        assert needle in main_c , f"missing {needle!r} in:\n{main_c}";
    }
    assert "unsupported" not in main_c , f"unsupported nodes remain:\n{main_c}";
}


test "jac2c multi-module linked binary matches the stock interpreter" {
    if cc() is None {
        return;
    }
    c_out = link_and_run(emit_units(MAIN), CALLS);
    py_out = interpreter_run([MAIN, LIB], MAIN, CALLS);
    assert c_out == py_out , f"multi-module emitted-C {c_out!r} != interpreter {py_out!r}";
}
