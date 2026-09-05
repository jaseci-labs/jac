"""Guardrail tests for the .jac / na {} native pipeline.

These tests verify that NaIRGenPass raises a clear E5090 error on AST
node types it does not yet support, rather than silently dropping them
and emitting empty function bodies.

Each test below targets one feature that NaIRGenPass currently no-ops.
When a feature gains real support, its test here should be deleted and
a behavioral test added to test_native_gen_pass.jac -- unless the
guardrail property survives the promotion in a stronger form, in which
case the test stays and pins the lowering instead. That is what the set
iteration below does: a demotion only promised Python would answer, so
pinning the two lanes to the same value is a strictly better statement
of "never miscompiles" than the demotion assertion it replaced.

A regression that re-introduces silent-failure mode shows up here as a
test that fails: "expected E5090, got no errors" — which is exactly the
class of bug this guardrail exists to prevent.
"""

import ctypes;
import os;
import from tests.support { TESTS_DIR, native_force_opts }
import jaclang;
import from jaclang.compiler.driver.program { JacProgram }
import from jaclang.compiler.driver.compile_options { CompileOptions }

glob FIXTURES_DIR = os.path.join(
         TESTS_DIR, "compiler", "backends", "native", "fixtures"
     );

"""Compile a snippet through the native pipeline and return the program.

Uses a synthetic .jac path under the fixtures directory so the file
extension routes the compile through NaIRGenPass.
"""
def compile_na_inline(label: str, code: str) -> JacProgram {
    path = os.path.join(FIXTURES_DIR, f"_guardrail_{label}.jac");
    prog = JacProgram();
    prog.compile(file_path=path, use_str=code, options=native_force_opts());
    return prog;
}

"""Like `compile_na_inline`, but also hand back the compiled module (for
layout assertions) and the JAC_NA_DEBUG stderr stream (for demotion-reason
assertions -- granular demotion reports its cause there rather than as a
program error)."""
def compile_na_inline_demote(label: str, code: str) -> tuple {
    import contextlib;
    import io;
    path = os.path.join(FIXTURES_DIR, f"_guardrail_{label}.jac");
    prog = JacProgram();
    buf = io.StringIO();
    _prev = os.environ.get("JAC_NA_DEBUG");
    os.environ["JAC_NA_DEBUG"] = "1";
    try {
        with contextlib.redirect_stderr(buf) {
            ir = prog.compile(
                file_path=path, use_str=code, options=native_force_opts()
            );
        }
    } finally {
        if _prev is None {
            del os.environ["JAC_NA_DEBUG"];
        } else {
            os.environ["JAC_NA_DEBUG"] = _prev;
        }
    }
    return (prog, ir, buf.getvalue(), );
}

"""Compile a snippet through the FRONT-END check schedule (the `type_check`
extras) with codegen OFF — the `jac check` path. This is the path that
historically did NOT surface native codegen-time E5090s, so structural native
gaps stayed invisible at check time and only failed at `jac nacompile` (issue
#6636 follow-up B). The native capability authority is now run here too."""
def check_na_inline(label: str, code: str) -> JacProgram {
    path = os.path.join(FIXTURES_DIR, f"_check_{label}.jac");
    prog = JacProgram();
    prog.compile(
        file_path=path,
        use_str=code,
        options=CompileOptions(
            no_cgen=True,
            native_parity=True,
            force_codespace="native",
            force_target_program=True
        )
    );
    return prog;
}

"""Call a no-argument int-returning function out of a compiled module's JIT
engine. A guardrail that has become a lowering pin needs the native lane's
answer, not just its layout membership."""
def native_answer(eng: any, name: str) -> int {
    assert eng is not None , f"no native engine produced for {name}";
    addr = eng.get_function_address(name);
    assert addr != 0 , f"'{name}' not found in the JIT engine";
    return ctypes.CFUNCTYPE(ctypes.c_int64)(addr)();
}

