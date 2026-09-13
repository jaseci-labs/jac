"""End-to-end tests for native object stringification (#7003).

`str(obj)`, `f"{obj}"`, and `print(obj)` must dispatch to a user object's
`__str__` method (resolving the runtime subclass through the vtable), and fall
back to a `<TypeName object at 0x...>` default -- not a garbage pointer -- when
no `__str__` is defined. All assertions hold the native (`na`) result to the
shape it would take on the `sv` pathway.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, compile_native, get_func, native_force_opts }

glob FIXTURES = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Run a void JIT function and capture what it writes to fd 1 (C stdout).

`contextlib.redirect_stdout` only sees Python writes; the JIT's printf goes
straight to the C runtime, so we redirect the OS-level file descriptor and
flush libc's stdio buffer before restoring it."""
def capture_stdout(fn: object) -> bytes {
    libc = ctypes.CDLL(None);
    # Drain anything (e.g. the launcher's first-run banner) still sitting in
    # libc's stdout buffer, or the JIT's own fflush dumps it into the capture.
    # Same guard `test_native_repr.jac` carries for the same reason.
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
        # Close the write-end to signal EOF, then drain and close the read-end.
        # Kept in `finally` so a raising fn() never leaks the pipe fds.
        os.close(w);
        data = os.read(r, 65536);
        os.close(r);
    }
    return data;
}

# --- str(obj) ---
test "str(obj) dispatches to __str__" {
    (native_program, eng, _) = compile_native("obj_str.jac");
    f = get_func(eng, "obj_str", ctypes.c_char_p);
    assert f() == b"hello";
}

test "str(obj) with a computed (f-string) __str__" {
    (native_program, eng, _) = compile_native("obj_str.jac");
    f = get_func(eng, "obj_str_computed", ctypes.c_char_p);
    assert f() == b"Q(42)";
}

# --- f"{obj}" ---
test "f-string interpolates obj via __str__" {
    (native_program, eng, _) = compile_native("obj_str.jac");
    f = get_func(eng, "obj_in_fstring", ctypes.c_char_p);
    assert f() == b"[world]";
}

# --- default repr fallback (no __str__) ---
test "str(obj) without __str__ falls back to default repr, not garbage" {
    (native_program, eng, _) = compile_native("obj_str.jac");
    f = get_func(eng, "obj_default_repr", ctypes.c_char_p);
    got = f();
    assert got.startswith(b"<Plain object at 0x") , f"got: {got!r}";
    assert got.endswith(b">") , f"got: {got!r}";
}

# --- polymorphism (vtable dispatch through a base-typed receiver) ---
test "str(obj) resolves the runtime subclass __str__" {
    (native_program, eng, _) = compile_native("obj_str.jac");
    f = get_func(eng, "poly_str", ctypes.c_char_p);
    assert f() == b"Dog:rex";
}

test "str(obj) on a base instance uses the base __str__" {
    (native_program, eng, _) = compile_native("obj_str.jac");
    f = get_func(eng, "base_str", ctypes.c_char_p);
    assert f() == b"Animal:generic";
}

# --- null receiver (T | None) ---
test "str(obj) on a null (None) struct pointer renders \"None\", not a crash" {
    (native_program, eng, _) = compile_native("obj_str.jac");
    f = get_func(eng, "maybe_str", ctypes.c_char_p, ctypes.c_int64);
    assert f(1) == b"set";
    assert f(0) == b"None";
}

# --- print(obj) ---
test "print(obj) writes __str__ to stdout" {
    (native_program, eng, _) = compile_native("obj_str.jac");
    `entry = get_func(eng, "jac_entry", None);
    got = capture_stdout(`entry);
    assert got == b"printed\n" , got;
}
