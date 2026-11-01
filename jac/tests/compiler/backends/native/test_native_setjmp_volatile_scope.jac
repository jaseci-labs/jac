"""Locals around a `try` keep their values across a raise.

A function that arms a setjmp frame shares it with hot loops and with locals
a protected body writes before a call that can raise; the path a raise lands
on must read the value the body wrote, and the loops must compute what Python
computes.
"""

import from tests.support { assert_native_identity, NATIVE_FIXTURES }

glob FIXTURE = "setjmp_volatile_scope.jac";

test "the scoped functions behave like Python" {
    out = assert_native_identity(
        f"{NATIVE_FIXTURES}/{FIXTURE}", profiles=["rc", "managed"]
    );
    assert out == "450 0\n45\n7 9\n-1 6\n" , out;
}
