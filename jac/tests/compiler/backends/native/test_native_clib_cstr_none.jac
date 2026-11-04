"""A NULL `char*` from a clib `-> str` function is None in a native build.

Python's ctypes `c_char_p` turns a NULL return into None, and the old native
backend kept the NULL pointer, so `getenv(name) != None` read as "set" only
when the variable was set. A native build that turned NULL into an empty str
read every unset variable as set: js_engine took `JS_ENGINE_LEAKS_TEST` as on
and parsed `int('')` from its unset GC tuning variables.
"""

import os;
import from pathlib { Path }
import from tests.support { assert_native_identity }

glob FIXTURES = Path(__file__).resolve().parent / "fixtures";

test "a NULL clib str return compares and tests as None" {
    os.environ["JAC_CSTR_NONE_SET"] = "42";
    os.environ.pop("JAC_CSTR_NONE_UNSET", None);
    try {
        out = assert_native_identity(str(FIXTURES / "clib_cstr_none.jac"));
    } finally {
        os.environ.pop("JAC_CSTR_NONE_SET", None);
    }
    assert "unset eq True\nunset ne False\nunset is True\nunset isnt False\n"
        in out , out;
    assert "unset falsy\nunset not True\nunset gate True\nunset ret True\n"
        in out , out;
    assert "unset num 7\nunset scaled 0\n" in out , out;
    assert "set eq False\nset ne True\nset is False\nset isnt True\nset lit True\n"
        in out , out;
    assert "set truthy\nset not False\nset int 43\nset gate True\n" in out , out;
    assert "set ret False\nset num 42\nset scaled 84\n" in out , out;
}
