# c2jac Coverage Roadmap - Effort Ranking

Status of the advanced-C frontier, ordered **simplest → hardest** to implement.
Today's baseline: a Tier-A core (functions, control flow incl. switch/do-while/
ternary, structs, enums, basic typedefs, 1-D arrays, malloc pointer idioms) with
a Tier-B surrogate fallback for everything else. Everything below is currently
either dropped silently or emitted as a `__c2jac_unsupported__` surrogate.

Effort scale: **XS** (a few lines) · **S** (one handler/util) · **M** (new pass
or cross-cutting change) · **L** (new subsystem) · **XL** (semantic model work).

---

## Tier 1 - Simplest

### 1. `register` keyword as recognized no-op - XS ✅ DONE

`register` is read off `Decl.storage` and ignored (no surrogate, Tier-A) - it is
not in the static/extern/volatile/restrict classification set added for #5/#6,
so it falls through to the normal emit. Locked by `register_noop` in
`test_compat_matrix.jac`.

### 2. Better integer-family normalization - S ✅ DONE

`_C_PRIM_MAP` (`mapper.jac`) collapses `long/short/unsigned/signed`→`int`.
Multi-word names already normalized via `names[-1]`, but `unsigned char` /
`signed char` wrongly resolved to `str`. Fixed: `_jac_prim(names)` special-cases
char-family (plain `char`→`str`, `signed/unsigned char`→`int`); `_prim_typename`
and `_ptr_typename` both route through it. Also added the missing `char` to
`_C_BUILTIN_TYPES` so `unsigned char *` resolves to `object` (byte buffer) rather
than leaking a bare `char` type. Locked by `test_compat_matrix.jac`.

### 3. Expression precedence / parenthesization audit - S

Add a focused test suite asserting grouping survives round-trip for every
supported operator; fix any AST-shape mismatches found. Mostly verification, not
new lowering.

### 4. `const char *` string APIs as first-class - S ✅ DONE

`const char *` params/returns already resolve to `str` (the `char`-family check
in `_jac_prim`/`_ptr_typename` ignores the `const` qualifier). Locked by
`const_char_ptr_param` / `const_char_ptr_ret` in `test_compat_matrix.jac`.

---

## Tier 1 - Moderate

### 5. static / extern storage-class classification - S→M ✅ DONE

`c_Decl` now reads `nd.storage`. `extern` with no initializer → no-op `return []`
(like the FuncDecl prototype path); `extern` WITH an initializer falls through as
a definition. File-scope `static` is unchanged (already a module var, Tier-A).
**Function-local `static`** is detected via a new `_func_depth` counter (bumped
around the function-body build in `c_FuncDef`): emitted as a best-effort
re-initialized local and flagged Tier-B for the lost cross-call persistence.
Locked by `extern_noop` / `extern_with_init` / `static_global` / `static_local`
in `test_compat_matrix.jac`.

### 6. const / volatile / restrict qualifier handling - S→M ✅ DONE

`c_Decl` collects qualifiers from the whole decl type chain via `_all_quals`
(`const`/`volatile` may sit on the Decl or the pointed-to TypeDecl; `restrict`
lives on the PtrDecl, so reading `nd.quals` alone misses `int * restrict p`).
`const` is a benign drop (value semantics preserved, immutability advisory) →
Tier-A. `volatile` (no read-cache suppression) and `restrict` (no-alias) carry
real semantics Jac can't express → emitted faithfully but flagged Tier-B, never
surrogated. Locked by `const_qual` / `volatile_var` / `restrict_ptr` in
`test_compat_matrix.jac`.

### 7. `typedef enum/struct Name;` edge forms - M

