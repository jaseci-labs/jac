"""P1a phase-exit: hello.c and control_flow.c round-trip, zero formatter errors."""

import os;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.c2jac.driver { transpile_c_str }
import from jaclang.compiler.c2jac.tags { Idiom, Tier }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "c2jac", "fixtures");

def _read(name: str) -> str {
    with open(os.path.join(FIXTURES, name)) as f {
        return f.read();
    }
}

def _transpile(name: str) -> str {
    src = _read(name);
    (jac_str, tags) = transpile_c_str(src, name);
    return jac_str;
}

test "hello.c transpiles without error" {
    jac_str = _transpile("hello.c");
    assert jac_str != "" , "Expected non-empty Jac output for hello.c";
    assert "def add" in jac_str , f"Expected 'def add' in output:\n{jac_str}";
    assert "def main" in jac_str , f"Expected 'def main' in output:\n{jac_str}";
}

test "hello.c add function params present" {
    jac_str = _transpile("hello.c");
    assert "a: int" in jac_str or "a" in jac_str , "Expected param 'a' in output";
    assert "b: int" in jac_str or "b" in jac_str , "Expected param 'b' in output";
}

test "hello.c return statement present" {
    jac_str = _transpile("hello.c");
    assert "return" in jac_str , "Expected 'return' in output";
}

test "control_flow.c transpiles without error" {
    jac_str = _transpile("control_flow.c");
    assert jac_str != "" , "Expected non-empty Jac output for control_flow.c";
}

test "control_flow.c contains if statement" {
    jac_str = _transpile("control_flow.c");
    assert "if " in jac_str , "Expected 'if' in output";
}

test "control_flow.c contains while statement" {
    jac_str = _transpile("control_flow.c");
    assert "while " in jac_str , "Expected 'while' in output";
}

test "control_flow.c contains return" {
    jac_str = _transpile("control_flow.c");
    assert "return" in jac_str , "Expected 'return' in output";
}

test "control_flow.c contains break" {
    jac_str = _transpile("control_flow.c");
    assert "break" in jac_str , "Expected 'break' in output";
}

test "control_flow.c contains continue" {
    jac_str = _transpile("control_flow.c");
    assert "continue" in jac_str , "Expected 'continue' in output";
}

test "control_flow.c headers are not split across lines" {
    # Regression guard for the formatter fix: synthesized IR once made the
    # formatter mis-classify `while`/`if` header tokens as body items, emitting
    # `while\n(cond)\n{` mangled across lines. Identity-based body membership
    # plus real break/continue lines keep headers contiguous.
    jac_str = _transpile("control_flow.c");
    assert "while (i < n) {" in jac_str , f"while header split:\n{jac_str}";
    assert "if (arr[i] < 0) {" in jac_str , f"if header split:\n{jac_str}";
    # break/continue must survive inside their blocks (broke when ctrl tokens
    # carried line=0 and the formatter dropped/mangled them).
    assert "break;" in jac_str , f"break lost:\n{jac_str}";
    assert "continue;" in jac_str , f"continue lost:\n{jac_str}";
}

test "for_block_spacing.c: multi-line loop body has no double blank line" {
    # Regression guard for the zero-line token fix-up (NormalizePass, via _stamp_zero_toks):
    # synthesized structural tokens (`{`/`}`) carry line=0. Stamping every zero
    # token with the block's FIRST descendant line compressed the block's apparent
    # span, and the formatter's blank-line gap logic (keyed off last_line) then
    # injected a DOUBLE blank line inside the loop body. Positional stamping —
    # opening tokens take the first following line, closing tokens the last
    # preceding line — keeps the span correct.
    #
    # Now that loop-body lowering is single-sourced through the mapper's py-ast
    # path (loop bodies no longer use the direct-IR builder, which collapsed every
    # body coord to line 1), a for-body spaces exactly like the same statements at
    # function top level: the formatter leaves ONE blank line between two
    # statements that sit on different source lines. That single blank is the
    # established c2jac py-ast style — the meaningful guard is that a span-
    # compression bug never doubles it.
    jac_str = _transpile("for_block_spacing.c");
    assert "total = total + i;" in jac_str , f"body stmt 1 missing:\n{jac_str}";
    assert "total = total + 1;" in jac_str , f"body stmt 2 missing:\n{jac_str}";
    # No two-blank-line gap should appear anywhere in the function.
    assert "\n\n\n" not in jac_str , f"double blank line in output:\n{jac_str}";
}

