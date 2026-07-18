"""Transitive multi-module emit conformance for the jac2c Emit leg of #7145.

`chain_main.jac` imports `make_cell` from `chain_mid.jac`, which in turn imports
the ref-type `Cell` from `chain_leaf.jac`. `chain_main` never names `chain_leaf`,
yet it receives and drives a `Cell` value across two module boundaries. jac2c
must walk the import graph transitively so `chain_main`'s translation unit
forward-declares `struct Cell` and `extern`s `Cell__bump` / `Cell__get`, and so
whole-program facts/layout cover the leaf module. A direct-imports-only walk
would leave `Cell` unresolved in the top unit and mis-lower `w.bump()`.

Differential oracle (shared with the other emit-leg tests via `emit_support`):
every translation unit is linked with jacrt and a generated driver, and its
runtime output is compared against the stock Jac interpreter running the same
top module. The expected output is derived from one shared `CALLS` list on both
sides, so nothing is hand-asserted.
"""

import os;
import from tests.compiler.c2jac.emit_support {
    cc,
    emit_units,
    unit_src,
    link_and_run,
    interpreter_run
}

glob MAIN: str = "chain_main.jac",
     MID: str = "chain_mid.jac",
     LEAF: str = "chain_leaf.jac",
     CALLS: list[str] = ["run_chain", "run_sum"];


test "jac2c emits a translation unit for every module in the import chain" {
    units = emit_units(MAIN);
    paths = [os.path.basename(p) for (p, _) in units];
    for fx in [MAIN, MID, LEAF] {
        assert fx in paths , f"{fx} missing from emitted units {paths}";
    }
}


test "jac2c transitive import resolves a leaf type reached through the middle module" {
    main_c = unit_src(MAIN, MAIN);
    # The top TU never imports chain_leaf directly, yet must forward-declare the
    # leaf struct and extern its methods, and lower the method calls to the
    # mangled cross-module symbols rather than emitting raw Jac names.
    for needle in [
        "struct Cell {",
        "extern int Cell__bump(struct Cell *self);",
        "extern int Cell__get(struct Cell *self);",
        "extern struct Cell * make_cell(int start);",
        "Cell__bump(",
        "Cell__get(",
        "make_cell("
    ] {
        assert needle in main_c , f"missing {needle!r} in:\n{main_c}";
    }
    assert "unsupported" not in main_c , f"unsupported nodes remain:\n{main_c}";
}


test "jac2c transitive-chain linked binary matches the stock interpreter" {
    if cc() is None {
        return;
    }
    c_out = link_and_run(emit_units(MAIN), CALLS);
    py_out = interpreter_run([MAIN, MID, LEAF], MAIN, CALLS);
    assert c_out == py_out , f"transitive emitted-C {c_out!r} != interpreter {py_out!r}";
}
