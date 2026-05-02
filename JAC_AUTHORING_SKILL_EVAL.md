# Jac Authoring Skill -- Evaluation Report

**Date:** 2026-04-23 (initial); 2026-04-28 (post-merge update)
**Status:** Two evaluation cycles complete. Filed bug #5677 was merged as #5678 (JSX entity decoding). One eval candidate (filter-tautology W3040) landed independently as #5679. Skill content updated for upstream changes to `root` syntax and the `any` type. Third evaluation cycle pending re-run after content refresh.

---

## 1. Goal

Determine whether a single Claude Code skill (a directory with `SKILL.md` + supporting files) can make a model competent enough to write production-quality Jac applications **without** depending on the `jac-mcp` MCP server. Distribution-friendly: the skill must be a self-contained, copy-pasteable artifact.

## 2. Motivation

Jac is syntactically close to Python but semantically distinct (codespaces, OSP, MTP). Models trained on Python/React reflexively produce Jac-shaped code that doesn't compile, or worse, compiles cleanly but behaves wrong at runtime. The existing `jac-mcp` content (`pitfalls.md`, `patterns.md`, `understand.md`) is comprehensive but only available when the MCP server is configured. A standalone skill closes that gap and answers a related question: how much of Jac's correctness can be enforced by static prose + a compile-test loop, vs. how much requires live tool access?

---

## 3. Methodology

### 3.1 Evaluation as a controlled A/B

Effectiveness is defined as the model's ability to produce Jac that:

1. Compiles cleanly under `jac check` on first try.
2. Boots and serves end-to-end under `jac start`.
3. Renders correctly in a browser when driven by `agent-browser`.
4. Avoids known anti-patterns (Python-isms, JSX-isms, OSP misuse).

Test architecture: spawn an isolated subagent (Claude Code `Agent` tool, `general-purpose` type) with **zero** prior context from this conversation. The subagent receives:

- A concrete task (build LinkedIn-lite full-stack in Jac).
- Mandate to read the skill files first as its only authoritative source on Jac.
- Bash access to the `jac` CLI and `agent-browser` for validation.
- A required compile-before-present loop (`jac check` → fix → repeat).
- A mandate to log challenges in real-time at `CHALLENGES.md`, with reproduction steps, diagnostic, and fix.
- A mandate to return a structured final report with quantitative compile-attempt counts, qualitative skill feedback, and screenshot-validated end-to-end functional verification.

This isolates *the skill's contribution to model behavior* from any contamination by the parent session's accumulated knowledge.

### 3.2 The benchmark task

LinkedIn-lite -- chosen because it exercises every paradigm Jac is designed for:

| Feature | Paradigms it tests |
|---|---|
| Signup / login / logout | `def:priv` + `jacLogin` / `jacSignup` runtime imports |
| User profile (name, headline, bio) | `node` declarations with persistence via root |
| Connection requests (A → B; B accepts/rejects) | Multi-user graph; cross-user discovery |
| Post feed (newest-first) | OSP queries + list rendering |
| AI "Polish my headline" | `by llm()` + `sem` + structured output |
| Multi-file split | `main.jac` + `frontend.cl.jac` + `frontend.impl.jac` + `styles.css` |

Out of scope (deliberately): messaging, job boards, file uploads, search, notifications. The agent could cut features in reverse-importance order if running long.

### 3.3 Metrics

Captured per run:

- **Wall-clock time** (subagent duration).
- **Tool calls** (subagent activity intensity).
- **Tokens used**.
- **Compile attempts per file** until clean.
- **Specific errors hit** + whether they were covered in the skill.
- **Pitfalls avoided** that the skill explicitly warned against.
- **Pitfalls hit** that the skill missed or covered incorrectly.
- **Final lines of code per file** (a rough proxy for tightness -- fewer is better when the same features ship).
- **End-to-end UI verification** via `agent-browser` screenshots.

### 3.4 Two-cycle iteration

Run 1 → identify gaps → patch the skill → Run 2 → measure deltas. The patches between runs target only the gaps surfaced in Run 1, so the delta isolates the patch effect.

---

## 4. The skill -- design and layout

### 4.1 Location

`jac-mcp/jac_mcp/skills/jac-write/` -- chosen for distribution: the `jac-mcp` package is included in the recommended Jac install line, so users can copy the skill directory into `~/.claude/skills/` with a single `cp -r`.

### 4.2 Progressive-disclosure structure

