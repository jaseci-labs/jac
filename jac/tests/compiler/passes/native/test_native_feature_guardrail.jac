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

# NOTE (issue #6146, Phase 4c): the `visit` / `disengage` / `report` guardrails
# were removed because these statements are now LOWERED to the portable kernel
# (`osp_visit` / `osp_disengage` / `osp_report`), so they no longer raise E5090.
#   * `disengage` and `visit` work end-to-end on native: edges lower to the
#     in-memory adjacency (osp_graph.jac) and the walk runs through the kernel's
#     `osp_visit`. OSP instances are pinned to a program-lifetime graph arena so
#     the walk's borrowed location handles are not refcount-freed mid-traversal.
#     The cross-backend traversal fixtures (osp_visit_order, osp_exit_ordering,
#     osp_disengage, osp_edge_typed) are `require=["na"]`.
#   * `report` works end-to-end: it lowers to `osp_report`, and the native
#     `on_complete` delivers `scope.reports` onto the walker's built-in `reports`
#     field at the spawn boundary, so `w.reports` reads back (osp_report is
#     `require=["na"]`).
# A guardrail asserting E5090 here would be a false negative now that the
# lowering exists; the equivalence fixtures are the runtime gate.

# A tuple/union trigger lowers field access on `here` through one shared member
# layout (issue #6470). When the members place a common field at *different*
# offsets, that single-layout lowering would misread it, so the native pass
# must surface E5091 rather than silently emit a wrong body.
test "guardrail: union trigger with mismatched field layout is rejected" {
    prog = compile_na_inline(
        "union_layout_conflict",
        "node Sub { has pad: int; has val: int; }\n"  # val at index 3
        "node Other { has val: int; }\n"  # val at index 2
        "walker W {\n"
        "    has either: int = 0;\n"
        "    can on_either with (Sub, Other) entry {\n"
        "        self.either = self.either + here.val;\n"
        "    }\n"
        "}\n"
    );
    assert has_error_code(prog, "E5091") , f"Expected E5091 for divergent union member layout, got: {fmt_errors(
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

# Iterating a `set` in a `for` loop is not lowered natively (the element type
# resolves to nothing), which used to drop the loop body silently. It must now
# raise E5090 instead of miscompiling -- iterate a list/range, or move to @sv.
test "guardrail: for-loop over a set is rejected" {
    prog = compile_na_inline(
        "for_over_set",
        "def run() -> int {\n"
        "    s: set[int] = {1, 2, 3};\n"
        "    total: int = 0;\n"
        "    for v in s { total = total + v; }\n"
        "    return total;\n"
        "}\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for for-over-set, got: {fmt_errors(
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

# Negative control for the silent-no-code guards (options 1 & 2 of the #6470
# audit): the consumers that now raise E5090 when a required sub-expression
# lowers to nothing (return value, assignment RHS, if/while/for conditions,
# field & subscript stores, augmented field assignment) must stay silent on
# the fully-supported forms they wrap. A false positive here would reject
# ordinary native code.
test "guardrail: field/index reads, writes, and loops do not trigger E5090" {
    prog = compile_na_inline(
        "supported_access_ok",
        "obj Pt { has x: int; has y: int; }\n"
        "obj Box { has items: list[int]; has tag: int; }\n"
        "def run() -> int {\n"
        "    p: Pt = Pt(x=1, y=2);\n"
        "    p.x = p.x + p.y;\n"  # field read + field write
        "    p.y += 5;\n"  # augmented field assignment
        "    b: Box = Box(items=[10, 20, 30], tag=0);\n"
        "    b.items[1] = b.items[1] + p.x;\n"  # subscript read + subscript write
        "    b.tag = b.items[0];\n"  # chained field/index read into field
        "    d: dict[str, int] = {\"a\": 1};\n"
        "    d[\"a\"] = d[\"a\"] + 1;\n"  # dict subscript read + write
        "    total: int = 0;\n"
        "    for v in b.items {\n"  # for over a field-held list
        "        if v > 0 { total = total + v; }\n"
        "    }\n"
        "    return total + p.x + p.y + d[\"a\"];\n"  # return of a real expression
        "}\n"
    );
    assert not has_error_code(prog, "E5090") , f"Supported field/index/loop forms triggered E5090: {fmt_errors(
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

# Edge disconnect has no native lowering (connect and traversal do - they
# ride the OSP kernel adjacency). The capability sweep rejects it
# pre-codegen.
test "guardrail: edge disconnect is rejected" {
    prog = compile_na_inline(
        "disconnect",
        "node N {}\n"
        "walker W {\n"
        "    can go with N entry {\n"
        "        here del --> [-->];\n"
        "    }\n"
        "}\n"
        "with entry { W() spawn N(); }\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for DisconnectOp, got: {fmt_errors(
        prog
    )}";
}

# ::py:: blocks cannot execute in a native binary. Before the capability
# sweep covered PyInlineCode they were silently DROPPED in native context -
# exactly the silent-failure class this guardrail file exists to prevent.
test "guardrail: inline Python block is rejected" {
    prog = compile_na_inline(
        "pyinline",
        "def f -> int {\n"
        "    ::py::\n"
        "x = 1\n"
        "::py::\n"
        "    return 1;\n"
        "}\n"
        "with entry { print(f()); }\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for PyInlineCode, got: {fmt_errors(
        prog
    )}";
}

# ─────────────────────────────────────────────────────────────────────
# OSP gate soundness (issue #6636)
# ─────────────────────────────────────────────────────────────────────
# OSP kernel emission used to be keyed on "module defines an archetype with an
# event ability", so a graph-builder module that only CONNECTS nodes (defining
# no walker) was E5090 while the byte-identical connects compiled fine next to
# an unrelated walker. The gate must key on OSP *usage*, not walker presence.
test "osp gate: connect-only module (no walker) lowers without E5090" {
    prog = compile_na_inline(
        "connect_no_walker",
        "node Area { has tag: int = 0; }\n"
        "edge In {}\n"
        "with entry {\n"
        "    a = Area(tag=1);\n"
        "    b = Area(tag=2);\n"
        "    c = Area(tag=3);\n"
        "    a +>: In() :+> b;\n"
        "    b <+: In :+> c;\n"
        "    a ++> c;\n"
        "    print(0);\n"
        "}\n"
    );
    assert not has_error_code(prog, "E5090") , f"connect-only module should lower, got: {fmt_errors(
        prog
    )}";
}

