# Review B — JAC Code Quality (c2jac package)

Scope: `jac/jaclang/compiler/c2jac/` on branch `jac-python` vs merge-base `upstream/main`.
Focus only: bloat, brittleness, type-safety, maintainability (per CONTRIBUTING "No Scaffolding", "Type Safety", "Check for Bloat"). Vendored pycparser ignored.

Format per finding: **severity** · `file:line` · issue · fix.

---

## TYPE SAFETY

The package is exemplary in one place — `tags.jac` defines `enum Tier/Mechanism/Idiom` and uses them everywhere, exactly as CONTRIBUTING asks. That makes the remaining stringly-typed spots inconsistent *within the same PR*.

### 1. Stringly-typed binop `kind` dispatch — **major**

- `c_common.jac:5-24` — `C_BINOPS: dict[str, tuple[str, str]]` embeds a `kind` field as bare strings `"arith"`/`"compare"`/`"bool"`.
- `mapper.impl/expressions.impl.jac:10-14` — `c_BinaryOp` dispatches on it: `if kind == "arith" … elif kind == "compare" … else (BoolOp)`.
- This is a closed 3-value option-set matched as strings — the textbook CONTRIBUTING "use enums not bare strings" case. The trailing `else` silently routes anything-not-arith/compare into `BoolOp`, so a future mislabeled entry would misroute with no error.
- **Fix:** add `enum BinKind { ARITH, COMPARE, BOOL }` (or reuse the `compare`/`arith` distinction) and key on it; make the dispatch an exhaustive `match`/`if-elif` with no fall-through `else`.

### 2. Untyped `-> tuple` returns on multi-field results — **major**

CONTRIBUTING: "Create named types or dataclasses for complex return values instead of raw tuples." These return fully-untyped `-> tuple`:

- `c_common.jac:279` — `enumerator_value(...) -> tuple` returns `(int value, bool simple)`. Consumed in 3 modules (`enum_prepass.jac:76,143`, `bindgen.jac:411`), always destructured `(v, simple)`. A named record (e.g. `obj EnumVal { has value: int; simple: bool }`) documents the bool at every call site instead of `(v, simple)`/`(_, simple)` mysteries.
- `c_common.jac:263` — `jac_prim_zero(jac) -> tuple` returns `(value, text)`; one caller takes it as `(val, _text)`.
- `bindgen.jac:180` — `_func_signature(...) -> tuple` returns `(sig_str, is_variadic)`.
- `bindgen.jac:303` — `_collect_struct_defs(...) -> tuple` returns `(emit_defs, all_names)` — two structurally different collections stuffed in one untyped tuple.
- `_emit_extern_vars -> tuple[str, set]` (bindgen.jac:264) and `preprocess_c_collect -> tuple[str, dict]` (preprocess.jac:133) are at least element-typed but still unnamed pairs.
- **Fix:** named records for the multi-field ones (`EnumVal`, a `Signature { sig; variadic }`, a `StructDefs { emit_defs; names }`). Leave the genuine coordinate pair `coord_of -> tuple[int,int]` as-is — that's a position, not a domain value.

### 3. Bare-string Jac-primitive matching — **minor**

`jac_prim` returns `"int"/"float"/"bool"/"str"/"None"` strings, matched as bare strings across the package:

- `c_common.jac:264,267` (`jac == "float"/"bool"`), `c_idioms.jac:42` (`… in ("int","float","bool")`), `c_types.jac:60` (`jac_prim(names) == "str"`), `expressions.impl.jac:23`, `declarations.impl.jac:215`.
- A small closed domain, repeated ~6×. An `enum JacPrim` would centralize it and turn typos into compile errors.
- Less severe than #1 (value-domain, not dispatch-domain), but the same anti-pattern.

---

## BLOAT / DEAD CODE / COPY-PASTE

The PR history ("drop dead code", "dedup …") did clear obvious scaffolding — no orphan infrastructure remains. What's left is *repetition*, not dead weight:

### 4. Duplicated "flatten conv_stmt result" loop — **minor** (×5)

```
for cl in items { n = self.conv_stmt(cl); if isinstance(n, list) { out += n } else { out.append(n) } }
```

appears in: `declarations.impl.jac:5` (c_FileAST), `:22` (c_Compound), `control_flow.impl.jac:400` (_for_init_stmts), `:422` (_for_step_stmts), `:176` (_switch_branch_body). **Fix:** one `_conv_stmts(items) -> list` helper.

### 5. Duplicated struct→ClassDef lowering — **minor**

`declarations.impl.jac:251` `c_Struct` and the struct-branch of `c_Typedef` (`:278-293`) are near-identical: iterate `*.decls` → `_struct_field` → Pass fallback → `ast3.ClassDef`. **Fix:** extract `_struct_classdef(snode, name, origin)`.

### 6. `_for_init_stmts` ≈ `_for_step_stmts` — **minor**

`control_flow.impl.jac:385` and `:409` differ only in that init also handles `DeclList`; both run the same flatten loop. Collapsible into the helper from #4.

### 7. Unreachable dispatch fallbacks — **nit**

