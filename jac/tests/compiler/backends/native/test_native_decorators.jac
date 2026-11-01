"""Decorator handling on the native (.jac / na {}) pipeline.

Before the capability gate learned about decorators, a decorated function in a
native module compiled silently WITHOUT its decorator: the undecorated body ran,
which is a correctness hole rather than a missing feature. These tests pin the
gate: decoration in a native context must either lower faithfully or be rejected
with a structured error — never dropped.
"""

import from pathlib { Path }
import from tests.support {
    compile_mir,
    compile_native,
    compile_native_refused,
    diagnostics_text,
    error_codes,
    kernel_compile_file,
    native_address,
    native_force_opts,
    write_case
}

"""Write a snippet as its own module; return (file name, directory)."""
def inline_case(label: str, code: str) -> tuple[str, str] {
    path = Path(write_case(code, f"_decorator_{label}.jac"));
    return (path.name, str(path.parent));
}

"""Compile a .jac fixture, run module glob-init (as init_native_globals
does in production), and return the JIT engine."""
def compile_fixture(fixture: str) -> any {
    import ctypes;
    (eng, _) = compile_native(fixture);
    gi_addr = native_address(eng, "__jac_glob_init");
    if gi_addr {
        ctypes.CFUNCTYPE(None)(gi_addr)();
    }
    return eng;
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: any, name: str, restype: any, *argtypes: any) -> any {
    import ctypes;
    addr = native_address(eng, name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

# Static decoration on module-level functions: the decorator chain is
# applied at glob-init to the raw function, calls go through the slot.
test "decorator: registration decorator runs at glob-init, calls pass through" {
    import ctypes;
    eng = compile_fixture("decorators.jac");
    f = get_func(eng, "use_val", ctypes.c_int64);
    # val(4) = 5 through the identity-decorated slot; marks counted 3
    # glob-init applications module-wide (val once, stacked twice).
    assert f() == 503 , "expected val(4)*100 + marks == 503";
}

test "decorator: a decorator returning another function redirects calls" {
    import ctypes;
    eng = compile_fixture("decorators.jac");
    f = get_func(eng, "use_val2", ctypes.c_int64);
    assert f() == 42 , "val2 must route to alt via the slot, not the raw body";
}

test "decorator: stacked decorators apply and calls still resolve" {
    import ctypes;
    eng = compile_fixture("decorators.jac");
    f = get_func(eng, "use_stacked", ctypes.c_int64);
    assert f() == 93 , "stacked(10)=9 through slot; marks==3 at call time";
}

# A decorator whose native signature does not take exactly one argument
# would emit a malformed call at glob-init; it must be a structured error.
test "guardrail: multi-argument decorator is rejected at apply time" {
    (name, where) = inline_case(
        "arity_dec",
        "def two(fn: any, extra: int) -> any { return fn; }\n"
        "@ two\n"
        "def val(x: int) -> int { return x; }\n"
    );
    result = compile_native_refused(name, where);
    assert "E5092" in error_codes(result) , (
        f"Expected E5092 for a 2-arg decorator, got: {diagnostics_text(result)}"
    );
}

# A decorator that is not statically resolvable (an arbitrary expression)
# stays rejected: silent mis-binding is never acceptable.
test "guardrail: non-static decorator expression demotes its function" {
    (name, where) = inline_case(
        "dynamic_dec",
        "def pick(fn: any) -> any { return fn; }\n"
        "glob decs: list[any] = [];\n"
        "@ (decs[0])\n"
        "def val(x: int) -> int { return x; }\n"
    );
    fx = compile_mir(name, where);
    assert fx.is_demoted("val") , (
        "the dynamically-decorated function must be demoted to the Python "
        f"implementation (which applies it), never run undecorated: {fx.demoted()}"
    );
}

# Method decorators interact with vtable layout, so a decorated method
# demotes to its Python implementation (which applies the decorator) rather
# than running undecorated -- and a native caller of the demoted method
# demotes with it.
test "guardrail: decorated method demotes, native callers demote with it" {
    (name, where) = inline_case(
        "method",
        "def ident(fn: any) -> any { return fn; }\n"
        "obj Box {\n"
        "    has v: int = 0;\n"
        "    @ ident\n"
        "    def get -> int { return self.v; }\n"
        "}\n"
        "def use_box -> int { b = Box(v=3); return b.get(); }\n"
    );
    fx = compile_mir(name, where);
    assert fx.is_demoted("Box.get") , (
        "the decorated method must be demoted, never run undecorated: "
        f"{fx.demoted()}"
    );
    assert fx.is_demoted("use_box") , (
        f"a native caller of the demoted method must demote with it: {fx.demoted()}"
    );
}

# Decorated archetypes (class decorators) are equally silently dropped today
# and must be gated.
test "guardrail: decorated archetype is rejected" {
    (name, where) = inline_case(
        "arch",
        "def tag(cls: any) -> any { return cls; }\n"
        "@ tag\n"
        "obj Marked {\n"
        "    has v: int = 0;\n"
        "}\n"
        "def mk -> int { m = Marked(v=1); return m.v; }\n"
    );
    result = kernel_compile_file(str(Path(where) / name), native_force_opts());
    assert "E5090" in error_codes(result) , (
        f"Expected E5090 for a decorated native archetype, got: {diagnostics_text(result)}"
    );
}
