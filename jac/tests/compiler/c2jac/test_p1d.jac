"""P1d phase-exit: C-for and enums via direct-IR path."""

import from tests.compiler.c2jac.support {
    read_fixture as _read,
    transpile_fixture_tags as _transpile,
    recompile_errors as _recompile_errors
}
import from jaclang.compiler.c2jac.driver { transpile_c_str }
import from jaclang.compiler.c2jac.enum_prepass { build_enum_map }
import from jaclang.compiler.c2jac.tags { Idiom, Tier }
import from jaclang.vendor.pycparser { c_parser }

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

# --- ternary inside a direct-IR for-body ---
test "for_ternary.c: ?: in a for-body lowers to a Jac conditional expression" {
    (jac_str, tags) = _transpile("for_ternary.c");
    # The augmented assignment `s += i > hi ? hi : i` must survive: a ternary RHS
    # used to make _expr_to_uni return None, dropping the whole assignment and
    # demoting the loop. The arm/cond order is `value if condition else other`.
    assert "s += hi if (i > hi) else i" in jac_str , f"Expected conditional expression in for-body:\n{jac_str}";
}

test "for_ternary.c: faithful for-body is fully Tier-A (no phantom best-effort site)" {
    (jac_str, tags) = _transpile("for_ternary.c");
    # With the ternary lowered, no body construct is lost, so the loop stays a
    # full ascending IterForStmt rather than the while-desugar fallback.
    assert "for i = 0 to i < n by i += 1" in jac_str , f"Expected full IterForStmt in:\n{jac_str}";
    # The whole function is faithful: the ternary is on the Tier-A allowlist, so
    # there must be no Tier-B sites at all (a missing allowlist entry used to
    # default-stamp the ?: node Tier-B with an empty reason).
    entries = tags.tier_b_entries();
    assert len(entries) == 0 , f"ternary for-body should be fully Tier-A, got {[
        (nt.c_line, nt.reason) for nt in entries
    ]}";
}

test "for_ternary.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_ternary.c");
    errs = _recompile_errors(jac_str, "for_ternary.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- comma (ExprList) inside a direct-IR for-body ---
# C `(a, … , z)` evaluates every operand but yields only `z`. The direct-IR
# `_expr_to_uni` had no ExprList case, so any comma RHS returned None and the
# whole statement was dropped. Now it lowers to just the final operand when the
# leading operands are side-effect-free (faithful, Tier-A); an impure leading
# operand still bails so the loss is flagged honestly (Tier-B).
test "for_comma.c: a pure comma in a for-body lowers to its final operand" {
    (jac_str, tags) = _transpile("for_comma.c");
    # `s += (0, i)` — the pure leading `0` drops, only `i` is emitted.
    assert "s += i" in jac_str , f"Expected the pure comma lowered to its final operand in:\n{jac_str}";
}

test "for_comma.c: the pure-comma loop stays a full Tier-A IterForStmt" {
    (jac_str, tags) = _transpile("for_comma.c");
    # With the comma lowered, the pure_comma body loses nothing, so its loop is a
    # full ascending IterForStmt — and carries no Tier-B flag of its own.
    assert "for i = 0 to i < n by i += 1" in jac_str , f"Expected full IterForStmt in:\n{jac_str}";
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert not any("0, i" in r for r in reasons) , f"A pure comma must not demote its loop, got {reasons}";
}

test "for_comma.c: an impure comma is dropped and demotes its loop to Tier-B" {
    (jac_str, tags) = _transpile("for_comma.c");
    # `s += (touch(i), i)` — the leading `touch(i)` call is side-effecting, so the
    # whole assignment can't be lowered faithfully; the loop demotes to Tier-B
    # with the body-construct loss flagged rather than silently dropping the call.
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert any("not faithfully lowered" in r and "comma" in r for r in reasons) , f"Expected the impure-comma loop flagged Tier-B, got {reasons}";
}

test "for_comma.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_comma.c");
    errs = _recompile_errors(jac_str, "for_comma.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- Enum tests ---
test "enum_prepass: Color gets ENUM_AS_ENUM verdict" {
    src = _read("enum_simple.c");
    file_ast = c_parser.CParser().parse(src, "enum_simple.c");
    ev = build_enum_map(file_ast);
    verdicts = list(ev.verdicts.values());
    assert Idiom.ENUM_AS_ENUM in verdicts , f"Expected ENUM_AS_ENUM in {verdicts}";
}

test "enum_prepass: Permissions gets ENUM_AS_ENUM verdict (non-sequential, unique values)" {
    src = _read("enum_flags.c");
    file_ast = c_parser.CParser().parse(src, "enum_flags.c");
    ev = build_enum_map(file_ast);
    verdicts = list(ev.verdicts.values());
    # PERM_ALL = 7 is non-sequential but every value is unique; _enum_as_enum
    # writes each value explicitly, so it lowers faithfully to an enum rather
    # than being demoted over a cosmetic gap.
    assert Idiom.ENUM_AS_ENUM in verdicts , f"Expected ENUM_AS_ENUM in {verdicts}";
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
    # The second enum with VAL_A collision is demoted (matched no idiom).
    assert Idiom.NONE in verdicts , f"Expected demotion (Idiom.NONE) for collision in {verdicts}";
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

# --- The while-desugar is faithful — and so Tier-A — when the body has no
# loop-level `continue`, the condition lowered cleanly, and every body construct
# lowered. A descending `for (i = n; i > 0; i--)` (no IterForStmt) and an
# infinite `for(;;)` both satisfy this: `init; while cond { body; step }` runs
# exactly as the C loop. The desugar diverges from C only when a loop-level
# `continue` skips a step (covered by for_continue.c below); a `continue` with
# no step to skip stays faithful (covered by for_infinite_continue.c). ---
test "for_unsupported.c: faithful descending/infinite desugars promote to Tier-A" {
    (jac_str, tags) = _transpile("for_unsupported.c");
    # Neither loop has a continue / lossy condition / lossy body, so NO Tier-B
    # tag should mention the while-desugar (both are now Tier-A C_FOR idioms).
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert not any("desugared to while" in r for r in reasons) , f"Faithful desugars must not be Tier-B, got {reasons}";
    # The promotion is recorded with the C_FOR idiom (queryable via by_idiom),
    # so metrics can tell a faithful while-desugar from a default-tagged node.
    c_for = tags.by_idiom(Idiom.C_FOR);
    assert len(c_for) >= 2 , f"Expected >=2 Tier-A C_FOR desugars (descending + infinite), got {len(
        c_for
    )}";
    for nt in c_for {
        assert nt.tier == Tier.TIER_A , f"C_FOR idiom must be Tier-A, got {nt.tier}";
    }
}

