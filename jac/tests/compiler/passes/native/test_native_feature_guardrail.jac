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
import from tests.support { TESTS_DIR }
import jaclang;
import from jaclang.jac0core.program { JacProgram }

glob FIXTURES_DIR = os.path.join(
         TESTS_DIR, "compiler", "passes", "native", "fixtures"
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

"""Compile a snippet through the FRONT-END check schedule (the `type_check`
extras) with codegen OFF — the `jac check` path. This is the path that
historically did NOT surface native codegen-time E5090s, so structural native
gaps stayed invisible at check time and only failed at `jac nacompile` (issue
#6636 follow-up B). The native capability authority is now run here too."""
def check_na_inline(label: str, code: str) -> JacProgram {
    path = os.path.join(FIXTURES_DIR, f"_check_{label}.na.jac");
    prog = JacProgram();
    prog.compile(file_path=path, use_str=code, type_check=True, no_cgen=True);
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

# Reading a field off an UNFILTERED node-ref element over an *untyped* edge is
# unsupported: the checker types the neighbour as `any` (a bare edge can connect
# any node types, so the adjacency returns untyped handles), so native cannot
# resolve the element to a struct layout. It must E5090 -- and crucially must
# NOT throw an uncaught codegen traceback (issue #6646 Bug 3) -- AND the
# diagnostic must guide the author to a narrowing: a `[?:Type]` node filter, or
# declaring the edge's endpoint node types. A typed receiver (edge ref, a
# `[?:Type]`-filtered node ref, or -- since #6657 -- a neighbour over an edge
# with declared endpoints) IS supported and reads correctly on native; see
# test_osp_equivalence.jac "osp field access" and "osp typed edge endpoints".
test "guardrail: field access on an untyped (any) node-ref element is rejected with a filter hint" {
    prog = compile_na_inline(
        "node_ref_any_field",
        "node N { has tag: int = 0; }\n"
        "edge Portal {}\n"
        "walker W {\n"
        "    has v: int = 0;\n"
        "    can go with N entry {\n"
        "        nbrs = [here ->:Portal:->];\n"
        "        if len(nbrs) > 0 { self.v = nbrs[0].tag; }\n"
        "    }\n"
        "}\n"
        "with entry { a = N(); b = N(tag=9); a +>: Portal() :+> b; a spawn W(); }\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for any-typed node-ref field access, got: {fmt_errors(
        prog
    )}";
    hinted = False;
    for alrt in prog.errors_had {
        if (
            alrt.code is not None
            and alrt.code.code == "E5090"
            and alrt.help_text is not None
            and "[?:" in alrt.help_text
        ) {
            hinted = True;
        }
    }
    assert hinted , f"E5090 help should suggest a `[?:Type]` filter: {fmt_errors(
        prog
    )}";
    # The native capability authority now rejects this pre-codegen, so the same
    # E5090 surfaces under `jac check` (codegen OFF), not only at `nacompile`.
    check_prog = check_na_inline(
        "node_ref_any_field",
        "node N { has tag: int = 0; }\n"
        "edge Portal {}\n"
        "walker W {\n"
        "    has v: int = 0;\n"
        "    can go with N entry {\n"
        "        nbrs = [here ->:Portal:->];\n"
        "        if len(nbrs) > 0 { self.v = nbrs[0].tag; }\n"
        "    }\n"
        "}\n"
        "with entry { a = N(); b = N(tag=9); a +>: Portal() :+> b; a spawn W(); }\n"
    );
    assert has_error_code(check_prog, "E5090") , f"Expected E5090 at check time (codegen OFF) for any-typed node-ref field access, got: {fmt_errors(
        check_prog
    )}";
}


# (The typed-endpoint counterpart -- that the UNFILTERED field read over an edge
# with declared endpoints compiles AND reads the right value on native -- is a
# behavioral test in test_osp_equivalence.jac "osp typed edge endpoints", per
# this file's convention of migrating a feature to a behavioral test once it
# gains real support.)

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

