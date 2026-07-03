"""§(#14) C-form → tier/lowering compatibility matrix.

A characterization suite: each row pins how one C form is currently transpiled
(the substrings that must / must not appear) and its tier (Tier-A rows must
produce no Tier-B tag and no `__c2jac_unsupported` surrogate). It keeps every
covered C form honest — a row's expectation flips the moment the matching
fix lands, so behavior changes can never slip in silently.

Packaging: the rows live in the `_MATRIX` table (keyed by label), but each row is
asserted by its **own** `test` block below — not one loop over the whole table —
so a CI failure names the exact C form that regressed instead of collapsing ~24
forms into a single opaque traceback. The shared `check(label)` helper holds the
per-row logic so the per-row tests stay one-liners. The `matrix_coverage` guard
fails if a row is added to `_MATRIX` without a dedicated test (keep `_COVERED` in
sync with the `test` blocks).

Rows whose comment notes a *known-wrong* current output lock that output on
purpose (so the suite stays green today); when the referenced roadmap item is
fixed, the row's `want`/`deny` must be updated in the same change.
"""

import from jaclang.compiler.c2jac.driver { transpile_c_str }

# One entry per C form, keyed by label (also the synthetic filename stem). Fields:
#   src   — inline C translation unit
#   want  — substrings that MUST appear in the emitted Jac
#   deny  — substrings that must NOT appear
#   tier  — "A":  zero Tier-B tags + no surrogate (faithful)
#           "Bf": faithful best-effort — >=1 Tier-B tag but NO surrogate (emitted
#                 form is valid, the lost semantics are only flagged in comments)
#           "B":  surrogate-backed best-effort (a __c2jac_unsupported marker)
glob _MATRIX: dict[str, dict] = {
         # -- integer-family normalization (#2) — currently correct via names[-1] -- #
         "unsigned_long": {
             "src": "unsigned long g(unsigned long x){ return x; }",
             "want": ["def g(x: int) -> int"],
             "deny": [],
             "tier": "A",

         },
         "long_long": {
             "src": "long long ll(short s){ return s; }",
             "want": ["def ll(s: int) -> int"],
             "deny": [],
             "tier": "A",

         },
         # -- const char * string APIs (#4) — already first-class -------------------- #
         "const_char_ptr_param": {
             "src": "int n(const char *s){ return 0; }",
             "want": ["def n(s: str) -> int"],
             "deny": [],
             "tier": "A",

         },
         "const_char_ptr_ret": {
             "src": "const char *get(void){ return \"hi\"; }",
             "want": ["def get() -> str", "return \"hi\""],
             "deny": [],
             "tier": "A",

         },
         # A null-pointer constant returned from a pointer-typed function is NULL —
         # lower it to Jac `None`, not the integer literal 0 (the return annotation
         # is str/object, so a bare `return 0` would be type-mismatched).
         "null_char_ptr_ret": {
             "src": "const char *s(void){ return 0; }",
             "want": ["def s() -> str", "return None"],
             "deny": ["return 0"],
             "tier": "A",

         },
         "null_int_ptr_ret": {
             "src": "int *p(void){ return 0; }",
             "want": ["def p() -> object", "return None"],
             "deny": ["return 0"],
             "tier": "A",

         },
         # An integer 0 returned from a NON-pointer function is a genuine 0 — the
         # pointer-context lowering must not over-fire and rewrite it to None.
         "zero_int_ret": {
             "src": "int z(void){ return 0; }",
             "want": ["def z() -> int", "return 0"],
             "deny": ["return None"],
             "tier": "A",

         },
         # -- register storage-class (#1) — already lowers as a no-op ---------------- #
         "register_noop": {
             "src": "int f(void){ register int x = 5; return x; }",
             "want": ["x: int = 5"],
             "deny": [],
             "tier": "A",

         },
         # -- const / volatile qualifiers (#6) — intent dropped, codegen clean ------- #
         "const_qual": {
             "src": "const int CI = 3;",
             "want": ["CI: int = 3"],
             "deny": [],
             "tier": "A",

         },
         # -- int-family (#2): unsigned/signed char are byte-numeric → `int` --------- #
         # (Plain `char` stays `str`; only the signed/unsigned forms are numeric.)      #
         "unsigned_char": {
             "src": "int uc(unsigned char c){ return c; }",
             "want": ["c: int"],
             "deny": ["c: str"],
             "tier": "A",

         },
         "signed_char": {
             "src": "int sc(signed char c){ return c; }",
             "want": ["c: int"],
             "deny": ["c: str"],
             "tier": "A",

         },
         "plain_char": {
             "src": "int pc(char c){ return c; }",
             "want": ["c: str"],
             "deny": ["c: int"],
             "tier": "A",

         },
         # -- char-pointer resolution: plain `char *` is a C string, but the signed/ -- #
         # unsigned byte-buffer forms are not — and must not leak a bare `char` type.   #
         "char_ptr": {
             "src": "int f(char *p){ return 0; }",
             "want": ["p: str"],
             "deny": [],
             "tier": "A",

         },
         "unsigned_char_ptr": {
             "src": "int f(unsigned char *p){ return 0; }",
             "want": ["p: object"],
             "deny": ["p: char", "p: str"],
             "tier": "A",

         },
         # -- suffixed literals (#13): u/U/l/L suffix is stripped before parsing ------ #
         # parse_c_int retries with the suffix removed, so `10L` lowers to `10`.        #
         "suffix_literal": {
             "src": "long big = 10L;",
             "want": ["big: int = 10"],
             "deny": ["10L"],
             "tier": "A",

         },
         # -- storage class (#5): extern w/o init is a pure declaration → no-op ------- #
         "extern_noop": {
             "src": "extern int ctr; int use(void){ return 0; }",
             "want": ["def use() -> int"],
             "deny": ["ctr"],
             "tier": "A",

         },
         # extern WITH an initializer is itself the definition → emitted faithfully.
         "extern_with_init": {
             "src": "extern int e = 7;",
             "want": ["e: int = 7"],
             "deny": [],
             "tier": "A",

         },
         # File-scope static is just a module var — no semantic loss.
         "static_global": {
             "src": "static int s = 4;",
             "want": ["s: int = 4"],
             "deny": [],
             "tier": "A",

         },
         # Function-local static loses cross-call persistence: emitted as a plain
         # local (best-effort) and flagged Tier-B, never silently dropped.
         "static_local": {
             "src": "int f(void){ static int n = 0; return n; }",
             "want": ["n: int = 0", "function-local 'static'"],
             "deny": ["__c2jac_unsupported"],
             "tier": "Bf",

         },
         # -- static storage duration (#2): C zero-initializes file-scope and ------- #
         # `static` objects, so an uninitialized decl must carry that guarantee.       #
         "uninit_global_int": {
             "src": "int g;",
             "want": ["g: int = 0"],
             "deny": [],
             "tier": "A",

         },
         # Uninitialized file-scope pointer → NULL → None.
         "uninit_global_ptr": {
             "src": "int *p;",
             "want": ["p: object = None"],
             "deny": [],
             "tier": "A",

         },
         # Uninitialized function-local static: zero-initialized AND flagged for the
         # lost cross-call persistence (#2 + #5).
         "uninit_static_local": {
             "src": "int f(void){ static int n; return n; }",
             "want": ["n: int = 0", "function-local 'static'"],
             "deny": ["__c2jac_unsupported"],
             "tier": "Bf",

         },
         # An automatic (non-static) local is genuinely indeterminate in C, so it
         # stays annotation-only — no synthesized zero.
         "uninit_auto_local": {
             "src": "int f(void){ int x; return x; }",
             "want": ["x: int"],
             "deny": ["x: int = 0"],
             "tier": "A",

         },
         # -- qualifiers (#6): only volatile carries semantics Jac can't express ------ #
         # `volatile` is emitted faithfully but flagged Bf; `const` (above) and
         # `restrict` stay Tier-A as benign drops (restrict is an aliasing /
         # optimization contract for the C optimizer, not a runtime op).
         "volatile_var": {
             "src": "volatile int v = 1;",
             "want": ["v: int = 1", "'volatile' qualifier dropped"],
             "deny": ["__c2jac_unsupported"],
             "tier": "Bf",

         },
         "restrict_ptr": {
             "src": "int *restrict rp;",
             "want": ["rp: object = None"],
             "deny": ["__c2jac_unsupported"],
             "tier": "A",

         },
         # Variadic `...` (#9): the declaration maps to a Jac `*args` so the
         # signature stays callable. When the body ignores the extra args (as
         # here), `*args` models the C exactly → Tier-A; only a body that reaches
         # into the varargs is flagged. Must NOT crash or be dropped.
         "variadic": {
             "src": "int log_many(const char *fmt, ...){ return 0; }",
             "want": ["*args"],
             "deny": ["__c2jac_unsupported"],
             "tier": "A",

         },
         # A variadic body that DOES reach into the varargs — declares a `va_list`
         # and calls `va_start`/`va_end` — cannot be modelled by `*args`, so it
         # stays Tier-B (flagged, never dropped). (`va_list` is typedef'd inline
         # because transpile_c_str gets no <stdarg.h>; the `va_arg(ap, int)` form
         # is omitted — its type-argument is unparseable without fake-libc macros.)
         "variadic_va_arg": {
             "src": "typedef int va_list; int sum_n(int n, ...){ va_list ap; va_start(ap, n); va_end(ap); return n; }",
             "want": ["*args", "variadic `...` lowered to Jac `*args`"],
             "deny": ["__c2jac_unsupported"],
             "tier": "Bf",

         },

     },
     # Labels that have a dedicated `test` block below. The `matrix_coverage` guard
     # asserts this equals `_MATRIX`'s keys, so a new row can't be added without also
     # adding a test (and vice-versa).
     _COVERED: set = {
         "unsigned_long",
         "long_long",
         "const_char_ptr_param",
         "const_char_ptr_ret",
         "null_char_ptr_ret",
         "null_int_ptr_ret",
         "zero_int_ret",
         "register_noop",
         "const_qual",
         "unsigned_char",
         "signed_char",
         "plain_char",
         "char_ptr",
         "unsigned_char_ptr",
         "suffix_literal",
         "extern_noop",
         "extern_with_init",
         "static_global",
         "static_local",
         "uninit_global_int",
         "uninit_global_ptr",
         "uninit_static_local",
         "uninit_auto_local",
         "volatile_var",
         "restrict_ptr",
         "variadic",
         "variadic_va_arg",

     };