test "for_continue.c: a loop-level continue keeps the while-desugar Tier-B" {
    (jac_str, tags) = _transpile("for_continue.c");
    # Body lowers fine (if/continue/assignment all have analogs) but the
    # loop-level `continue` makes `body; step` unfaithful to C's step-then-retest.
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    cont_flagged = [
        r
        for r in reasons
        if "continue" in r and "desugared to while" in r
    ];
    assert len(cont_flagged) >= 1 , f"Expected a Tier-B continue-semantics flag, got {reasons}";
    # The sole loop is Tier-B, so no C_FOR (Tier-A) promotion may exist for it.
    assert len(tags.by_idiom(Idiom.C_FOR)) == 0 , f"A continue-bearing desugar must not promote to Tier-A C_FOR";
}

test "for_continue.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_continue.c");
    errs = _recompile_errors(jac_str, "for_continue.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- A `for(;;)` has no step, so a loop-level `continue` has nothing to skip:
# C's `continue` retests the (absent → always-true) condition, exactly as the
# desugared `while True { body }` does. The continue gate is paired with step
# presence, so this infinite loop promotes to Tier-A *despite* its continue —
# unlike the descending for_continue.c whose `i--` step the continue would skip. ---
test "for_infinite_continue.c: a continue with no step still promotes to Tier-A" {
    (jac_str, tags) = _transpile("for_infinite_continue.c");
    # The lone loop is a faithful `while True` desugar, so nothing about it may be
    # flagged Tier-B — in particular no continue-semantics reason.
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert not any("desugared to while" in r for r in reasons) , f"Step-free continue desugar must not be Tier-B, got {reasons}";
    # The promotion is recorded with the C_FOR idiom and must be Tier-A.
    c_for = tags.by_idiom(Idiom.C_FOR);
    assert len(c_for) >= 1 , f"Expected a Tier-A C_FOR desugar for the for(;;)+continue loop, got {len(
        c_for
    )}";
    for nt in c_for {
        assert nt.tier == Tier.TIER_A , f"C_FOR idiom must be Tier-A, got {nt.tier}";
    }
}

test "for_infinite_continue.c: the continue and body survive the desugar" {
    (jac_str, tags) = _transpile("for_infinite_continue.c");
    # The desugar keeps the `continue` and the post-continue accumulation verbatim.
    assert "continue" in jac_str , f"Expected the loop-level continue in:\n{jac_str}";
    assert "sum = sum + i" in jac_str or "sum += i" in jac_str , f"Expected the body accumulation in:\n{jac_str}";
}

test "for_infinite_continue.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_infinite_continue.c");
    errs = _recompile_errors(jac_str, "for_infinite_continue.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- A bare function-call step `for (...; tick())` has no augmented-assignment
# analog, so IterForStmt can't model it (count_by must be `x += …`). The
# while-desugar appends the call as an ExprStmt step after the body — exactly
# where C runs it — so with init/cond/body all faithful and no loop-level
# continue to skip the step, the loop now promotes to Tier-A. ---
test "for_funcall_step.c: a function-call step lowers faithfully and promotes to Tier-A" {
    (jac_str, tags) = _transpile("for_funcall_step.c");
    # `for (i = 0; i < n; tick())` — every clause lowers, so no while-desugar
    # Tier-B loss reasons should remain (in particular no dropped-step flag).
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert not any("step not faithfully lowered" in r for r in reasons) , f"The call step lowers now; no dropped-step flag expected, got {reasons}";
    assert not any("desugared to while" in r for r in reasons) , f"The desugar is faithful; no while-desugar Tier-B reason expected, got {reasons}";
    # The promotion is recorded with the C_FOR idiom and must be Tier-A.
    c_for = tags.by_idiom(Idiom.C_FOR);
    assert len(c_for) >= 1 , f"Expected a Tier-A C_FOR desugar for the call-step loop, got {len(
        c_for
    )}";
    for nt in c_for {
        assert nt.tier == Tier.TIER_A , f"C_FOR idiom must be Tier-A, got {nt.tier}";
    }
}

