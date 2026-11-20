"""Values typed by a class-bounded type variable lower natively.

A generic function `def run[W: Base](kind: type[W]) -> W` constructs through
`kind(...)` and reads fields off its `W` values, the shape the compiler's
own pass driver has. The native capability check took every type variable
for `any` and refused the field reads, and the class-value constructor did
not look through `type[W]` to the bound, so both demoted. A variable
bounded by an archetype now addresses the bound's layout.
"""

import from tests.support { assert_native_identity }

import os;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

test "class-bounded type variables construct and read fields like CPython" {
    assert_native_identity(
        os.path.join(FIXTURES, "bounded_typevar.jac"), profiles=["rc", "managed"]
    );
}
