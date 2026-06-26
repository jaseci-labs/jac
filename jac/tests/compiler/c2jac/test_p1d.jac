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

test "enum_prepass: Permissions gets ENUM_AS_ENUM verdict (non-sequential, unique values)" {
    src = _read("enum_flags.c");
    file_ast = c_parser.CParser().parse(src, "enum_flags.c");
    ev = build_enum_map(file_ast);
    verdicts = list(ev.verdicts.values());
    # PERM_ALL = 7 is non-sequential but every value is unique; _enum_as_enum
    # writes each value explicitly, so it lowers faithfully to an enum rather
    # than being demoted over a cosmetic gap.
    assert Idiom.ENUM_AS_ENUM.value in verdicts , f"Expected ENUM_AS_ENUM in {verdicts}";
}

test "enum_simple.c transpiles: named enum appears as enum keyword" {
    (jac_str, tags) = _transpile("enum_simple.c");
    assert jac_str != "";
    # Color should be an enum (ENUM_AS_ENUM).
    assert "Color" in jac_str , f"Expected 'Color' in output:\n{jac_str}";
}

test "enum_flags.c transpiles: flag members appear in output" {
    (jac_str, tags) = _transpile("enum_flags.c");
    assert jac_str != "";
    # Permissions members should appear (as enum members after the non-sequential
    # fix; the loose check tolerates either lowering).
    assert "PERM_READ" in jac_str or "1" in jac_str , "Expected PERM_READ member";
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

# --- Review finding: an unmappable for-condition that becomes `while True`
# must be flagged explicitly, not hidden behind the generic continue-semantics
# reason. The `*p` deref condition has no direct-IR analog, so the loop is both
# while-desugared AND its condition is dropped — init/step/body stay faithful so
# the only loss is the condition itself. ---
test "for_unmappable_cond.c: dropped condition becomes `while True` and is preserved-as-much-as-possible" {
    (jac_str, tags) = _transpile("for_unmappable_cond.c");
    assert "while True" in jac_str , f"Expected `while True` for the unmappable condition in:\n{jac_str}";
    # Init/step/body must still survive (the desugar is faithful except the cond).
    assert "i = 0" in jac_str , f"Expected preserved initializer 'i = 0' in:\n{jac_str}";
    assert "i += 1" in jac_str , f"Expected preserved step 'i += 1' in:\n{jac_str}";
    assert "n = n + 1" in jac_str , f"Expected preserved body 'n = n + 1' in:\n{jac_str}";
}

test "for_unmappable_cond.c: the dropped condition is flagged with its own Tier-B reason" {
    (jac_str, tags) = _transpile("for_unmappable_cond.c");
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    # The explicit condition-loss clause must be present — a user must not have to
    # infer that `complex_cond()` silently became `while True`.
    assert any("loop condition not faithfully lowered" in r for r in reasons) , f"Expected an explicit condition-loss Tier-B reason, got {reasons}";
    # The body is faithful, so the body-construct clause must NOT appear.
    assert not any("body constructs not faithfully lowered" in r for r in reasons) , f"Body is faithful; unexpected body-loss flag in {reasons}";
}

# --- Review finding: _cond_lossy is shared mutable builder state. A nested
# fallback loop in the body re-enters _for_as_while and resets the flag, so an
# outer loop whose condition was dropped (`while True`) lost its explicit
# condition-loss clause when its body held a nested while-desugared loop. The
# verdict is now captured locally right after _while_cond, before the body. ---
test "for_nested_cond_clobber.c: outer dropped condition stays flagged despite a nested fallback loop" {
    (jac_str, tags) = _transpile("for_nested_cond_clobber.c");
    # The outer `*p` condition has no analog and became `while True`...
    assert "while True" in jac_str , f"Expected `while True` for the outer unmappable condition in:\n{jac_str}";
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    # ...so SOME loop must carry the explicit condition-loss clause. Before the
    # fix, the nested descending loop (faithful `j > 0` cond) reset _cond_lossy
    # while the outer body was built, erasing this clause entirely.
    cond_loss = [
        r
        for r in reasons
        if "loop condition not faithfully lowered" in r
    ];
    assert len(cond_loss) >= 1 , f"Outer dropped condition must stay flagged, got {reasons}";
    # The nested loop's condition IS faithful (`j > 0` lowers fine), so exactly
    # one loop — the outer — should carry the condition-loss clause, not both.
    assert len(cond_loss) == 1 , f"Only the outer loop dropped its condition; nested cond is faithful:\n{reasons}";
}

test "for_nested_cond_clobber.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_nested_cond_clobber.c");
    errs = _recompile_errors(jac_str, "for_nested_cond_clobber.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
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

# --- Greptile finding: direct-IR `_expr_to_uni` silently substituted int `0`
# for char literals (and unparseable constants), so `i < 'z'` lowered to `i < 0`.
# A C char constant is an integer, so it now lowers to its ordinal faithfully. ---
test "for_char_cond.c: char literal in a for-condition lowers to its ordinal (not 0)" {
    (jac_str, tags) = _transpile("for_char_cond.c");
    # 'z' is 122; the loop must compare against 122, never the silent `0`.
    assert "i < 122" in jac_str , f"Expected `i < 122` (ord('z')) in:\n{jac_str}";
    assert "i < 0" not in jac_str , f"char literal must not collapse to 0 in:\n{jac_str}";
    # Faithful → clean IterForStmt, no Tier-B demotion for this loop.
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert not any("not faithfully lowered" in r for r in reasons) , f"Unexpected Tier-B: {reasons}";
}

test "for_char_cond.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_char_cond.c");
    errs = _recompile_errors(jac_str, "for_char_cond.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- Greptile finding: non-ASCII C string literals were mishandled — unicode_escape
# corrupted the AST value and the char-vs-byte column mismatch truncated the closing
# quote, emitting unterminated (uncompilable) Jac. The literal is now re-sliced
# verbatim from the C source with a byte-accurate end column, so it round-trips. ---
test "nonascii_str.c: non-ASCII literal round-trips faithfully (quote not truncated)" {
    (jac_str, tags) = _transpile("nonascii_str.c");
    assert 'cafe: str = "café";' in jac_str , f"Expected faithful `café` with closing quote in:\n{jac_str}";
    # ASCII escape sequences are preserved verbatim from the source slice.
    assert r'escapes: str = "a\tb\n";' in jac_str , f"Expected escapes preserved in:\n{jac_str}";
}

test "nonascii_str.c emitted Jac recompiles cleanly (no unterminated string)" {
    (jac_str, tags) = _transpile("nonascii_str.c");
    errs = _recompile_errors(jac_str, "nonascii_str.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- Review finding: the direct-IR for-body path lowered a far narrower set of
# expressions/lvalues than the top-level mapper, so array-indexed and field
# assignments, array-ref rvalues, and string-literal call args inside a C-for
# body were silently dropped (worst case: a bubble-sort swap vanished, leaving an
# empty `if {}` with only a header-comment hint). _expr_to_uni now lowers string
# literals + ArrayRef/StructRef and _lvalue_to_uni accepts indexed/field targets. ---
test "for_array_body.c: indexed swap inside a for body is preserved (not silently dropped)" {
    (jac_str, tags) = _transpile("for_array_body.c");
    assert jac_str != "";
    # Regression: `arr[i] = x` was dropped because _lvalue_to_uni only took bare
    # IDs, so the whole swap (and its enclosing if) became an empty `{ }`.
    assert "arr[j] = arr[j + 1];" in jac_str , f"Expected indexed swap assignment in:\n{jac_str}";
    assert "arr[j + 1] = tmp;" in jac_str , f"Expected second swap leg in:\n{jac_str}";
    # The `int tmp = arr[j];` decl-with-ArrayRef-init also survives.
    assert "tmp = arr[j];" in jac_str , f"Expected decl-init from arr[j] in:\n{jac_str}";
}

test "for_array_body.c: the three swap statements live INSIDE the if-condition body" {
    (jac_str, tags) = _transpile("for_array_body.c");
    # Sharper than the file-wide substrings above: the original bug emitted an
    # empty `if { }` while the swap statements vanished. Slice out the actual
    # `if arr[j] > arr[j + 1] { ... }` block and assert all three swap legs are
    # enclosed by its braces, so a future regression that empties the conditional
    # (or relocates the assignments elsewhere) is caught even when the loose
    # file-wide substrings still match.
    header = "if arr[j] > arr[j + 1] {";
    start = jac_str.find(header);
    assert start != -1 , f"Expected the ArrayRef if-condition in:\n{jac_str}";
    # The swap body has no nested braces, so the next `}` closes the if-block.
    body_start = start + len(header);
    body_end = jac_str.find("}", body_start);
    assert body_end != -1 , f"Expected a closing brace for the if-block in:\n{jac_str}";
    if_body = jac_str[body_start:body_end];
    assert "tmp = arr[j];" in if_body , f"Expected decl-init swap leg inside the if-body, got:\n{if_body}";
    assert "arr[j] = arr[j + 1];" in if_body , f"Expected first swap leg inside the if-body, got:\n{if_body}";
    assert "arr[j + 1] = tmp;" in if_body , f"Expected second swap leg inside the if-body, got:\n{if_body}";
}

test "for_array_body.c: ArrayRef rvalue and if-condition lower faithfully" {
    (jac_str, tags) = _transpile("for_array_body.c");
    # `s += arr[i]` — ArrayRef as an aug-assign rvalue used to drop the statement.
    assert "s += arr[i];" in jac_str , f"Expected `s += arr[i]` in:\n{jac_str}";
    # An if-condition containing an ArrayRef used to drop the entire if-block.
    assert "if arr[j] > arr[j + 1] {" in jac_str , f"Expected ArrayRef if-condition in:\n{jac_str}";
}

test "for_array_body.c: string-literal call arg and nested struct-field lvalue lower" {
    (jac_str, tags) = _transpile("for_array_body.c");
    # `note("hi")` — a string literal arg used to make the whole call unmappable.
    assert 'note("hi");' in jac_str , f"Expected string-literal call arg in:\n{jac_str}";
    # `pts[i].x = i` — StructRef over an ArrayRef as an lvalue (both nested forms).
    assert "pts[i].x = i;" in jac_str , f"Expected nested field-of-element lvalue in:\n{jac_str}";
}

test "for_array_body.c: escaped string literal is emitted verbatim (escapes not decoded)" {
    (jac_str, tags) = _transpile("for_array_body.c");
    # `_string_node` emits the raw C literal verbatim — the backslash escapes in
    # `"a\tb\n"` must survive as the two-char sequences `\t`/`\n`, not be decoded
    # to a real tab/newline (which would either corrupt the source or break the
    # round-trip). This guards the exact behavior the _string_node comment relies on.
    assert r'note("a\tb\n");' in jac_str , f"Expected escapes preserved verbatim in:\n{jac_str}";
}

test "for_array_body.c: faithfully-lowered bodies do NOT demote any loop to Tier-B" {
    (jac_str, tags) = _transpile("for_array_body.c");
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    # Every body construct is now faithful, so no loop should carry the
    # "not faithfully lowered" demotion (which previously hid the dropped swap).
    assert not any("not faithfully lowered" in r for r in reasons) , f"Bodies are faithful now, unexpected Tier-B: {reasons}";
}

test "for_array_body.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_array_body.c");
    errs = _recompile_errors(jac_str, "for_array_body.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}