"""Run the same snippet through the server (Python) lane and call one of its
functions. This is the other half of a two-lane pin: a lowering is only correct
if it agrees with the lane it replaced."""
def server_answer(label: str, code: str, name: str) -> int {
    path = os.path.join(FIXTURES_DIR, f"_guardrail_{label}.jac");
    prog = JacProgram();
    ir = prog.compile(
        file_path=path, use_str=code, options=CompileOptions(default_codespace='server')
    );
    assert not prog.errors_had , f"server-lane compilation errors: {fmt_errors(prog)}";
    ns: dict = {};
    exec(compile(ir.gen.py, path, "exec"), ns);
    return ns[name]();
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
# All match pattern kinds are supported (value / OR / capture / wildcard /
# guard in test_native_gen_pass.jac; sequence / mapping / star / class in
# test_native_match_patterns.jac), so the structural-pattern guardrail was
# deleted per this file's convention.

# Nested functions capturing enclosing locals lower natively (read captures
# bind by value at each call, rebound captures write through a frame-slot
# pointer), and escaping capturing closures lower via closure conversion
# (RC heap cells + {fn, env} pairs); behavioral coverage lives in
# test_native_closures.jac. Only a capture borrowed from an outer frame, a
# closure call through an `any`-typed value, and capturing map/filter
# lambda callbacks remain rejected, with a structured E5092 from codegen.

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
# Generators lower natively (state-machine resume over the JacIter ABI);
# behavioral coverage lives in test_native_generators.jac. A yield in a
# function that does not declare a generator-family return type is still a
# structured error, never a silent drop.
test "guardrail: yield without a generator return type is rejected" {
    prog = compile_na_inline(
        "yield_expr", "def gen() -> int {\n" "    yield 1;\n" "    return 0;\n" "}\n"
    );
    assert has_error_code(prog, "E5092") , f"Expected E5092 for yield in a non-generator signature, got: {fmt_errors(
        prog
    )}";
}

# Reading a field off an UNFILTERED node-ref element over an *untyped* edge is
# unsupported: the checker types the neighbour as `any` (a bare edge can connect
# any node types, so the adjacency returns untyped handles), so native cannot
# resolve the element to a struct layout. The ability that reads it is the
# violation's owning unit, so granular demotion (epic #8201) seams exactly that
# ability instead of refusing the whole module -- and crucially must NOT throw
# an uncaught codegen traceback (issue #6646 Bug 3). The `[?:Type]` narrowing
# guidance still reaches the author through the demotion diagnostic. A typed
# receiver (edge ref, a `[?:Type]`-filtered node ref, or -- since #6657 -- a
# neighbour over an edge with declared endpoints) IS supported and reads
# correctly on native; see test_osp_equivalence.jac "osp field access" and
# "osp typed edge endpoints".
test "guardrail: field access on an untyped (any) node-ref element demotes the ability with a filter hint" {
    (prog, ir, log) = compile_na_inline_demote(
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
    assert not has_error_code(prog, "E5090") , f"An ability-owned violation must demote, not fail the module: {fmt_errors(
        prog
    )}";
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "W.go" not in layout.methods , (
        "the violating ability must be demoted out of the native layout"
    );
    assert "NA_DEBUG demote W.go" in log , f"no demotion recorded for W.go in:\n{log}";
    assert "[?:" in log , f"the demotion diagnostic should suggest a `[?:Type]` filter:\n{log}";
}


# (The typed-endpoint counterpart -- that the UNFILTERED field read over an edge
# with declared endpoints compiles AND reads the right value on native -- is a
# behavioral test in test_osp_equivalence.jac "osp typed edge endpoints", per
# this file's convention of migrating a feature to a behavioral test once it
# gains real support.)

test "guardrail: starred tuple assignment is rejected" {
    src = (
        "with entry {\n" "    (first, *rest) = (1, 2, 3);\n" "    print(first);\n" "}\n"
    );
    prog = compile_na_inline("starred_tuple_assign", src);
    assert has_error_code(prog, "E5090") , f"Expected E5090 for starred tuple assignment, got: {fmt_errors(
        prog
    )}";
    checked = check_na_inline("starred_tuple_assign_check", src);
    assert has_error_code(checked, "E5090") , (
        "the front-end native capability gate must reject starred tuple "
        f"assignment, got: {fmt_errors(checked)}"
    );
}

# ─────────────────────────────────────────────────────────────────────
# Import / builtin gaps (issue #6357)
# ─────────────────────────────────────────────────────────────────────
# Native compilation cannot import an ARBITRARY Python module: the import is
# dropped, then `collections.OrderedDict(...)` lowers to nothing and the binary
# prints empty output. That silent-wrong result is the worst failure mode --
# reject it. (`math`/`time`/`sys`/`os`/`random` are lowered builtins, and the
# bundled `na_stdlib` modules -- `hashlib`/`json`/`os.path`/... -- are now
# whole-module-importable per #6978; so the rejection example must be a module
# that is neither, i.e. a pure-Python one like `collections` that will never be
# an FFI-floor target.)
test "guardrail: Python module import is rejected" {
    prog = compile_na_inline(
        "py_import_collections",
        "import collections;\n" "with entry { print(collections.OrderedDict()); }\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for unsupported Python import 'collections', got: {fmt_errors(
        prog
    )}";
}

