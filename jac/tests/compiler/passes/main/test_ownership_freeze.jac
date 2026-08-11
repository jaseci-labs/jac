"""The freeze(x) membrane builtin (#7857 Phase C).

freeze promotes a statically unique value (an owned binding or a fresh
expression) into the deep-immutable world: the source is consumed
(E1301 afterwards), the result binds as `imm`, and writes through it are
E1309. Freezing a possibly-aliased managed binding is fenced (E1311) --
static uniqueness is the proof, so freeze is the identity function at
runtime on every backend.
"""

import from tests.ownership_helpers {
    compile_fixture,
    expect_ownership_codes,
    render_alerts
}

test "freeze of an owned binding is clean and error-free" {
    prog = compile_fixture("freeze_own_ok.jac");
    assert not prog.errors_had , render_alerts(prog);
    expect_ownership_codes(prog, []);
}

test "freeze consumes its argument (E1301 on later reads)" {
    prog = compile_fixture("freeze_use_after.jac");
    expect_ownership_codes(prog, ["E1301"]);
}

test "freeze of a possibly-aliased managed binding is E1311" {
    prog = compile_fixture("freeze_aliased_fenced.jac");
    expect_ownership_codes(prog, ["E1311"]);
}

test "writes through a frozen binding are E1309" {
    prog = compile_fixture("freeze_imm_write.jac");
    expect_ownership_codes(prog, ["E1309"]);
}
