"""Tests for OwnershipCheckPass Phase 3 P2.2 — sendability at flow/wait boundaries.

Only a deep-immutable `val` value or a moved `own` value may cross a
`flow`/`wait`/`thread_run` boundary. A live `&`/`&mut` borrow is never sendable
and reports E1308; a `val` snapshot or a moved `own` payload is fine.
"""

import from tests.ownership_helpers { compile_fixture, expect_ownership_codes }

test "E1308: a `&` borrow handed to a `flow` boundary is not sendable" {
    prog = compile_fixture("send_borrow_flow.jac");
    expect_ownership_codes(prog, ["E1308"]);
}

test "E1308: a `&mut` borrow handed to a `flow` boundary is not sendable" {
    prog = compile_fixture("send_mut_borrow.jac");
    expect_ownership_codes(prog, ["E1308"]);
}

test "a deep-immutable `val` value is sendable across a `flow` boundary" {
    prog = compile_fixture("send_val_ok.jac");
    expect_ownership_codes(prog, []);
}

test "a moved `own` value is sendable across a `flow` boundary" {
    prog = compile_fixture("send_own_moved_ok.jac");
    expect_ownership_codes(prog, []);
}

test "E1308: a plain mutable (unannotated) value passed to `flow` is not sendable" {
    prog = compile_fixture("send_plain_mutable.jac");
    expect_ownership_codes(prog, ["E1308"]);
}
