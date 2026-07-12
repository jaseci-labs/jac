"""Structural runtime-ABI conformance for the Emit leg (jac2c) of #7145.

Proves the *shape* of the C the backend emits for reference-semantic Jac
objects: heap objects behind the jacrt RC header, `init` constructors,
per-class vtables and virtual dispatch, string and exception lowering to the
runtime, and the OwnershipFacts-driven move/copy calling conventions.

Behavioral equivalence of these same fixtures is proven differentially against
the stock Jac interpreter in `test_jac2c_differential.jac` (shared oracle in
`emit_support`), so nothing here pins runtime output to a hand-computed
constant. The only executions kept in this module are the refcount-balance
checks: they assert `jac_rc_live() == 0` after the calls run -- a property the
interpreter reference cannot express -- while still deriving the value half of
the output from the interpreter.
"""

import from tests.compiler.c2jac.emit_support {
    cc,
    emit_units,
    interpreter_run,
    link_and_run,
    unit_src
}


def _fn_body(c_src: str, sig: str) -> str {
    start = c_src.find(sig + " {");
    assert start >= 0 , f"function {sig!r} not found";
    end = c_src.find("\n}", start);
    return c_src[start:end];
}


test "jac2c emits RC objects, constructors, methods, and balanced retain/release" {
    c_src = unit_src("obj_rc.jac", "obj_rc.jac");
    for needle in [
        "#include \"jacrt.h\"",
        "struct Counter *Counter__new(int start)",
        "jac_rc_alloc(sizeof(struct Counter)",
        "int Counter__bump(struct Counter *self)",
        "self->n = (self->n + 1)",
        "return Counter__get(self->c)",
        "jac_rc_retain(",
        "jac_rc_release(self->c)",
        "jac_rc_release(c)"
    ] {
        assert needle in c_src , f"missing {needle!r} in:\n{c_src}";
    }
    assert "unsupported" not in c_src , f"unsupported nodes remain:\n{c_src}";
}

test "jac2c emits per-class vtables and virtual dispatch for inheritance" {
    c_src = unit_src("obj_poly.jac", "obj_poly.jac");
    for needle in [
        "void **__vtable;",
        "static void *Animal__vtable[]",
        "static void *Dog__vtable[]",
        "(void *)Dog__speak",
        "(void *)Animal__who",
        "jac_vtable_slot(self->__vtable,",
        "self->__vtable = Dog__vtable;"
    ] {
        assert needle in c_src , f"missing {needle!r} in:\n{c_src}";
    }
    assert "unsupported" not in c_src , f"unsupported nodes remain:\n{c_src}";
}

test "jac2c lowers string concat, equality, and length to the runtime" {
    c_src = unit_src("str_ops.jac", "str_ops.jac");
    for needle in ["jac_str_concat(\"ab\", \"cd\")", "jac_str_len(", "jac_str_eq("] {
        assert needle in c_src , f"missing {needle!r} in:\n{c_src}";
    }
    assert "unsupported" not in c_src , f"unsupported nodes remain:\n{c_src}";
}

test "jac2c lowers try/except/raise to the setjmp runtime" {
    c_src = unit_src("exceptions.jac", "exceptions.jac");
    for needle in [
        "jac_exc_frame ",
        "setjmp(",
        "jac_exc_push(",
        "jac_exc_throw(",
        "jac_exc_current_type()",
        "jac_exc_clear();"
    ] {
        assert needle in c_src , f"missing {needle!r} in:\n{c_src}";
    }
    assert "unsupported" not in c_src , f"unsupported nodes remain:\n{c_src}";
}

test "jac2c uses OwnershipFacts callee conventions to move or copy across calls" {
    c_src = unit_src("obj_move.jac", "obj_move.jac");
    # Holder stores a fresh Counter(5): owned -> moved, no retain.
    holder = _fn_body(c_src, "struct Holder *Holder__new(void)");
    assert "Counter__new(5)" in holder , f"missing constructor store:\n{holder}";
    assert "jac_rc_retain(" not in holder , f"owned store should move, not retain:\n{holder}";
    # Wrap consumes its parameter (stored once, used nowhere else): the callee
    # takes ownership, so no retain on store.
    wrap = _fn_body(c_src, "struct Wrap *Wrap__new(struct Counter * inner)");
    assert "jac_rc_retain(" not in wrap , f"consumed param should move, not retain:\n{wrap}";
    # Keep also reads its parameter, so it only borrows: retain on store.
    keep = _fn_body(c_src, "struct Keep *Keep__new(struct Counter * inner)");
    assert "jac_rc_retain(" in keep , f"borrowed param should retain:\n{keep}";
    # Caller: the owned Counter(9) moves into the consuming Wrap (passed inline,
    # no temp), while the owned Counter(4) handed to the borrowing Keep is hoisted
    # into a temp and released after the call.
    run = _fn_body(c_src, "int run_move(void)");
    assert "Wrap__new(Counter__new(9))" in run , f"consumed arg should move inline:\n{run}";
    assert "jac_rc_release(_arg" in run , f"borrowed owned arg should be released:\n{run}";
}

test "jac2c callee-convention moves and copies stay balanced under cc" {
    if cc() is None {
        return;
    }
    calls = ["run_move"];
    c_out = link_and_run(emit_units("obj_move.jac"), calls, rc_live=True);
    py_out = interpreter_run(["obj_move.jac"], "obj_move.jac", calls);
    # The value half of the line must match the stock interpreter; the trailing
    # jac_rc_live() == 0 proves every allocation was released exactly once (the
    # earlier Wrap(Counter(9)) leak would have left it positive).
    assert c_out == f"{py_out} 0" , f"got {c_out!r}, want {py_out!r} + ' 0'";
}

test "jac2c copies an aliased reference local but moves it at its last use" {
    c_src = unit_src("obj_alias.jac", "obj_alias.jac");
    # run_alias: `b = a` with a used again -> co-own via retain.
    alias = _fn_body(c_src, "int run_alias(void)");
    assert "jac_rc_retain(b)" in alias , f"aliased copy should retain:\n{alias}";
    # run_transfer: `b = a` at a's last use -> move, no retain, a not released.
    transfer = _fn_body(c_src, "int run_transfer(void)");
    assert "jac_rc_retain(" not in transfer , f"last-use copy should move:\n{transfer}";
    assert "jac_rc_release(a)" not in transfer , f"moved source must not be released:\n{transfer}";
}

test "jac2c reference-local aliasing is refcount-balanced under cc" {
    if cc() is None {
        return;
    }
    calls = ["run_alias", "run_transfer"];
    c_out = link_and_run(emit_units("obj_alias.jac"), calls, rc_live=True);
    py_out = interpreter_run(["obj_alias.jac"], "obj_alias.jac", calls);
    # run_alias would double-free without the aliased retain; run_transfer would
    # leak without the last-use move. Values match the interpreter and the
    # trailing jac_rc_live() == 0 proves both stay balanced.
    assert c_out == f"{py_out} 0" , f"got {c_out!r}, want {py_out!r} + ' 0'";
}
