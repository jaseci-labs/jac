"""The derivation subset (#7870 item 2): in enforced modules a
step-free string slice is a view -- a borrow of its base that also
binds. Locally usable and returnable along the single-candidate
elision subset; storing one into containers is E1315, returning with
two-plus borrow candidates is E1315, and outliving a consumed owner is
E1301 via the borrow machinery views ride on."""

import from tests.ownership_helpers { compile_fixture, expect_ownership_codes }

test "local views and single-borrow elision returns are clean" {
    prog = compile_fixture("view_local_ok.jac", enforce=True);
    expect_ownership_codes(prog, []);
}

test "stored views, ambiguous returns, and outliving views are rejected" {
    prog = compile_fixture("view_escape_bad.jac", enforce=True);
    expect_ownership_codes(prog, ["E1301", "E1315", "E1315"]);
}

test "container, own-binding, and global smuggles are each rejected" {
    prog = compile_fixture("view_smuggle_bad.jac", enforce=True);
    expect_ownership_codes(prog, ["E1315", "E1315", "E1315"]);
}

test "chunked flow for licenses the lent shape only" {
    prog = compile_fixture("chunk_ok.jac", enforce=True);
    expect_ownership_codes(prog, []);
}

test "bound, bare, or grown chunks are rejected" {
    prog = compile_fixture("chunk_bad.jac", enforce=True);
    expect_ownership_codes(prog, ["E1313", "E1313"]);
}