def check(label: str) -> list[str] {
    # Transpile one row's C source and collect every expectation it violates
    # (empty list ⇒ the form lowers exactly as pinned). Shared by all the per-row
    # tests so each stays a one-liner and the matrix logic lives once.
    row = _MATRIX[label];
    failures: list[str] = [];
    (js, tags) = transpile_c_str(row["src"], f"{label}.c");
    for w in row["want"] {
        if w not in js {
            failures.append(f"[{label}] missing {repr(w)} in:\n{js}");
        }
    }
    for d in row["deny"] {
        if d in js {
            failures.append(f"[{label}] unexpected {repr(d)} in:\n{js}");
        }
    }
    tb = tags.tier_b_entries();
    surrogate = "__c2jac_unsupported" in js;
    tier = row["tier"];
    if tier == "A" {
        if len(tb) != 0 {
            failures.append(
                f"[{label}] expected Tier-A but got Tier-B sites: {[
                    t.reason for t in tb
                ]}"
            );
        }
        if surrogate {
            failures.append(f"[{label}] expected Tier-A but found surrogate in:\n{js}");
        }
    } elif tier == "Bf" {
        if len(tb) == 0 {
            failures.append(
                f"[{label}] expected a faithful Tier-B tag, none recorded in:\n{js}"
            );
        }
        if surrogate {
            failures.append(
                f"[{label}] expected faithful Tier-B (no surrogate) but found one in:\n{js}"
            );
        }
    } else {
        if not surrogate {
            failures.append(f"[{label}] expected Tier-B surrogate, none in:\n{js}");
        }
    }
    return failures;
}

