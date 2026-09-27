"""`is` over by-value tuples and scalars answers identity by value.

A native tuple local is a by-value struct and an int, float or bool is the
word itself, so there is no object address to compare. The backend already
defines identity for such values in `id()`: an unboxed value's identity is
its own bits. `is` now follows the same rule. Two by-value tuples are
identical when every field is identical -- reference fields by address,
scalar fields by bits, nested tuples field by field -- and a by-value tuple
against a heap-boxed tuple of its shape compares against the box's contents
(a null box is `None`). A by-value value is never identical to a reference
or to `None`. This agrees with CPython wherever CPython's answer does not
depend on object caching: aliases of one tuple are identical, tuples with a
differing field are not, and a tuple or scalar is never `None`.

Previously a tuple operand could not lower at all, and `is` / `is not`
between two scalars fell through to the left operand's truthiness, so
`flag is False` answered `bool(flag)` and `is not` answered the same thing
as `is`. Operand shapes that fit none of the identity rules are now refused
naming both representations instead of being answered from truthiness.
"""

import from tests.support { assert_native_identity }

import os;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures"),
     PROFILES: list[str] = ["managed", "rc"];

test "is over tuples and scalars answers like CPython" {
    assert_native_identity(
        os.path.join(FIXTURES, "value_identity.jac"), profiles=PROFILES
    );
}
