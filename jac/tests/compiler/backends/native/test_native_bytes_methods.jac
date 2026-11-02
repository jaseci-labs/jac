"""Native bytes methods agree with CPython.

The kernel's compile-time evaluator folds these with the host's `bytes`;
natively they run through the formatting kernel's bytes helpers.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "bytes methods match CPython" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "bytes_methods_fidelity.jac"
    );
    out = assert_native_identity(source, profiles=["managed"]);
    assert out.splitlines()[0] == "007fff616263" , out;
}
