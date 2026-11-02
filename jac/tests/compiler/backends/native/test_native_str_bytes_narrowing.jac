"""A method on a `str | bytes` value narrowed to `bytes` calls the bytes method.

The receiver arrives in the union's representation; a bytes method on it used
to fall through to the string path and return empty text. It now converts to
the narrowed type first, as binding it to a `bytes` local does. The nogc
profile refuses unannotated heap parameters, so the program runs under the
counted and managed profiles.
"""

import from tests.support { assert_native_identity }

import os;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

test "narrowed str | bytes receivers match CPython" {
    assert_native_identity(
        os.path.join(FIXTURES, "str_bytes_narrowing.jac"), profiles=["rc", "managed"]
    );
}