# A dotted non-bundled Python import is equally unsupported (a dotted
# bundled name like `os.path` now resolves, #6978; `collections.abc`
# joined NATIVE_SUPPORTED_STDLIB with the unitree lowering coverage).
test "guardrail: dotted Python module import is rejected" {
    prog = compile_na_inline(
        "py_import_dotted", "import xml.etree;\n" "with entry { print(\"hi\"); }\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for unsupported Python import 'xml.etree', got: {fmt_errors(
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
    assert has_error_code(prog, "E5092") , f"Expected E5092 for unsupported builtin 'sum', got: {fmt_errors(
        prog
    )}";
}

# A call to a function that resolves to nothing must also be loud.
test "guardrail: call to an undefined function is rejected" {
    prog = compile_na_inline(
        "undefined_call",
        "def use() -> int { return mystery(3); }\n" "with entry { print(use()); }\n"
    );
    assert prog.errors_had , f"Expected a loud analysis-time rejection for call to undefined 'mystery', got: {fmt_errors(
        prog
    )}";
}

# Iterating a `set` in a `for` loop LOWERS. It used to drop the loop body
# silently, then (with granular demotion) leave the function out of the native
# layout entirely, because a set's element type resolved to nothing and the
# native lane had no storage for an erased element. The rc-facts solver's
# dataflow prerequisite fixed both halves: a set-typed lattice keeps its
# element type, and `_codegen_for` grew a real set iteration to go with it.
#
# So this is no longer a guardrail against a silent drop -- it is the pin on
# the lowering that replaced it, and it keeps the never-miscompile property in
# the strongest available form. Demotion only ever promised that Python would
# answer instead; agreement between the lanes promises the native answer is
# right. A regression to a silent body-drop fails on the value, a regression to
# demotion fails on layout membership, and either way this test names it.
test "for-loop over a set lowers, and both lanes answer the same sum" {
    src = "def run() -> int {\n"
    "    s: set[int] = {1, 2, 3};\n"
    "    total: int = 0;\n"
    "    for v in s { total = total + v; }\n"
    "    return total;\n"
    "}\n";
    (prog, ir, log) = compile_na_inline_demote("for_over_set", src);
    assert not prog.errors_had , f"a lowered set loop must compile clean, got: {fmt_errors(
        prog
    )}";
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "run" in layout.functions , (
        "iterating a set lowers now; run must stay in the native layout"
    );
    assert "NA_DEBUG demote run" not in log , (
        f"run must not demote for iterating a set:\n{log}"
    );
    native = native_answer(ir.gen.native_engine, "run");
    assert native == 6 , (
        f"the native lane must sum every element of the set once, got {native}"
    );
    server = server_answer("for_over_set", src, "run");
    assert native == server , (
        f"the lanes disagree on the set sum: native {native}, server {server}"
    );
}

# A container stored inside another container comes back as a bare pointer:
# the outer dict keeps pointer-valued entries untyped, so the inner
# `dict`/`list` arrives with no layout attached. Subscripting a bare pointer
# used to fall straight through to the string-index emitter, which read the
# inner container's header bytes as characters -- `b['items']` compiled to a
# character load and raised IndexError at run time. Only an integer index can
# mean "index this string", so a non-integer key is a seam, not a character.
test "guardrail: subscripting an element-erased container is not a char read" {
    (prog, ir, log) = compile_na_inline_demote(
        "erased_subscript",
        "def run(t: dict[int, dict[str, list[str]]]) -> int {\n"
        "    for b in t.values() {\n"
        "        if len(b['items']) > 0 { return 1; }\n"
        "    }\n"
        "    return 0;\n"
        "}\n"
    );
    assert not prog.errors_had , f"A function-owned E5092 must demote, got: {fmt_errors(
        prog
    )}";
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "run" not in layout.functions , (
        "an erased-container subscript must demote, not compile to a char read"
    );
    assert "subscript of an element-erased collection" in log , (
        f"the demotion must name the erased subscript, got:\n{log}"
    );
}


# The same erasure reaching a membership test: every registered container
# answers `in` from its own layout, and the one pointer shape left over is the
# substring test. It used to accept any two pointers, so an object needle
# handed `strstr` a `%Tag*` and raised a raw llvmlite TypeError -- an ICE-shaped
# demotion with no diagnostic of its own.
test "guardrail: membership with a non-string needle names its seam" {
    (prog, ir, log) = compile_na_inline_demote(
        "erased_membership",
        "obj Tag { has n: int = 0; }\n"
        "def run(t: dict[str, list[Tag]], x: Tag) -> int {\n"
        "    for v in t.values() {\n"
        "        if x in v { return 1; }\n"
        "    }\n"
        "    return 0;\n"
        "}\n"
    );
    assert not prog.errors_had , f"A function-owned E5092 must demote, got: {fmt_errors(
        prog
    )}";
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "run" not in layout.functions , (
        "an erased-container membership test must demote"
    );
    assert "membership over an element-erased collection" in log , (
        f"the demotion must name the erased membership test, got:\n{log}"
    );
    assert "TypeError" not in log , (
        f"the seam must be a diagnostic, not a raw emitter crash:\n{log}"
    );
}


