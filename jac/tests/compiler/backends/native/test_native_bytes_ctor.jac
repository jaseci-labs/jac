"""The bytes and bytearray constructors lower natively and agree with Python.

`bytes(n)`, `bytes()` and `bytes(b)` had no native lowering, so a function
allocating a zero-filled buffer (`bytes(width * height * 4)` for a texture)
was demoted to Python and the program fell back to the server codespace.
`bytes(list)` truncated out-of-range ints instead of raising, negative sizes
were not rejected, and `list(bytearray)` read the narrow byte storage as
64-bit ints. The fixture sweeps sizes (including negative ones), empty and
copy constructors, bool arguments and the range checks; a native build
refuses any demoted function, so identity with the Python backend under
every memory profile also proves the native path was taken.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "native bytes and bytearray constructors agree with Python" {
    source = str(Path(__file__).resolve().parent / "fixtures" / "bytes_ctor.jac");
    out = assert_native_identity(source);
    assert "8 b'\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00' True | 8 [0, 0, 0, 0, 0, 0, 0, 0]\n"
        in out , out[:400];
    assert "bytes(-1): negative count | bytearray(-1): negative count\n" in out;
    assert "0 b'' True b''\n" in out;
    assert "24 0 0 0\n" in out;
    assert "bytes(list): bytes must be in range(0, 256) | bytearray(list): byte must be in range(0, 256)"
        in out;
    assert "[120, 121] [0, 0, 0] [1, 254]\n" in out;
}
