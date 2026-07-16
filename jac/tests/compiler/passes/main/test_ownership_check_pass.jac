"""Tests for the OwnershipCheckPass (Phase 1 — E1301 use-after-move).

Compiles fixtures with type checking (which runs the type-check schedule the
OwnershipCheckPass slots into) and asserts on the emitted E13xx diagnostics.

Each test pins the COMPLETE set of E13xx ownership codes its fixture emits, not
just one code, so any code that silently appears or disappears is caught.

Ownership here is affine (issue #6905, decision #2): a plain `own` value that is
never consumed is simply dropped at scope end and reclaimed by the managed RC/GC
floor, so that is NOT an error. A borrow-conflict or escape fixture therefore
reports only its borrow code.
"""

import from tests.ownership_helpers {
    compile_fixture,
    ownership_codes,
    render_alerts,
    expect_ownership_codes
}

test "E1301: use of an own binding after it is moved" {
    prog = compile_fixture("use_after_move.jac");
    expect_ownership_codes(prog, ["E1301"]);
}

test "a binding that is moved but never read again is clean" {
    prog = compile_fixture("move_only_ok.jac");
    expect_ownership_codes(prog, []);
}

test "reassigning a moved-from own binding revives it (no diagnostics)" {
    prog = compile_fixture("reassign_revives.jac");
    expect_ownership_codes(prog, []);
}

test "un-annotated bindings are never move-checked" {
    prog = compile_fixture("unannotated_untouched.jac");
    expect_ownership_codes(prog, []);
}

test "E1301: a conditional move reaching a later use is flagged" {
    prog = compile_fixture("branch_use_after_move.jac");
    expect_ownership_codes(prog, ["E1301"]);
}

test "mutually-exclusive branches each moving the binding is clean" {
    prog = compile_fixture("branch_exclusive_ok.jac");
    expect_ownership_codes(prog, []);
}

test "a conditionally-moved binding that is not used afterwards is clean" {
    prog = compile_fixture("branch_no_use_ok.jac");
    expect_ownership_codes(prog, []);
}

# --- Borrow states (E1302–E1304): borrow conflicts. Each fixture reports ONLY
# its borrow code — the un-consumed owner is affinely dropped, not a leak. ------
test "E1302: two live mutable borrows conflict" {
    prog = compile_fixture("two_mut_aliases.jac");
    expect_ownership_codes(prog, ["E1302"]);
}

test "E1303: mutating an owner while a shared borrow is live" {
    prog = compile_fixture("mutate_while_shared.jac");
    expect_ownership_codes(prog, ["E1303"]);
}

test "E1304: destroying an owner while borrowed" {
    prog = compile_fixture("destroy_while_borrowed.jac");
    expect_ownership_codes(prog, ["E1304"]);
}

test "affine: an own value dropped at scope end is not a leak" {
    prog = compile_fixture("owned_leak.jac");
    expect_ownership_codes(prog, []);
}

test "an own resource handed off before scope end is clean" {
    prog = compile_fixture("owned_consumed_ok.jac");
    expect_ownership_codes(prog, []);
}

# --- Escaping borrows (E1306): a borrow may not outlive its creating scope ----
test "E1306: returning a borrow escapes its scope" {
    prog = compile_fixture("escaping_borrow_return.jac");
    expect_ownership_codes(prog, ["E1306"]);
}

test "E1306: storing a borrow into a field escapes its scope" {
    prog = compile_fixture("escaping_borrow_field.jac");
    expect_ownership_codes(prog, ["E1306"]);
}

test "moving the owned value out by return is clean" {
    prog = compile_fixture("return_move_ok.jac");
    expect_ownership_codes(prog, []);
}

# --- Borrow-typed parameters: returning a borrow rooted at a borrow parameter
# is the one allowed escape (P1.1 passthrough) --------------------------------
test "returning a borrow parameter (single passthrough) is clean" {
    prog = compile_fixture("param_borrow_passthrough_ok.jac");
    expect_ownership_codes(prog, []);
}

test "an own parameter consumed by return is clean (no E1301 re-use)" {
    prog = compile_fixture("own_param_consumed_ok.jac");
    expect_ownership_codes(prog, []);
}