# A demotion is telemetry, not an answer: the author gets a silently-slower
# function and no instruction. Where the operand genuinely has no static type,
# the checker now refuses it at check time (#8323, decision 3) and says what to
# write. The emitter guard above stays as defense in depth for whatever reaches
# it by another route rather than as the only thing standing between an erased
# container and `strstr`.
#
# The two erased shapes the checker can see, and both are annotation bugs the
# author can act on: an operand typed `any`, and a builtin container spelled
# without its element types.
test "checker: membership over an operand with no static type is refused (E1124)" {
    prog = check_na_inline(
        "erased_membership_any",
        "def run(t: any, x: int) -> int {\n"
        "    if x in t { return 1; }\n"
        "    return 0;\n"
        "}\n"
    );
    assert has_error_code(prog, "E1124") , (
        f"an `any`-typed membership operand must be refused at check time, got: {fmt_errors(
            prog
        )}"
    );
    # The refusal must name the remedy the author can act on, not just the fact.
    e1124 = [
        e
        for e in prog.errors_had
        if e.code is not None and e.code.code == "E1124"
    ];
    for e in e1124 {
        _help = e.code.help_text if e.code is not None else None;
        assert "annotate" in (_help or "") , (
            f"E1124 must demand an annotation, got: {e}"
        );
    }
}


# A bare `list`/`dict`/`set` operand is erased too, but it is NOT this arm's
# job. It HAS a static type -- the container is merely unparameterized -- and
# the fix belongs at the annotation, where one refusal covers every use, rather
# than at each membership test, where the author would collect N copies of the
# same instruction. Decision 3's first half refuses the annotation itself; this
# arm stays out of its way.
#
# The distinction was not free to learn. An earlier cut of this check also
# refused unparameterized containers, and the seal caught it: NON_ESCAPED_KEYWORDS
# in compiler/frontend/constant.jac and _proto_checks_in_progress in
# types/impl/type_utils.impl.jac are both bare `set`, so the compiler
# refused to compile itself.
test "checker: a bare container operand is left to the annotation refusal" {
    prog = check_na_inline(
        "erased_membership_bare",
        "def lst(t: list, x: int) -> int { if x in t { return 1; } return 0; }\n"
        "def dct(t: dict, x: str) -> int { if x not in t { return 1; } return 0; }\n"
        "def st(t: set, x: int) -> int { if x in t { return 1; } return 0; }\n"
    );
    assert not has_error_code(prog, "E1124") , (
        "an unparameterized container has a static type; refusing it here would "
        f"duplicate the annotation refusal at every use site, got: {fmt_errors(prog)}"
    );
}


# The residual this arm does NOT close, recorded rather than papered over.
#
# `v` here is `list[Tag]` by the checker's own reckoning -- fully typed, nothing
# for the author to annotate -- yet the emitter still refuses it as
# element-erased and demotes `run`. The erasure is introduced by the lowering of
# `t.values()`, which does not carry the value type's layout through to the
# comparison; it is not a missing annotation. Demanding one here would be the
# checker telling the author to fix something already correct, so E1124
# deliberately stays silent and the demotion above remains the honest answer
# until the `dict.values()` lowering carries its element layout.
test "checker: a correctly-typed operand the emitter still erases is not refused" {
    prog = check_na_inline(
        "erased_membership_emitter_side",
        "obj Tag { has n: int = 0; }\n"
        "def run(t: dict[str, list[Tag]], x: Tag) -> int {\n"
        "    for v in t.values() {\n"
        "        if x in v { return 1; }\n"
        "    }\n"
        "    return 0;\n"
        "}\n"
    );
    assert not has_error_code(prog, "E1124") , (
        "`v` is list[Tag]: the erasure is the emitter's, and demanding an "
        f"annotation for an annotated operand would be a false accusation, got: {fmt_errors(
            prog
        )}"
    );
}


# The negative control for the checker arm: an operand that carries its element
# type answers `in` from its own layout and must never be refused. This is the
# shape rider 1 of #8323 makes the norm, so a false positive here would refuse
# most correctly-typed native code.
test "checker: typed containers and strings are never refused" {
    prog = check_na_inline(
        "membership_typed_ok",
        "def sub(s: str, w: str) -> int { if w in s { return 1; } return 0; }\n"
        "def lst(w: str, l: list[str]) -> int { if w in l { return 1; } return 0; }\n"
        "def dct(k: str, d: dict[str, int]) -> int {\n"
        "    if k in d { return 1; }\n"
        "    return 0;\n"
        "}\n"
        "def st(w: str, s: set[str]) -> int { if w not in s { return 1; } return 0; }\n"
        "def tup(w: str, t: tuple[str, str]) -> int {\n"
        "    if w in t { return 1; }\n"
        "    return 0;\n"
        "}\n"
    );
    assert not has_error_code(prog, "E1124") , (
        f"typed containers must answer membership without a refusal, got: {fmt_errors(
            prog
        )}"
    );
}


