# Architecture & Long-Term Design Review — c2jac PR (#6973)

Branch `jac-python` vs merge-base `upstream/main` (`00d9415f`). Scope: the
`c2jac` transpiler, `cbindgen`, vendored `pycparser`, bundled `pcpp`, the
`transform` CLI, and the compiler-core touches.

**Bottom line:** This is a *well-engineered, principled* addition — not a hack.
The module boundaries are cohesive, the core-pass changes are minimal and
correctly gated, vendoring is justified, and the "Tier-A/Tier-B honest
reporting" is a genuine design feature rather than a disguise for
incompleteness. The one structural smell is the low-level uni-tree surgery
(`_promote_for`) living in `driver.jac`. No blockers. Findings below.

---

## 1. Module Boundaries — GOOD

### mapper.impl split is real cohesion, not arbitrary ✅

`jac/jaclang/compiler/c2jac/mapper.impl/`:

- **core.impl.jac** (167 ln): dispatch (`conv`/`conv_stmt`/`conv_expr`), token
  stamping, tag machinery (`_mark_tier_a/b`, `_earn_tier_a`), surrogate +
  direct-IR-slot allocation. *Infrastructure.*
- **control_flow.impl.jac** (437 ln): `If/While/DoWhile/Switch/Ternary/Return/
  Break/Continue/For` + for-promotion helpers. *Control flow.*
- **declarations.impl.jac** (408 ln): `FileAST/Compound/FuncDef/Decl/Assignment/
  Struct/Typedef/ArrayDecl/Enum*` + type annotations. *Declarations/types.*
- **expressions.impl.jac** (394 ln): `BinaryOp/UnaryOp/ID/Constant/StructRef/
  ArrayRef/InitList/Cast/FuncCall` + idiom matchers (`_malloc_array`,
  `_realloc_elide`). *Expressions.*

Every file maps to a recognized compiler-frontend partition. The split is the
right one — there is no cross-cutting leakage between the four files beyond the
shared `CMapper` state. **Verdict: keep.**

### driver.jac is the right orchestrator, but it's doing too much low-level surgery

`driver.jac` cleanly owns the pipeline (`transpile_c_file` → preprocess →
`transpile_c_str` → parse → `_transpile_ast` → map → build uni → splice →
unparse → inject comments). **However**, `_splice_directir`, `_promote_for`,
`_do_splice`, and `_hoist_to_module_body` (lines 102–344) are raw
`parent`/`kid`/`body`-list manipulation with manual
`_invalidate_sub_node_tab()` calls. The For-promotion path in particular walks
both `gp.body` and `gp.kid` to swap a `WhileStmt`+iter pair for an
`IterForStmt` — fragile tree surgery.

- **Severity: minor.**
- **Location:** `driver.jac:102–344` (`_splice_directir`, `_promote_for`,
  `_hoist_to_module_body`).
- **Concern:** The splice protocol is correct (it has thorough invariant checks
  that raise on every malformed case, and a final leak-detection sweep), but the
  *mechanics* of tree mutation are out of place in an orchestrator and would be
  at home in `uni_builder.jac` (which today only knows how to *build* enum
  nodes, not *splice* them). If the direct-IR set grows beyond `For`/`Enum`,
  this file will accumulate more bespoke surgery.
- **Long-term direction:** Extract the splice/hoist/promote mechanics into a
  dedicated module (e.g. `splice.jac`, or fold into `uni_builder.jac`) so
  `driver.jac` is pure orchestration. Not urgent — the current code is correct
  and well-guarded — but worth doing before the direct-IR type set expands.

### bindgen is a clean sibling

`bindgen.jac` (599 ln) reuses the shared pcpp front-end (`preprocess.jac`) and
emits a *different* output shape (FFI bindings, not transpiled Jac). It does
**not** share `CMapper` — correct, because binding-generation is a different
problem (declarations only, no bodies). The CBINDGEN.md phasing doc (P0–P4)
matches the code. **Verdict: clean separation.**

