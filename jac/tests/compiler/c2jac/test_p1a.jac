"""P1a phase-exit: hello.c and control_flow.c round-trip, zero formatter errors."""

import os;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.c2jac.driver { transpile_c_str }

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

test "unsupported node yields valid Jac surrogate" {
    # A file with only a Goto (unsupported) should still emit valid Jac — not crash.
    c_src = "void f(void) { goto label; label: ; }";
    (jac_str, tags) = transpile_c_str(c_src, "goto_test.c");
    assert jac_str is not None;
    # There must be at least one tier-B entry.
    assert len(tags.tier_b_entries()) > 0 , "Expected Tier-B tags for goto";
}
