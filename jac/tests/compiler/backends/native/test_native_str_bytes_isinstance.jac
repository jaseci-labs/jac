"""isinstance discriminates str from bytes natively, as the Python backend does.

`str | bytes` lowers to one untagged pointer (both members are headered
heap pointers of the same box kind), and in a wider union both box to the
same pointer tag, so neither the LLVM type nor the tag could tell the two
apart: `isinstance(v, str)` was false for a string held in a `str | bytes`
slot, and true for bytes in a wide union. isinstance now reads the buffer
kind from the allocation header, the check `isinstance(x, bytes)` already
used for boxed values, and a read narrowed to `bytes` retypes the untagged
pointer so `len` and friends use the bytes layout.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "str and bytes isinstance agree with Python across representations" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "str_bytes_isinstance.jac"
    );
    out = assert_native_identity(source, profiles=["managed", "rc"]);
    assert out.splitlines()[0] == "str:hi bytes:3" , out;
}
