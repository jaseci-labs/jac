"""Tests for the OwnershipCheckPass region-escape rule (Phase 3 P2.1, E1307).

An `in <handle> {}` region open allocates everything created inside it into
the opened region, which is freed wholesale when its handle drops. A value or
reference rooted inside the region must not escape the open block: it may not
be returned, stored into a location outside the region, or handed to a
`flow`/`wait` concurrency boundary. Each test pins the COMPLETE set of E13xx
codes its fixture emits.

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

# Laundering closure (#7491 R1 safety invariant): with a real arena, a bulk
# free at the drop point turns any symbol-level blind spot into use-after-
# free, so heap-typed region-locals handed to opaque callees are escapes.
test "E1307: a region-local handed to an opaque call statement escapes" {
    expect_ownership_codes(compile_fixture("region_escape_call_stmt.jac"), ["E1307"]);
}

test "E1307: a region-local appended to an outer container escapes" {
    expect_ownership_codes(
        compile_fixture("region_escape_append_outer.jac"), ["E1307"]
    );
}

test "E1307: a region-local laundered through an aug-assign escapes" {
    expect_ownership_codes(compile_fixture("region_escape_aug_store.jac"), ["E1307"]);
}

# Type-aware refinement: scalars copy by value at the boundary, and refs fed
# to a constructor allocated under the same open stay region-internal
# (decision #7), so neither is an escape.
test "a scalar field read assigned out of a region is clean" {
    expect_ownership_codes(compile_fixture("region_scalar_out_ok.jac"), []);
}

test "a region-local stored into a region-allocated object is clean" {
    expect_ownership_codes(compile_fixture("region_internal_ctor_ok.jac"), []);
}

# R2 borrow-collapse (#7491 decision #3): region-rooted values that flow to
# bindings which cannot outlive the handle become shared borrows of it, and
# helpers that receive the handle are legal carriers for them.
test "R2: outward flow to a binding within the handle's extent is clean" {
    expect_ownership_codes(compile_fixture("region_extent_ok.jac"), []);
}

test "R2: single-region elision lets a &Region helper return region values" {
    expect_ownership_codes(compile_fixture("region_elision_ok.jac"), []);
}

test "R2: E1307 with two &Region params a region-rooted return is ambiguous" {
    expect_ownership_codes(compile_fixture("region_two_region_reject.jac"), ["E1307"]);
}

test "R2: E1307 returning region values rooted in a local handle" {
    expect_ownership_codes(
        compile_fixture("region_local_handle_return_reject.jac"), ["E1307"]
    );
}

test "R2: a call receiving the handle may also take region borrows" {
    expect_ownership_codes(compile_fixture("region_helper_call_ok.jac"), []);
}

test "R2: the result of a &Region call is a usable borrow of the handle" {
    expect_ownership_codes(compile_fixture("region_call_result_ok.jac"), []);
}

test "R2: E1307 a region borrow handed to an opaque callee outside the open" {
    expect_ownership_codes(
        compile_fixture("region_borrow_launder_reject.jac"), ["E1307"]
    );
}

test "R2: E1307 a fresh heap value returned from inside an open" {
    expect_ownership_codes(
        compile_fixture("region_escape_fresh_return.jac"), ["E1307"]
    );
}

# R3 (#7491): regions are the sendable unit for graphs, and the membrane
# forbids cross-extent topology.
test "R3: an own handle with no borrows moves across a flow boundary" {
    expect_ownership_codes(compile_fixture("region_send_ok.jac"), []);
}

test "R3: E1307 sending a handle while borrows of it exist" {
    expect_ownership_codes(compile_fixture("region_send_borrow_reject.jac"), ["E1307"]);
}

test "R3: E1307 wiring a region node to managed topology" {
    expect_ownership_codes(
        compile_fixture("region_connect_membrane_reject.jac"), ["E1307"]
    );
}

test "R3: region-internal topology wires freely" {
    expect_ownership_codes(compile_fixture("region_connect_internal_ok.jac"), []);
}

# R4 (#7491): the `own` rebox is the membrane's outbound crossing -- the
# copy exits, so scalar and string reboxes are boundary-safe.
test "R4: an own rebox of a region string field is clean" {
    expect_ownership_codes(compile_fixture("region_own_rebox_ok.jac"), []);
}
