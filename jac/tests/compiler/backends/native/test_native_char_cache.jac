"""Single-character access returns real one-character strings.

`for c in str` and `s[i]` extract single characters. The native backend serves
them without heap-allocating a fresh RC string per character (a CPython
latin1-style cache); regressing that made string iteration allocate one string
per character. These tests pin the runtime behavior: characters compare and
concatenate correctly, and a cached character still reports length 1.
"""

import ctypes;
import from tests.support { compile_native, native_str_func }

glob FIXTURE = "char_cache.jac";

test "cached characters behave as real strings at runtime" {
    (eng, _) = compile_native(FIXTURE);

    scan = native_str_func(eng, "char_scan", ctypes.c_int64, ctypes.c_char_p);
    assert scan(b"foobar") == 2;  # two 'o'
    assert scan(b"banana") == 0;

    idx = native_str_func(
        eng, "char_index", ctypes.c_char_p, ctypes.c_char_p, ctypes.c_int64
    );
    assert idx(b"Hello", 0).decode("utf-8") == "H";
    assert idx(b"Hello", 4).decode("utf-8") == "o";

    combine = native_str_func(eng, "combine", ctypes.c_int64, ctypes.c_char_p);
    assert combine(b"Hello") == 5;  # concat of 5 cached chars
    assert combine(b"") == 0;
}