# ─────────────────────────────────────────────────────────────────────
# Negative controls — supported features must NOT trigger E5090
# ─────────────────────────────────────────────────────────────────────
# The guards above must not cost the shapes that do lower: a substring test
# over two plain strings, and a membership test over a directly-typed list.
test "guardrail: string and typed-list membership still lower" {
    (prog, ir, log) = compile_na_inline_demote(
        "membership_ok",
        "def sub(s: str, w: str) -> int { if w in s { return 1; } return 0; }\n"
        "def nsub(s: str, w: str) -> int { if w not in s { return 1; } return 0; }\n"
        "def lst(w: str) -> int {\n"
        "    l: list[str] = [\"alpha\", \"beta\"];\n"
        "    if w in l { return 1; }\n"
        "    return 0;\n"
        "}\n"
        "def chr_at(s: str, i: int) -> str { return s[i]; }\n"
    );
    assert not prog.errors_had , f"Supported membership must not error, got: {fmt_errors(
        prog
    )}";
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    for name in ["sub", "nsub", "lst", "chr_at"] {
        assert name in layout.functions , (
            f"'{name}' must still lower natively; demotion log:\n{log}"
        );
    }
}


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

# A3 (issue #6930): a field whose type the native backend cannot model lowers
# to a nullable opaque slot (null at native construction) instead of rejecting
# the declaration. A type-only foreign import that merely NAMES that type
# (`import ast as ast3;` used only in the annotation `ast3.AST | None`) is
# tolerated -- it is never lowered to a runtime value. Neither the field nor the
# import may trigger E5090.
test "guardrail: foreign-typed field lowers to an opaque slot, not E5090" {
    prog = compile_na_inline(
        "opaque_foreign_field",
        "import ast as ast3;\n"
        "obj Carrier {\n"
        "    has name: str,\n"
        "        py_ctx: ast3.AST | None = None;\n"
        "    def label -> str { return self.name; }\n"
        "}\n"
        "with entry { print(Carrier(name=\"x\").label()); }\n"
    );
    assert not has_error_code(prog, "E5090") , f"Foreign-typed field / type-only import triggered E5090: {fmt_errors(
        prog
    )}";
    # Same must hold at check time (codegen OFF), so `jac check` and
    # `jac nacompile` agree.
    check_prog = check_na_inline(
        "opaque_foreign_field",
        "import ast as ast3;\n"
        "obj Carrier {\n"
        "    has name: str,\n"
        "        py_ctx: ast3.AST | None = None;\n"
        "    def label -> str { return self.name; }\n"
        "}\n"
        "with entry { print(Carrier(name=\"x\").label()); }\n"
    );
    assert not has_error_code(check_prog, "E5090") , f"Foreign-typed field / type-only import triggered E5090 at check time: {fmt_errors(
        check_prog
    )}";
}

# The opaque slot is null and never dereferenced on the native path. If native
# code DOES dereference it (reads an attribute off the foreign value), that must
# still raise E5090 -- the "error only when the opaque value is actually used"
# half of A3. A type-only import stays type-only here: `ast3` appears solely in
# the annotation, never as a runtime value.
test "guardrail: dereferencing an opaque foreign field is rejected" {
    prog = compile_na_inline(
        "opaque_foreign_deref",
        "import ast as ast3;\n"
        "obj Carrier {\n"
        "    has node: ast3.AST | None = None;\n"
        "    def line -> int { return self.node.lineno; }\n"
        "}\n"
        "with entry { print(Carrier().line()); }\n"
    );
    assert prog.errors_had , f"Expected a loud analysis-time rejection for dereference of an opaque foreign field, got: {fmt_errors(
        prog
    )}";
}

# A foreign import used as a RUNTIME VALUE (not merely as a type) stays rejected:
# the type-only tolerance must not become a blanket import allowance (issue
# #6357). `ast3.parse(...)` calls into the dropped module and would lower to
# garbage.
test "guardrail: foreign import used as a runtime value is still rejected" {
    prog = compile_na_inline(
        "foreign_runtime_use",
        "import ast as ast3;\n"
        "def f -> int { x = ast3.parse(\"1\"); return 0; }\n"
        "with entry { print(f()); }\n"
    );
    assert has_error_code(prog, "E5090") , f"Expected E5090 for runtime use of a foreign import, got: {fmt_errors(
        prog
    )}";
}