# --- aggregate faithfulness gate (#6) ----------------------------------------- #
# The per-row tests pin each form individually, but nothing stops the corpus as a
# whole from drifting Tier-B: add a feature lazily as best-effort, flip its row to
# "Bf"/"B", and every test stays green while the transpiler quietly gets less
# faithful. These floors aggregate the *actual emitted tags* (never the declared
# `tier` literal — that would be circular) across the whole `_MATRIX` corpus, so a
# net loss of faithfulness fails CI. They are a one-way ratchet: lowering either
# floor is an explicit, reviewed line in the diff that says "we are now less
# faithful than before" — that is the point, it makes the honesty load-bearing.
#
# Two ratios, because they catch different drift:
#   node ratio — fraction of all input C-AST nodes that lowered faithfully (no
#                recorded Tier-B loss; see TagTable.tier_counts). Coarse:
#                dominated by trivially-recognized leaves, so it mostly catches
#                large-scale regressions (a whole construct family going Tier-B).
#   form ratio — fraction of corpus forms that emit ZERO Tier-B tags. Sensitive:
#                a single A->Bf downgrade or one new lossy form drops it, which is
#                exactly the slow drift the per-row tests can't see.
# When a floor trips: either restore faithfulness, or, if the downgrade is
# genuinely intended, lower the floor here in the same change and say why.
glob _TIER_A_NODE_FLOOR: float = 0.97,
     _TIER_A_FORM_FLOOR: float = 0.78;

