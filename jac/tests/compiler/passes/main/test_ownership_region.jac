"""Tests for the OwnershipCheckPass region-escape rule (Phase 3 P2.1 — E1307).

A `region {}` arena owns everything allocated inside it and frees the whole
arena at the closing brace. A value/reference rooted inside the region must not
escape it: it may not be returned, stored into a location outside the region, or
handed to a `flow`/`wait` concurrency boundary. Each test pins the COMPLETE set
of E13xx codes its fixture emits.

"""

import from tests.ownership_helpers { compile_fixture, expect_ownership_codes }

test "E1307: a region-local returned from its function escapes the arena" {
    expect_ownership_codes(compile_fixture("region_escape_return.jac"), ["E1307"]);
}

test "E1307: a region-local stored into an outer object escapes the arena" {
    expect_ownership_codes(compile_fixture("region_escape_store.jac"), ["E1307"]);
}

test "E1307: a region-local handed to a `flow` boundary escapes the arena" {
    expect_ownership_codes(compile_fixture("region_escape_flow.jac"), ["E1307"]);
}

test "E1307: a region-local assigned to an enclosing-scope binding escapes" {
    expect_ownership_codes(compile_fixture("region_escape_outer.jac"), ["E1307"]);
}

test "a region-local used only inside its region is clean" {
    expect_ownership_codes(compile_fixture("region_ok.jac"), []);
}

test "E1307: a region-local returned inside a list literal escapes the arena" {
    expect_ownership_codes(compile_fixture("region_escape_list.jac"), ["E1307"]);
}

test "E1307: a region-local stored via a tuple into an outer binding escapes" {
    expect_ownership_codes(compile_fixture("region_escape_tuple_store.jac"), ["E1307"]);
}

test "a container of a region-local kept inside the region is clean" {
    expect_ownership_codes(compile_fixture("region_container_local_ok.jac"), []);
}

# Default-deny: a region-local routed through an opaque call in an escaping
# position is an escape. The old container-literal whitelist saw through list/
# tuple/dict literals only and silently passed `return wrap(x)` — a latent
# use-after-free once the arena is freed. The place collector treats a call's
# result as aliasing its arguments, so this is now caught.
test "E1307: a region-local passed through a call in a return escapes" {
    expect_ownership_codes(
        compile_fixture("region_escape_through_call.jac"), ["E1307"]
    );
}