---

## 2. Compiler-Core Invasiveness — MINIMAL & CORRECTLY GATED

This was the highest-risk area. Verdict per file:

### normalize_pass — clean, gated, no-op for normal Jac ✅

`passes/tool/impl/normalize_pass.impl.jac:1815` adds an `after_pass` that runs
`_fix_zero_toks_in_subtree` **only when**
`self.ir_in.has_synthesized_tokens` is True (`impl:1816`). That flag is set in
exactly one place — `c2jac/driver.jac:82` — and defaults to `False`
(`jac0core/unitree.jac:332`). So for every normally-parsed `.jac`/`.py` module,
the new code is a **guaranteed no-op** (confirmed by grep: the only reader is
the normalize gate, the only writer is c2jac).

`after_pass` itself is a legitimate `UniPass` base hook
(`jac0core/passes/uni_pass.jac:15`, no-op default at `uni_pass.impl.jac:7`,
called at `uni_pass.impl.jac:48`) already overridden by `GrammarExtractPass`,
`TypeCheckPass`, and `BoundaryAnalysisPass`. Using it here is an established
pattern, **not** a special-case bolt-on.

- **Severity: nit.**
- **Location:** `normalize_pass.impl.jac:1880–1897` (the `RBRACE` branch:
  stamps `k.line_no = body_max + 1`).
- **Concern:** The closing-brace line is synthesized as `max(body_last_line)+1`.
  It's a heuristic that produces tight output but has no real "source line"
  semantics — acceptable for emitted (non-round-tripped) code, but it's the one
  spot that's pure cosmetics rather than correctness.
- **Long-term direction:** Leave as-is; it's gated and tested via the c2jac
  golden-output suite. If token positions were ever load-bearing for c2jac
  output (they aren't — c2jac emits, doesn't reparse), revisit.

### pyast_load_pass (proc_continue / proc_break) — a *general* fix ✅

`passes/main/impl/pyast_load_pass.impl.jac:1280,1415`: `continue`/`break`
`Token`s previously got `line=0,col=0`; now they pull real `lineno`/`col_offset`
via a new `ctrl_loc` helper. This changes the token positions for **every**
Python→Jac path, not just c2jac.

- **Severity: minor (behavior change for all pyast consumers).**
- **Location:** `pyast_load_pass.impl.jac:1280–1430`.
- **Concern:** Having real positions is *strictly* better than `line=0` (nothing
  sane depends on `0`), and it's what unblocked c2jac's `_fix_zero_toks` from
  having to handle these. Low regression risk. The only gap: there's no
  isolated unit test pinning the general pyast `break`/`continue` positions —
  it's exercised only indirectly via c2jac golden tests.
- **Long-term direction:** Acceptable as-is. Optionally add one assertion in the
  pyast test suite that a `break`/`continue` carries the source line.

### doc_ir_gen_pass (is_within → is_body_member) — strictly more correct ✅

`passes/tool/impl/doc_ir_gen_pass.impl.jac`: body-detection call sites (if/with/
while/for/else) switched from line-range containment (`is_within`) to identity
membership (`is_body_member`, `impl:2246`). `is_within` is **retained** for the
`nd.target` case (`impl:400`) where a single expression's range is the right
test — a surgical, not blanket, change.