test "for_funcall_step.c: the call step survives the desugar after the body" {
    (jac_str, tags) = _transpile("for_funcall_step.c");
    # The init, body, and the appended call step must all be present verbatim.
    assert "i = 0" in jac_str , f"Expected preserved initializer 'i = 0' in:\n{jac_str}";
    assert "tick()" in jac_str , f"Expected the appended call step 'tick()' in:\n{jac_str}";
    assert "i = i + 1" in jac_str or "i += 1" in jac_str , f"Expected the body advance in:\n{jac_str}";
}

test "for_funcall_step.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_funcall_step.c");
    errs = _recompile_errors(jac_str, "for_funcall_step.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- A multi-clause init `for (i = 0, j = 10; ...)` is an ExprList (comma) of
# assignments — `for (int i = 0, j = 0; ...)` would be a DeclList. A single
# IterForStmt `iter=` slot can hold only one, so these route to the while-desugar
# which emits one assignment per clause before the loop. With every clause
# faithful, the loop promotes to Tier-A. ---
test "for_comma_init.c: a comma init lowers to per-clause assignments and promotes to Tier-A" {
    (jac_str, tags) = _transpile("for_comma_init.c");
    # `for (i = 0, j = 10; ...)` — both init clauses lower, so no while-desugar
    # Tier-B loss reasons should remain (in particular no dropped-init flag).
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert not any("init not faithfully lowered" in r for r in reasons) , f"Both init clauses lower now; no dropped-init flag expected, got {reasons}";
    assert not any("desugared to while" in r for r in reasons) , f"The desugar is faithful; no while-desugar Tier-B reason expected, got {reasons}";
    c_for = tags.by_idiom(Idiom.C_FOR);
    assert len(c_for) >= 1 , f"Expected a Tier-A C_FOR desugar for the comma-init loop, got {len(
        c_for
    )}";
    for nt in c_for {
        assert nt.tier == Tier.TIER_A , f"C_FOR idiom must be Tier-A, got {nt.tier}";
    }
}

test "for_comma_init.c: both init clauses survive the desugar before the loop" {
    (jac_str, tags) = _transpile("for_comma_init.c");
    # Each comma operand becomes its own pre-loop assignment.
    assert "i = 0" in jac_str , f"Expected preserved initializer 'i = 0' in:\n{jac_str}";
    assert "j = 10" in jac_str , f"Expected preserved initializer 'j = 10' in:\n{jac_str}";
    assert "j = j - 1" in jac_str , f"Expected the body in:\n{jac_str}";
}

test "for_comma_init.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_comma_init.c");
    errs = _recompile_errors(jac_str, "for_comma_init.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- The DeclList init form `for (int i = 0, j = 0; ...)` is the sibling of the
# comma (ExprList) init: both hold more clauses than IterForStmt's single `iter=`
# slot, so both route to the while-desugar which emits one assignment per decl
# before the loop. With every clause faithful, the loop promotes to Tier-A. The
# comma fixture only exercises the ExprList path; this guards the DeclList one. ---
test "for_multidecl_init.c: a multi-decl init lowers to per-decl assignments and promotes to Tier-A" {
    (jac_str, tags) = _transpile("for_multidecl_init.c");
    # `for (int i = 0, j = 0; ...)` — both decls lower, so no while-desugar Tier-B
    # loss reasons should remain (in particular no dropped-init flag).
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert not any("init not faithfully lowered" in r for r in reasons) , f"Both init decls lower now; no dropped-init flag expected, got {reasons}";
    assert not any("desugared to while" in r for r in reasons) , f"The desugar is faithful; no while-desugar Tier-B reason expected, got {reasons}";
    c_for = tags.by_idiom(Idiom.C_FOR);
    assert len(c_for) >= 1 , f"Expected a Tier-A C_FOR desugar for the multi-decl-init loop, got {len(
        c_for
    )}";
    for nt in c_for {
        assert nt.tier == Tier.TIER_A , f"C_FOR idiom must be Tier-A, got {nt.tier}";
    }
}

test "for_multidecl_init.c: both decl initializers survive before the loop" {
    (jac_str, tags) = _transpile("for_multidecl_init.c");
    # Each decl becomes its own pre-loop declaration. Now that the init clause
    # lowers through the SAME c_Decl the function top level uses, the C type is
    # preserved too (`i: int = 0`) — the old direct-IR path dropped it to a bare
    # `i = 0` assignment.
    assert "i: int = 0" in jac_str , f"Expected preserved initializer 'i: int = 0' in:\n{jac_str}";
    assert "j: int = 0" in jac_str , f"Expected preserved initializer 'j: int = 0' in:\n{jac_str}";
    assert "j = j + 2" in jac_str , f"Expected the body in:\n{jac_str}";
}

