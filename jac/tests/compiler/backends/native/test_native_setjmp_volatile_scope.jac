"""A `try` keeps in memory only the locals a raise could leave stale.

A function that arms a setjmp frame used to keep every local written after
the arming volatile, so a hot loop sharing a function with one cold `try` ran
every access through the stack. A local is now volatile only when a protected
body writes it before a call that can raise, and the path a raise lands on
reads it before writing it. The fixture's output pins that a handler still
reads the value the protected body wrote.
"""

import from tests.support { assert_native_identity, NATIVE_FIXTURES }

glob FIXTURE = "setjmp_volatile_scope.jac";

test "the scoped functions behave like Python" {
    out = assert_native_identity(
        f"{NATIVE_FIXTURES}/{FIXTURE}", profiles=["rc", "managed"]
    );
    assert out == "450 0\n45\n7 9\n-1 6\n" , out;
}
