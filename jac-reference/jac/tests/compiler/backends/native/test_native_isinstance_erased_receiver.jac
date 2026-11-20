"""`isinstance` on an archetype value held in erased form lowers natively.

A value popped from a `list[Base]` arrives as an untyped pointer while its
static type names `Base`. The runtime class check read the vtable through
that pointer without casting it to the class layout first, and the emitter
raised, demoting the enclosing function (the compiler's native capability
check among them).
"""

import from tests.support { assert_native_identity }

import os;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

test "isinstance on erased archetype values matches CPython" {
    assert_native_identity(
        os.path.join(FIXTURES, "isinstance_erased_receiver.jac"),
        profiles=["rc", "managed"]
    );
}
