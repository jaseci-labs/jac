"""`set(...)` and `frozenset(...)` lower natively over ranges and other iterables.

The native `set` constructor only knew bytes, lists and sets, so
`set(range(1, n + 1))`, the same over a tuple or a dict, and `frozenset` of
any of them were refused (E5092) and their function sent to Python. For
numeric elements they now drain the iterable the way `list` does; a native
build refuses any demoted function, so identity with the Python backend
under every memory profile also proves the native path was taken.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "native set and frozenset over ranges and other iterables agree with Python" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "set_from_iterable.jac"
    );
    out = assert_native_identity(source);
    lines = out.splitlines();
    assert lines[0] == "3 3 [1, 2, 3]" , out;
    assert lines[1] == "[5, 15, 4, 1, 5] [0, 0, 4, 1, 0]" , out;
    assert lines[2] == "[2, 4, 9] [3, 5, 7]" , out;
    assert lines[3] == "[-0.5, 1.5, 2.5] 0" , out;
}