test "affine: an own parameter dropped at function end is not a leak" {
    prog = compile_fixture("own_param_leak.jac");
    expect_ownership_codes(prog, []);
}

# --- Fuller escape routes (P1.1): flow boundary, subscript slot, outer scope --
test "E1308: a borrow handed to a `flow` boundary is not sendable" {
    prog = compile_fixture("escaping_borrow_flow.jac");
    expect_ownership_codes(prog, ["E1308"]);
}

test "E1306: storing a borrow into a subscript slot escapes" {
    prog = compile_fixture("escaping_borrow_subscript.jac");
    expect_ownership_codes(prog, ["E1306"]);
}

test "E1306: a borrow assigned into an outer scope outlives its owner" {
    prog = compile_fixture("escaping_borrow_outlives_owner.jac");
    # E1304 must NOT fire here: the owner is still in scope at the use site; it
    # is the borrow that escapes, not the owner being destroyed while borrowed.
    expect_ownership_codes(prog, ["E1306"]);
}

# --- Membrane (P1.2): sealing an own value into managed storage moves it in;
# the source is consumed, so it neither is re-used (E1301) nor escapes (E1306). -
test "sealing an owned value into a managed field is clean" {
    prog = compile_fixture("membrane_seal_in_ok.jac");
    expect_ownership_codes(prog, []);
}

test "E1301: reading an owned value after it is sealed into managed storage" {
    prog = compile_fixture("membrane_use_after_seal.jac");
    expect_ownership_codes(prog, ["E1301"]);
}

# --- Loop-depth rule (P0.3): moving a pre-loop own binding inside a loop is
# rejected; it would be consumed on the first iteration, invalid thereafter. ---
test "E1301: moving a pre-loop own binding inside a loop body is rejected" {
    prog = compile_fixture("move_in_loop.jac");
    expect_ownership_codes(prog, ["E1301"]);
}

test "a pre-loop own binding only read (not moved) in a loop is clean" {
    prog = compile_fixture("read_in_loop_ok.jac");
    expect_ownership_codes(prog, []);
}

# --- Intra-statement moves (E1301): a single statement is one CFG node, so a
# value consumed by one sub-expression and re-used by a later one in the SAME
# statement must still be caught -- the entry-consumed set can't see it. -------
test "E1301: an own value passed twice to one call is moved twice" {
    prog = compile_fixture("intra_stmt_double_move_call.jac");
    expect_ownership_codes(prog, ["E1301"]);
}

test "E1301: an own value moved then read within one statement" {
    prog = compile_fixture("intra_stmt_move_then_read.jac");
    expect_ownership_codes(prog, ["E1301"]);
}

test "a method receiver read alongside a moved argument is clean (one move)" {
    prog = compile_fixture("method_recv_and_arg_ok.jac");
    expect_ownership_codes(prog, []);
}

# --- Move-out from under a live borrow (E1304): relocating an owner while a
# borrow of it is still live-and-reaching leaves the borrow dangling. This is
# the mid-scope move form of "destroyed while borrowed"; the scope-exit form is
# covered by destroy_while_borrowed.jac. --------------------------------------
test "E1304: moving an owner out while a borrow of it is still live" {
    prog = compile_fixture("move_while_borrowed.jac");
    expect_ownership_codes(prog, ["E1304"]);
}

test "moving an owner after its borrow is dead (NLL) is clean" {
    prog = compile_fixture("move_after_borrow_dead_ok.jac");
    expect_ownership_codes(prog, []);
}

# Known limitation (issue #6905, deferred): a borrow captured by a closure that
# escapes its scope (`return (lambda : v)`) is not yet flagged -- closure capture
# is outside Phase 1 escape analysis. No test pins it until the feature lands.

# --- The ownership checker is diagnostics-only: a consumed, never-borrowed own
# binding is sound and must raise no ownership codes. RC move-lowering for this
# shape is proven independently by the core `RcFactsPass` and is covered
# in `tests/compiler/passes/native/test_move_elision.jac`; the checker no longer
# writes any backend-consumed fact. --------------------------------------------
test "a consumed, unborrowed own binding raises no ownership diagnostics" {
    expect_ownership_codes(compile_fixture("proven_unique_ok.jac"), []);
}

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
