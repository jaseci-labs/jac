"""Decorator handling on the native (.na.jac / na {}) pipeline.

Before the capability gate learned about decorators, a decorated function in a
native module compiled silently WITHOUT its decorator: the undecorated body ran,
which is a correctness hole rather than a missing feature. These tests pin the
gate: decoration in a native context must either lower faithfully or be rejected
with a structured error — never dropped.
"""

import os;
import from tests.support { TESTS_DIR }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES_DIR = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
     );

"""Compile a snippet through the native pipeline and return the program."""
def compile_na_inline(label: str, code: str) -> JacProgram {
    path = os.path.join(FIXTURES_DIR, f"_decorator_{label}.na.jac");
    prog = JacProgram();
    prog.compile(file_path=path, use_str=code);
    return prog;
}

"""Return True if the program emitted at least one alert with the given code."""
def has_error_code(prog: JacProgram, code: str) -> bool {
    for alrt in prog.errors_had {
        if alrt.code is not None and alrt.code.code == code {
            return True;
        }
    }
    return False;
}

"""Format errors for assertion messages."""
def fmt_errors(prog: JacProgram) -> str {
    return str([str(e) for e in prog.errors_had]);
}

"""Compile a .na.jac fixture, run module glob-init (as init_native_globals
does in production), and return the JIT engine."""
def compile_fixture(fixture: str) -> object {
    import ctypes;
    import from jaclang.compiler.passes.native.llvm.binding { ExecutionEngine }
    prog = JacProgram();
    ir = prog.compile(file_path=str(os.path.join(FIXTURES_DIR, fixture)));
    errors = [str(e) for e in prog.errors_had] if prog.errors_had else [];
    assert not prog.errors_had , f"Compilation errors in {fixture}: {errors}";
    eng = ir.gen.native_engine;
    assert eng is not None , f"No native engine produced for {fixture}";
    gi_addr = eng.get_function_address("__jac_glob_init");
    if gi_addr {
        ctypes.CFUNCTYPE(None)(gi_addr)();
    }
    return eng;
}

"""Get a ctypes-callable function from the JIT engine."""
def get_func(eng: object, name: str, restype: object, *argtypes: object) -> object {
    import ctypes;
    addr = eng.get_function_address(name);
    assert addr != 0 , f"Function '{name}' not found in JIT engine";
    functype = ctypes.CFUNCTYPE(restype, *argtypes);
    return functype(addr);
}

# Static decoration on module-level functions: the decorator chain is
# applied at glob-init to the raw function, calls go through the slot.
test "decorator: registration decorator runs at glob-init, calls pass through" {
    import ctypes;
    eng = compile_fixture("decorators.na.jac");
    f = get_func(eng, "use_val", ctypes.c_int64);
    # val(4) = 5 through the identity-decorated slot; marks counted 3
    # glob-init applications module-wide (val once, stacked twice).
    assert f() == 503 , "expected val(4)*100 + marks == 503";
}

test "decorator: a decorator returning another function redirects calls" {
    import ctypes;
    eng = compile_fixture("decorators.na.jac");
    f = get_func(eng, "use_val2", ctypes.c_int64);
    assert f() == 42 , "val2 must route to alt via the slot, not the raw body";
}

test "decorator: stacked decorators apply and calls still resolve" {
    import ctypes;
    eng = compile_fixture("decorators.na.jac");
    f = get_func(eng, "use_stacked", ctypes.c_int64);
    assert f() == 93 , "stacked(10)=9 through slot; marks==3 at call time";
}

# A decorator whose native signature does not take exactly one argument
# would emit a malformed call at glob-init; it must be a structured error.
test "guardrail: multi-argument decorator is rejected at apply time" {
    prog = compile_na_inline(
        "arity_dec",
        "def two(fn: any, extra: int) -> any { return fn; }\n"
        "@ two\n"
        "def val(x: int) -> int { return x; }\n"
    );
    assert has_error_code(prog, "E5092") , (
        f"Expected E5092 for a 2-arg decorator, got: {fmt_errors(prog)}"
    );
}

# A decorator that is not statically resolvable (an arbitrary expression)
# stays rejected: silent mis-binding is never acceptable.
test "guardrail: non-static decorator expression is rejected" {
    prog = compile_na_inline(
        "dynamic_dec",
        "def pick(fn: any) -> any { return fn; }\n"
        "glob decs: list = [];\n"
        "@ (decs[0])\n"
        "def val(x: int) -> int { return x; }\n"
    );
    assert has_error_code(prog, "E5090") , (
        f"Expected E5090 for a non-static decorator expression, got: "
        f"{fmt_errors(prog)}"
    );
}

# Method decorators interact with vtable layout and stay rejected even after
# module-level static decoration lands.
test "guardrail: decorated method is rejected" {
    prog = compile_na_inline(
        "method",
        "def ident(fn: any) -> any { return fn; }\n"
        "obj Box {\n"
        "    has v: int = 0;\n"
        "    @ ident\n"
        "    def get -> int { return self.v; }\n"
        "}\n"
        "def use_box -> int { b = Box(v=3); return b.get(); }\n"
    );
    assert has_error_code(prog, "E5090") , (
        f"Expected E5090 for a decorated native method, got: {fmt_errors(prog)}"
    );
}

# Decorated archetypes (class decorators) are equally silently dropped today
# and must be gated.
test "guardrail: decorated archetype is rejected" {
    prog = compile_na_inline(
        "arch",
        "def tag(cls: any) -> any { return cls; }\n"
        "@ tag\n"
        "obj Marked {\n"
        "    has v: int = 0;\n"
        "}\n"
        "def mk -> int { m = Marked(v=1); return m.v; }\n"
    );
    assert has_error_code(prog, "E5090") , (
        f"Expected E5090 for a decorated native archetype, got: {fmt_errors(prog)}"
    );
}