test "switch_basic.c: switch lowers to an if/elif chain with OR-folded case labels" {
    jac_str = _transpile("switch_basic.c");
    assert jac_str != "" , "Expected non-empty output for switch_basic.c";
    # Empty-statement cases (`case 1: case 2:`) fold into one OR-ed branch.
    assert "(x == 1) or (x == 2)" in jac_str , f"Expected OR-folded case labels in:\n{jac_str}";
    assert "elif (x == 3)" in jac_str , f"Expected elif branch in:\n{jac_str}";
    # default → else; the switch-terminating breaks are dropped.
    assert "} else {" in jac_str , f"Expected default→else in:\n{jac_str}";
    # A `break` *statement* ends with `;`; the Tier-B header prose may mention the
    # word "break", so assert on the statement form, not a bare substring.
    assert "break;" not in jac_str , f"switch breaks should be dropped, not emitted:\n{jac_str}";
}

test "switch_basic.c: a clean switch is faithful (Tier-A), not flagged Tier-B" {
    # Every non-final case ends in break and the selector `x` is a pure read, so
    # the if/elif/else chain is exact — it must promote to Tier-A.
    (jac_str, tags) = transpile_c_str(_read("switch_basic.c"), "switch_basic.c");
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert not any("switch lowered" in r for r in reasons) , f"clean switch must stay faithful, got {reasons}";
    assert len(tags.by_idiom(Idiom.SWITCH_CLEAN)) == 1 , "Expected the clean switch recorded as a SWITCH_CLEAN idiom";
}

test "switch_fallthrough.c: a fall-through case keeps the switch Tier-B" {
    # case 1 has a body but no break, so it falls into case 2 — the if/elif chain
    # cannot model that, so the switch must be flagged for verification.
    (jac_str, tags) = transpile_c_str(
        _read("switch_fallthrough.c"), "switch_fallthrough.c"
    );
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert any("switch lowered" in r for r in reasons) , f"fall-through switch must be Tier-B, got {reasons}";
    assert len(tags.by_idiom(Idiom.SWITCH_CLEAN)) == 0 , "A fall-through switch must not be tagged SWITCH_CLEAN";
}

test "switch with a side-effecting selector stays Tier-B" {
    # The selector is re-emitted per `==`; a call would run once per branch in
    # the lowering but exactly once in C, so it cannot be promoted.
    c_src = "int g(void); int f(void) { int r = 0; switch (g()) { case 1: r = 1; break; default: r = 0; } return r; }";
    (jac_str, tags) = transpile_c_str(c_src, "switch_call_sel.c");
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert any("switch lowered" in r for r in reasons) , f"side-effecting selector must be Tier-B, got {reasons}";
}

test "an empty default mid-switch falls through and stays Tier-B" {
    # `default:` is never OR-folded, so an empty default that is not the last
    # section falls straight into the following case (x not 1 → default → case 2
    # body). if/elif cannot model that, so it must NOT be promoted to Tier-A.
    c_src = "int f(int x) { int r = 0; switch (x) { case 1: r = 10; break; default: case 2: r = 20; break; } return r; }";
    (jac_str, tags) = transpile_c_str(c_src, "sw_empty_default.c");
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert any("switch lowered" in r for r in reasons) , f"empty default mid-switch must be Tier-B, got {reasons}";
    assert len(tags.by_idiom(Idiom.SWITCH_CLEAN)) == 0 , "fall-through via empty default must not be SWITCH_CLEAN";
}

