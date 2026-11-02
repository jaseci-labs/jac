"""`del xs[a:b]` lowers natively for lists.

The bounds normalize as a slice read does (negative indices wrap, both clamp
to the list), and the elements go from the high end down through the list's
own `del_at`, so each one is released as a single deletion releases it and
truncating a tail moves nothing. A slice with a step still refuses.
"""

import from tests.support { assert_native_identity }

import os;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

test "list slice deletion matches CPython under every memory profile" {
    assert_native_identity(os.path.join(FIXTURES, "list_slice_delete.jac"));
}