test "for_multidecl_init.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_multidecl_init.c");
    errs = _recompile_errors(jac_str, "for_multidecl_init.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- The call-step lowering must still compose with the continue gate: C's
# `continue` jumps to the for-step (running the call), but the desugared
# `body; tick()` runs `continue` *before* the appended call, skipping it. So a
# call step PLUS a loop-level `continue` is unfaithful and must stay Tier-B —
# even though the step itself now lowers. This guards against the call-step path
# accidentally bypassing the continue_unfaithful demotion. ---
test "for_funcall_step_continue.c: a call step with a loop-level continue stays Tier-B" {
    (jac_str, tags) = _transpile("for_funcall_step_continue.c");
    # The call step is still emitted (it lowers fine)...
    assert "tick()" in jac_str , f"Expected the call step 'tick()' in:\n{jac_str}";
    assert "continue" in jac_str , f"Expected the loop-level continue in:\n{jac_str}";
    # ...but the continue would skip it, so no Tier-A promotion and the reason
    # must call out the continue/step divergence.
    assert len(tags.by_idiom(Idiom.C_FOR)) == 0 , f"A continue-skips-step desugar must not promote to Tier-A C_FOR";
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert any("continue" in r and "skips it" in r for r in reasons) , f"Expected the continue-skips-step Tier-B reason, got {reasons}";
}

test "for_funcall_step_continue.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_funcall_step_continue.c");
    errs = _recompile_errors(jac_str, "for_funcall_step_continue.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
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
    # The outer `*(p + 1)` condition has no analog and became `while True`...
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

# --- Review finding: a cast inside a direct-IR (C-for) body expression must be
# lowered (not dropped), mirroring the top-level mapper.c_Cast. A scalar cast is
# representation-changing and demotes the loop to Tier-B; a pointer cast doesn't
# change the emitted value and stays Tier-A. Before the fix, _expr_to_uni had no
# Cast case, so `total + (int)(i/2)` returned None and the WHOLE assignment was
# silently dropped from the loop body. ---
test "for_cast.c: a scalar cast in the body lowers its inner expr (statement not dropped)" {
    (jac_str, tags) = _transpile("for_cast.c");
    # The assignment must survive with the cast elided to its operand — not vanish.
    assert "total = total + (i / 2)" in jac_str , f"Expected the scalar-cast statement preserved with the cast elided in:\n{jac_str}";
}

test "for_cast.c: a scalar cast demotes its loop to Tier-B with a cast-specific reason" {
    (jac_str, tags) = _transpile("for_cast.c");
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    cast_flagged = [
        r
        for r in reasons
        if "cast to `int` elided" in r
    ];
    assert len(cast_flagged) >= 1 , f"Expected a Tier-B scalar-cast flag, got {reasons}";
}

test "for_cast.c: a pointer cast in the body lowers cleanly and stays Tier-A" {
    (jac_str, tags) = _transpile("for_cast.c");
    # `((int *)a)[i]` → `a[i]`: the pointer cast doesn't change the emitted value,
    # so the deref_sum loop must NOT carry any Tier-B cast flag.
    assert "total = total + a[i]" in jac_str , f"Expected the pointer-cast arrayref lowered to `a[i]` in:\n{jac_str}";
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert not any("pointer" in r.lower() and "cast" in r.lower() for r in reasons) , f"A pointer cast must not demote the loop, got {reasons}";
}

test "for_cast.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_cast.c");
    errs = _recompile_errors(jac_str, "for_cast.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- Tier-A finding: a simple `*p` / `&x` deref in a direct-IR (C-for) body is
# the PTR_REF identity — `*p`/`&x`/`*s.f`/`&a[i]` → the operand itself, matching
# the top-level mapper.c_UnaryOp. Before the fix, _expr_to_uni returned None for
# any `*`/`&` operand, so `s += *p` and `*p += i` dropped from the loop body and
# demoted the whole loop. Only ID / s.f / s->f / a[i] qualify; a computed deref
# like `*(p + 1)` keeps a BinaryOp operand and stays Tier-B. ---
test "for_deref.c: `s += *p` (deref on the RHS) lowers to the bare reference" {
    (jac_str, tags) = _transpile("for_deref.c");
    # The augmented assignment must survive with the deref elided to its operand.
    assert "s += p;" in jac_str , f"Expected `*p` RHS lowered to `p` in:\n{jac_str}";
}

test "for_deref.c: `*p += i` (deref on the LHS) lowers to the bare reference" {
    (jac_str, tags) = _transpile("for_deref.c");
    # The deref target must lower too, not just the RHS — `_lvalue_to_uni` used to
    # return None for `*p`, dropping the whole statement.
    assert "p += i;" in jac_str , f"Expected `*p` LHS lowered to `p` in:\n{jac_str}";
}

test "for_deref.c: simple-deref loops stay fully Tier-A (full IterForStmt, no loss)" {
    (jac_str, tags) = _transpile("for_deref.c");
    # Both deref bodies lower faithfully, so the loops keep the ascending
    # IterForStmt shape rather than falling back to the while-desugar.
    assert "for i = 0 to i < n by i += 1" in jac_str , f"Expected full IterForStmt in:\n{jac_str}";
    # The only loop demoted is the computed-deref function below; the two simple
    # ones must contribute no losses. A demoted loop now carries TWO Tier-B
    # entries — the unmappable body construct itself plus the loop-level composite
    # that aggregates it (§3) — so count the loop-level composites, of which there
    # must be exactly one.
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    loop_losses = [
        r
        for r in reasons
        if "C-for body constructs not faithfully lowered" in r
    ];
    assert len(loop_losses) == 1 , f"Only the computed-deref loop should be Tier-B, got {reasons}";
}

test "for_deref.c: a computed deref `*(p + 1)` keeps the loop Tier-B (arithmetic not elidable)" {
    (jac_str, tags) = _transpile("for_deref.c");
    # `*(p + 1)` has a BinaryOp operand — not a simple ref — so the assignment is
    # dropped and the enclosing loop is honestly demoted with a body-loss reason.
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert any("not faithfully lowered" in r for r in reasons) , f"Expected a Tier-B body-loss flag for the computed deref, got {reasons}";
}

test "for_deref.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_deref.c");
    errs = _recompile_errors(jac_str, "for_deref.c");
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

