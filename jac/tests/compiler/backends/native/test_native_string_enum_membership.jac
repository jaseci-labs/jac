"""`text in container` over a string enum's members lowers natively.

A set, dict or list of `StrEnum` members answers a text probe the way Python
does: the probe matches the member whose value it spells. The compiler's own
passes test token names against sets of `Tokens` members this way.
"""
import ctypes;
import from tests.support { compile_native, get_func }

test "a text probe finds string enum members in a set, a dict and a list" {
    (eng, _) = compile_native("string_enum_membership.jac");
    got = get_func(eng, "chk_membership", ctypes.c_int64)();
    assert got == 1 + 2 + 8 + 32 , got;
}
