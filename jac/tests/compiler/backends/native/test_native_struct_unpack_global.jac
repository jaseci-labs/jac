"""A `struct.unpack` result bound to a module-level name reads back natively.

`struct.unpack` is typed `tuple[Any, ...]`, which a module global lowers to
as a boxed sequence, but the native call builds a tuple of unboxed ints and
floats. Storing it into the global bitcast the tuple to the sequence layout,
so reading it back trapped, segfaulted or raised IndexError. The tuple is now
boxed into the sequence. Identity with the Python backend under every memory
profile proves the reads, aliasing, rebinding and iteration all agree.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "struct.unpack bound to a module global agrees with Python" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "struct_unpack_global.jac"
    );
    out = assert_native_identity(source);
    assert out.startswith("7 7\n1.0 2.5 -3.0 3\n2.5\n7 8 15\n") , out[:400];
    assert "-2 256\n9 0.5\n5\n15\n298 298\n" in out , out[:400];
}
