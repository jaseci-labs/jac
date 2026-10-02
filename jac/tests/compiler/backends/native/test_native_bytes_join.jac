"""`bytes.join` lowers natively and agrees with Python.

`bytes.join` had no native emitter, so a function joining bytes was demoted to
Python and a native program depending on it could not be built. A list of
bytes shares the erased pointer list with a list of str, so the emitter reads
the argument's checked element type to tell them apart. The fixture joins
with empty, one-byte and longer separators, empty and one-element lists,
embedded NULs and comprehension-built parts, and checks `str.join` still
takes its own path; a native build refuses any demoted function, so identity
with the Python backend also proves the native path was taken.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "native bytes.join agrees with Python" {
    source = str(Path(__file__).resolve().parent / "fixtures" / "bytes_join.jac");
    out = assert_native_identity(source);
    assert out.startswith("ab-cd-e\n0 1\n") , out[:200];
    assert "0,1,255,1,2,255,2,3,255\n" in out;
    assert "97,0,98,0,0,99\n" in out;
    assert "one, two 0\n" in out;
    assert out.endswith("kept as str\n") , out[-100:];
}
