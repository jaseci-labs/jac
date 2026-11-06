"""A local variable named `any` shadows the builtin type keyword.

`any` lexes as a builtin type, so the checker bound every read of it to
typing.Any even when the function declared `any: bool` itself; the Python
backend still read the local at run time, but native lowering refused the
name (js_engine's lockfile writer uses exactly this shape). Reads outside a
type annotation now resolve through the lexical scope first.
"""

import from pathlib { Path }
import from tests.support { assert_native_identity }

glob FIXTURES = Path(__file__).resolve().parent / "fixtures";

test "a local named any is read as the local" {
    out = assert_native_identity(
        str(FIXTURES / "local_shadows_any.jac"), profiles=["rc", "managed"]
    );
    assert "3,3 seen\n empty\n" == out , out;
}