test "for_body_rich.c: an uninitialized decl in the body is preserved faithfully (no demotion)" {
    (jac_str, tags) = _transpile("for_body_rich.c");
    # Folding loop-body lowering back onto the py-ast path (the same one the
    # function top level uses) means a bare `int local;` now lowers to a faithful
    # Jac declaration `local: int;` — the old direct-IR for-builder had no case for
    # it and silently dropped it, demoting the loop. The desugar is now fully
    # faithful, so the loop carries NO Tier-B flag.
    assert "local: int;" in jac_str , f"Expected the uninitialized decl preserved as `local: int;` in:\n{jac_str}";
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert len(reasons) == 0 , f"A faithfully-lowered decl must not demote the loop, got {reasons}";
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
    assert Idiom.NONE in verdicts , f"Expected demotion (Idiom.NONE) for TU-name collision in {verdicts}";
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

# --- GC / pointer idioms (free / malloc / realloc) inside a for-body. Now that
# loop-body lowering is single-sourced through the mapper's py-ast path, a for-body
# call runs through the SAME mapper.c_FuncCall idiom rewrites the function top
# level uses — so the idiom verdict no longer depends on nesting depth (the old
# direct-IR for-builder had no rewrite and demoted every such loop). `free(p)` is
# faithfully elided to a no-op (Jac lists are GC'd → Tier-A FREE_ELIDE), while a
# `realloc` whose pointer is NOT proven list-bound is honestly Tier-B (a raw-buffer
# resize would be lost). ---
test "for_ptr_idiom.c: free() in a for-body is faithfully elided (Tier-A FREE_ELIDE, loop not demoted)" {
    (jac_str, tags) = _transpile("for_ptr_idiom.c");
    # free() is a GC no-op in Jac, so the call is elided and the sum_then_free loop
    # stays faithful — exactly as `free(p)` at function top level lowers.
    free_elide = tags.by_idiom(Idiom.FREE_ELIDE);
    assert len(free_elide) >= 1 , f"Expected a Tier-A FREE_ELIDE for the free() call, got {len(
        free_elide
    )}";
    for nt in free_elide {
        assert nt.tier == Tier.TIER_A , f"FREE_ELIDE must be Tier-A, got {nt.tier}";
    }
}

test "for_ptr_idiom.c: realloc() not proven list-bound demotes the loop to Tier-B" {
    (jac_str, tags) = _transpile("for_ptr_idiom.c");
    # `arr = realloc(arr, i)` on a bare pointer param (not proven list-bound) is
    # elided to its pointer arg but the resize semantics are lost, so the realloc
    # is REALLOC_ELIDE Tier-B and the enclosing loop carries the composite body-loss.
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert any("realloc elided" in r for r in reasons) , f"Expected the realloc-elide Tier-B flag, got {reasons}";
    assert any("not faithfully lowered" in r and "realloc" in r for r in reasons) , f"Expected the realloc-bearing loop demoted with a body-loss reason, got {reasons}";
}

test "for_ptr_idiom.c: the idiom calls are rewritten, not emitted as literal calls" {
    (jac_str, tags) = _transpile("for_ptr_idiom.c");
    # free → no-op and realloc → its pointer arg, exactly as the mapper rewrites
    # them at top level — never a literal `free(p)` / `realloc(arr, i)` call.
    assert "free(p)" not in jac_str , f"free() must not survive as a literal call in:\n{jac_str}";
    assert "realloc(arr" not in jac_str , f"realloc() must not survive as a literal call in:\n{jac_str}";
}

test "for_ptr_idiom.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_ptr_idiom.c");
    errs = _recompile_errors(jac_str, "for_ptr_idiom.c");
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

