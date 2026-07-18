"""Cross-module virtual-dispatch conformance for the jac2c Emit leg of #7145.

`xmod_main.jac` imports `Shape` from `xmod_base.jac` and subclasses it as `Sq`,
overriding only `speak`. The base `who` is compiled in xmod_base's translation
unit yet calls `self.speak()` virtually, so a `Sq(100).who()` must re-dispatch
across the module boundary back into `Sq__speak` in the importing unit. That
only works when both translation units agree on the vtable slot numbering, which
is precisely what a single whole-program shared layout registry guarantees.

`emit_translation_units` (reached here via `emit_support.emit_units`) is the
backend orchestrator both the CLI and these tests consume: it discovers the
import graph, builds one shared layout over every module, then re-emits each
unit against that shared layout.

Differential oracle (shared with the other emit-leg tests via `emit_support`):
the emitted translation units are linked with jacrt and a generated driver, and
their runtime output is compared against the stock Jac interpreter running the
same importing module. The expected output is derived from one shared `CALLS`
list on both sides, so nothing is hand-asserted.
"""

import os;
import from tests.compiler.c2jac.emit_support {
    cc,
    emit_units,
    link_and_run,
    interpreter_run
}

glob MAIN: str = "xmod_main.jac",
     BASE: str = "xmod_base.jac",
     CALLS: list[str] = ["run_base", "run_derived"];


test "jac2c cross-module vtable slots agree across translation units" {
    units = emit_units(MAIN);
    assert len(units) == 2 , f"expected 2 translation units, got {len(units)}";
    by_name: dict = {};
    for (path, src) in units {
        by_name[os.path.basename(path)] = src;
    }
    assert BASE in by_name , f"base TU {BASE!r} not emitted: {list(by_name.keys())}";
    assert MAIN in by_name , f"main TU {MAIN!r} not emitted: {list(by_name.keys())}";
    base_c = by_name[BASE];
    main_c = by_name[MAIN];

    # The defining unit emits the base's vtable; the whole-program shared layout
    # is what marks `Shape` vtable-bearing even though no subclass lives here.
    assert "Shape__vtable[" in base_c , f"base TU missing Shape__vtable:\n{base_c}";

    # The importing unit's extern struct must carry the vtable pointer as its
    # first member so the cross-TU object layout matches the defining unit.
    assert "struct Shape {" in main_c , f"main TU missing extern struct Shape:\n{main_c}";
    vptr_at = main_c.find("void **__vtable;");
    assert vptr_at != -1 , f"main TU extern struct Shape lacks vtable pointer:\n{main_c}";

    # The base `who`, compiled in the base TU, dispatches self.speak() virtually.
    assert "jac_vtable_slot(" in base_c , f"base TU has no virtual call site:\n{base_c}";
}


test "jac2c cross-module virtual dispatch matches the stock interpreter" {
    if cc() is None {
        return;
    }
    c_out = link_and_run(emit_units(MAIN), CALLS);
    py_out = interpreter_run([MAIN, BASE], MAIN, CALLS);
    assert c_out == py_out , f"cross-module emitted-C {c_out!r} != interpreter {py_out!r}";
}
