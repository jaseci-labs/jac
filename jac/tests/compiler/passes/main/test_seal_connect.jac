"""Connect-as-seal (#7857 Phase D).

Attaching region topology to a managed node -- a directed connect from a
managed anchor into a region-local node, under an open on an owned named
handle -- is the membrane seal for subgraphs: it consumes the handle and
promotes the topology into the managed world. The handle is dead
afterwards (E1301 on reuse), the open admits no graph operations after
the seal, and every non-seal wiring shape (region edge out to managed,
undirected, borrowed handle) keeps the E1307 rejection.
"""

import from tests.ownership_helpers { compile_fixture, expect_ownership_codes }

test "managed-into-region connect seals cleanly" {
    prog = compile_fixture("seal_connect_ok.jac");
    expect_ownership_codes(prog, []);
}

test "reusing the sealed handle is E1301" {
    prog = compile_fixture("seal_handle_reuse.jac");
    expect_ownership_codes(prog, ["E1301"]);
}

test "non-seal directions stay E1307" {
    prog = compile_fixture("seal_wrong_direction.jac");
    expect_ownership_codes(prog, ["E1307", "E1307"]);
}

test "seal through a borrowed handle stays E1307" {
    prog = compile_fixture("seal_borrowed_handle.jac");
    expect_ownership_codes(prog, ["E1307"]);
}

test "graph operations after the seal are E1307" {
    prog = compile_fixture("seal_post_alloc.jac");
    expect_ownership_codes(prog, ["E1307", "E1307"]);
}