# Edge disconnect lowers natively for scalar AND list-valued endpoints:
# scalars through osp_disconn_between, list operands through
# osp_disconn_between_many (a scalar side wrapped with osp_wrap1), and
# attribute predicates through osp_disconn_between_pred (#8775 step 3).
# The residual unlowered shape is a LIST operand combined with attribute
# predicates - one kernel call does not carry both today - and codegen
# rejects that with a structured E5092 instead of silently disconnecting
# nothing.
test "guardrail: list-endpoint disconnect lowers; list plus predicate stays loud" {
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
    assert not prog.errors_had , f"a list-endpoint disconnect must lower via osp_disconn_between_many, got: {fmt_errors(
        prog
    )}";
    prog2 = compile_na_inline(
        "disconnect_pred_list",
        "edge E { has w: int = 0; }\n"
        "node N {}\n"
        "walker W {\n"
        "    can go with N entry {\n"
        "        here del ->:E:w>1:-> [-->];\n"
        "    }\n"
        "}\n"
        "with entry { W() spawn N(); }\n"
    );
    assert has_error_code(prog2, "E5092") , f"Expected E5092 for a list-endpoint DisconnectOp with predicates, got: {fmt_errors(
        prog2
    )}";
}

# ::py:: blocks cannot execute in a native binary. Before the capability
# sweep covered PyInlineCode they were silently DROPPED in native context -
# exactly the silent-failure class this guardrail file exists to prevent.
# Granular demotion seams the owning function (Python executes the block),
# and a NATIVE caller of the demoted function stays a structured error
# rather than silently binding its abort stub.
test "guardrail: inline Python block demotes its function, native callers stay loud" {
    (prog, ir, log) = compile_na_inline_demote(
        "pyinline",
        "def f -> int {\n" "    ::py::\n" "x = 1\n" "::py::\n" "    return 1;\n" "}\n"
    );
    assert not prog.errors_had , f"A function-owned PyInlineCode must demote, got: {fmt_errors(
        prog
    )}";
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "f" not in layout.functions , (
        "the PyInlineCode function must be demoted out of the native layout"
    );
    assert "NA_DEBUG demote f" in log , f"no demotion recorded for f in:\n{log}";
    caller = compile_na_inline(
        "pyinline_caller",
        "def f -> int {\n"
        "    ::py::\n"
        "x = 1\n"
        "::py::\n"
        "    return 1;\n"
        "}\n"
        "with entry { print(f()); }\n"
    );
    assert has_error_code(caller, "E5092") , f"A native caller of a demoted function must fail loudly, got: {fmt_errors(
        caller
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
        src = os.path.join(td, "bad_import.jac");
        with open(src, "w") as f {
            f.write("import collections;\nwith entry { print(0); }\n");
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
# event ability. In a value-returning function it is unsupported: granular
# demotion seams that function, and the module entry that natively calls it
# then fails with a structured E5092. The check-parity schedule runs the same
# codegen at check time, so `jac check` and `jac nacompile` still agree.
test "check surfaces the demoted skip-in-value-fn through its native caller" {
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
    assert has_error_code(prog, "E5092") , f"Expected E5092 at check for the native caller of the demoted skip-in-value-fn, got: {fmt_errors(
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

test "nacompile demotes skip-in-value-fn and rejects its native caller" {
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
    assert has_error_code(prog, "E5092") , f"Expected E5092 at full compile for the native caller of the demoted skip-in-value-fn, got: {fmt_errors(
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

# Unknown object field annotations are rejected at analysis time (E2018 from
# StaticAnalysisPass, the single detection source) naming the written type.
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

# ─────────────────────────────────────────────────────────────────────
# open() builtin vs. the POSIX open(path, flags_int) extern (issue #7010)
# ─────────────────────────────────────────────────────────────────────
# `open` is a native builtin lowering to fopen(path, mode_str) (a File). The
# POSIX `open(path, flags_int) -> fd` syscall shares the name but is a libc
# extern callers import. When such an extern is NOT in scope (e.g. a standalone
# precompile of a native module whose libc imports live in a sibling file), an
# integer second argument used to be forced through fopen(i8*, i8*), raising a
# raw `TypeError: Type of #2 arg mismatch: i8* != i64` straight out of the IR
# builder — an internal compiler crash, not a diagnostic. It must surface the
# same clean E5090 every other unlowerable native call gets. A regression
# re-raises the TypeError, failing this test with an error (not an assertion).
test "guardrail: open() with a non-string (POSIX flags) mode is a clean diagnostic, not an ICE" {
    prog = compile_na_inline(
        "posix_open_flags",
        "def parse_argc(path: str) -> i32 {\n"
        "    fd: i32 = open(path, 0);\n"
        "    if fd >= 0 { return fd; }\n"
        "    return -1;\n"
        "}\n"
    );
    assert prog.errors_had , f"Expected a clean diagnostic for POSIX open(path, flags), got: {fmt_errors(
        prog
    )}";
    for alrt in prog.errors_had {
        if alrt.code is not None {
            assert alrt.code.code not in ("E9001", "E9002") , f"ICE leaked for POSIX open(path, flags): {fmt_errors(
                prog
            )}";
        }
    }
}

