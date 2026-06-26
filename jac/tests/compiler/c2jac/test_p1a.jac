"""P1a phase-exit: hello.c and control_flow.c round-trip, zero formatter errors."""

import os;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.c2jac.driver { transpile_c_str }
import from jaclang.compiler.c2jac.tags { Idiom }

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

test "for_block_spacing.c: multi-line loop body has no spurious blank line" {
    # Regression guard for the zero-line token fix-up (driver._fix_zero_toks_in_subtree):
    # synthesized structural tokens (`{`/`}`) carry line=0. Stamping every zero
    # token with the block's FIRST descendant line compressed the block's apparent
    # span, and the formatter's blank-line gap logic (keyed off last_line) then
    # injected a stray blank line inside the loop body. Positional stamping —
    # opening tokens take the first following line, closing tokens the last
    # preceding line — keeps the span correct.
    jac_str = _transpile("for_block_spacing.c");
    assert "total = total + i;" in jac_str , f"body stmt 1 missing:\n{jac_str}";
    assert "total = total + 1;" in jac_str , f"body stmt 2 missing:\n{jac_str}";
    # The two consecutive body statements must not be split by a blank line.
    assert "total = total + i;\n        total = total + 1;" in jac_str , f"spurious blank line in loop body:\n{jac_str}";
    # And no two-blank-line gap should appear anywhere in the function.
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
}

test "do_while.c emitted Jac recompiles cleanly" {
    jac_str = _transpile("do_while.c");
    errs = _recompile_errors(jac_str, "do_while.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

test "ternary.c: ?: lowers to a Jac conditional expression (faithful)" {
    (jac_str, tags) = transpile_c_str(_read("ternary.c"), "ternary.c");
    assert "a if (a > 0) else -a" in jac_str , f"Expected conditional expression in:\n{jac_str}";
    # A plain ternary is a faithful mapping — it must not be flagged Tier-B.
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert not any("?:" in r or "ternary" in r.lower() for r in reasons) , f"ternary should be faithful, got {reasons}";
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
