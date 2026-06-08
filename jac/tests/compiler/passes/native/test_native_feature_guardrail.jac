"""Guardrail tests for the .na.jac / na {} native pipeline.

These tests verify that NaIRGenPass raises a clear E5090 error on AST
node types it does not yet support, rather than silently dropping them
and emitting empty function bodies.

Each test below targets one feature that NaIRGenPass currently no-ops.
When a feature gains real support, its test here should be deleted and
a behavioral test added to test_native_gen_pass.jac.

A regression that re-introduces silent-failure mode shows up here as a
test that fails: "expected E5090, got no errors" — which is exactly the
class of bug this guardrail exists to prevent.
"""

import os;
import from pathlib { Path }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES_DIR = str(
         Path(jaclang.__file__).parent.parent / "tests" / "compiler" / "passes" / "native" / "fixtures"
     );

"""Compile a snippet through the native pipeline and return the program.

Uses a synthetic .na.jac path under the fixtures directory so the file
extension routes the compile through NaIRGenPass.
"""
def compile_na_inline(label: str, code: str) -> JacProgram {
    path = os.path.join(FIXTURES_DIR, f"_guardrail_{label}.na.jac");
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

# ─────────────────────────────────────────────────────────────────────
# Statement-level gaps
# ─────────────────────────────────────────────────────────────────────
# Value / OR / capture / wildcard / guard match patterns are supported
# (see test_native_gen_pass.jac). Structural patterns (sequence/mapping/
# class) are not yet lowered and must still raise E5090.
test "guardrail: structural match pattern is rejected" {
    prog = compile_na_inline(
        "match_seq",
        "def classify(x: list[int]) -> int {\n"
        "    match x {\n"
        "        case [1, 2]: return 1;\n"
        "        case _: return 0;\n"
        "    }\n"
        "}\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for MatchSequence, got: {fmt_errors(
        prog
    )}";
}

# Non-capturing nested functions are supported (see test_native_gen_pass.jac).
# A nested function that captures an enclosing-function local is still
# rejected, since closure capture is not yet implemented.
test "guardrail: nested function capturing an enclosing local is rejected" {
    prog = compile_na_inline(
        "nested_def_capture",
        "def outer(y: int) -> int {\n"
        "    def inner(x: int) -> int { return x * y; }\n"
        "    return inner(5);\n"
        "}\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for capturing nested Ability, got: {fmt_errors(
        prog
    )}";
}

test "guardrail: visit statement is rejected" {
    prog = compile_na_inline(
        "visit",
        "node N { has v: int = 0; }\n"
        "walker W {\n"
        "    can run with N entry {\n"
        "        visit [-->];\n"
        "    }\n"
        "}\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for VisitStmt, got: {fmt_errors(
        prog
    )}";
}

test "guardrail: disengage statement is rejected" {
    prog = compile_na_inline(
        "disengage",
        "node N { has v: int = 0; }\n"
        "walker W {\n"
        "    can run with N entry {\n"
        "        disengage;\n"
        "    }\n"
        "}\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for DisengageStmt, got: {fmt_errors(
        prog
    )}";
}

test "guardrail: report statement is rejected" {
    prog = compile_na_inline(
        "report",
        "node N { has v: int = 0; }\n"
        "walker W {\n"
        "    can run with N entry {\n"
        "        report here.v;\n"
        "    }\n"
        "}\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for ReportStmt, got: {fmt_errors(
        prog
    )}";
}

# ─────────────────────────────────────────────────────────────────────
# Expression-level gaps
# ─────────────────────────────────────────────────────────────────────
test "guardrail: yield expression is rejected" {
    prog = compile_na_inline(
        "yield_expr", "def gen() -> int {\n" "    yield 1;\n" "    return 0;\n" "}\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for YieldExpr, got: {fmt_errors(
        prog
    )}";
}


# ─────────────────────────────────────────────────────────────────────
# Import / builtin gaps (issue #6357)
# ─────────────────────────────────────────────────────────────────────
# Native compilation cannot import arbitrary Python modules: the import is
# dropped, then `json.dumps(...)` lowers to nothing and the binary prints empty
# output. That silent-wrong result is the worst failure mode -- reject it.
# (`math`/`time`/`sys`/`os`/`random` are now lowered; `json` is still
# unsupported per the #6404 roadmap, so it stays a valid rejection example.)
test "guardrail: Python module import is rejected" {
    prog = compile_na_inline(
        "py_import_json",
        "import json;\n" "with entry { print(json.dumps({\"a\": 1})); }\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for unsupported Python import 'json', got: {fmt_errors(
        prog
    )}";
}

# A dotted Python import (`import os.path;`) is equally unsupported.
test "guardrail: dotted Python module import is rejected" {
    prog = compile_na_inline(
        "py_import_dotted", "import os.path;\n" "with entry { print(\"hi\"); }\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for unsupported Python import 'os.path', got: {fmt_errors(
        prog
    )}";
}

# Builtins that are not lowered to the native subset (sum, min, max, ...)
# currently dispatch to nothing and silently yield an empty value. Reject
# the call rather than emitting a binary that prints garbage.
test "guardrail: unsupported builtin over an iterable is rejected" {
    prog = compile_na_inline(
        "py_builtin_sum", "with entry { print(f\"Total: {sum(range(1, 101))}\"); }\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for unsupported builtin 'sum', got: {fmt_errors(
        prog
    )}";
}

# A call to a function that resolves to nothing must also be loud.
test "guardrail: call to an undefined function is rejected" {
    prog = compile_na_inline(
        "undefined_call",
        "def use() -> int { return mystery(3); }\n" "with entry { print(use()); }\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for call to undefined 'mystery', got: {fmt_errors(
        prog
    )}";
}

# ─────────────────────────────────────────────────────────────────────
# Negative controls — supported features must NOT trigger E5090
# ─────────────────────────────────────────────────────────────────────
test "guardrail: supported features do not trigger E5090" {
    prog = compile_na_inline(
        "supported_ok",
        "glob counter: int = 0;\n"
        "def add(a: int, b: int) -> int { return a + b; }\n"
        "def loops(n: int) -> int {\n"
        "    total: int = 0;\n"
        "    i: int = 0;\n"
        "    while i < n {\n"
        "        total = total + i;\n"
        "        i = i + 1;\n"
        "    }\n"
        "    for v in [1, 2, 3] { total = total + v; }\n"
        "    if total > 0 { total = total + 1; } else { total = -1; }\n"
        "    try {\n"
        "        if n < 0 { raise ValueError(\"neg\"); }\n"
        "    } except ValueError as e {\n"
        "        return -1;\n"
        "    }\n"
        "    return total;\n"
        "}\n"
    );
    assert not has_error_code(prog, "E5090") , f"Supported features triggered E5090: {fmt_errors(
        prog
    )}";
}

# `import sys;` is the one Python import the native backend models (sys.argv,
# sys.platform). Rejecting unsupported imports must not regress it.
test "guardrail: import sys is not rejected" {
    prog = compile_na_inline(
        "import_sys_ok", "import sys;\n" "with entry { print(sys.platform); }\n"
    );
    assert not has_error_code(prog, "E5090") , f"`import sys` should be supported, got: {fmt_errors(
        prog
    )}";
}
