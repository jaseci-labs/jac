"""Tests for path-granular borrow tracking (issue #7857 Phase A).

A borrow of `p.field` records a loan on that field, not on all of `p`, so
borrows and writes touching provably disjoint single-level fields of one
owner may coexist. Whole-object borrows still conflict with every field,
same-field overlaps stay errors, and anything deeper than one attribute
level collapses to the whole object (conservative).

Each test pins the COMPLETE set of E13xx ownership codes its fixture emits,
per the convention in test_ownership_check_pass.jac.
"""

import from tests.ownership_helpers { compile_fixture, expect_ownership_codes }

test "disjoint fields: shared borrow of one field, write to another is clean" {
    prog = compile_fixture("split_fields_disjoint_ok.jac");
    expect_ownership_codes(prog, []);
}

test "same field: write under a live shared borrow of that field is E1303" {
    prog = compile_fixture("split_fields_same_conflict.jac");
    expect_ownership_codes(prog, ["E1303"]);
}

test "disjoint fields: two mutable borrows of different fields is clean" {
    prog = compile_fixture("split_fields_two_mut_ok.jac");
    expect_ownership_codes(prog, []);
}

test "whole-object borrow still conflicts with any field write (E1303)" {
    prog = compile_fixture("split_fields_whole_conflict.jac");
    expect_ownership_codes(prog, ["E1303"]);
}

test "same field twice: overlapping mutable borrows stay E1302" {
    prog = compile_fixture("split_fields_mut_overlap_conflict.jac");
    expect_ownership_codes(prog, ["E1302"]);
}

test "deep paths collapse to the whole object (conservative E1303)" {
    prog = compile_fixture("split_fields_deep_path_conservative.jac");
    expect_ownership_codes(prog, ["E1303"]);
}
