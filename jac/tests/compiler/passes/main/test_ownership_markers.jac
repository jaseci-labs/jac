"""Tests for the OwnershipCheckPass `imm` marker (Phase 3 P2.3).

`imm` marks a deep-immutable binding: reassigning it, writing one of its fields,
or taking a `&mut` through it is a mutation and raises E1309. Reading it is fine.

"""

import from tests.ownership_helpers { compile_fixture, expect_ownership_codes }

test "E1309: reassigning an `imm` binding is a mutation" {
    expect_ownership_codes(compile_fixture("marker_imm_reassign.jac"), ["E1309"]);
}

test "E1309: writing a field of an `imm` binding is a mutation" {
    expect_ownership_codes(compile_fixture("marker_imm_field_write.jac"), ["E1309"]);
}

test "E1309: taking a `&mut` through an `imm` binding is a mutation" {
    expect_ownership_codes(compile_fixture("marker_imm_mut_borrow.jac"), ["E1309"]);
}

test "reading an `imm` binding (field read, passthrough) is clean" {
    expect_ownership_codes(compile_fixture("marker_imm_read_ok.jac"), []);
}