# NOTE (issue #6642): the cross-module spawn/connect/edge-ref guardrail that
# asserted E5090 was REMOVED, and so was its follow-up that asserted E5090 for a
# consumer with a tag-shifting LOCAL archetype. OSP type tags are now globally
# stable content hashes (not position-based), so imported OSP archetypes
# materialize and lower correctly in EVERY configuration -- including a consumer
# that defines its own OSP archetypes or imports from multiple modules. The
# end-to-end behavior (including the local-archetype shape) is pinned by the
# native runs in test_osp_equivalence.jac ("osp cross-module ..." and
# "osp cross-module general ..."). A guardrail asserting E5090 here would now be
# a false negative.

# ─────────────────────────────────────────────────────────────────────
# Diagnostic rendering + check/nacompile parity (issue #6636 follow-ups)
# ─────────────────────────────────────────────────────────────────────
# (A) `jac nacompile` rendered diagnostics with `str(_err)`, which drops
# `Alert.help_text` — so the cross-module-OSP / stdlib-import guidance that
# the native E5090s carry never reached the user. nacompile must render like
# `jac check` / `jac run` (Alert.pretty_print), which includes the help line.
# The stdlib-import E5090 is the simplest carrier (single file, stable help).
test "nacompile surfaces native E5090 help text, not just the generic message" {
    import contextlib;
    import io;
    import tempfile;
    import from jaclang.cli.commands.nacompile { nacompile }
    with tempfile.TemporaryDirectory() as td {
        src = os.path.join(td, "bad_import.na.jac");
        with open(src, "w") as f {
            f.write("import json;\nwith entry { print(0); }\n");
        }
        buf = io.StringIO();
        with contextlib.redirect_stdout(buf) {
            rc = nacompile(filename=src, output=os.path.join(td, "out"));
        }
        out = buf.getvalue();
        assert rc != 0 , "nacompile should fail on an unsupported stdlib import";
        assert "Native compilation supports these stdlib imports" in out , (
            f"E5090 help text missing from nacompile output:\n{out}"
        );
    }
}

# (B) `skip` is an object-spatial walker statement (Return-family); native can
# only lower it where the body returns no value — i.e. inside a walker `with`
# event ability. In a value-returning function it is unsupported. That rejection
# used to be a codegen-time E5090 only, so `jac check` passed while `jac
# nacompile` failed. The native capability authority now sees it, so BOTH agree.
test "check rejects skip in a value-returning native function" {
    prog = check_na_inline(
        "skip_in_value_fn",
        "def f(n: int) -> int {\n"
        "    for i in range(n) {\n"
        "        if i == 2 { skip; }\n"
        "    }\n"
        "    return n;\n"
        "}\n"
        "with entry { print(f(5)); }\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 at check for skip-in-value-fn, got: {fmt_errors(
        prog
    )}";
}

test "check accepts skip in a walker event ability" {
    prog = check_na_inline(
        "skip_in_event_ability",
        "node C { has tag: int; }\n"
        "walker W {\n"
        "    has seen: list[C] = [];\n"
        "    can step with C entry {\n"
        "        if here in self.seen { skip; }\n"
        "        self.seen.append(here);\n"
        "    }\n"
        "}\n"
        "with entry { W() spawn C(tag=1); }\n"
    );
    assert not has_error_code(prog, "E5090") , f"skip in an event ability should be accepted, got: {fmt_errors(
        prog
    )}";
}

test "nacompile still rejects skip in a value-returning native function" {
    prog = compile_na_inline(
        "skip_in_value_fn_cg",
        "def f(n: int) -> int {\n"
        "    for i in range(n) {\n"
        "        if i == 2 { skip; }\n"
        "    }\n"
        "    return n;\n"
        "}\n"
        "with entry { print(f(5)); }\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 at full compile for skip-in-value-fn, got: {fmt_errors(
        prog
    )}";
}

