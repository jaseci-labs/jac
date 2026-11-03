"""Containers boxed into `any` describe themselves.

A list, dict or set records its element kinds in its header when it is made,
and a tuple box records each member's kind, so native code can iterate, print,
compare and search a container it only knows as `any`. The fixture covers
iteration over every container family, `str`/`repr` (nested containers,
objects with and without `__str__`, an `any` field inside a generated repr),
`==` across element kinds, ordering with the Python `TypeError` for an
unordered pair, and `in`, all against the Python backend.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "containers boxed into any iterate, print, compare and search as in Python" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "any_self_describing.jac"
    );
    out = assert_native_identity(source, profiles=["managed", "rc"]);
    lines = out.splitlines();
    assert lines[0] == "1,2,3" , out;
    assert "Holder(payload=[1, 'x'], name='h')" in lines , out;
    assert "TypeError '<' not supported between instances of 'int' and 'str'"
        in lines , out;
    assert lines[-1] == "300" , out;
}
