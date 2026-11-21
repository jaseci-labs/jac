"""Tests for the OwnershipCheckPass (Phase 1 — E1301 use-after-move).

Compiles fixtures with type checking (which runs the type-check schedule the
OwnershipCheckPass slots into) and asserts on the emitted E13xx diagnostics.

Each case pins the COMPLETE set of E13xx ownership codes its fixture emits, not
just one code, so any code that silently appears or disappears is caught.

Ownership here is affine (issue #6905, decision #2): a plain `own` value that is
never consumed is simply dropped at scope end and reclaimed by the managed RC/GC
floor, so that is NOT an error. A borrow-conflict or escape fixture therefore
reports only its borrow code.

The fixture-plus-expected-codes cases for this rule live in the shared
`test_ownership_codes.jac` table; what stays here asserts something that
table cannot express.
"""

import from tests.ownership_helpers { compile_fixture, render_alerts }

# Known limitation (issue #6905, deferred): a borrow captured by a closure that
# escapes its scope (`return (lambda : v)`) is not yet flagged -- closure capture
# is outside Phase 1 escape analysis. No test pins it until the feature lands.

# --- Regression: diagnostic help text is a template, formatted with the same
# kwargs as the message. E1301's help must mention the binding by name, not a
# literal {name} placeholder. ----------------------------------------------
test "E1301 help text substitutes the binding name, not a literal placeholder" {
    prog = compile_fixture("use_after_move.jac");
    alerts = [
        a
        for a in {*(list(prog.errors_had) + list(prog.warnings_had))}
        if a.code is not None and a.code.code == "E1301"
    ];
    assert len(alerts) == 1 , "expected exactly one E1301 alert";
    rendered = alerts[0].pretty_print();
    assert "'a' is an `own` binding" in rendered , "help text not formatted with the binding name";
    assert "{name}" not in rendered , "literal {name} placeholder leaked into rendered help text";
}

# --- Regression: a borrow expression (&x / &mut x) type-checks as its operand,
# not <Unknown>. Otherwise valid borrow code spuriously fails with E1001/E1053
# "Cannot assign <Unknown> ...", which used to mask the borrow checker behind
# unrelated type noise. -------------------------------------------------------
test "a borrow-typed program type-checks with no errors" {
    prog = compile_fixture("param_borrow_passthrough_ok.jac");
    assert len(prog.errors_had) == 0 , f"expected no errors; got:\n  {render_alerts(
        prog
    )}";
}

test "a borrow-conflict fixture reports only its ownership code, no type fallout" {
    prog = compile_fixture("two_mut_aliases.jac");
    fallout = [
        a
        for a in list(prog.errors_had)
        if a.code is not None and not a.code.code.startswith("E13")
    ];
    assert len(fallout) == 0 , f"unexpected non-ownership errors: {render_alerts(
        prog
    )}";
}