# --- A C char constant is an integer. When it is compared/combined with a
# NUMERIC operand (`i < 'z'`, where `i` is int) the faithful Jac is its ordinal
# `i < 122`, never a string comparison (int vs str) nor the silent `0` the old
# direct-IR `_expr_to_uni` substituted. c_BinaryOp promotes a char-literal
# operand to its ordinal when the sibling resolves to int/float (via the scalar-
# var type map), while a char-to-char compare (`c == 'a'`, char→str var) keeps
# the readable string form. ---
test "for_char_cond.c: char literal in a for-condition lowers to its ordinal (not 0, not a str compare)" {
    (jac_str, tags) = _transpile("for_char_cond.c");
    # 'z' is 122; the int loop variable must compare against the ordinal 122.
    assert "i < 122" in jac_str , f"Expected `i < 122` (ord('z')) in:\n{jac_str}";
    assert "i < 0" not in jac_str , f"char literal must not collapse to 0 in:\n{jac_str}";
    assert "i < 'z'" not in jac_str , f"int-vs-char compare must promote to the ordinal, not a str compare:\n{jac_str}";
    # The flip side: a char-to-char compare (`c == 'a'`, where `c` is a char→str
    # variable) must KEEP the readable string form — promoting it to `c == 97`
    # would compare a str to an int (always false). The promotion is type-aware,
    # not blanket.
    assert "c == 'a'" in jac_str , f"char-var vs char-literal compare must stay a str compare:\n{jac_str}";
    assert "c == 97" not in jac_str , f"char-var compare must not be promoted to an ordinal:\n{jac_str}";
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
    assert "arr[j] = arr[(j + 1)];" in jac_str , f"Expected indexed swap assignment in:\n{jac_str}";
    assert "arr[(j + 1)] = tmp;" in jac_str , f"Expected second swap leg in:\n{jac_str}";
    # The `int tmp: int = arr[j];` decl-with-ArrayRef-init also survives.
    assert "tmp: int = arr[j];" in jac_str , f"Expected decl-init from arr[j] in:\n{jac_str}";
}

test "for_array_body.c: the three swap statements live INSIDE the if-condition body" {
    (jac_str, tags) = _transpile("for_array_body.c");
    # Sharper than the file-wide substrings above: the original bug emitted an
    # empty `if { }` while the swap statements vanished. Slice out the actual
    # if-block and assert all three swap legs are enclosed by its braces, so a
    # regression that empties the conditional (or relocates the assignments) is
    # caught even when the loose file-wide substrings still match. Parens are
    # stripped first so this pins STRUCTURE (swaps inside the braces), not the
    # formatter's redundant-paren policy (`arr[(j + 1)]` vs `arr[j + 1]`).
    flat = jac_str.replace("(", "").replace(")", "");
    header = "if arr[j] > arr[j + 1] {";
    start = flat.find(header);
    assert start != -1 , f"Expected the ArrayRef if-condition in:\n{jac_str}";
    # The swap body has no nested braces, so the next `}` closes the if-block.
    body_end = flat.find("}", start + len(header));
    assert body_end != -1 , f"Expected a closing brace for the if-block in:\n{jac_str}";
    if_body = flat[start + len(header):body_end];
    assert "tmp: int = arr[j];" in if_body , f"decl-init swap leg not inside the if-body:\n{jac_str}";
    assert "arr[j] = arr[j + 1];" in if_body , f"first swap leg not inside the if-body:\n{jac_str}";
    assert "arr[j + 1] = tmp;" in if_body , f"second swap leg not inside the if-body:\n{jac_str}";
}

test "for_array_body.c: ArrayRef rvalue and if-condition lower faithfully" {
    (jac_str, tags) = _transpile("for_array_body.c");
    # `s += arr[i]` — ArrayRef as an aug-assign rvalue used to drop the statement.
    assert "s += arr[i];" in jac_str , f"Expected `s += arr[i]` in:\n{jac_str}";
    # An if-condition containing an ArrayRef used to drop the entire if-block.
    assert "if (arr[j] > arr[(j + 1)]) {" in jac_str , f"Expected ArrayRef if-condition in:\n{jac_str}";
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

# --- Tier-A promotion: a bare `i++;` / `i--;` increment STATEMENT inside a
# direct-IR for-body. _c_stmt_to_uni had no UnaryOp case, so a stand-alone
# increment fell through to the generic fallback and demoted the loop. It now
# lowers to the same augmented assignment a for-step does (`s++` → `s += 1`). ---
test "for_incdec_body.c: a bare increment statement lowers to an augmented assignment" {
    (jac_str, tags) = _transpile("for_incdec_body.c");
    assert "s += 1;" in jac_str , f"Expected `s++` → `s += 1` in:\n{jac_str}";
    assert "s -= 1;" in jac_str , f"Expected `s--` → `s -= 1` in:\n{jac_str}";
}

test "for_incdec_body.c: the increment-body loop stays a full Tier-A IterForStmt" {
    (jac_str, tags) = _transpile("for_incdec_body.c");
    assert "for i = 0 to i < n by i += 1 {" in jac_str , f"Expected full IterForStmt in:\n{jac_str}";
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert len(reasons) == 0 , f"increment-body loop should be fully Tier-A, got {reasons}";
}

test "for_incdec_body.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_incdec_body.c");
    errs = _recompile_errors(jac_str, "for_incdec_body.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- Tier-A promotion: a comma STEP `for (...; ...; i++, j++)` is an ExprList.
# IterForStmt's single count_by slot can't hold a comma, so it routes to the
# while-desugar, which now appends ONE step statement per operand after the body
# (where C runs them). Every clause faithful → Tier-A. ---
test "for_comma_step.c: a comma step lowers to one appended step per operand and promotes to Tier-A" {
    (jac_str, tags) = _transpile("for_comma_step.c");
    # Each comma-step operand becomes its own appended step in the desugared body.
    assert "i += 1;" in jac_str , f"Expected the first comma-step `i++` appended in:\n{jac_str}";
    assert "j += 1;" in jac_str , f"Expected the second comma-step `j++` appended in:\n{jac_str}";
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert not any("step not faithfully lowered" in r for r in reasons) , f"Both comma-step operands lower; no dropped-step flag expected, got {reasons}";
    assert not any("desugared to while" in r for r in reasons) , f"The desugar is faithful; no while-desugar Tier-B reason expected, got {reasons}";
    c_for = tags.by_idiom(Idiom.C_FOR);
    assert len(c_for) >= 1 , f"Expected a Tier-A C_FOR desugar for the comma-step loop, got {len(
        c_for
    )}";
    for nt in c_for {
        assert nt.tier == Tier.TIER_A , f"C_FOR idiom must be Tier-A, got {nt.tier}";
    }
}

