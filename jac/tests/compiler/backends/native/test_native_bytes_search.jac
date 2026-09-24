"""Bytes search methods lower natively and agree with Python.

`bytes.find` and its family used to have no native emitter, so a function
calling one was demoted to Python and a program depending on it fell back
to the server codespace. The fixture sweeps find/rfind/index/rindex/count,
startswith/endswith (with tuple candidates) and `in`, over bytes and int
needles, embedded NULs, empty needles and every start/end adjustment; a
native build refuses any demoted function, so identity with the Python
backend under every memory profile also proves the native path was taken.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "native bytes search methods agree with Python" {
    source = str(Path(__file__).resolve().parent / "fixtures" / "bytes_search.jac");
    out = assert_native_identity(source);
    assert out.startswith("sbar nonul \n") , out[:200];
    assert "2 -1 4 1\n" in out;
    assert "True True True\n" in out;
    assert "True True False\n" in out;
    assert "find: byte must be in range(0, 256) in: byte must be in range(0, 256)"
        in out;
    assert "index: subsection not found" in out;
}
