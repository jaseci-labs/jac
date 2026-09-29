"""Native bytes.hex() and bytes.fromhex() agree with CPython.

The kernel's compile-time evaluator folds both; natively they run through the
formatting kernel's hex helpers.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "bytes.hex and bytes.fromhex match CPython" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "bytes_hex_fidelity.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    assert out.splitlines()[0] == "007fff616263" , out;
}
