"""A dict or set keyed by a union of archetypes hashes its keys by identity.

A union of two archetype pointers lowers to a bare `i8*`, which the hash
helpers took for a string key: they hashed and compared the objects' bytes as
C strings, so distinct objects of the same class collapsed into one entry. The
type checker's argument matching keys a dict by `Expr | KWPair`, and in the
kernel every keyword argument landed on the last parameter.
"""

import ctypes;
import from tests.support { compile_native, get_func }

test "union-typed object keys stay distinct in dicts and sets" {
    (eng, _ir) = compile_native("union_dict_keys.jac");
    assert get_func(eng, "obj_keys_same_type", ctypes.c_int64)() == 21;
    assert get_func(eng, "union_keys", ctypes.c_int64)() == 312;
    assert get_func(eng, "union_keys_optional_values", ctypes.c_int64)() == 22;
    assert get_func(eng, "equal_field_keys", ctypes.c_int64)() == 2;
    assert get_func(eng, "union_set", ctypes.c_int64)() == 21;
    assert get_func(eng, "union_keys_returned", ctypes.c_int64)() == 33;
    assert get_func(eng, "str_keys_still_by_value", ctypes.c_int64)() == 12;
}
