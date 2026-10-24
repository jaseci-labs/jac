"""`bytes(...)` and `bytearray(...)` lower natively over ranges and tuples.

The native constructors took a count, a buffer or a list of ints, so
`bytes(range(256))` was refused (E5092) and its function sent to Python.
They now drain any other iterable through the list path first, as `set`
does; a native build refuses any demoted function, so identity with the
Python backend under every memory profile also proves the native path was
taken.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "native bytes and bytearray over ranges and tuples agree with Python" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "bytes_from_iterable.jac"
    );
    out = assert_native_identity(source);
    lines = out.splitlines();
    assert lines[0] == "[256, 255, 3, 250, 254, 4, 9]" , out;
    assert lines[1] == "[3, 255]" , out;
}