# ─────────────────────────────────────────────────────────────────────
# C-library (clib) import decl type resolution
# ─────────────────────────────────────────────────────────────────────
test "check rejects clib decl with an unknown parameter type" {
    prog = check_na_inline(
        "clib_unknown_param",
        "import from \"/usr/lib/libm.so.6\" {\n"
        "    def takes_unknown(x: uint32_t) -> f64;\n"
        "}\n"
    );
    assert has_error_code(prog, "E2018") , f"Expected E2018 for unknown clib param type 'uint32_t', got: {fmt_errors(
        prog
    )}";
}

test "check rejects clib decl with an unknown return type" {
    prog = check_na_inline(
        "clib_unknown_ret",
        "import from \"/usr/lib/libm.so.6\" {\n"
        "    def make_handle(x: f64) -> some_handle;\n"
        "}\n"
    );
    assert has_error_code(prog, "E2018") , f"Expected E2018 for unknown clib return type 'some_handle', got: {fmt_errors(
        prog
    )}";
}

test "nacompile rejects clib decl with an unknown type (no silent i64)" {
    prog = compile_na_inline(
        "clib_unknown_cg",
        "import from \"/usr/lib/libm.so.6\" {\n"
        "    def takes_unknown(x: uint32_t) -> some_handle;\n"
        "}\n"
        "def use_it(n: f64) -> f64 { return n; }\n"
    );
    assert has_error_code(prog, "E2018") , f"Expected E2018 (not a silent i64 declare) for unknown clib types, got: {fmt_errors(
        prog
    )}";
}

# Native signatures with unresolved annotation types are E2018, not W2001.
test "check rejects a native def with an unknown parameter type" {
    prog = check_na_inline(
        "native_unknown_param", "def takes_unknown(x: uint32_t) -> int { return 0; }\n"
    );
    assert has_error_code(prog, "E2018") , f"Expected E2018 for unknown native param type 'uint32_t', got: {fmt_errors(
        prog
    )}";
}

test "check rejects a native def with an unknown return type" {
    prog = check_na_inline(
        "native_unknown_ret", "def make_it(x: int) -> some_handle { return x; }\n"
    );
    assert has_error_code(prog, "E2018") , f"Expected E2018 for unknown native return type 'some_handle', got: {fmt_errors(
        prog
    )}";
}

# Object field annotations are caught at codegen; E2018 must name the written type.
test "native object field with an unknown type names the type, not '<Unknown>'" {
    prog = compile_na_inline(
        "obj_field_unknown",
        "obj Handle { has raw: uint32_t; }\n"
        "with entry { h = Handle(raw=0); print(h.raw); }\n"
    );
    assert has_error_code(prog, "E2018") , f"Expected E2018 for unknown object field type, got: {fmt_errors(
        prog
    )}";
    named = False;
    for alrt in prog.errors_had {
        if (
            alrt.code is not None
            and alrt.code.code == "E2018"
            and "uint32_t" in str(alrt)
            and "<Unknown>" not in str(alrt)
        ) {
            named = True;
        }
    }
    assert named , f"E2018 should name 'uint32_t', not '<Unknown>': {fmt_errors(prog)}";
}

# Negative control: known clib types must compile without E2018/E5090.
test "clib decl with known types is not rejected" {
    prog = compile_na_inline(
        "clib_known_ok",
        "import from \"/usr/lib/libm.so.6\" {\n"
        "    obj Vec2 { has x: f64, y: f64; }\n"
        "    def sqrt(x: f64) -> f64;\n"
        "    def scale(v: Vec2, s: f64) -> Vec2;\n"
        "}\n"
        "def hypot(a: f64, b: f64) -> f64 { return sqrt(a * a + b * b); }\n"
    );
    assert not has_error_code(prog, "E2018") , f"Known clib types triggered E2018: {fmt_errors(
        prog
    )}";
    assert not has_error_code(prog, "E5090") , f"Known clib types triggered E5090: {fmt_errors(
        prog
    )}";
}
