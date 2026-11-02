"""A static method called through a module alias lowers natively.

`alias.Class.method()` names the class through its module, so the receiver
is an attribute rather than a bare class name. The call resolves the class
from the attribute's declaration, as a bare `Class.method()` resolves it from
its name; it used to demote the calling function.
"""

import from tests.support { assert_native_identity }

import os;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

test "module-qualified static calls match CPython under every memory profile" {
    assert_native_identity(os.path.join(FIXTURES, "qualified_static.jac"));
}