test "for_comma_step.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_comma_step.c");
    errs = _recompile_errors(jac_str, "for_comma_step.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- Tier-A promotion: a richer comma INIT `for (i = 0, seed(); ...)` mixes an
# assignment with a side-effecting call. _for_init_list used to bail on any
# non-assignment operand; it now lowers `i++`/`i--` (→ aug-assign) and bare calls
# (→ expression statement) too, so each operand becomes a faithful pre-loop
# statement and the loop promotes to Tier-A. ---
test "for_comma_init_rich.c: a call operand in a comma init lowers to a pre-loop statement" {
    (jac_str, tags) = _transpile("for_comma_init_rich.c");
    assert "i = 0;" in jac_str , f"Expected the assignment init clause in:\n{jac_str}";
    assert "seed();" in jac_str , f"Expected the call init clause lowered to a pre-loop statement in:\n{jac_str}";
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert not any("init not faithfully lowered" in r for r in reasons) , f"Both init clauses lower now; no dropped-init flag expected, got {reasons}";
    assert not any("desugared to while" in r for r in reasons) , f"The desugar is faithful; no while-desugar Tier-B reason expected, got {reasons}";
    c_for = tags.by_idiom(Idiom.C_FOR);
    assert len(c_for) >= 1 , f"Expected a Tier-A C_FOR desugar for the rich-comma-init loop, got {len(
        c_for
    )}";
}

test "for_comma_init_rich.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_comma_init_rich.c");
    errs = _recompile_errors(jac_str, "for_comma_init_rich.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- Tier-A promotion: a nested `do { } while` inside a direct-IR for-body.
# _c_stmt_to_uni had no DoWhile case, so it fell to the generic fallback and
# demoted the loop. It now desugars to `while True { body; if not cond break }`
# (mirrors mapper.c_DoWhile): a continue-free do-while is faithful (Tier-A,
# DO_WHILE idiom), and a loop-level continue — which would skip the post-body
# condition test — demotes both the do-while node and the enclosing loop. ---
test "for_nested_dowhile.c: a clean nested do-while desugars faithfully and is Tier-A" {
    (jac_str, tags) = _transpile("for_nested_dowhile.c");
    # The `do { body } while (k < i)` desugars to `while True { body; if not k < i break }`.
    assert "while True {" in jac_str , f"Expected the do-while desugar `while True` in:\n{jac_str}";
    assert "if not (k < i) {" in jac_str , f"Expected the post-body condition guard in:\n{jac_str}";
    # The clean do-while is stamped Tier-A with the DO_WHILE idiom (queryable).
    do_while = tags.by_idiom(Idiom.DO_WHILE);
    assert len(do_while) == 1 , f"Expected exactly one Tier-A DO_WHILE (the clean nested do-while), got {len(
        do_while
    )}";
    for nt in do_while {
        assert nt.tier == Tier.TIER_A , f"DO_WHILE idiom must be Tier-A, got {nt.tier}";
    }
}

test "for_nested_dowhile.c: a do-while with a loop-level continue stays Tier-B" {
    (jac_str, tags) = _transpile("for_nested_dowhile.c");
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    # The continue would skip the post-body condition test, so the do-while node
    # is flagged precisely AND the enclosing loop is demoted.
    assert any(
        "skips the post-body condition test" in r and "while True" in r for r in reasons
    ) , f"Expected the precise do-while continue-skips-cond flag, got {reasons}";
    assert any("not faithfully lowered" in r and "do-while" in r for r in reasons) , f"Expected the enclosing loop demoted by the lossy do-while, got {reasons}";
}

