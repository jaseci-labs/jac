"""§(#14) C-form → tier/lowering compatibility matrix.

A table-driven characterization test: each row pins how one C form is currently
transpiled (the substrings that must / must not appear) and its tier (Tier-A
rows must produce no Tier-B tag and no `__c2jac_unsupported` surrogate). It keeps
every COVERAGE_ROADMAP item honest — a row's expectation flips the moment the
matching fix lands, so behavior changes can never slip in silently.

Rows tagged `# CHARACTERIZES BUG` lock *current, known-wrong* output on purpose
(so the suite stays green today); when the referenced roadmap item is fixed, the
row's `want`/`deny` must be updated in the same change.
"""

import from jaclang.compiler.c2jac.driver { transpile_c_str }

# One row per C form. Fields:
#   label — short id (also the synthetic filename stem)
#   src   — inline C translation unit
#   want  — substrings that MUST appear in the emitted Jac
#   deny  — substrings that must NOT appear
#   tier  — "A": expect zero Tier-B tags + no surrogate; "B": expect a surrogate
glob _MATRIX: list[dict] = [
         # -- integer-family normalization (#2) — currently correct via names[-1] -- #
         {
             "label": "unsigned_long",
             "src": "unsigned long g(unsigned long x){ return x; }",
             "want": ["def g(x: int) -> int"],
             "deny": [],
             "tier": "A",

         },
         {
             "label": "long_long",
             "src": "long long ll(short s){ return s; }",
             "want": ["def ll(s: int) -> int"],
             "deny": [],
             "tier": "A",

         },
         # -- const char * string APIs (#4) — already first-class -------------------- #
         {
             "label": "const_char_ptr_param",
             "src": "int n(const char *s){ return 0; }",
             "want": ["def n(s: str) -> int"],
             "deny": [],
             "tier": "A",

         },
         {
             "label": "const_char_ptr_ret",
             "src": "const char *get(void){ return \"hi\"; }",
             "want": ["def get() -> str", "return \"hi\""],
             "deny": [],
             "tier": "A",

         },
         # -- register storage-class (#1) — already lowers as a no-op ---------------- #
         {
             "label": "register_noop",
             "src": "int f(void){ register int x = 5; return x; }",
             "want": ["x: int = 5"],
             "deny": [],
             "tier": "A",

         },
         # -- const / volatile qualifiers (#6) — intent dropped, codegen clean ------- #
         {
             "label": "const_qual",
             "src": "const int CI = 3;",
             "want": ["CI: int = 3"],
             "deny": [],
             "tier": "A",

         },
         # -- int-family (#2): unsigned/signed char are byte-numeric → `int` --------- #
         # (Plain `char` stays `str`; only the signed/unsigned forms are numeric.)      #
         {
             "label": "unsigned_char",
             "src": "int uc(unsigned char c){ return c; }",
             "want": ["c: int"],
             "deny": ["c: str"],
             "tier": "A",

         },
         {
             "label": "signed_char",
             "src": "int sc(signed char c){ return c; }",
             "want": ["c: int"],
             "deny": ["c: str"],
             "tier": "A",

         },
         {
             "label": "plain_char",
             "src": "int pc(char c){ return c; }",
             "want": ["c: str"],
             "deny": ["c: int"],
             "tier": "A",

         },
         # -- char-pointer resolution: plain `char *` is a C string, but the signed/ -- #
         # unsigned byte-buffer forms are not — and must not leak a bare `char` type.   #
         {
             "label": "char_ptr",
             "src": "int f(char *p){ return 0; }",
             "want": ["p: str"],
             "deny": [],
             "tier": "A",

         },
         {
             "label": "unsigned_char_ptr",
             "src": "int f(unsigned char *p){ return 0; }",
             "want": ["p: object"],
             "deny": ["p: char", "p: str"],
             "tier": "A",

         },
         # -- suffixed literals (#13): u/U/l/L suffix is stripped before parsing ------ #
         # parse_c_int retries with the suffix removed, so `10L` lowers to `10`.        #
         {
             "label": "suffix_literal",
             "src": "long big = 10L;",
             "want": ["big: int = 10"],
             "deny": ["10L"],
             "tier": "A",

         },

     ];

test "c-form compatibility matrix" {
    failures: list[str] = [];
    for row in _MATRIX {
        (js, tags) = transpile_c_str(row["src"], f"{row['label']}.c");
        for w in row["want"] {
            if w not in js {
                failures.append(f"[{row['label']}] missing {repr(w)} in:\n{js}");
            }
        }
        for d in row["deny"] {
            if d in js {
                failures.append(f"[{row['label']}] unexpected {repr(d)} in:\n{js}");
            }
        }
        if row["tier"] == "A" {
            tb = tags.tier_b_entries();
            if len(tb) != 0 {
                failures.append(
                    f"[{row['label']}] expected Tier-A but got Tier-B sites: {[
                        t.reason for t in tb
                    ]}"
                );
            }
            if "__c2jac_unsupported" in js {
                failures.append(
                    f"[{row['label']}] expected Tier-A but found surrogate in:\n{js}"
                );
            }
        } else {
            if "__c2jac_unsupported" not in js {
                failures.append(
                    f"[{row['label']}] expected Tier-B surrogate, none in:\n{js}"
                );
            }
        }
    }
    assert not failures , "\n\n".join(failures);
}