- **Severity: nit (positive).**
- **Concern:** None. Identity membership (`kid is member`) is *more* correct
  than line-range containment for "is this kid a body statement" — the latter
  can both false-positive (a condition/`def`/decorator token whose range falls
  inside the body span) and false-negative (synthesized `line=0` tokens). c2jac
  merely exposed the latent weakness; the fix benefits hand-written Jac too.
  A new golden test (`test_jac_format_pass.jac:611`, "nested if elif else golden
  output") pins the behavior for the normal path. **This is an improvement, not
  a workaround.**

### jir_registry + unitree (has_synthesized_tokens field) ✅

`jac0core/unitree.jac:332` adds one defaulted bool field; `jir_registry.jac:1183`
registers it in the node spec. Minimal, mechanical, defaults off. No consumer
other than the normalize gate reads it. **Clean extension.**

> **Could it regress other consumers?** No. Every core change is either
> gated behind a c2jac-only flag (normalize), strictly more correct
> (doc_ir_gen), or a general fix with strictly-better positions (pyast_load).
> No shared pass acquired c2jac-specific branching.

---

## 3. Vendoring + Build Decisions — JUSTIFIED

### Vendoring pycparser: correct call ✅

`vendor/pycparser/README.vendor.md` states the real reason: c2jac relies on
`isinstance(c_node, c_ast.X)` against pycparser node types, which **breaks
across duplicate module identities** if a stray site-packages `pycparser`
coexists with the vendored one. pycparser 3.0 is pure-Python, zero transitive
deps (dropped PLY), so vendoring is cheap. Keeping it byte-for-byte upstream
and putting all c2jac behavior *outside* the dir is the right discipline. The
README documents the re-vendor procedure. **Verdict: right long-term call.**

### pcpp as a declared dep + bundled: consistent, one minor inconsistency

`payload.zig:931` adds `pcpp>=1.30` to the build-time pip bundle (alongside
pytest/watchdog/tomlkit); `jac/jac.toml:15` also lists it under `dependencies`.
The reasoning is sound: pcpp has no `isinstance`-identity constraint, so
vendoring it gains nothing, and declaring it is the honest move.

- **Severity: nit.**
- **Location:** `jac/jac.toml:12–16` vs `payload.zig:931`.
- **Concern:** `pcpp` is the **only** runtime dep in `jac.toml`'s
  `dependencies` — pytest/watchdog/tomlkit are *bundle-only* (payload.zig), not
  declared as runtime deps. So pcpp is double-sourced (declared dep + bundled),
  while its siblings are single-sourced. Given CONTRIBUTING.md states "Nothing
  is published to PyPI" and jaclang ships only as a binary, the `dependencies`
  field is effectively vestigial metadata; the inconsistency is cosmetic. But it
  does mean "is pcpp a runtime dependency or a bundled build tool?" is answered
  two ways.
- **Long-term direction:** Either (a) keep pcpp in `dependencies` and accept
  the bundle mirrors it, or (b) add a one-line comment in `jac.toml` noting the
  binary bundles it via payload.zig so the dual listing is intentional. No
  action required for correctness.

### No hackiness in the pcpp bundle

The change is a single token appended to an existing `pip install --target`
invocation — the same mechanism already used for pytest/watchdog/tomlkit. Clean.

---

## 4. Workaround Detection

### Tier-A/Tier-B reporting — NOT a workaround; it's the design ✅

`tags.jac` (Tier/Mechanism/Idiom enums + `TagTable`), `boundary.jac`
(everything defaults to Tier-B), `mapper.impl/core.impl.jac` (`_earn_tier_a`,
`_mark_tier_a/b`), `comments.jac` (`inject_tier_b_comments`), and the
`c_For` faithfulness computation (`control_flow.impl.jac:233–340`).

This is **genuinely honest engineering**, not cosmetic. The `c_For` path
*computes* faithfulness from first principles: it snapshots the Tier-B tag set
before/after lowering the body and declares the loop faithful iff there are no
new losses, no lossy condition, and no `continue`-skips-step hazard — then emits
a precise human-readable reason when it isn't. The `comments.jac` header +
inline `# c2jac: BEST-EFFORT` notes surface every best-effort site in the output.
**Verdict: this is the right way to do a best-effort transpiler. Keep.**

### direct-IR slot-sentinel splice — acceptable pragmatic boundary (minor)

For constructs with no Python-AST analog (`C for` → `IterForStmt`, enums as
consts), the mapper emits a `__c2jac_directir__(<slot>)` placeholder
(`directir.jac`) and registers the original C node in `slot_map`; the driver
splices real uni nodes back in (`_splice_directir`).

- **Severity: minor.**
- **Location:** `directir.jac`, `core.impl.jac:98` (`_directir_placeholder`),
  `driver.jac:102` (`_splice_directir`).
- **Concern:** This is a defensible two-track design (pyast for the 90%,
  direct-uni for the rest) rather than forcing every C construct through a
  lossy pyast roundtrip. The cost is a second IR-construction path
  (`uni_builder.jac`) + a fragile splice protocol keyed by `id()` and validated
  by post-splice leak detection. It is **not** tech debt today — it's the
  honest boundary for "no pyast analog" — but its complexity scales with how
  many types need direct-IR. Right now that's just `For`/`Enum`, so it's lean.
- **Long-term direction:** Fine as-is. If a 3rd/4th direct-IR type is added,
  promote the splice mechanics to their own module (see §1 driver note).

### pcpp lazy-import — clean boundary ✅

`driver.jac:21` imports `preprocess` (which imports pcpp) **lazily inside**
`transpile_c_file`, so the pycparser-only `transpile_c_str` entry point and its
tests run without pcpp installed. `preprocess.jac:3` imports pcpp eagerly, but
only the explicit `transpile_c_file`/cbindgen paths reach it. This is a clean
optional-dependency seam, not a workaround.

### token-stamping fix-ups (`_stamp` / `_fix_zero_toks`) — safety net, not root cause ✅

`_stamp_manual` (`core.impl.jac:12`) sets synthetic `lineno`/`col_offset` on
pyast nodes so `ast3.fix_missing_locations` and the downstream passes don't see
`None`s; `_fix_zero_toks_in_subtree` (normalize) repairs any residual `line==0`
uni tokens. Together they compensate for c2jac emitting nodes that have no
single real source span.

- **Severity: nit.**
- **Concern:** This *is* compensating for a structural fact (synthesized IR has
  no genuine positions), but it is **gated** (normalize path) and **correct by
  construction** for the non-synthesized world. The ideal long-term state —
  every synthesized uni token carries a real position at build time (which
  `uni_builder.jac` already does for the nodes it constructs) — is partially
  achieved; the normalize fix-up is the residual safety net for the pyast-leg
  tokens. Acceptable.
- **Long-term direction:** Leave the safety net; it's cheap and isolated.

---

## Summary Table

| # | Area | Severity | Verdict |
|---|------|----------|---------|
| 1 | mapper.impl split (4 files) | — | Real cohesion. Keep. |
| 1 | driver low-level tree surgery (`_promote_for`/`_hoist`) | minor | Correct but misplaced; extract when direct-IR grows. |
| 2 | normalize_pass `after_pass` + gate | nit | Clean; gated no-op for normal Jac. |
| 2 | pyast_load_pass break/continue positions | minor | General fix, strictly better; add an isolated test optionally. |
| 2 | doc_ir_gen_pass `is_body_member` | nit | Strictly more correct; golden-tested. Improvement. |
| 2 | `has_synthesized_tokens` field | — | Minimal, defaulted. Clean. |
| 3 | Vendor pycparser | — | Justified (isinstance identity). Right call. |
| 3 | pcpp declared dep + bundled | nit | Consistent; dual-listing is cosmetic. |
| 4 | Tier-A/Tier-B reporting | — | Honest design feature, not a disguise. Keep. |
| 4 | direct-IR slot splice | minor | Defensible two-track design; lean today. |
| 4 | pcpp lazy-import | — | Clean optional-dep seam. |
| 4 | token-stamping fix-ups | nit | Gated safety net. Acceptable. |

**Overall:** This is the *right* long-term design for a best-effort C→Jac
transpiler living alongside an existing pyast-based compiler. The core-pass
invasiveness is appropriately minimized (one gated flag, one general fix, one
correctness improvement). There are **no blockers** and no shortcuts that will
become tech debt. The single recommendation worth acting on — and only later —
is relocating the uni-tree splice mechanics out of `driver.jac` if the
direct-IR construct set expands.
