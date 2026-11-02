"""`sum` over a bytes or bytearray value lowers natively and agrees with Python.

The native `sum` only knew lists, so `sum(data)` over `bytes` was refused
(E5092) and its function sent to Python. A `bytearray`, which is a list of
`u8` underneath, did lower but through the signed-element path: every byte
of 128 and above was added as a negative number. Both now add the unsigned
byte values, with an int or float `start`; a native build refuses any demoted
function, so identity with the Python backend under every memory profile also
proves the native path was taken.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "native sum over bytes and bytearray agrees with Python" {
    source = str(Path(__file__).resolve().parent / "fixtures" / "bytes_sum.jac");
    out = assert_native_identity(source);
    lines = out.splitlines();
    assert lines[0] == "763 1763 0" , out;
    assert lines[1] == "0 7 0 76500" , out;
    assert lines[2] == "127.16666666666667 763.5" , out;
    assert lines[3] == "752 166" , out;
    assert lines[4] == "655 656 0 128.25" , out;
    assert lines[5]
        == "1.0000000000000002e+16 1.0000000000000256e+16 -9999999999999998.0 1e+16" , out;
}