# Positive control: with the libc `open(path, flags) -> i32` extern in scope
# (the real native-build case, where cef_dispatch.jac declares it), the call
# resolves to the POSIX extern rather than the file-open builtin — no crash and
# no E5090. This is what lets the spliced CEF native modules compile.
test "declared libc open(path, flags) extern resolves without the file-open builtin" {
    prog = compile_na_inline(
        "posix_open_extern",
        "import from \"libc.so.6\" {\n"
        "    def open(path: str, flags: i32) -> i32;  def close(fd: i32) -> i32;\n"
        "}\n"
        "def use_fd(path: str) -> i32 {\n"
        "    fd: i32 = open(path, 0);\n"
        "    if fd >= 0 { close(fd); }\n"
        "    return fd;\n"
        "}\n"
    );
    assert not has_error_code(prog, "E5090") , f"Declared POSIX open extern triggered E5090: {fmt_errors(
        prog
    )}";
}

"""Compile a snippet through the sv pipeline (plain .jac path)."""
def compile_sv_inline(label: str, code: str) -> JacProgram {
    path = os.path.join(FIXTURES_DIR, f"_guardrail_{label}.jac");
    prog = JacProgram();
    prog.compile(file_path=path, use_str=code, options=native_force_opts());
    return prog;
}

# Walrus on non-Name targets is a SyntaxError in CPython; Jac rejects it
# with the general E0020 in ASTValidationPass on every backend. These pin
# that E0020 stays the single diagnostic: no native-specific E5090
# duplicate, no E5007 bootstrap cascade, no E9001/E9002 ICE (#7593 item 3).
test "walrus on a subscript target: one general E0020, no native cascade" {
    prog = compile_na_inline(
        "walrus_subscript_lhs", "with entry { xs = [1, 2, 3]; print((xs[0] := 9)); }\n"
    );
    assert has_error_code(prog, "E0020") , f"Expected general E0020, got: {fmt_errors(
        prog
    )}";
    assert not has_error_code(prog, "E5090") , f"native E5090 duplicate leaked: {fmt_errors(
        prog
    )}";
    assert not has_error_code(prog, "E5007") , f"bootstrap E5007 cascade leaked: {fmt_errors(
        prog
    )}";
    for alrt in prog.errors_had {
        if alrt.code is not None {
            assert alrt.code.code not in ("E9001", "E9002") , f"ICE leaked: {fmt_errors(
                prog
            )}";
        }
    }
}

test "walrus on an attribute target: one general E0020, no native cascade" {
    prog = compile_na_inline(
        "walrus_attr_lhs",
        "obj Box { has f: int = 0; }\n" "with entry { b = Box(); print((b.f := 5)); }\n"
    );
    assert has_error_code(prog, "E0020") , f"Expected general E0020, got: {fmt_errors(
        prog
    )}";
    assert not has_error_code(prog, "E5090") , f"native E5090 duplicate leaked: {fmt_errors(
        prog
    )}";
    assert not has_error_code(prog, "E5007") , f"bootstrap E5007 cascade leaked: {fmt_errors(
        prog
    )}";
    for alrt in prog.errors_had {
        if alrt.code is not None {
            assert alrt.code.code not in ("E9001", "E9002") , f"ICE leaked: {fmt_errors(
                prog
            )}";
        }
    }
}

test "walrus on a subscript target is the same single E0020 on sv" {
    prog = compile_sv_inline(
        "walrus_subscript_sv", "with entry { xs = [1, 2, 3]; print((xs[0] := 9)); }\n"
    );
    assert has_error_code(prog, "E0020") , f"Expected general E0020, got: {fmt_errors(
        prog
    )}";
    assert not has_error_code(prog, "E5007") , f"bootstrap E5007 cascade leaked: {fmt_errors(
        prog
    )}";
    for alrt in prog.errors_had {
        if alrt.code is not None {
            assert alrt.code.code not in ("E9001", "E9002") , f"ICE leaked: {fmt_errors(
                prog
            )}";
        }
    }
}