# spawn / connect on OSP archetypes IMPORTED from another native module have
# no lowering yet (cross-module archetype materialization is #6146 Phases
# 3-4): tag numbering and the __osp_setup tables are per-module, so lowering
# against an imported archetype would dispatch on mismatched type tags. The
# E5090 must fire AND its help text must name the defining module so the
# failure is diagnosable as the cross-module gap, not a generic unsupported-op.
test "osp gate: spawn/connect on imported archetypes E5090 names the import" {
    prog = compile_na_inline(
        "xmod_osp",
        "import from osp_xmod_lib { Area, In, Noop }\n"
        "with entry {\n"
        "    a = Area(tag=1);\n"
        "    b = Area(tag=2);\n"
        "    a +>: In() :+> b;\n"
        "    n = Noop();\n"
        "    n spawn a;\n"
        "    print(n.count);\n"
        "}\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for cross-module OSP, got: {fmt_errors(
        prog
    )}";
    named = False;
    for alrt in prog.errors_had {
        if (
            alrt.code is not None
            and alrt.code.code == "E5090"
            and alrt.help_text is not None
            and "osp_xmod_lib" in alrt.help_text
        ) {
            named = True;
        }
    }
    assert named , f"E5090 help should name the defining module: {fmt_errors(prog)}";
}