```
jac-mcp/jac_mcp/skills/jac-write/
├── SKILL.md           ~300 lines -- always loaded; reset, workflow, syntax, index
├── pitfalls.md        ~830 lines -- WRONG vs RIGHT pairs; loaded for compile errors
├── paradigms.md       ~680 lines -- OSP, MTP, codespaces playbooks; loaded for paradigm work
└── examples/
    ├── walker.jac          -- accumulator / counter / search-disengage walker patterns (runs)
    ├── by_llm.jac          -- enum-constrained + obj-structured AI output (compiles)
    └── mini_todo.jac       -- full-stack canonical (compiles)
```

`SKILL.md` is small enough to load on every fire without context bloat. Heavier reference content lives in sibling files indexed by `SKILL.md`'s "When to load more" table -- model only pulls them in when the task actually requires.

### 4.3 Design principles

1. **Reset before reference.** The first section of `SKILL.md` is the "ten rules you must never break" -- short, imperative, Python-vs-Jac deltas. The model internalizes these before writing any code.
2. **Compile-loop is mandatory, not optional.** The workflow section names exact commands (`jac check <file>`, `jac start main.jac`) and forbids presenting code that hasn't passed.
3. **Examples are validated artifacts.** Every `.jac` example was compile-tested against the installed CLI before commit. The skill's "ground truth" code is provably correct, not aspirational.
4. **Triggers are aggressive.** The frontmatter `description` field lists concrete signals (`.jac` file edits, mentions of Jac/Jaseci/jaclang/byllm/jac-client/jac-scale, any `.jac` code block, any `jac` CLI output) so Claude Code fires the skill broadly.
5. **Self-check before presenting.** A 13-item checklist runs in the model's mental loop before final output -- every item is a specific failure mode the skill is designed to prevent.

---

## 5. Run 1 -- Baseline test (pre-patches)

### 5.1 Outcome

Working LinkedIn-lite app with all six features. End-to-end UI flows verified via `agent-browser` (signup, login, profile edit, post creation, cross-user connection request, accept).

### 5.2 Quantitative results

| Metric | Value |
|---|---|
| Wall-clock | ~50 min (2,977,938 ms) |
| Tool calls | 211 |
| Tokens | 189,003 |
| `main.jac` compile attempts | 2 |
| `frontend.cl.jac` compile attempts | 5 |
| `frontend.impl.jac` compile attempts | 2 |
| Total compile attempts | 9 |
| Source LOC | 827 Jac + 144 CSS |
| Challenges log | 184 lines, 9 entries |

### 5.3 Pitfalls avoided (attributed to the skill)

- `from X import Y` syntax -- never used; correctly used `import from X { Y }`.
- `.append()` mutation on reactive `cl` state -- never used; correctly used `xs = xs + [x]`.
- `for i, x in enumerate(xs)` -- added required parens.
- `class Foo` for data containers -- went straight to `obj` / `node`.
- Bare `root` without `()` -- always `root()`.
- Walker ability headers used `with Root entry`, not `` with `root` entry ``.
- List rendering with `key={jid(...)}`.
- Manual `user_id` filtering with `def:priv` -- relied on automatic per-user root isolation.

### 5.4 Pitfalls hit (skill missed or actively misled)

Ranked by time lost:

1. **Stale reactive closure in `async can with entry`** -- 25 min. Wrote `logged_in = jacIsLoggedIn(); if logged_in { ... }`. Compiled clean. At runtime, `if logged_in` read the captured pre-update value (always `False`), so the post-login data refresh never fired. Required reading minified compiled JS to diagnose. Single most expensive challenge.
2. **JSX component tags must be PascalCase** -- 15 min. `<linkedin_app/>` rendered as a literal HTML element with no React binding. No compile warning; just a blank page.
3. **Multi-file `main.jac` + `frontend.cl.jac` wiring** -- 15 min. Tried `include frontend;` (circular import), then `to cl: import` with name `app` (E2016 collision). The canonical shape (server-side re-export with `to cl: import from frontend { MyApp }`) lives in `tests/compiler/passes/ecmascript/fixtures/separated_defpub.jac` but wasn't in the skill.
4. **`lambda -> None` in JSX `onClick`** -- 8 min. SKILL.md actively listed this as the canonical "no-arg void" pattern; in JSX it raises E1103 because intrinsic prop signatures require a typed event arg.
5. **CSS file 404 under `jac start`** -- 8 min. Dev server doesn't serve arbitrary static files; had to inline via `<style dangerouslySetInnerHTML={{"__html": ...}}/>`.
6. **`datetime.datetime.now()` E1031 in function bodies** -- 5 min. Type-checker can't resolve `.strftime()` on the `Self`-typed return; works as a `has` default but not in a `def` body.
7. **`any` collides with built-in `any()`** -- 5 min. SKILL.md listed `any` as a "Special type"; correct form is `Any` from `typing`.
8. **`return None` from `-> Profile`** -- 2 min. Needed `Profile | None`.
9. **`impl app.with entry { ... }` parse error** -- 2 min. Lifecycle hooks can't be split into `.impl.jac` files; only named `def`/`can` can.

