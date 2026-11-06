"""Module-level shapes the native lowering once refused and the old backend took.

Each fixture is built natively and must print what the Python backend prints:

- a typed glob with no initializer (`glob _REALM: Realm;`) is a zero slot that
  a setter fills later, as the old backend's null initializer was;
- a constant an archwire import takes from a platform-variant module
  (`_F_GETFL`, `_TCSANOW`, `_NCCS`) binds the selected variant's global, since
  the portable module declares none of them;
- an `any` narrowed by `isinstance(x, tuple)` stays a dynamic value, so
  `x[0]` and `len(x)` read the real tuple instead of an empty one;
- a glob a module takes through `include` binds the including unit to the
  included module's global, not to the absorbed stub name.
"""

import from pathlib { Path }
import from tests.support { assert_native_identity }

glob FIXTURES = Path(__file__).resolve().parent / "fixtures";

test "a typed glob with no initializer is a zero slot a setter fills" {
    out = assert_native_identity(
        str(FIXTURES / "uninit_typed_glob.jac"), profiles=["rc", "managed"]
    );
    assert "first:11\nsecond:12\ncount 6 1.5\n" == out , out;
}

test "an archwire import of a variant-only constant reads the variant global" {
    out = assert_native_identity(
        str(FIXTURES / "variant_wired_consts.jac"), profiles=["managed"]
    );
    assert "tcgetattr refused a bad descriptor" in out , out;
}

test "an any narrowed to a bare tuple subscripts the real tuple" {
    out = assert_native_identity(
        str(FIXTURES / "any_narrowed_bare_tuple.jac"), profiles=["rc", "managed"]
    );
    assert "10.0.0.1/24\n10.0.0.2/32\n10.0.0.3/32\n" in out , out;
}

test "a glob absorbed through include reads the included module's global" {
    out = assert_native_identity(
        str(FIXTURES / "absorb_clib" / "main.jac"), profiles=["managed"]
    );
    assert out == "9\n" , out;
}
