"""Ownership states in Callable type positions (#7857 Phase F).

Higher-order signatures may declare ownership states on their callable
parameters (`Callable[[own Buffer], None]`); the states parse, check, and
compose with the existing consumption rules -- passing an owned binding
into the higher-order call consumes it like any own-parameter call.
"""

import from tests.ownership_helpers { compile_fixture, expect_ownership_codes }

test "callable-position own states parse and consumption composes (E1301)" {
    prog = compile_fixture("callable_own_states.jac");
    expect_ownership_codes(prog, ["E1301"]);
}