### 5.5 Diagnostic insight

The agent followed the validate-before-present workflow. Most pitfalls hit were *gaps* in the skill (missing content) or one *active error* in the skill (the `lambda -> None` example). The skill was being read and trusted; failures came from the skill's own incompleteness, not from the model ignoring it. That made the next patch cycle's targets unambiguous.

---

## 6. Patches applied between runs

Seven concrete additions/corrections, each tied directly to a Run-1 challenge:

### SKILL.md

- Removed `any` from "Special types"; added explicit `Any` (from `typing`) guidance with E1100 symptom.
- Rewrote lambda section: showed `lambda -> None { ... }` is rejected by JSX intrinsic props (E1103); demonstrated `lambda e: MouseEvent { ... }` as the correct form.
- Expanded top-10 anti-pitfall reminders to 15: PascalCase JSX tags, stale reactive closures, `lambda -> None` in JSX, `Any` vs `any`, lifecycle hooks not impl-separable.
- Added new **"Traps that compile clean but fail at runtime"** subsection -- the three runtime bug classes that `jac check` cannot catch (stale closures, lowercase JSX tags, static-asset 404s).
- Self-check checklist grew from 10 → 13 items.

### pitfalls.md

- Rule 20 rewrite: `lambda -> None` JSX trap with the exact E1103 diagnostic.
- New rule 29: lifecycle hooks (`can with entry`, etc.) cannot be impl'd externally.
- New rules 30–35 in a "Full-stack / client-side runtime traps" section:
  - 30: stale reactive closures (with compiled-JS explanation).
  - 31: PascalCase JSX component tags.
  - 32: static assets not served by `jac start`.
  - 33: untyped `list` / `dict` → `Unknown` element type (E1053).
  - 34: `Any` vs `any` capitalization.
  - 35: `datetime.datetime.now()` E1031 workaround.
- Error-code quick-match table expanded from 5 → 12 entries (added E1002, E1031, E1053, E1100, E1103, E2016, W1050, W3037).

### paradigms.md

- § Multi-file organization clarified: lifecycle hooks stay inline.
- New § "Full-stack multi-file shape (main.jac + frontend.cl.jac + frontend.impl.jac)" -- the previously undocumented canonical shape, with full working examples for each file, the rationale for the `to cl: import from frontend { MyApp }` wrapper, and a symptoms→cause→fix table for every Run-1 issue.

Net skill growth: 1,362 → 1,815 lines across the three markdown files. All three example `.jac` files re-compiled clean after edits.

---

## 7. Run 2 -- Post-patch test

### 7.1 Outcome

Working LinkedIn-lite app with all six features. End-to-end UI flows verified.

### 7.2 Quantitative comparison

| Metric | Run 1 | Run 2 | Δ |
|---|---:|---:|---:|
| Wall-clock | ~50 min | ~11.5 min | **4.3× faster** |
| Tool calls | 211 | 91 | -57% |
| Tokens | 189,003 | 121,368 | -36% |
| Total compile attempts | 9 | 6 | -33% |
| `main.jac` attempts | 2 | **1** | clean first try |
| `frontend.cl.jac` attempts | 5 | 3 | -40% |
| `frontend.impl.jac` attempts | 2 | 2 | -- |
| Source LOC | 827 + 144 CSS | 605 + inline CSS | tighter |

### 7.3 All seven patched pitfalls avoided on first try

The agent explicitly credited each new rule:

- Rule 20 (typed event lambdas) → all JSX handlers used `lambda e: MouseEvent { ... }` from file 1.
- Rule 29 (lifecycle hooks stay inline) → `async can with entry` straight into `.cl.jac`, no guesswork.
- Rule 30 (stale reactive closures) → wrote `is_auth = jacIsLoggedIn(); logged_in = is_auth; if is_auth { ... }` from the start.
- Rule 31 (PascalCase JSX tags) → named `LinkedInApp`, used `<LinkedInApp/>` immediately.
- Rule 32 (inline CSS) → used `<style dangerouslySetInnerHTML={{"__html": APP_CSS}}/>`; no 404 hunt.
- Rule 34 (`Any` vs `any`) → avoided by typing concretely.
- paradigms.md full-stack shape → `to cl: import from frontend { LinkedInApp }` wrapper landed verbatim; no `include`, no E2016.

Run 1 spent ~80 min debugging these. Run 2 spent **0 min**.

### 7.4 New gaps surfaced (next iteration candidates)

The patches dissolved Run 1's high-cost issues, so Run 2 hit a fresh layer of less-frequent issues:

