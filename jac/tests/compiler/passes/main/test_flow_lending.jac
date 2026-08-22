"""Scoped lending across flow bounded by wait (#7857 Phase D).

A `&`/`&mut` of an owner may cross a flow boundary when the checker sees
the matching wait barrier before any conflicting use of the owner in the
same block -- the join is the borrow's extent, and no annotation names
it. Without a same-block join, or with the owner touched between spawn
and join, the payload stays unsendable (E1308).
"""

import from tests.ownership_helpers { compile_fixture, expect_ownership_codes }

test "borrow into flow with a same-block wait before reuse is clean" {
    prog = compile_fixture("flow_lend_ok.jac");
    expect_ownership_codes(prog, []);
}

test "borrow into flow with no join stays E1308" {
    prog = compile_fixture("flow_lend_no_wait.jac");
    expect_ownership_codes(prog, ["E1308"]);
}

test "owner touched between flow and wait stays E1308" {
    prog = compile_fixture("flow_lend_use_before_wait.jac");
    expect_ownership_codes(prog, ["E1308"]);
}

test "side exit between spawn and wait stays E1308" {
    prog = compile_fixture("flow_lend_early_exit.jac");
    expect_ownership_codes(prog, ["E1308"]);
}
