"""Tests for the OwnershipCheckPass region-escape rule (Phase 3 P2.1, E1307).

An `in <handle> {}` region open allocates everything created inside it into
the opened region, which is freed wholesale when its handle drops. A value or
reference rooted inside the region must not escape the open block: it may not
be returned, stored into a location outside the region, or handed to a
`flow`/`wait` concurrency boundary.

The fixture-plus-expected-codes cases for this rule live in the shared
`test_ownership_codes.jac` table; what stays here asserts something that
table cannot express.
"""

import from tests.ownership_helpers { compile_fixture, expect_ownership_codes }

test "R2: a return inside a region open is not a missing-return (no E1004)" {
    # `expect_ownership_codes` only inspects E13xx, so assert the full error
    # set is empty: the type checker must count `return` inside `in r {}` as
    # a guaranteed return, not emit E1004 'may implicitly return None'.
    prog = compile_fixture("region_elision_ok.jac");
    codes = [
        a.code.code
        for a in prog.errors_had
        if a.code is not None
    ];
    assert codes == [] , f"expected no errors, got {codes}";
}
