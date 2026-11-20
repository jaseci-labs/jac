"""`...` is a first-class value on the native backend.

The Ellipsis literal had no native representation, so any function that used
it as a value -- `Ellipsis.lit_value` in the unitree returning `...` among
them -- was demoted with "Native lowering failed for expression 'Ellipsis'".
It now lowers to the `any` box with its own tag, `JACVAL_ELLIPSIS_TAG`, next
to None's: a singleton, so identity and equality are the tag compare, it is
truthy, it prints as `Ellipsis`, and `isinstance(v, type(...))` reads the
tag. It stays distinct from None and from every int.

The fixture runs under the counted and managed profiles only, since the nogc
profile refuses `any`-typed values.
"""

import from tests.support { assert_native_identity }

import os;
import from pathlib { Path }

glob FIXTURES = str(Path(__file__).resolve().parent / "fixtures");

test "Ellipsis as a value matches CPython" {
    out = assert_native_identity(
        os.path.join(FIXTURES, "ellipsis_value.jac"), profiles=["rc", "managed"]
    );
    assert "Ellipsis" in out;
}
