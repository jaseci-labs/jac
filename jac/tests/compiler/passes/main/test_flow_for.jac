"""flow for -- the disjoint-partition loop (#7857 Phase C/D surface).

The existing `flow` modifier applied to the existing loop: the body runs
per element over a lent collection, the closing brace is the join, and
the checker enforces exactly that shape -- the collection must be `&xs`
or `&mut xs`, control flow may not cross the join (E1313 on
break/return; continue is fine), nesting is rejected for now, and body
captures follow the sendability rule (E1308 on shared mutation or
non-sendable reads). Execution is currently sequential on both backends
(the same degenerate lowering as native `flow` calls), so erasure is
byte-exact by construction; parallel execution rides the concurrency
runtime work.
"""

import from tests.ownership_helpers { compile_fixture, expect_ownership_codes }

test "lent collections with element writes and scalar captures are clean" {
    prog = compile_fixture("flow_for_ok.jac");
    expect_ownership_codes(prog, []);
}

test "break out of the body is E1313, inner-loop break is fine" {
    prog = compile_fixture("flow_for_break.jac");
    expect_ownership_codes(prog, ["E1313"]);
}

test "return in the body is E1313" {
    prog = compile_fixture("flow_for_return.jac");
    expect_ownership_codes(prog, ["E1313"]);
}

test "shared-mutation captures are E1308" {
    prog = compile_fixture("flow_for_capture.jac");
    expect_ownership_codes(prog, ["E1308", "E1308"]);
}

test "reduction idiom: += and min/max folds on outer ints are clean" {
    prog = compile_fixture("flow_for_reduce.jac");
    expect_ownership_codes(prog, []);
}

test "unlicensed accumulator shapes remain E1308" {
    prog = compile_fixture("flow_for_reduce_bad.jac");
    expect_ownership_codes(prog, ["E1308", "E1308", "E1308", "E1308"]);
}

test "nested flow for is E1313" {
    prog = compile_fixture("flow_for_nested.jac");
    expect_ownership_codes(prog, ["E1313"]);
}

test "non-lent collection is E1313" {
    prog = compile_fixture("flow_for_plain.jac");
    expect_ownership_codes(prog, ["E1313"]);
}