`c_Enumerator` (`declarations.impl.jac:367`) and `c_EnumeratorList` (`:371`) are pure surrogate fallbacks that can never be dispatched to: enums are consumed wholesale by the direct-IR path (`c_Decl`→`_directir_placeholder`, `c_Enum`→placeholder), so `conv()` is never called on an individual `Enumerator`/`EnumeratorList`. `boundary.jac:5-10` `_DIRECT_IR_TYPES` likewise lists them, but `uni_builder.build` only special-cases `"Enum"`. Harmless, but vestigial — either drop or add a one-line comment so a future reader doesn't re-flag them.

---

## BRITTLENESS

### 8. Regex over unparsed generated text — **minor** (the most fragile coupling)

`comments.jac:7` `_MARKER_RE` matches the literal surrogate call `__c2jac_unsupported__(\d+)` **in the unparsed Jac string** to find where to append inline Tier-B notes (`:30-44`). This couples the comment pass to the exact textual form `unparse()` emits for a `Call`. If unparse formatting shifts (spacing, paren style, how the marker renders), the inline notes silently degrade to the generic `"unsupported C construct"` with no error. The line-number-keyed **header** (`_build_header`) is robust; only the inline annotation is text-coupled. **Fix:** key the inline note off the surrogate `Expr` node's stamped `lineno` *before* unparsing (you already carry `c_line`), rather than re-parsing the emitted string.

### 9. Suffix-based constant classification — **nit**

`c_common.jac:104` `classify_c_constant` uses `c_type.endswith("int")` / `endswith("double")` / `endswith("float")`. Correct for pycparser's synthesized type strings today, but substring-based — a token containing those as a non-suffix would misclassify. Add a comment pinning the pycparser-output assumption.

### 10. Unexplained magic bounds — **nit**

`declarations.impl.jac:182` `for _ in range(8)` (qualifier-nesting depth cap) and `bindgen.jac:103` `depth < 16` (typedef-chain recursion cap) are bare magic numbers. Both are reasonable guards; name them (`MAX_QUAL_DEPTH`, `MAX_TYPEDEF_DEPTH`) with a one-line comment.

### 11. Bare `except ValueError { }` — **nit**

`directir.jac:25` `slot_id_of` swallows a `ValueError` from `int(params[0].value)`, but `params[0]` is already `isinstance`-checked as `uni.Int`, so the catch is unreachable. Drop the try or comment that it's defensive.

---

## MAINTAINABILITY — giant functions (>80 lines, deep nesting)

### 12. `c_For` ~115 lines — **major**

`control_flow.impl.jac:233-347`. Interleaves list-bound kill tracking, promotability, surrogate-condition handling, body/step conversion, a faithfulness computation from three booleans, and two large tier-message branches. **Fix:** extract `_for_faithfulness(...) -> (bool, str reason)` and `_for_tier_message(...)`; the main body should read as a sequence of these. Single biggest readability hotspot in the mapper.

### 13. `_promote_for` ~110 lines — **major**

`driver.jac:150-259`. Manual tree surgery: index math, 6 distinct `raise ValueError` invariant checks, and two near-identical parent-list rebuild loops (`for b in gbody` at ~`238` and `for k in gp.kid` at ~`248`) — that pair is copy-paste. **Fix:** extract `_replace_pair_in_list(lst, old_a, old_b, new)` for the two rebuild loops, and split into `_validate_for_promotion()` + `_build_iterfor()` + `_relink_parent()`.

### 14. `build_enum_map` ~100 lines, 4-way nested branching — **major**

`enum_prepass.jac:101-203`. A four-armed `if/elif/elif/else` over enum classification, each arm repeating the `collision` check / `seen_glob_names.add` / `ev.verdicts[id(en)] = …` bookkeeping. The classification (explicit-values-not-int-use / explicit-but-int-use-or-collision / non-constant) is data-driven logic. **Fix:** a `_classify_enum(en, int_use_names, seen) -> (Idiom, name_map, reason)` helper returning a verdict, with the `ev.verdicts/name_map/reasons` writes applied uniformly afterward — collapses the repeated bookkeeping and flattens the nesting.

### 15. `_loc` hidden side effect — **minor** (footgun)

`core.impl.jac:1-6` `_loc` mutates `self._lineno = line`; `_stamp` calls it, `_stamp_manual` does **not**, so `_stamp_manual` callers must pass `self._lineno` by hand. The two stamping paths look symmetric but aren't. Document the split (or have `_stamp_manual` not depend on the caller remembering it).

---

## Verdict

No blockers. The package is **well-modularized** (clean `c_types`/`c_idioms`/`c_dataflow`/`c_common` split, good single-responsibility) and the `tags.jac` enums show the author knows the type-safety bar — which is exactly why the remaining items are worth fixing: they're internal inconsistencies against the PR's own standard.

**Must-fix before merge (majors):**

- #1 stringly-typed binop `kind` → enum (smallest, clearest CONTRIBUTING win)
- #2 untyped `-> tuple` returns on `enumerator_value`/`jac_prim_zero`/`_func_signature`/`_collect_struct_defs` → named records
- #12 `c_For`, #13 `_promote_for`, #14 `build_enum_map` — extract sub-helpers to get each under ~50 lines

**Polish (minor/nit):** #4–#6 dedup helpers, #8 inline-comment keying, #10/#11 magic numbers & silent catch.
