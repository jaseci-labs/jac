"""`math` functions named after libm symbols stay native across modules.

`math.sqrt`, `math.sin`, `math.cos`, `math.tan` and `math.atan2` have the same
names as the libm externs `_math_native` declares. Those names are propagated
into `math`'s clib metadata, and the exported native layout skipped any
function whose name was in that map, so the layout of `math` left them out. A
module compiled as its own unit reads that layout, took the functions to be
demoted, and fell back to Python for every function calling them. A single
module program never consulted the layout, which is why only multi-module
programs broke. A native build refuses any demoted function, so identity with
the Python backend under the managed profiles also proves the native path was
taken.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "math functions named after libm symbols lower across modules" {
    # Importing `math` emits managed runtime machinery, which the headerless
    # (nogc) profile rejects even for a single module, so only rc and managed.
    source = str(Path(__file__).resolve().parent / "fixtures" / "libm_names.jac");
    out = assert_native_identity(source, profiles=["rc", "managed"]);
    assert out.startswith("5.0 0.5 ") , out;
    assert "4.0 1.0 0.785398163\n" in out;
    assert "sqrt: expected a nonnegative input, got -1.0\n" in out;
}
