"""A property read dispatched through the vtable releases its temporary
receiver once.

The virtual call released every owned argument, the receiver included, and
the property read released the same temporary again afterwards, as it does
for a direct getter call. Reading a property off an object a getter just
returned (`h.private.vals`) freed that object while its owner still held it.
"""

import os;
import from tests.support { TESTS_DIR, assert_native_identity }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

test "a vtable-dispatched property off a temporary receiver keeps its owner's reference" {
    out = assert_native_identity(
        os.path.join(FIXTURES, "vtable_accessor_receiver.jac")
    );
    assert "total 404000\n" in out , f"got {out!r}";
}
