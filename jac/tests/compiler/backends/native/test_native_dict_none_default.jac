"""`dict.pop(key, None)` and `dict.get(key, None)` lower natively on dicts of
raw values and agree with Python.

`get` with no default already read as an optional value, but a `None`
default was coerced to the dict's value type: on a dict of floats, ints or
bools that made a `phi` with a `null` incoming value, and the LLVM IR did
not parse, so the whole native build failed. A `None` default now gives the
optional value `get` with no default gives; identity with the Python backend
under every memory profile also proves the native path was taken.
"""
import from pathlib { Path }
import from tests.support { assert_native_identity }

test "dict pop and get with a None default agree with Python natively" {
    source = str(
        Path(__file__).resolve().parent / "fixtures" / "dict_none_default.jac"
    );
    out = assert_native_identity(source);
    lines = out.splitlines();
    assert lines[0] == "0 None 2.5" , out;
    assert lines[1] == "3.5" , out;
    assert lines[2] == "3 None 3 None" , out;
    assert lines[3] == "True True None" , out;
    assert lines[4] == "v None" , out;
}