test "matrix_faithfulness_floor" {
    total_nodes = 0;
    tier_a_nodes = 0;
    faithful_forms = 0;
    for label in _MATRIX.keys() {
        (js, tags) = transpile_c_str(_MATRIX[label]["src"], f"{label}.c");
        stats = tags.tier_counts();
        total_nodes += stats.total;
        tier_a_nodes += stats.tier_a;
        # A form is "faithful" iff it emits no Tier-B tag at all (matches the
        # Tier-A contract in `check`): surrogate-backed and best-effort both count
        # against it.
        if len(tags.tier_b_entries()) == 0 {
            faithful_forms += 1;
        }
    }
    node_ratio = tier_a_nodes / total_nodes if total_nodes else 1.0;
    form_ratio = faithful_forms / len(_MATRIX) if _MATRIX else 1.0;
    assert node_ratio >= _TIER_A_NODE_FLOOR , f"Tier-A node ratio {node_ratio:.4f} "
    f"({tier_a_nodes}/{total_nodes}) fell below floor {_TIER_A_NODE_FLOOR}. "
    f"Restore faithfulness, or lower _TIER_A_NODE_FLOOR in the same change "
    f"and justify the regression.";
    assert form_ratio >= _TIER_A_FORM_FLOOR , f"Faithful-form ratio {form_ratio:.4f} "
    f"({faithful_forms}/{len(_MATRIX)} forms emit zero Tier-B tags) fell "
    f"below floor {_TIER_A_FORM_FLOOR}. A form was downgraded to best-effort "
    f"or a new lossy form was added. Restore faithfulness, or lower "
    f"_TIER_A_FORM_FLOOR in the same change and justify the regression.";
}

# Guard: every matrix row must have a dedicated test, and every covered label must
# still be a real row. Keeps the per-row suite exhaustive as rows come and go.
test "matrix_coverage" {
    rows: set = set(_MATRIX.keys());
    missing_test: set = rows - _COVERED;
    stale_test: set = _COVERED - rows;
    assert not missing_test and not stale_test , f"matrix rows without a dedicated test: {missing_test}; "
    f"_COVERED labels with no matching row: {stale_test}";
}

# --- one test per C form (a regression names the exact form that broke) ------- #
# integer-family normalization (#2)
test "matrix_unsigned_long" {
    fails = check("unsigned_long");
    assert not fails , "\n\n".join(fails);
}

test "matrix_long_long" {
    fails = check("long_long");
    assert not fails , "\n\n".join(fails);
}

# const char * string APIs (#4)
test "matrix_const_char_ptr_param" {
    fails = check("const_char_ptr_param");
    assert not fails , "\n\n".join(fails);
}

test "matrix_const_char_ptr_ret" {
    fails = check("const_char_ptr_ret");
    assert not fails , "\n\n".join(fails);
}

# null-pointer constant returned from a pointer-typed function → None
test "matrix_null_char_ptr_ret" {
    fails = check("null_char_ptr_ret");
    assert not fails , "\n\n".join(fails);
}

test "matrix_null_int_ptr_ret" {
    fails = check("null_int_ptr_ret");
    assert not fails , "\n\n".join(fails);
}