test "an empty case before default does not leak its label onto a later case" {
    # `case 1:` is empty and precedes `default:`, so in C x==1 falls into the
    # default body, NOT case 2. The grouping must drop the pending `1` at the
    # default, never OR-fold it into case 2's `==` test.
    c_src = "int f(int x) { int r = 0; switch (x) { case 1: default: r = 9; break; case 2: r = 2; break; } return r; }";
    (jac_str, tags) = transpile_c_str(c_src, "sw_case_default.c");
    assert "(x == 1) or (x == 2)" not in jac_str , f"case 1's label leaked onto case 2:\n{jac_str}";
    assert "x == 2" in jac_str , f"expected a case-2 branch:\n{jac_str}";
    # default carries a terminating break, so the lowering is exact → faithful.
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert not any("switch lowered" in r for r in reasons) , f"this shape is faithful, got {reasons}";
    errs = _recompile_errors(jac_str, "sw_case_default.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

test "a clean braced switch is faithful (Tier-A)" {
    # Each case body is wrapped in `{ ... }` (a Compound) ending in break. The
    # terminator must be seen through the braces, and the break dropped from the
    # emitted branch — a clean braced switch is exactly an if/elif chain.
    c_src = "int f(int x) { int r = 0; switch (x) { case 1: { r = 1; break; } case 2: { r = 2; break; } default: { r = -1; } } return r; }";
    (jac_str, tags) = transpile_c_str(c_src, "sw_braced.c");
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert not any("switch lowered" in r for r in reasons) , f"clean braced switch must stay faithful, got {reasons}";
    assert len(tags.by_idiom(Idiom.SWITCH_CLEAN)) == 1 , "Expected the braced switch recorded as a SWITCH_CLEAN idiom";
    # The switch-terminating breaks must be dropped, not emitted.
    assert "break;" not in jac_str , f"braced-case breaks should be dropped:\n{jac_str}";
    errs = _recompile_errors(jac_str, "sw_braced.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

test "switch_fallthrough.c emitted Jac recompiles cleanly" {
    jac_str = _transpile("switch_fallthrough.c");
    errs = _recompile_errors(jac_str, "switch_fallthrough.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

test "switch_basic.c emitted Jac recompiles cleanly" {
    jac_str = _transpile("switch_basic.c");
    errs = _recompile_errors(jac_str, "switch_basic.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

test "do_while.c: do-while desugars to a faithful while-True/break" {
    (jac_str, tags) = transpile_c_str(_read("do_while.c"), "do_while.c");
    assert "while True {" in jac_str , f"Expected while-True desugar in:\n{jac_str}";
    # Body runs before the post-test, which guards an exit `break`.
    assert "if not (n > 0) {" in jac_str , f"Expected post-body condition guard in:\n{jac_str}";
    assert "break;" in jac_str , f"Expected exit break in:\n{jac_str}";
    # No loop-level `continue` → the desugar is faithful, so no Tier-B flag.
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert not any("do-while" in r for r in reasons) , f"continue-free do-while must stay faithful, got {reasons}";
    # Faithful is not enough: the verdict must be stamped Tier-A explicitly with
    # the DO_WHILE idiom (DoWhile is off the boundary allowlist, so without the
    # stamp it would silently keep its default Tier-B tag and be undercounted).
    do_while = tags.by_idiom(Idiom.DO_WHILE);
    assert len(do_while) == 1 , f"Expected one Tier-A DO_WHILE promotion, got {len(
        do_while
    )}";
    assert do_while[0].tier == Tier.TIER_A , f"DO_WHILE idiom must be Tier-A, got {do_while[
        0
    ].tier}";
}

test "do_while.c emitted Jac recompiles cleanly" {
    jac_str = _transpile("do_while.c");
    errs = _recompile_errors(jac_str, "do_while.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- A loop-level `continue` is the one hazard: in C it jumps to the post-body
# condition test, but the `while True { body; if not cond break }` desugar's
# `continue` re-enters the loop top and skips that guard. So a continue-bearing
# do-while must stay Tier-B and must NOT get the Tier-A DO_WHILE promotion. ---
test "do_while_continue.c: a loop-level continue keeps the do-while Tier-B" {
    (jac_str, tags) = transpile_c_str(
        _read("do_while_continue.c"), "do_while_continue.c"
    );
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert any("do-while" in r and "continue" in r for r in reasons) , f"Expected a Tier-B continue-semantics flag, got {reasons}";
    # The hazard is present, so no faithful DO_WHILE promotion may exist.
    assert len(tags.by_idiom(Idiom.DO_WHILE)) == 0 , f"A continue-bearing do-while must not promote to Tier-A DO_WHILE";
}

test "do_while_continue.c emitted Jac recompiles cleanly" {
    jac_str = _transpile("do_while_continue.c");
    errs = _recompile_errors(jac_str, "do_while_continue.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

test "ternary.c: ?: lowers to a Jac conditional expression (faithful)" {
    (jac_str, tags) = transpile_c_str(_read("ternary.c"), "ternary.c");
    assert "a if (a > 0) else -a" in jac_str , f"Expected conditional expression in:\n{jac_str}";
    # A plain ternary is a faithful mapping — the whole function must be Tier-A.
    # The ?: node sits on the boundary allowlist; before that it default-stamped
    # Tier-B with an empty reason, so a reason-substring check alone passed while
    # a phantom best-effort site lingered. Pin the count to catch a regression.
    entries = tags.tier_b_entries();
    assert len(entries) == 0 , f"ternary should be fully Tier-A, got {[
        (nt.c_line, nt.reason) for nt in entries
    ]}";
}

test "ternary.c emitted Jac recompiles cleanly" {
    jac_str = _transpile("ternary.c");
    errs = _recompile_errors(jac_str, "ternary.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

def _recompile_errors(jac_str: str, name: str) -> list {
    import tempfile;
    import from jaclang.jac0core.program { JacProgram }
    out_dir = tempfile.mkdtemp();
    stem = name.rsplit(".", 1)[0];
    path = os.path.join(out_dir, stem + ".jac");
    with open(path, "w") as f {
        f.write(jac_str);
    }
    prog = JacProgram();
    prog.compile(file_path=path);
    return prog.errors_had;
}

test "unsupported node yields valid Jac surrogate" {
    # A file with only a Goto (unsupported) should still emit valid Jac — not crash.
    c_src = "void f(void) { goto label; label: ; }";
    (jac_str, tags) = transpile_c_str(c_src, "goto_test.c");
    assert jac_str is not None;
    # There must be at least one tier-B entry.
    assert len(tags.tier_b_entries()) > 0 , "Expected Tier-B tags for goto";
}
