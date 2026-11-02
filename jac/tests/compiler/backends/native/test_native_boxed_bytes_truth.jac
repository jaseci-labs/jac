"""Boxed bytes have their own truth and length natively, as in Python.

`flag and data` boxes the bytes under the pointer tag strings share, and the
boxed value's truth and `len` read it as a string: the first byte of the bytes'
length field. Bytes whose length is a multiple of 256 tested false, and `len`
was wrong. Both now read the buffer kind from the allocation header, as
`isinstance` does, and the bytes' own length.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "boxed bytes keep their truth and length at every size" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "boxed_bytes_truth.jac"
    );
    out = assert_native_identity(source, profiles=["managed", "rc"]);
    assert out.splitlines()[3] == "256 T T T T 256" , out;
    assert out.splitlines()[6] == "3072 T T T T 3072" , out;
}