test "matrix_zero_int_ret" {
    fails = check("zero_int_ret");
    assert not fails , "\n\n".join(fails);
}

# register storage-class (#1)
test "matrix_register_noop" {
    fails = check("register_noop");
    assert not fails , "\n\n".join(fails);
}

# const qualifier (#6)
test "matrix_const_qual" {
    fails = check("const_qual");
    assert not fails , "\n\n".join(fails);
}

# char-family int normalization (#2)
test "matrix_unsigned_char" {
    fails = check("unsigned_char");
    assert not fails , "\n\n".join(fails);
}

test "matrix_signed_char" {
    fails = check("signed_char");
    assert not fails , "\n\n".join(fails);
}

test "matrix_plain_char" {
    fails = check("plain_char");
    assert not fails , "\n\n".join(fails);
}

# char-pointer resolution
test "matrix_char_ptr" {
    fails = check("char_ptr");
    assert not fails , "\n\n".join(fails);
}

test "matrix_unsigned_char_ptr" {
    fails = check("unsigned_char_ptr");
    assert not fails , "\n\n".join(fails);
}

# suffixed literals (#13)
test "matrix_suffix_literal" {
    fails = check("suffix_literal");
    assert not fails , "\n\n".join(fails);
}

# storage class (#5)
test "matrix_extern_noop" {
    fails = check("extern_noop");
    assert not fails , "\n\n".join(fails);
}

test "matrix_extern_with_init" {
    fails = check("extern_with_init");
    assert not fails , "\n\n".join(fails);
}

test "matrix_static_global" {
    fails = check("static_global");
    assert not fails , "\n\n".join(fails);
}

test "matrix_static_local" {
    fails = check("static_local");
    assert not fails , "\n\n".join(fails);
}

# static storage duration zero-init (#2)
test "matrix_uninit_global_int" {
    fails = check("uninit_global_int");
    assert not fails , "\n\n".join(fails);
}

test "matrix_uninit_global_ptr" {
    fails = check("uninit_global_ptr");
    assert not fails , "\n\n".join(fails);
}

test "matrix_uninit_static_local" {
    fails = check("uninit_static_local");
    assert not fails , "\n\n".join(fails);
}

test "matrix_uninit_auto_local" {
    fails = check("uninit_auto_local");
    assert not fails , "\n\n".join(fails);
}

# volatile (Bf) / restrict (Tier-A) qualifiers (#6)
test "matrix_volatile_var" {
    fails = check("volatile_var");
    assert not fails , "\n\n".join(fails);
}

test "matrix_restrict_ptr" {
    fails = check("restrict_ptr");
    assert not fails , "\n\n".join(fails);
}

# variadic functions (#9)
test "matrix_variadic" {
    fails = check("variadic");
    assert not fails , "\n\n".join(fails);
}

test "matrix_variadic_va_arg" {
    fails = check("variadic_va_arg");
    assert not fails , "\n\n".join(fails);
}

# --- direct-IR slot protocol (c2jac.directir) --------------------------------- #
# `for` and `enum` have no faithful CPython-`ast` shape, so the mapper emits a
# placeholder that the driver splices away (see c2jac.directir). This locks the
# end-to-end invariant the protocol rests on: NO `__c2jac_directir__` sentinel may
# survive into emitted Jac. If a future change broke the py-ast round-trip, the
# driver's post-splice guard would raise here instead of leaking the sentinel —
# the guarantee is enforced and tested, not riding on convention.
test "directir_no_leak" {
    for_src = "int sum(int n){ int t = 0; for (int i = 0; i < n; i++){ t += i; } return t; }";
    enum_src = "enum Color { RED, GREEN, BLUE };";
    (for_js, _) = transpile_c_str(for_src, "directir_for.c");
    (enum_js, _) = transpile_c_str(enum_src, "directir_enum.c");
    # The placeholder must be fully spliced out of both outputs...
    assert "__c2jac_directir__" not in for_js , for_js;
    assert "__c2jac_directir__" not in enum_js , enum_js;
    # ...and the real lowered forms must be present (the splice ran, not just a
    # silent drop): a Jac `for` iterator and the enum constants.
    assert "for " in for_js , for_js;
    assert "RED" in enum_js and "GREEN" in enum_js and "BLUE" in enum_js , enum_js;
}