1. **`jac start` requires `jac.toml`** -- biggest new gap. Skill says "boot the app: `jac start main.jac`" but the project needs a manifest. Belongs in paradigms.md § full-stack shape as a prerequisite block.
2. **Multi-line string E0100** -- the inline-CSS example used a trivial single-line string; real CSS is multi-line, requiring `"""..."""`. Update rule 32's example.
3. **Filter-expression variable shadowing** -- `[?:Type, x == x]` silently becomes a tautology when the RHS name matches a node field. Compile-clean bug; deserves a runtime-traps entry.
4. **Multiple `await`s in single `try/except` swallowing** -- after a state-mutating `await`, a subsequent dict access silently short-circuited. Splitting into two try-blocks fixed it. Smells like a codegen issue.
5. **JSX HTML entities not decoded** -- `-&gt;` rendered literally. Filed as Jac compiler bug (see §8).
6. **Server REST schema** (`/user/login`, `/user/register` curl-level shape) -- undocumented; agent probed for ~15 min.

These are smaller-scope and more incidental than Run 1's; the trajectory is converging.

---

## 8. Upstream Jac improvements identified

A categorical observation: when the same test reveals the same failure modes across model runs, the cause is more likely Jac itself than the skill. Reviewing both runs' challenge logs through that lens, several issues are not skill-content gaps but Jac compiler / runtime / UX issues.

### 8.1 Filed and resolved

