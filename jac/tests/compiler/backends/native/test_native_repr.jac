"""End-to-end tests for native container repr (#7593 item 5).

`str(container)`, `f"{container}"`, and `print(container)` must produce
CPython-exact repr text, recursing through nested containers and
dispatching obj elements to `__repr__` (not `__str__`).
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Run a void JIT function and capture what it writes to fd 1 (C stdout)."""
def capture_stdout(fn: any) -> bytes {
    libc = ctypes.CDLL(None);
    # Drain anything (e.g. the launcher's first-run banner) still sitting in
    # libc's stdout buffer, or the JIT's own fflush dumps it into the capture.
    libc.fflush(None);
    (r, w) = os.pipe();
    saved = os.dup(1);
    os.dup2(w, 1);
    try {
        fn();
        libc.fflush(None);
    } finally {
        os.dup2(saved, 1);
        os.close(saved);
        os.close(w);
        data = os.read(r, 65536);
        os.close(r);
    }
    return data;
}

test "str(list[int]) is CPython repr" {
    (eng, _) = compile_native("container_repr.jac");
    f = get_func(eng, "list_int_str", ctypes.c_char_p);
    assert f() == b"[1, 2, 3]";
}

test "str of empty list" {
    (eng, _) = compile_native("container_repr.jac");
    f = get_func(eng, "list_empty_str", ctypes.c_char_p);
    assert f() == b"[]";
}

test "nested list repr" {
    (eng, _) = compile_native("container_repr.jac");
    f = get_func(eng, "nested_list_str", ctypes.c_char_p);
    assert f() == b"[[1, 2], [3]]";
}

test "str elements get CPython quote choice" {
    (eng, _) = compile_native("container_repr.jac");
    f = get_func(eng, "list_str_quoting", ctypes.c_char_p);
    assert f() == b"['a', \"b'c\", 'd\"e']";
}

test "dict repr" {
    (eng, _) = compile_native("container_repr.jac");
    f = get_func(eng, "dict_str", ctypes.c_char_p);
    assert f() == b"{'a': 1, 'b': 2}";
}

test "set repr" {
    (eng, _) = compile_native("container_repr.jac");
    f = get_func(eng, "set_str", ctypes.c_char_p);
    assert f() == b"{1, 2, 3}";
}

test "tuple repr" {
    (eng, _) = compile_native("container_repr.jac");
    f = get_func(eng, "tuple_str", ctypes.c_char_p);
    assert f() == b"(1, 'x')";
}

test "one-tuple trailing comma" {
    (eng, _) = compile_native("container_repr.jac");
    f = get_func(eng, "one_tuple_str", ctypes.c_char_p);
    assert f() == b"(1,)";
}

test "bool elements repr as True/False" {
    (eng, _) = compile_native("container_repr.jac");
    f = get_func(eng, "bool_list_str", ctypes.c_char_p);
    assert f() == b"[True, False]";
}

test "None element in optional-str list" {
    (eng, _) = compile_native("container_repr.jac");
    f = get_func(eng, "opt_str_list", ctypes.c_char_p);
    assert f() == b"['a', None]";
}

test "float elements use repr formatting" {
    (eng, _) = compile_native("container_repr.jac");
    f = get_func(eng, "float_list_str", ctypes.c_char_p);
    assert f() == b"[1.0, 2.5, 1e+300]";
}

test "f-string container interpolation" {
    (eng, _) = compile_native("container_repr.jac");
    f = get_func(eng, "fstr_container", ctypes.c_char_p);
    assert f() == b"v=[1, 2]";
}

test "obj element uses __repr__" {
    (eng, _) = compile_native("container_repr.jac");
    f = get_func(eng, "obj_elem_repr", ctypes.c_char_p);
    assert f() == b"[P(1)]";
}

test "obj element default repr" {
    (eng, _) = compile_native("container_repr.jac");
    f = get_func(eng, "obj_elem_default", ctypes.c_char_p);
    out = f();
    assert out.startswith(b"[<Plain object at 0x") , f"got {out!r}";
    assert out.endswith(b">]") , f"got {out!r}";
}

test "print(list) and print(tuple) to stdout" {
    (eng, _) = compile_native("container_repr.jac");
    `entry = get_func(eng, "jac_entry", None);
    out = capture_stdout(`entry);
    assert out == b"[1, 2, 3]\n(1, 2)\n" , f"got {out!r}";
}

test "str of sized integers preserves unsigned range and vararg width" {
    (eng, _) = compile_native("container_repr.jac");
    f = get_func(eng, "sized_integer_str", ctypes.c_bool);
    assert f();
}
