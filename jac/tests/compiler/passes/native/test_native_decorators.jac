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

# A decorated module-level function must not compile with the decorator
# silently dropped. Until static decoration lands, the only acceptable
# outcome is a structured E5090 from the capability gate.
test "guardrail: decorated module-level function is rejected, not dropped" {
    prog = compile_na_inline(
        "module_fn",
        "def double(fn: any) -> any { return fn; }\n"
        "@ double\n"
        "def val(x: int) -> int { return x; }\n"
    );
    assert has_error_code(prog, "E5090") , (
        f"Expected E5090 for a decorated native function (silent decorator "
        f"drop), got: {fmt_errors(prog)}"
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
