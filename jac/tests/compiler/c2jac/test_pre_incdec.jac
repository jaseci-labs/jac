"""Pre/post increment-decrement lowering in EXPRESSION position.

Statement-position `i++;` / `--i;` already lowered to augmented assignments
(test_p1d). This file pins the EXPRESSION-position behaviour:

  * prefix  `++x` / `--x` → Jac walrus `(x := x ± 1)` — the prefix value IS the
    new value, exactly what `:=` yields, so it is a faithful Tier-A lowering.
    Restricted to a bare-ID operand (Jac's `:=` target must be a plain Name).
  * postfix `x++` / `x--` use the OLD value yet still mutate — no faithful
    single-expression form exists, so they stay Tier-B surrogates.
  * `--a[i]` / `--p->f` (non-Name targets) can't be a walrus target → Tier-B.
"""

import from jaclang.compiler.c2jac.driver { transpile_c_str }
import from jaclang.compiler.c2jac.tags { Idiom, Tier }
import from jaclang.compiler.c2jac.c_common { UNSUPPORTED_EXPR }

def _transpile(src: str) -> tuple {
    return transpile_c_str(src, "test.c");
}

def _tier_b_reasons(tags: object) -> list {
    return [nt.reason for nt in tags.tier_b_entries()];
}

# --- prefix: faithful walrus lowering --------------------------------------
test "pre-decrement in a condition lowers to a walrus and is Tier-A" {
    (jac_str, tags) = _transpile("int f(int n) { while (--n > 0) { } return n; }");
    assert "n := (n - 1)" in jac_str , f"expected `--n` → walrus in:\n{jac_str}";
    assert UNSUPPORTED_EXPR not in jac_str , f"no surrogate expected:\n{jac_str}";
    assert _tier_b_reasons(tags) == [] , f"expected fully Tier-A, got: {_tier_b_reasons(
        tags
    )}";
}

test "pre-increment as a returned expression lowers to a walrus and is Tier-A" {
    (jac_str, tags) = _transpile("int f(int n) { return ++n; }");
    assert "n := (n + 1)" in jac_str , f"expected `++n` → walrus in:\n{jac_str}";
    assert UNSUPPORTED_EXPR not in jac_str , f"no surrogate expected:\n{jac_str}";
    assert _tier_b_reasons(tags) == [] , f"expected fully Tier-A, got: {_tier_b_reasons(
        tags
    )}";
}

test "pre-inc/dec expression is tagged with the PRE_INCDEC idiom at Tier-A" {
    (jac_str, tags) = _transpile("int f(int n) { return ++n; }");
    pre = tags.by_idiom(Idiom.PRE_INCDEC);
    assert len(pre) == 1 , f"expected one PRE_INCDEC site, got {len(pre)}";
    assert pre[0].tier == Tier.TIER_A , f"PRE_INCDEC must be Tier-A, got {pre[0].tier}";
}

# --- postfix + non-Name targets: honestly Tier-B --------------------------
test "post-increment in expression position stays Tier-B (old value used)" {
    # `return n++` returns the OLD value but still mutates n — no faithful
    # single Jac expression captures that, so it must surface as a surrogate.
    (jac_str, tags) = _transpile("int f(int n) { return n++; }");
    assert UNSUPPORTED_EXPR in jac_str , f"expected a surrogate for `n++`:\n{jac_str}";
    reasons = _tier_b_reasons(tags);
    assert len(reasons) == 1 , f"expected exactly one Tier-B site, got: {reasons}";
}

test "pre-decrement of a non-Name target stays Tier-B" {
    # `--a[0]` — the operand is an ArrayRef, not a bare ID, so it can't be a
    # walrus target. Must fall back to a surrogate rather than mis-lowering.
    (jac_str, tags) = _transpile("int f(int *a) { return --a[0]; }");
    assert UNSUPPORTED_EXPR in jac_str , f"expected a surrogate for `--a[0]`:\n{jac_str}";
    assert _tier_b_reasons(tags) != [] , "non-Name pre-dec must stay Tier-B";
}

test "pre-increment of a pointer stays Tier-B (pointer arithmetic, not +1)" {
    # `++p` on an `int *` advances by sizeof(int) bytes — pointer arithmetic,
    # NOT an integer `+1`. Lowering to `p := p + 1` would mis-model it, so it
    # must surface a surrogate and earn NO PRE_INCDEC Tier-A tag.
    (jac_str, tags) = _transpile("int f(int *p) { return ++p; }");
    assert UNSUPPORTED_EXPR in jac_str , f"expected a surrogate for pointer `++p`:\n{jac_str}";
    assert _tier_b_reasons(tags) != [] , "pointer `++p` must stay Tier-B";
    assert tags.by_idiom(Idiom.PRE_INCDEC) == [] , "pointer ++ must not earn PRE_INCDEC";
}

test "pre-increment of a char stays Tier-B (char maps to str, not a number)" {
    # `char` resolves to Jac `str`; `c := c + 1` is not a faithful model of
    # C's integer char arithmetic, so it must not be Tier-A.
    (jac_str, tags) = _transpile("int f(char c) { return ++c; }");
    assert UNSUPPORTED_EXPR in jac_str , f"expected a surrogate for char `++c`:\n{jac_str}";
    assert tags.by_idiom(Idiom.PRE_INCDEC) == [] , "char ++ must not earn PRE_INCDEC";
}

# --- round-trip: emitted Jac is valid compiler input -----------------------
test "walrus-lowered pre-inc/dec recompiles cleanly" {
    (jac_str, tags) = _transpile("int f(int n) { while (--n > 0) { } return n; }");
    import from jaclang.jac0core.program { JacProgram }
    prog = JacProgram();
    prog.compile(use_str=jac_str, file_path="emitted.jac");
    assert prog.errors_had == [] , f"emitted Jac must recompile:\n{jac_str}";
}