Extend `c_Typedef` (`mapper.jac:1120`) beyond `typedef struct {…} Name` and
scalar alias: handle tag-reference typedefs, forward typedefs, and
`typedef enum {…} Name`. Interacts with declaration-vs-definition (#10).

### 8. Multi-dimensional arrays + indexing - M

`_decl_array` (`mapper.jac:1171`) only does 1-D `T[]→list[T]`. Recurse on nested
`ArrayDecl` to build `list[list[T]]` and the nested default initializer; extend
`ArrayRef` lowering for `a[i][j]`. Self-contained but fiddly.

### 9. Variadic functions (printf-style) - M ◑ PARTIAL

Decl-level done: `c_FuncDef` detects `EllipsisParam` in the param list and emits
a Jac `*args` vararg, flagging the function Tier-B (was previously crashing the
whole transpilation with `'EllipsisParam' object has no attribute 'name'`).
Locked by `variadic` in `test_compat_matrix.jac`. Still open: faithful call-site
lowering and `va_list`/`va_arg` bodies (Tier-B for now).

### 10. Declaration vs definition classifier - M

A dedicated shape pass: var / func / typedef / tag / forward-decl /
storage-qualified / qualified-pointer. Replaces the inline branching in `c_Decl`.
Unblocks #5, #6, #7 doing the right thing per shape.

---

## Tier 1 - Hardest

### 11. Anonymous structs/unions embedded in named structs - M→L

Needs name synthesis for the anonymous member and field-access rewriting so outer
accessors reach inner fields. `Union` isn't even in the Tier-A allowlist yet -
add union support first.

### 12. Function-pointer decls + callback call sites - L

Currently a flat surrogate (`mapper.jac:414`). Structured support needs a
callable-type representation and call-site rewriting - high payoff (unlocks many
C APIs) but a genuine subsystem.

---

## Compiler-engineering foundations (cross-cutting)

### 13. Shared constant-folding utility - S→M (partial)

Extract the per-site folding (enum_prepass; malloc factor folding at
`mapper.jac:934`) into one util used by enum values, array sizes, and
initializers. Small surface, broad reuse. **Do early** - #2, #7, #8 all want it.
*Seed done:* `parse_c_int`/`parse_c_float` (`c_common.jac`) now strip C literal
suffixes (`10L`→`10`, `5U`→`5`, `1.5f`→`1.5`), and `c_Constant` matches the
widened pycparser type names (`long int`, `unsigned int`, `long double`) and
stamps the parsed value so suffixes no longer leak into emitted Jac. The broader
fold-extraction (array sizes, initializer arithmetic) is still open.

### 14. Tier-1/2/unsupported compatibility matrix in tests - S

A table-driven test asserting each C form's tier. Cheap, and it keeps every item
above honest as it lands. **Do early.**

### 15. Canonical internal C type model - XL

The big one. Type logic is ad-hoc today (`_C_PRIM_MAP`, `_typename`,
`_resolve_*` scattered in `mapper.jac`). A real type model makes #2, #6, #8, #11,

# 12 dramatically cleaner - but it's the largest single piece and best done once

a few of the above expose the requirements.

---

## Tier 2 (lower priority - best-effort metadata)

Roughly easiest → hardest: `inline` no-op (XS) · `__attribute__` capture
post-preprocess (S) · `#pragma` recording in sidecar (S, preprocessor change) ·
K&R old-style decls (S) · hex floats / wide-char literal variants (S) ·
`_Bool`/`_Complex`/`_Imaginary` classification (S→M) · asm / inline-asm
detection + reporting (M) · `_Alignof`/`_Alignas`/packing (M) · flexible array
members (M) · `offsetof` and layout-sensitive macro idioms (M→L) ·
`sizeof` semantic distinctions function/array/pointer (M).

---

## Suggested order

1. **#14 compatibility matrix** + **#13 const-fold util** - cheap foundations.
2. **#2 int normalization**, **#5 storage classes**, **#6 qualifiers** - high
   value, currently *silently wrong*, not just unsupported.
3. **#10 decl/def classifier** → unblocks #7.
4. **#8 multi-dim arrays**, **#7 typedef edges**, **#9 variadics** - discrete wins.
5. **#15 type model** once requirements are clear, then **#11 anon structs** and
   **#12 function pointers** on top of it.