**[Jaseci-Labs/jaseci#5677](https://github.com/Jaseci-Labs/jaseci/issues/5677) -- JSX text and attribute values not HTML-entity-decoded**

Confirmed empirically via `jac jac2js`: `&gt;`, `&amp;`, `&lt;` passed through to emitted JS as literal strings, both in text children and attribute values. Diverged from the JSX spec (and React, Preact, Solid, Vue JSX). Silent wrong-rendering -- no compile error, no runtime error. Root cause in [`jsx_processor.impl.jac:201-208`](jac/jaclang/jac0core/passes/ast_gen/impl/jsx_processor.impl.jac#L201-L208) and [`unitree.impl.jac:2077-2091`](jac/jaclang/jac0core/impl/unitree.impl.jac#L2077-L2091). Proposed fix: `html.unescape` at emission boundary (~3 lines).

**Status: RESOLVED** -- merged as [PR #5678](https://github.com/Jaseci-Labs/jaseci/pull/5678). The fix added `html.unescape` to `JsxText.get_normalized_text()` and parallel decode on `uni.String` attribute values in both `EsJsxProcessor.normal_attribute` and `PyJsxProcessor.normal_attribute`. Verified via `jac jac2js` after merge: `<div title="A &amp; B">Before &gt; After</div>` now compiles to `{"title": "A & B"}, ["Before > After"]`.

### 8.2 Strong candidates to file

These are clear correctness issues -- silent wrong behavior, compiler bugs, or missing diagnostics the compiler has the information to emit.

**1. Stale reactive closures in `async can with entry`**
The most expensive Run-1 challenge. `has` field assignments lower to `useState` calls; subsequent reads in the same synchronous block close over the pre-update value. Compiles clean; runtime semantics violate the natural reading of the source. Compiler has the information to either lower differently or warn.

**2. Multiple `await`s in single `try/except` silently short-circuit**
After a state-mutating `await`, a subsequent dict access in the same try block silently no-ops. Smells like a codegen bug in async + try/except lowering. Needs minimal repro to confirm.

**3.** ~~Filter-expression tautology on shadowed names -- `[?:Type, x == x]`~~ -- **landed independently as W3040 lint** ([PR #5679](https://github.com/Jaseci-Labs/jaseci/pull/5679)). Compiler now warns `Filter comparison 'x == x' is always true -- both sides resolve to the same node field [filter-compare-tautology]`. Skill `pitfalls.md` rule 35 documents the warning.

**4. `datetime.datetime.now()` E1031 in function bodies**
Type-checker infers `now()` as `Self`, then can't resolve `.strftime()`. Works in `has` defaults; fails in `def` bodies. Typeshed-handling bug for Python stdlib classmethods returning `Self`.

### 8.3 Diagnostic / UX improvements worth filing

These aren't bugs but represent compiler-level UX cliffs:

- **Lowercase JSX tags rendering as literal HTML** -- Jac's compiler has more context than Babel does (it sees imported symbols); a "did you mean `<MyWidget/>`?" warning when `<my_widget/>` references an in-scope function would prevent silent blank-render failures.
- **Missing intrinsic JSX elements** -- `<b>`, `<strong>`, `<style>`, `<link>`, `<script>` warn as unknown (W2001/W1050). Whitelist needs expansion.
- **`any` vs `Any` did-you-mean** -- current E1100 message buries the root cause; a hint pointing to `typing.Any` would close a 5-minute hunt.
- **`jac start` requires `jac.toml` without explaining** -- fail with a clear "create `jac.toml` with these contents" message, or auto-scaffold with prompt.
- **E0100 (unterminated string) hint** -- fix is always "use triple-quoted `"""..."""`"; add as a hint.
- **Static assets convention** -- `jac start` 404s on `/styles.css`. Either document a `static/` directory convention, or add a one-liner `[serve] static = "static/"` config in `jac.toml`.

---

## 9. What the methodology revealed about skill design

Distilling the cross-cutting observations:

**A. The validate-before-present workflow is the single most important behavior the skill enforces.** Without it, no amount of pitfall content prevents the model from emitting plausible-but-broken code. With it, the skill becomes a feedback loop: model writes → compiler rejects → model consults pitfalls → fixes. Both runs showed the agent following this loop without prompting once internalized.

**B. The skill catches *systematic* errors and misses *novel* ones.** The "ten rules" reset prevented every recurring Python-ism. New errors (the runtime traps in §5.4) were either compile-clean bugs or content gaps -- the model can't avoid what the skill doesn't mention.

**C. Compile-clean runtime bugs are the killer category.** Stale closures, JSX entity rendering, filter shadowing, await-in-try short-circuits -- all compile cleanly. The "compile before present" workflow is necessary but not sufficient. The skill needs a dedicated "runtime traps" inventory for this class, *plus* the compiler should ideally be improved to either fix or warn about as many as possible.

**D. The MCP-free design holds up.** The skill needs the `jac` CLI on `$PATH` (which is everywhere Jac is installed) and works in any Claude Code session. No server, no live tool dependency. The trade is real but bounded: novel compiler errors not in the pitfall table fall back to model speculation, but the volume of those is small once the major classes are documented.

**E. The skill closed an 80-minute gap to ~zero.** Run 1 spent ~80 minutes debugging the seven gaps Run 2 didn't hit. That's the magnitude of value a single skill iteration can deliver -- assuming the patches are tied directly to measured failures, not speculative additions.

---

## 10. Next steps

### Skill content

Apply Run 2's three patches:

1. `paradigms.md` -- add `jac.toml` + `jac install` prerequisite block to § Full-stack shape.
2. `pitfalls.md` -- upgrade rule 32 inline-CSS example to triple-quoted strings; add E0100 to error-code table.
3. ~~`pitfalls.md` -- add filter-expression-tautology entry~~ **DONE post-merge as rule 35, references W3040.** Multiple-await-in-try still pending.

### Distribution

- Add a `jac mcp install-skill` subcommand (or equivalent in `jac-mcp/jac_mcp/plugin.jac`) that copies `jac-mcp/jac_mcp/skills/jac-write/` into `~/.claude/skills/jac-write/` for users.
- Document the skill's existence and install command in the main Jac docs (`docs/docs/quick-guide/`).

### Upstream Jac

- Triage the §8.2 candidates (stale closures, await-in-try, filter shadowing, datetime E1031). File any that survive minimal-repro confirmation.
- Triage §8.3 UX improvements; some may be one-line fixes worth bundling.

### Re-test cadence

A third test cycle would measure diminishing returns. Forecast: another 10–20% reduction in time, and most new gaps will be smaller-scope still (configuration, ecosystem-edge issues). Worth running once Run-2's three patches land, to confirm the patch effect generalizes.

### Methodology generalization

The same A/B test pattern (subagent + skill-only knowledge + concrete benchmark + compile-loop + screenshot validation) is reusable for any language-authoring skill. Worth codifying as a reusable evaluation harness if more language skills get built.

---

## 11. Post-merge content refresh (2026-04-28)

Between Run 2 and the planned Run 3, upstream `main` advanced 34 commits. Three of them changed Jac language behavior in ways that directly affected skill correctness:

| Upstream change | Skill impact | Action taken |
|---|---|---|
| **#5678** -- JSX entity decoding (resolves my #5677) | Run-2 gap dissolves; no skill content needed updating because the original skill never warned against entities. | None. §8.1 marked resolved. |
| **#5724** -- `root` restored as `SpecialVarRef` keyword | **Pitfall #15** wording inverted: bareword `root` is now idiomatic; `root()` is backward-compat. Examples across `SKILL.md`, `paradigms.md`, `pitfalls.md`, `walker.jac`, `mini_todo.jac` updated to bareword. | All `root()` → `root` (35 sites total). Rule 15 rewritten to teach the new canonical form while noting `root()` still compiles. |
| **#5588** + **#5689** -- lowercase `any` is now the type | **Pitfall #34 was actively wrong** (told models to use `Any` from `typing`; modern Jac treats lowercase `any` as the type). | Rule 34 inverted: lowercase `any` is canonical, no `import from typing { Any }`, `` `any `` (backticked) for the built-in function. SKILL.md "Types" section, anti-pitfall list rule 14, and self-check checklist all updated. Pitfall #3's import example switched from `Any` to `Callable`. |
| **#5679** -- W3040 lint for filter tautology | Eval candidate (§8.2) landed independently; one less thing to file. Skill could now warn models to treat W3040 as a hard error. | Added new pitfall rule 35 referencing W3040. §8.2 item 3 marked resolved. |
| **#5661** -- `/assets` proxy in Vite dev server | Affects pitfall #32 (static CSS 404). The fix is scoped to `jac create --use client` projects, not ad-hoc `jac start` scripts. | Pitfall #32 augmented with a paragraph distinguishing the two cases. |

The content refresh affected no examples behaviorally -- all three `.jac` files still compile clean and `walker.jac` still runs end-to-end. The skill is now consistent with Jac as of `origin/main` HEAD (`73bd3a438`).

Run 3 will measure whether models using the refreshed skill see further compile-attempt reductions, or whether the diminishing-returns curve has flattened.

---

## 12. Recommended improvements to the Jac language

This section consolidates everything three test cycles have surfaced about Jac itself -- distinct from §8, which is a list of specific bugs and diagnostics to file. §8 is operational; this section is strategic. The throughline: **the most valuable language-level improvements are those that eliminate "compiles clean but runs wrong" failure modes and close the gap between paradigm intent and developer experience**.

### 12.1 Eliminate the compile-clean-runtime-wrong category

This is the single most important class of improvement, and the one where AI-assisted authoring suffers most. Models trust the compile pass; bugs that pass `jac check` propagate. Across three runs, this category cost the most aggregate time and produced the most subtle failures.

**Open instances surfaced across runs:**

- **Stale reactive closures** in `async can with entry`: assigning a `has` field then reading it in the same block reads the captured pre-update value (Run 1, ~25 min lost). Compiler has the symbol-table information to either lower differently or warn.
- **Multiple `await`s in a single `try/except` short-circuiting** (Run 2): a state-mutating await silently caused subsequent dict access to no-op. Needs minimal-repro confirmation; likely codegen bug in async + try/except lowering.
- **JSX component tags being lowercase** (Run 1): `<my_widget/>` rendered as a literal HTML element with no compile warning. Compiler sees the imported symbol in scope; could warn "did you mean `<MyWidget/>`?".
- **Logout reactive-state leakage** (Run 3): `has` fields holding messages/errors persist across logout/login because the handler resets data fields but not status fields. This is more an ergonomic gap than a bug, but a `:reset` modifier on `has` (or a built-in reset helper) would be a one-line cure.

**Pattern:** every silent-runtime-wrong bug we hit had information in the compiler that *could* drive a warning. Pursuing them as a category -- "what bugs in client-side reactive code can the type system + symbol table detect that we're not currently flagging?" -- would compound returns. AI-assisted Jac authoring is most valuable when the compiler is the floor on correctness; lifting that floor is the highest-leverage move.

### 12.2 First-class API surface for cross-user data

Per-user root isolation via `def:priv` is the right default and a real selling point of the language. But every non-trivial multi-user app needs *some* cross-user mechanism, and the current path -- `allroots()` + `grant(node, level=Perm)` -- is undocumented in the main reference and only discoverable by reading the `littleX` example or `jac-scale` source. Three runs all needed it; only Run 3 had it in the skill (after the eval surfaced the gap).

**What would help:**

- A dedicated **"Cross-user data" reference page** in `docs/docs/reference/language/` covering `allroots()`, `grant()`, the permission ladder (`ConnectPerm`, `ReadPerm`, `WritePerm`, etc.), and worked examples for the three canonical patterns: discovery (find a user by handle), social graph (connection requests), and shared content (public posts).
- **An `allroots` filter shorthand** so `[r-->[?:Profile, username == target]]` doesn't need a nested loop. The current pattern has every cross-user app reinventing the same triple-nested loop.
- **A type-system hook so `def:priv` knows about `grant(...)`** -- right now you can mark a node `:priv` and forget to grant it, and the only signal is "other users can't find this thing." A diagnostic ("this node is referenced by a public walker but never granted access") would close the loop.

This is currently the single biggest "you have to read the source to figure it out" gap in the language.

### 12.3 Project-setup ergonomics

`jac start` requires a `jac.toml` manifest but doesn't say so when missing. Run 2 lost ~10 minutes scaffolding one by hand from an example; Run 3 hit the same gap and still lost ~3 minutes. The skill now documents it, but the language-level fix is better:

- **Auto-scaffold a minimal `jac.toml` on first `jac start`** with a `Y/n` prompt, or fail with a copy-pasteable template in the error message.
- **Surface a `static/` convention** for serving arbitrary assets without the `jac-client` scaffold. Either a `[serve] static = "static/"` config in `jac.toml`, or convention-over-configuration.
- **Make `/cl/<name>` URL convention discoverable** via a `jac start --print-routes` flag or a default landing page that lists all mounted endpoints/walkers/components.

The end-to-end "I have a `.jac` file, I want to see it in a browser" path has too many implicit prerequisites for someone -- human or model -- coming in cold.

### 12.4 Diagnostic-quality pass

Several E-codes the agents hit have all the information needed for a "did you mean..." hint, but emit only the technical error:

- **E1100** ("Type not assignable") on `lambda -> None` in JSX -> hint: "JSX intrinsic prop expects `Callable[[MouseEvent], None]`; use `lambda e: MouseEvent { ... }`."
- **E0100** ("unterminated string literal") -> hint: "for multi-line strings, use triple-quoted `\"\"\"...\"\"\"`."
- **E1031** on `datetime.datetime.now().strftime(...)` -> deeper fix is the typeshed-handling bug; short-term hint: "Python stdlib classmethods returning `Self` don't compose with attribute access in function bodies; intermediate-typed variable narrows the inference."
- **E1096/E1097** ("connection operand must be a node") -> hint: "operand resolved to `None | T`; narrow with `is not None` before connecting."

These are all small additions on top of existing diagnostics, not new analyses. A diagnostic-polish sprint would yield outsized ergonomic gains.

### 12.5 JSX intrinsic element coverage

Run 2 hit W2001 / W1050 on `<b>`, `<style>`, `<link>`, `<script>` -- standard HTML elements that warn as "unknown intrinsic." The whitelist is too narrow. Expanding to cover the standard HTML5 element set (formatting, structural, document-head, embedded content) would eliminate a recurring and confusing warning. This is a one-time table edit, not an architectural change.

### 12.6 Lambda + event-prop ergonomics

`lambda -> None { ... }` is a documented pattern in the language but rejected by every JSX intrinsic prop. The mismatch is real -- intrinsic prop signatures take typed event args -- but the surface friction is high because models reflexively reach for the no-arg form for click handlers that don't use the event. Three options worth considering:

- **Auto-coerce no-arg lambdas at JSX-prop boundaries** so the typed-event arg is implicitly available but optional.
- **Make `lambda -> None { ... }` an error in JSX-prop contexts with a hard fix-it suggestion** instead of a generic E1103.
- **Introduce a no-arg JSX handler form** (e.g. `<button onClick=action />` where `action: () -> None`) so users can write what they mean.

Option 2 is the cheapest and most likely to land cleanly; option 1 is the most ergonomic.

### 12.7 Type system: nullable-by-default in find-in-loop patterns

The "search for a node, capture in a variable, act if found" pattern is so common that requiring `T | None` annotation + manual `is not None` narrowing for every instance feels like Jac's type system fighting the developer. Worth exploring whether the checker can:

- **Infer `T | None`** when a variable is initialized to `None` and conditionally reassigned, without requiring the explicit annotation.
- **Auto-narrow** under the canonical `if x is not None { ... }` pattern (it does this already for some cases; coverage could be expanded to include attribute access and edge ops).
- **Flow-aware after a loop**: if every path through a loop assigns to `target`, narrow to `T` after the loop without an explicit guard.

This would remove a real friction point and is squarely in the territory modern type checkers (Pyright, Roc, Flow) do well.

### 12.8 Reactive state lifecycle

Two recurring patterns suggest first-class language support is warranted:

- **Reset on logout / unmount** -- some declarative way to mark "reset this `has` field on lifecycle X." Every component reinvents the cleanup-on-logout pattern.
- **Stale-closure prevention** -- the Run-1 25-minute bug. Either lower setState calls to immediately-resolved local bindings, or warn on read-after-write of reactive state in the same synchronous block.

The reactive system is one of Jac's most attractive features for full-stack work, but the rough edges are concentrated here.

### 12.9 Documentation as a load-bearing artifact

This isn't a code change but a process observation: the skill's value comes overwhelmingly from condensed, opinionated, error-trace-tied prose. The upstream Jac docs are comprehensive but spread across many files; some of the most load-bearing patterns (the multi-file full-stack shape, `allroots`/`grant`, the `/cl/<name>` URL convention) only existed in test fixtures or examples. Hoisting those into the official reference would benefit human and AI authors equally, and would mean the skill doesn't have to rediscover them.

A possible model: a `docs/recipes/` directory whose files mirror what proved load-bearing in the skill, kept in lockstep with the skill content via CI.

### 12.10 Skill-driven testing as upstream feedback

Meta-observation worth surfacing: this evaluation methodology -- isolated subagent + skill-only knowledge + concrete benchmark + compile loop + screenshot validation -- is a useful upstream feedback channel for the language itself. Each test cycle surfaces a fresh layer of friction; many of those frictions are genuinely fixable upstream. If Jaseci-Labs adopted skill-driven testing as part of the language-development feedback loop (run the LinkedIn-lite benchmark on each major release), it would catch regressions and surface ergonomic gaps that lab-style testing misses. The `eval` harness this work created is reusable; the three cycles documented here produced both the resolved items in §8 and the strategic items in this section.

### Tier ranking for action

If maintainer attention is the bottleneck:

| Tier | Work | Why |
|---|---|---|
| **High-impact / low-effort** | Diagnostic hints (12.4), JSX intrinsic expansion (12.5), `jac.toml` auto-scaffold (12.3) | Each is small and removes a recurring source of confusion. |
| **High-impact / medium-effort** | Stale-closure warning or fix (12.1), cross-user data API surface (12.2), reactive cleanup-on-lifecycle (12.8) | These remove the deepest pain points and are the gaps AI-assisted authoring most reliably trips over. |
| **High-impact / high-effort** | Flow-sensitive narrowing for find-in-loop (12.7), comprehensive reactive-state semantics overhaul (12.8), JSX no-arg handler ergonomics (12.6) | Worth doing but more invasive. |
| **Strategic** | Docs/recipes directory (12.9), skill-driven testing as part of the release loop (12.10) | Multiplies the value of every other improvement above. |

---

## Appendix A -- Artifacts

| Artifact | Path |
|---|---|
| Skill entry point | [jac-mcp/jac_mcp/skills/jac-write/SKILL.md](jac-mcp/jac_mcp/skills/jac-write/SKILL.md) |
| Pitfall table | [jac-mcp/jac_mcp/skills/jac-write/pitfalls.md](jac-mcp/jac_mcp/skills/jac-write/pitfalls.md) |
| Paradigm playbooks | [jac-mcp/jac_mcp/skills/jac-write/paradigms.md](jac-mcp/jac_mcp/skills/jac-write/paradigms.md) |
| Walker example | [jac-mcp/jac_mcp/skills/jac-write/examples/walker.jac](jac-mcp/jac_mcp/skills/jac-write/examples/walker.jac) |
| `by llm` example | [jac-mcp/jac_mcp/skills/jac-write/examples/by_llm.jac](jac-mcp/jac_mcp/skills/jac-write/examples/by_llm.jac) |
| Mini todo example | [jac-mcp/jac_mcp/skills/jac-write/examples/mini_todo.jac](jac-mcp/jac_mcp/skills/jac-write/examples/mini_todo.jac) |
| Run 1 source tree | `/tmp/linkedin_test/` |
| Run 1 challenge log | `/tmp/linkedin_test/CHALLENGES.md` |
| Run 2 source tree | `/tmp/linkedin_test2/` |
| Run 2 challenge log | `/tmp/linkedin_test2/CHALLENGES.md` |
| Run 1 screenshots | `/tmp/app_01_login.png` through `/tmp/app_08_alice_accepted.png` |
| Run 2 screenshots | `/tmp/app2_01_initial.png` through `/tmp/app2_05_connections_final.png` |
| Filed bug | [Jaseci-Labs/jaseci#5677](https://github.com/Jaseci-Labs/jaseci/issues/5677) |

## Appendix B -- Test environment

- Jac 0.11.3 (jaclang 0.11.3, jac-client 0.3.3, byllm 0.5.3, jac-mcp 0.1.2, jac-scale 0.2.3)
- Python 3.12.12 (venv at `/Users/marsninja/repos/jaseci/.venv/`)
- macOS arm64 (Darwin 24.6.0)
- `agent-browser` at `/opt/homebrew/bin/agent-browser`
- Subagent type: Claude Code `general-purpose` agent (default model)

## Appendix C -- Reproducibility

To re-run the evaluation:

1. Clean test directory: `rm -rf /tmp/linkedin_testN/ && mkdir /tmp/linkedin_testN/`
2. Spawn `general-purpose` Agent with the prompt from §3.1 (full text in this conversation's transcript).
3. Wait for the structured report.
4. Compare metrics against §5.2 (Run 1) or §7.2 (Run 2).
5. Use any new challenges in the returned `CHALLENGES.md` to drive the next skill-patch cycle.

Approximate cost per run: 90k–190k tokens of subagent activity, 12–50 minutes wall-clock depending on skill maturity.