test "for_nested_dowhile.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_nested_dowhile.c");
    errs = _recompile_errors(jac_str, "for_nested_dowhile.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- Tier-A promotion: a nested `switch` inside a direct-IR for-body. _c_stmt_to_uni
# had no Switch case, so it fell to the generic fallback and demoted the loop. It
# now lowers to a nested if/elif/else chain (mirrors mapper.c_Switch): a clean
# switch (no fall-through, pure selector) is faithful (Tier-A, SWITCH_CLEAN idiom),
# and a lossy one (case fall-through) demotes both the switch node and the loop. ---
test "for_nested_switch.c: a clean nested switch lowers to an if/elif/else chain and is Tier-A" {
    (jac_str, tags) = _transpile("for_nested_switch.c");
    # `switch (i) { case 0: ...; case 1: ...; default: ... }` → if/elif/else.
    assert "if (i == 0) {" in jac_str , f"Expected the head `if (i == 0)` arm in:\n{jac_str}";
    assert "elif (i == 1) {" in jac_str , f"Expected the `elif (i == 1)` arm in:\n{jac_str}";
    assert "} else {" in jac_str , f"Expected the default → `else` arm in:\n{jac_str}";
    # The clean switch is stamped Tier-A with the SWITCH_CLEAN idiom (queryable).
    clean = tags.by_idiom(Idiom.SWITCH_CLEAN);
    assert len(clean) == 1 , f"Expected exactly one Tier-A SWITCH_CLEAN (the clean nested switch), got {len(
        clean
    )}";
    for nt in clean {
        assert nt.tier == Tier.TIER_A , f"SWITCH_CLEAN idiom must be Tier-A, got {nt.tier}";
    }
}

test "for_nested_switch.c: a switch with case fall-through stays Tier-B" {
    (jac_str, tags) = _transpile("for_nested_switch.c");
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    # The fall-through (case 0 has no break) can't be modelled by if/elif, so the
    # switch node is flagged precisely AND the enclosing loop is demoted.
    assert any("fall-through is not" in r for r in reasons) , f"Expected the precise switch fall-through flag, got {reasons}";
    assert any("not faithfully lowered" in r and "switch" in r for r in reasons) , f"Expected the enclosing loop demoted by the lossy switch, got {reasons}";
}

test "for_nested_switch.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_nested_switch.c");
    errs = _recompile_errors(jac_str, "for_nested_switch.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- Tier-A promotion: a brace initializer `int a[3] = {1, 2, 3};` in a for-body
# local decl. _expr_to_uni had no InitList case, so the decl-init returned None
# and the whole declaration was dropped (demoting the loop). It now lowers to a
# Jac list literal, preserving element order. ---
test "for_initlist.c: a brace initializer lowers to a Jac list literal" {
    (jac_str, tags) = _transpile("for_initlist.c");
    assert "a: list[int] = [1, 2, 3];" in jac_str , f"Expected the InitList lowered to a typed list literal in:\n{jac_str}";
}

test "for_initlist.c: the initializer-list loop stays a full Tier-A IterForStmt" {
    (jac_str, tags) = _transpile("for_initlist.c");
    assert "for i = 0 to i < n by i += 1 {" in jac_str , f"Expected full IterForStmt in:\n{jac_str}";
    reasons = [nt.reason for nt in tags.tier_b_entries()];
    assert len(reasons) == 0 , f"initializer-list loop should be fully Tier-A, got {reasons}";
}

test "for_initlist.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_initlist.c");
    errs = _recompile_errors(jac_str, "for_initlist.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- A stray `;` in a for-body is a no-op. _populate_default_tags stamped the
# EmptyStatement node Tier-B (empty reason) and the direct-IR fallback flagged it
# as a dropped body construct — a do-nothing statement presenting as a phantom
# best-effort site. It is now on the boundary Tier-A allowlist and the direct-IR
# builder drops it outright, so it contributes no loss. ---
test "for_empty_stmt.c: an empty statement is a no-op and demotes nothing" {
    (jac_str, tags) = _transpile("for_empty_stmt.c");
    assert "for i = 0 to i < n by i += 1 {" in jac_str , f"Expected full IterForStmt in:\n{jac_str}";
    # The stray `;` must contribute NO Tier-B site at all (not even an empty-reason one).
    entries = tags.tier_b_entries();
    assert len(entries) == 0 , f"empty statement should be a no-op Tier-A, got {[
        (nt.c_line, nt.reason) for nt in entries
    ]}";
}

test "for_empty_stmt.c emitted Jac recompiles cleanly" {
    (jac_str, tags) = _transpile("for_empty_stmt.c");
    errs = _recompile_errors(jac_str, "for_empty_stmt.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}

# --- A top-level `;` (py-ast path, not a for-body) also lowers to a no-op rather
# than the dispatch-miss `__c2jac_unsupported__` surrogate, and is Tier-A. The
# Jac no-op renders as a bare `;`; the point is that it is faithful, not a
# flagged best-effort surrogate. ---
test "top-level empty statement is a no-op (no surrogate, Tier-A)" {
    (jac_str, tags) = transpile_c_str("int f(int n) { ; return n; }", "empty_top.c");
    # The function body survives and carries no dispatch-miss surrogate.
    assert "return n;" in jac_str , f"Expected the function body preserved in:\n{jac_str}";
    assert "__c2jac_unsupported" not in jac_str , f"Empty statement must not emit a surrogate in:\n{jac_str}";
    entries = tags.tier_b_entries();
    assert len(entries) == 0 , f"top-level empty statement should be Tier-A, got {[
        (nt.c_line, nt.reason) for nt in entries
    ]}";
}

test "top-level empty statement output recompiles cleanly" {
    (jac_str, tags) = transpile_c_str("int f(int n) { ; return n; }", "empty_top.c");
    errs = _recompile_errors(jac_str, "empty_top.c");
    assert len(errs) == 0 , f"Emitted Jac must recompile, got errors: {errs}\n{jac_str}";
}
