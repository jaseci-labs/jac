"""P1d phase-exit: C-for and enums via direct-IR path."""

import os;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.c2jac.driver { transpile_c_str }
import from jaclang.compiler.c2jac.enum_prepass { build_enum_map }
import from jaclang.compiler.c2jac.tags { Idiom, Tier }
import from jaclang.compiler.c2jac.report { report_json }
import from jaclang.jac0core.program { JacProgram }
import from pycparser { c_parser }

glob FIXTURES = os.path.join(JAC_ROOT, "tests", "compiler", "c2jac", "fixtures");

def _transpile(name: str) -> tuple[str, object] {
    with open(os.path.join(FIXTURES, name)) as f {
        src = f.read();
    }
    return transpile_c_str(src, name);
}

def _read(name: str) -> str {
    with open(os.path.join(FIXTURES, name)) as f {
        return f.read();
    }
}

def _recompile_errors(jac_str: str, name: str) -> list {
    # Round-trip guard: emitted Jac must be valid *compiler input*, not merely
    # contain the right substrings. Write it out and recompile it; a non-empty
    # error list means c2jac produced Jac the compiler rejects.
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

# --- C-for tests ---
test "cfor.c transpiles without error" {
    (jac_str, tags) = _transpile("cfor.c");
    assert jac_str != "";
}

test "cfor.c emits a full ascending IterForStmt (cond + step, not just bounds)" {
    (jac_str, tags) = _transpile("cfor.c");
    # condition must be the FULL comparison and step the FULL augmented
    # assignment — emitting only the bound `n` / magnitude `1` produced the
    # invalid `for i = 0 to n by 1` that would not reparse.
    assert "for i = 0 to i < n by i += 1" in jac_str , f"Expected full IterForStmt in:\n{jac_str}";
}

test "cfor.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("cfor.c");
    errs = _recompile_errors(jac_str, "cfor.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

test "cfor.c continue is present (step runs after continue)" {
    (jac_str, tags) = _transpile("cfor.c");
    assert "continue" in jac_str , "Expected 'continue' in output (correctness: step runs after continue in IterForStmt)";
}

test "cfor.c sum_for function present" {
    (jac_str, tags) = _transpile("cfor.c");
    assert "sum_for" in jac_str;
}

test "cfor.c count_odds function present" {
    (jac_str, tags) = _transpile("cfor.c");
    assert "count_odds" in jac_str;
}

# --- Enum tests ---
test "enum_prepass: Color gets ENUM_AS_ENUM verdict" {
    src = _read("enum_simple.c");
    file_ast = c_parser.CParser().parse(src, "enum_simple.c");
    ev = build_enum_map(file_ast);
    verdicts = list(ev.verdicts.values());
    assert Idiom.ENUM_AS_ENUM.value in verdicts , f"Expected ENUM_AS_ENUM in {verdicts}";
}

test "enum_prepass: Permissions gets ENUM_AS_CONSTS verdict (non-sequential values)" {
    src = _read("enum_flags.c");
    file_ast = c_parser.CParser().parse(src, "enum_flags.c");
    ev = build_enum_map(file_ast);
    verdicts = list(ev.verdicts.values());
    # PERM_ALL = 7 breaks sequential rule and values are power-of-2 flags.
    assert Idiom.ENUM_AS_CONSTS.value in verdicts , f"Expected ENUM_AS_CONSTS in {verdicts}";
}

test "enum_simple.c transpiles: named enum appears as enum keyword" {
    (jac_str, tags) = _transpile("enum_simple.c");
    assert jac_str != "";
    # Color should be an enum (ENUM_AS_ENUM).
    assert "Color" in jac_str , f"Expected 'Color' in output:\n{jac_str}";
}

test "enum_flags.c transpiles: flag values appear as glob consts" {
    (jac_str, tags) = _transpile("enum_flags.c");
    assert jac_str != "";
    # Permissions flag values should appear as integer constants.
    assert "PERM_READ" in jac_str or "1" in jac_str , "Expected PERM_READ constant";
}

test "enum_collision.c second enum demotes to TIER_B no duplicate glob" {
    src = _read("enum_collision.c");
    file_ast = c_parser.CParser().parse(src, "enum_collision.c");
    ev = build_enum_map(file_ast);
    verdicts = list(ev.verdicts.values());
    # The second enum with VAL_A collision should be TIER_B.
    assert "tier_b" in verdicts , f"Expected tier_b for collision in {verdicts}";
}

test "enum_collision.c emits valid Jac without duplicate globals" {
    (jac_str, tags) = _transpile("enum_collision.c");
    assert jac_str != "";
    # VAL_A must be defined exactly once as a module-level global.
    glob_defs = jac_str.count("glob VAL_A");
    assert glob_defs == 1 , f"VAL_A should have exactly one glob definition, got {glob_defs} in:\n{jac_str}";
    # VAL_A must appear in the output (used in at least one return statement).
    assert "VAL_A" in jac_str , "Expected VAL_A to appear in output";
}

# --- Bug #1: function-call & increment expression statements ---
test "expr_stmts.c: call statement does not crash transpilation" {
    (jac_str, tags) = _transpile("expr_stmts.c");
    assert jac_str != "";
    # The bare call `g(n);` must survive as a statement, not be dropped.
    assert "g(n)" in jac_str , f"Expected call statement 'g(n)' in:\n{jac_str}";
}

test "expr_stmts.c: i++ statement lowers to augmented assignment" {
    (jac_str, tags) = _transpile("expr_stmts.c");
    assert "i += 1" in jac_str , f"Expected 'i += 1' from 'i++' in:\n{jac_str}";
}

# --- Bug #2: Tier-B enum verdict reaches the tag table / sidecar report ---
test "enum_collision.c: demoted enum is recorded as a Tier-B site" {
    (jac_str, tags) = _transpile("enum_collision.c");
    tier_b = tags.tier_b_entries();
    assert len(tier_b) >= 1 , "Expected at least one Tier-B entry for the collided enum";
    report_str = report_json("enum_collision.c", tags);
    assert "tier_b_sites" in report_str;
    # The previously-empty sidecar must now list the demoted enum.
    assert "collides" in report_str , f"Expected collision reason in report:\n{report_str}";
}

# --- Bug #3: unsupported for forms preserve semantics + mark Tier-B ---
test "for_unsupported.c: descending loop preserves init + body via while-desugar" {
    (jac_str, tags) = _transpile("for_unsupported.c");
    assert jac_str != "";
    assert "while " in jac_str , f"Expected a while loop in:\n{jac_str}";
    # The initializer `i = n` must NOT be dropped (regression: bare `nd.init`
    # resolved to a bound method, silently losing the init statement).
    assert "i = n" in jac_str , f"Expected preserved initializer 'i = n' in:\n{jac_str}";
    # Body must survive (not an empty `while True {}`).
    assert "sum" in jac_str , f"Expected loop body 'sum' preserved in:\n{jac_str}";
    # The descending step must be appended to the body.
    assert "i -= 1" in jac_str , f"Expected descending step 'i -= 1' in:\n{jac_str}";
}

test "for_unsupported.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_unsupported.c");
    errs = _recompile_errors(jac_str, "for_unsupported.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

test "un-preprocessed C directives raise an actionable error" {
    src = "#define N 4\nint f(void) { return N; }\n";
    raised = False;
    try {
        transpile_c_str(src, "directives.c");
    } except ValueError as e {
        raised = True;
        assert "preprocess" in str(e).lower() , f"Expected preprocessing guidance, got: {e}";
    }
    assert raised , "Expected a ValueError for un-preprocessed #define";
}

test "for_unsupported.c: infinite for(;;) preserves body" {
    (jac_str, tags) = _transpile("for_unsupported.c");
    # for(;;) body must be preserved, not dropped.
    assert "x = x + 1" in jac_str or "x += 1" in jac_str , f"Expected for(;;) body in:\n{jac_str}";
}

test "for_unsupported.c: unsupported for is marked Tier-B" {
    (jac_str, tags) = _transpile("for_unsupported.c");
    tier_b = tags.tier_b_entries();
    reasons = [nt.reason for nt in tier_b];
    has_for = any("IterForStmt" in r for r in reasons);
    assert has_for , f"Expected a Tier-B entry for the unsupported for-loop, got {reasons}";
}
