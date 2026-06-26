"""P1d phase-exit: C-for and enums via direct-IR path."""

import os;
import tempfile;
import from tests.support { JAC_ROOT }
import from jaclang.compiler.c2jac.driver { transpile_c_str }
import from jaclang.compiler.c2jac.enum_prepass { build_enum_map }
import from jaclang.compiler.c2jac.tags { Idiom, Tier }
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

# --- Bug #2: Tier-B enum verdict reaches the tag table ---
test "enum_collision.c: demoted enum is recorded as a Tier-B site" {
    (jac_str, tags) = _transpile("enum_collision.c");
    tier_b = tags.tier_b_entries();
    assert len(tier_b) >= 1 , "Expected at least one Tier-B entry for the collided enum";
    # The demoted enum must carry its collision reason on the tag.
    reasons = [nt.reason for nt in tier_b];
    assert any("collides" in r for r in reasons) , f"Expected collision reason on a Tier-B tag:\n{reasons}";
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

# --- Review finding 1: for-body lowering must be faithful or honest, never
# silently lossy. else/return are now preserved; a body construct with no
# direct-IR analog (e.g. an uninitialized local decl) demotes the loop Tier-B. ---
test "for_body_rich.c: if/else arm is preserved (else not dropped)" {
    (jac_str, tags) = _transpile("for_body_rich.c");
    assert jac_str != "";
    # Regression: _c_stmt_to_uni built IfStmt with else_body=None, dropping the
    # entire else arm of every `if` in a C-for body.
    assert "} else {" in jac_str , f"Expected the else arm preserved in:\n{jac_str}";
    assert "result = 1" in jac_str , f"Expected else-body statement in:\n{jac_str}";
}

test "for_body_rich.c: return inside a for body is preserved" {
    (jac_str, tags) = _transpile("for_body_rich.c");
    # Regression: a `return` in a C-for body had no case and was silently dropped.
    assert "return result" in jac_str , f"Expected 'return result' in:\n{jac_str}";
}

test "for_body_rich.c: dropped uninitialized decl demotes the loop to Tier-B" {
    (jac_str, tags) = _transpile("for_body_rich.c");
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    # The bare `int local;` has no faithful direct-IR analog, so the loop must be
    # flagged rather than presenting a truncated body as faithful.
    assert any("declaration" in r for r in reasons) , f"Expected a Tier-B decl flag, got {reasons}";
}

test "for_body_rich.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_body_rich.c");
    errs = _recompile_errors(jac_str, "for_body_rich.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- Review finding 2: collision check must cover the whole translation unit,
# not just prior enum-derived names. An enum constant clashing with a top-level
# function/variable name demotes to Tier-B instead of shadowing it at module scope. ---
test "enum_tu_collision.c: enum constant colliding with a top-level function demotes to Tier-B" {
    src = _read("enum_tu_collision.c");
    file_ast = c_parser.CParser().parse(src, "enum_tu_collision.c");
    ev = build_enum_map(file_ast);
    verdicts = list(ev.verdicts.values());
    # STATUS_OK is also a top-level function name — seeding TU names makes this
    # collision visible regardless of declaration order.
    assert "tier_b" in verdicts , f"Expected tier_b for TU-name collision in {verdicts}";
}

# --- Review finding 4: direct-IR for-body/condition expression coverage.
# A function call and a unary `!` inside a C-for body now lower faithfully, so
# the loop stays a clean IterForStmt and is NOT demoted to Tier-B. ---
test "for_call_body.c: call + unary-! in the body lower faithfully (clean IterForStmt)" {
    (jac_str, tags) = _transpile("for_call_body.c");
    assert "for i = 0 to i < n by i += 1 {" in jac_str , f"Expected clean IterForStmt in:\n{jac_str}";
    # The bare call statement and the call sub-expression both survive.
    assert "total + sink(i)" in jac_str , f"Expected call expression preserved in:\n{jac_str}";
    # Unary `!` lowers to `not`.
    assert "if not total {" in jac_str , f"Expected unary-! → 'not' in:\n{jac_str}";
}

test "for_call_body.c: faithfully-lowered body does NOT demote the loop to Tier-B" {
    (jac_str, tags) = _transpile("for_call_body.c");
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    # Regression: calls/unary-! used to have no direct-IR case and demoted the
    # whole loop. They are faithful now, so no "not faithfully lowered" flag.
    assert not any("not faithfully lowered" in r for r in reasons) , f"Body is faithful now, unexpected Tier-B: {reasons}";
}

test "for_call_body.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_call_body.c");
    errs = _recompile_errors(jac_str, "for_call_body.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

test "enum_tu_collision.c: no duplicate module global shadows the function" {
    (jac_str, tags) = _transpile("enum_tu_collision.c");
    assert jac_str != "";
    # The enum was demoted, so STATUS_OK must not be re-emitted as a glob const.
    assert jac_str.count("glob STATUS_OK") == 0 , f"Enum const must not shadow the function:\n{jac_str}";
    assert jac_str.count("def STATUS_OK") == 1 , f"Expected the function preserved exactly once:\n{jac_str}";
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert any("collides" in r for r in reasons) , f"Expected a collision reason, got {reasons}";
}
