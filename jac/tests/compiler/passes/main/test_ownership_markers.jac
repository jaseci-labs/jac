"""Tests for the OwnershipCheckPass `val` marker (Phase 3 P2.3).

`val` marks a deep-immutable binding: reassigning it, writing one of its fields,
or taking a `&mut` through it is a mutation and raises E1309. Reading it is fine.

"""

import from tests.ownership_helpers { compile_fixture, expect_ownership_codes }

test "E1309: reassigning a `val` binding is a mutation" {
    expect_ownership_codes(compile_fixture("marker_val_reassign.jac"), ["E1309"]);
}

test "E1309: writing a field of a `val` binding is a mutation" {
    expect_ownership_codes(compile_fixture("marker_val_field_write.jac"), ["E1309"]);
}

test "E1309: taking a `&mut` through a `val` binding is a mutation" {
    expect_ownership_codes(compile_fixture("marker_val_mut_borrow.jac"), ["E1309"]);
}

test "reading a `val` binding (field read, passthrough) is clean" {
    expect_ownership_codes(compile_fixture("marker_val_read_ok.jac"), []);
}