# Green pin (already true on main): check-time shape yields exactly E0020.
test "walrus on a subscript target at check time is E0020 only" {
    prog = check_na_inline(
        "walrus_subscript_lhs_chk",
        "with entry { xs = [1, 2, 3]; print((xs[0] := 9)); }\n"
    );
    assert has_error_code(prog, "E0020") , f"Expected general E0020, got: {fmt_errors(
        prog
    )}";
    assert not has_error_code(prog, "E5090") , f"native E5090 duplicate leaked: {fmt_errors(
        prog
    )}";
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

# !r and dynamic format specs now lower natively (#7593 item 6); the !a
# conversion still requires CPython-exact ascii() escaping and stays gated.
test "guardrail: f-string !a conversion demotes its function" {
    (prog, ir, log) = compile_na_inline_demote(
        "fstr_ascii", "def f(s: str) -> str { return f\"{s!a}\"; }\n"
    );
    assert not prog.errors_had , f"A function-owned !a violation must demote, got: {fmt_errors(
        prog
    )}";
    layout = ir.gen.native_layout;
    assert layout is not None , "whole-module native compile aborted";
    assert "f" not in layout.functions , (
        "the !a function must be demoted out of the native layout"
    );
    assert "NA_DEBUG demote f" in log , f"no demotion recorded for f in:\n{log}";
}

# Positional arguments to an archetype WITHOUT an explicit init map onto the
# implicit field constructor via the declared has-field order (#7593 item 14),
# so `Vec(1.0, 3.0)` lowers cleanly instead of demoting. The remaining gaps
# are the new() forms the checker's `*args` stub cannot reject: more
# positional args than declared fields, and a dynamic (non-static) class
# value. Both stay a structured E5092 that demotes the owning function --
# never a silent wrong-value compile (sv raises TypeError at runtime for the
# overflow form).
test "guardrail: implicit-ctor positionals lower; dynamic new() demotes" {
    ok = compile_na_inline(
        "pos_ctor",
        "obj Vec {\n"
        "    has x: float = 0.0;\n"
        "    has z: float = 0.0;\n"
        "}\n"
        "def make() -> float {\n"
        "    return Vec(1.0, 3.0).z;\n"
        "}\n"
        "with entry {}\n"
    );
    assert not ok.errors_had , f"Implicit-ctor positional args must lower: {fmt_errors(
        ok
    )}";
    (over, over_ir, over_log) = compile_na_inline_demote(
        "new_overflow",
        "obj Vec {\n"
        "    has x: float = 0.0;\n"
        "    has z: float = 0.0;\n"
        "}\n"
        "def make() -> float {\n"
        "    v = new(Vec, 1.0, 2.0, 3.0);\n"
        "    return v.z;\n"
        "}\n"
        "with entry {}\n"
    );
    assert not over.errors_had , f"new() arity overflow must demote its function, got: {fmt_errors(
        over
    )}";
    assert "make" not in over_ir.gen.native_layout.functions , (
        "the new()-overflow function must be demoted out of the native layout"
    );
    assert "NA_DEBUG demote make" in over_log , (
        f"no demotion recorded for make in:\n{over_log}"
    );
    (dyn, dyn_ir, dyn_log) = compile_na_inline_demote(
        "new_dynamic",
        "def make(c: any) -> int {\n"
        "    v = new(c, 1);\n"
        "    return 0;\n"
        "}\n"
        "with entry {}\n"
    );
    assert not dyn.errors_had , f"A dynamic new() class value must demote its function, got: {fmt_errors(
        dyn
    )}";
    assert "make" not in dyn_ir.gen.native_layout.functions , (
        "the dynamic-new() function must be demoted out of the native layout"
    );
    assert "NA_DEBUG demote make" in dyn_log , (
        f"no demotion recorded for make in:\n{dyn_log}"
    );
}

# A component-style event ability (`can with entry`) reaching the native
# nested-ability path must fail structurally, never with an AttributeError
# ICE (EventSignature has no get_parameters); surfaced by the corpus probe
# over mini_todo. The structured E5092 now demotes the owning function.
test "guardrail: nested event ability demotes its function, not an ICE" {
    (prog, ir, log) = compile_na_inline_demote(
        "nested_event_ability",
        "def widget -> int {\n"
        "    can with entry {\n"
        "        x = 1;\n"
        "    }\n"
        "    return 1;\n"
        "}\n"
    );
    for alrt in prog.errors_had {
        if alrt.code is not None {
            assert alrt.code.code not in ("E9001", "E9002") , (
                f"ICE leaked for a nested event ability: {fmt_errors(prog)}"
            );
        }
    }
    assert not prog.errors_had , f"A nested event ability must demote its function, got: {fmt_errors(
        prog
    )}";
    assert "widget" not in ir.gen.native_layout.functions , (
        "the function hosting the nested event ability must be demoted"
    );
    assert "NA_DEBUG demote widget" in log , (
        f"no demotion recorded for widget in:\n{log}"
    );
}
