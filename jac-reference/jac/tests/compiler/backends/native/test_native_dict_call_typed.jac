"""A dict made by calling `dict(...)` is a typed dict natively.

`dict(x)` was typed as a bare `dict`: its `__new__` takes anything, and the
`__init__` overloads that say what the keys and values are were not asked.
A value read from the copy then had no type, a string's method on it could
not be lowered ("Native pathway does not yet support attribute access
'strip'"), and the function fell back to Python. The call now takes its
type arguments from the `__init__` it matches.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "dicts made by calling dict match Python" {
    source = str(Path(__file__).resolve().parent / "fixtures" / "dict_call_typed.jac");
    out = assert_native_identity(source, profiles=["rc", "managed"]);
    lines = out.splitlines();
    assert lines[-3] == "90| 0|" , out;
    assert lines[-2] == "['30/1/ 300 ', '90/1/x', '90/1/-']" , out;
    assert lines[-1] == "14 0" , out;
}
