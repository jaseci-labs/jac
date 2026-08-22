"""Frozen-region traversals (#7857 Phase D).

freeze of an owned Region handle consumes it and transfers handle-ness:
the imm result deep-freezes the subgraph and crosses flow freely under
the existing imm sendability rule, opening it for allocation is mutation
through imm (E1309), and reopening the consumed source is E1301.
"""

import from tests.ownership_helpers { compile_fixture, expect_ownership_codes }

test "frozen handle crosses flow freely" {
    prog = compile_fixture("frozen_region_ok.jac");
    expect_ownership_codes(prog, []);
}

test "opening a frozen region is E1309" {
    prog = compile_fixture("frozen_region_open.jac");
    expect_ownership_codes(prog, ["E1309"]);
}

test "reopening the consumed source handle is E1301" {
    prog = compile_fixture("frozen_region_stale_handle.jac");
    expect_ownership_codes(prog, ["E1301"]);
}
