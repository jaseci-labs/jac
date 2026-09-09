"""The freeze(x) membrane builtin (#7857 Phase C).

freeze promotes a statically unique value (an owned binding or a fresh
expression) into the deep-immutable world: the source is consumed
(E1301 afterwards), the result binds as `imm`, and writes through it are
E1309. Freezing a possibly-aliased managed binding is fenced (E1311) --
static uniqueness is the proof, so freeze is the identity function at
runtime on every backend.

The fixture-plus-expected-codes cases for this rule live in the shared
`test_ownership_codes.jac` table; what stays here asserts something that
table cannot express.
"""

import from tests.ownership_helpers {
    compile_fixture,
    expect_ownership_codes,
    render_alerts
}
import from jaclang.testing.test { parametrize }
import from jaclang.compiler.driver.compile_options { CompileOptions }
import from jaclang.compiler.driver.program { JacProgram }
import from tests.ownership_helpers { FIXTURES }
import os;

def _immutable_alias_case(profile: str) {
    for (fixture, expected) in [
        ("freeze_alias_write.jac", ["E1309"]),
        ("freeze_projection_write.jac", ["E1309"]),
        ("freeze_scalar_copy_ok.jac", [])
    ] {
        prog = JacProgram();
        prog.compile(
            os.path.join(FIXTURES, fixture),
            options=CompileOptions(memory_profile=profile)
        );
        expect_ownership_codes(prog, expected);
        if not expected {
            assert not prog.errors_had , render_alerts(prog);
        }
    }
}

with entry {
    parametrize("immutable aliases", ["managed", "rc", "nogc"], _immutable_alias_case);
}

test "freeze of an owned binding is clean and error-free" {
    prog = compile_fixture("freeze_own_ok.jac");
    assert not prog.errors_had , render_alerts(prog);
    expect_ownership_codes(prog, []);
}
