# Solid dom-expressions parity (TODO #3) - implementation plan

> Status: **plan only, not started.** This is the design track for closing TODO
> item #3 ("`solid-js/h` (no vite-plugin-solid) caps long-term parity").
>
> **Subordinate to `framework-view-ir-plan.md`.** This is no longer a peer document.
> Solid parity is delivered as the **first consumer of the View IR seam**, not as a
> Solid-only JSX bolt-on. The branch sequence below is the View IR plan's branch
> sequence, with the Solid-specific detail (estree JSX nodes, unparser, `lower_view`
> → JSX, shim self-compile, routing gate) re-homed onto it. Read the View IR plan
> first; this doc assumes its seam ① vocabulary (`ViewElement`, `lower_view`).

## Context

Today all three framework backends (React / Preact / Solid) share **one** JSX
lowering: every JSX element becomes a `__jacJsx(tag, props, children)`
**CallExpression** (`jac/jaclang/jac0core/passes/ast_gen/impl/jsx_processor.impl.jac`,
`element` → factory call at ~L127), which at runtime is `h(...)` (Solid) or
`React.createElement` (React/Preact). Dynamic JSX positions are routed through
`backend.lower_view_expr` - identity on React, a `() => expr` thunk on Solid.

`solid-js/h` is the universal hyperscript *runtime*, not Solid's compiled
`dom-expressions`. That caps parity in three concrete ways (TODO #3):

1. **Reactive spreads are snapshotted.** Spreads lower to `Object.assign({}, …)`
   in the framework-neutral `EsJsxProcessor.element` (`jsx_processor.impl.jac:55-79`),
   which eagerly reads reactive getters and freezes them.
2. **Component callback props vs. reactive props are ambiguous.** The view seam
   keys on a fragile `on[A-Z]` heuristic (`normal_attribute`, ~L224); a function
   prop can be misread as a reactive accessor.
3. **Control flow / keyed lists aren't native** - `.map()` and conditionals lower
   as plain JS instead of Solid's `<For>`/`<Show>`/`<Index>`.

`dom-expressions` resolves all three **structurally at compile time**, which is
why it's the path to "same level as React." Under the View IR plan, #1 and #2 are
fixed in the **producer** (one attribute-classification rule, native `SpreadAttr`)
regardless of backend, and #3 becomes the neutral `IfChild`/`EachChild` nodes; the
Solid-specific work here is the `lower_view` impl that turns those neutral nodes
into JSX estree.

## Solid implements `lower_view` → JSX estree

Under the View IR seam there is no `emits_jsx_syntax` boolean and no "two Solid
output forms." There is one neutral `ViewElement` tree produced by the shared pass,
and each backend implements `lower_view(node: ViewElement)`:

- **React/Preact** - `lower_view` builds `createElement` **call** expressions
  (the shared `JsxFamilyBackend` default).
- **Solid** - `lower_view` builds **JSX estree nodes** that `es_unparse` prints as
  JSX text, then `vite-plugin-solid` (`babel-plugin-jsx-dom-expressions`) compiles.

The call-form-vs-syntax-form distinction is **just two `lower_view` impls**, not a
flag on the producer. (This supersedes the earlier framing of `emits_jsx_syntax` as
a "permanent per-backend capability" and the "the seam stays; the second class does
not" section - both are deleted. The seam is `lower_view`, owned by the View IR
plan.)

### Why JSX *syntax*, not the template form (the one decision that survives)

Two sub-variants of the dom-expressions path:

- **A.1 - emit real JSX *syntax*** (`<div onClick={…}>{count()}</div>`) and let
  `vite-plugin-solid` compile it. ✅ **Chosen.** This is what `SolidBackend.lower_view`
  produces.
- **A.2 - emit the dom-expressions *template form* directly** (`_$template` /
  `_$insert` / `_$createComponent`). ❌ Rejected: that *is* reimplementing Solid's
  compiler - version-coupled and brittle, exactly the "no workarounds, best
  long-term solution" violation AGENTS.md warns against.

So `h` *is the thing dom-expressions exists to replace* - you cannot point
`vite-plugin-solid` at `h(...)` calls. Solid's `lower_view` therefore builds estree
**JSX nodes**; `es_unparse` prints them as JSX text; `vite-plugin-solid` owns
reactivity from there.

### Replace in place - do NOT fork a second backend

**Decision:** evolve the existing `SolidBackend` so its `lower_view` emits JSX, and
**delete the hyperscript path** in the same program. Do *not* ship a
`SolidDomExprBackend` sibling.

Rationale - what the `h`-based backend actually is:

- It is **not** scaffolding next to a "real" Solid backend; it **is** the only Solid
  backend, documented in-code as a "v1 best-effort subset" (`solid.impl.jac:1`,
  `solid.jac:14`).
- `solid-js/h` is Solid's *hyperscript runtime* - the fallback Solid ships for
  environments that can't run the babel transform. dom-expressions is the thing `h`
  exists as a fallback *for*. Every cap in the TODO (snapshotted spreads, no native
  control flow) is **inherent to compiling to hyperscript**, not a v1 shortcut.
- The dom-expr path is therefore **strictly more capable on every axis** the h-path
  is capped on. The only thing hyperscript buys is "no `vite-plugin-solid`
  dependency" - but React/Preact already require a vite plugin, so zero-build-plugins
  is not a property this framework promises, and no consumer needs it.
- The framework identity is `"solid"` (`name()`), not `"solid-h"`. Nothing external
  pins "Solid output is hyperscript"; the only thing pinning `h(...)` is our own
  tests, which the test branch rewrites regardless.

A sibling class would be a strictly-inferior, structurally-capped codepath kept alive
forever - the exact "permanent maintenance surface" the cross-cutting risks flag, and
the kind of workaround AGENTS.md's "best long-term solution" rule rejects.

Delivery safety (ship the new path without destabilizing the shipping one) comes from
the View IR Branch 1 landing inert (React/Preact/Solid all still emit hyperscript via
`JsxFamilyBackend.lower_view`), then Solid's `lower_view` flipping to JSX in a later
branch with the fixture matrix green before the `h` route is deleted.

## Four soundness items (added per review)

These were under-acknowledged in the peer-document framing and are pulled forward so
they are not discovered mid-implementation.

1. **Refs are a Phase 0 spike, not a "passes through" assumption.** Do **not** claim
   the current `lower_ref_field` plain `let` (`solid.impl.jac:91-94`, docstring: refs
   "deferred in v1") "is correct" under dom-expressions. TODO #1 refs are
   `ref={field.ref}` - a **member access** on a `Ref[T]` object, not a bare-identifier
   lvalue. Solid's `ref={ident}` lvalue-assignment transform fires for **simple
   identifiers**; member/accessor refs go down the **callback** path with different
   semantics. TODO #1 is marked `[FIXED]` only for the *hyperscript* seam (it excluded
   `ref` from the thunk so `ref: field.ref` survives) - that says nothing about how
   dom-expressions treats `ref={field.ref}`. **Action:** Phase 0 must verify
   `Ref[T]`-object refs end-to-end through `vite-plugin-solid` (assignment vs callback,
   does the DOM node actually register), and `lower_ref_field` + the ref attribute
   lowering in `lower_view` must be designed around what the spike finds - not assumed.

2. **Async boundaries must flow through View IR (open design question).**
   `lower_async_boundary` (`solid.impl.jac:195-235`) returns `es.Expression` and builds
   `h(Suspense, …)` / `h(ErrorBoundary, …)` **directly** via `jsx_factory_name()` /
   `_jsx_fragment`, bypassing the view producer. Its `try`/`fallback`/`except` are view
   fragments. **These fragments should flow through View IR** - modeled as
   `ComponentTag` `ViewElement`s (`Suspense`/`ErrorBoundary`) whose children/attrs are
   neutral view children - and lowered by `lower_view`. Otherwise Suspense/ErrorBoundary
   stay a per-backend JSX-construction island that will **not** generalize to Svelte's
   `{#await}` / error boundaries. **Open question to resolve in Branch 1/3:** what is the
   neutral View IR shape for an async boundary (a dedicated node, or just
   `ComponentTag` elements)? Flag, decide, don't paper over.

3. **Entry scripts are a real neutrality leak (named as debt).** The entry scripts
   (`solid_entry.jac` - `build_simple_solid_entry_script`,
   `build_pages_solid_entry_script`) hand-concatenate JS **strings** that emit JSX text
   and rely on a `.jsx` extension + vite `include` config to get transformed. This is
   brittle and **will not survive Svelte's mount model**. It is already behind a backend
   seam (`build_*_entry_script`), which is right, but the long-term bootstrap should be
   built as **estree and unparsed**, not string-glued. This program keeps the string
   approach (it is the smallest change that makes Solid build), but **records the
   estree-bootstrap migration as explicit debt** - do not pretend the string seam is the
   end state.

4. **Slot neutrality - do not bake in "slots are just JS."** On Solid the accumulator
   IIFE "just works," so it is tempting to treat `SlotChild` as solved. It is not - the
   View IR plan's three-tier slot analysis (keep accumulator/IIFE synthesis behind the
   **JS-family** `lower_view`; carry the **pristine pre-accumulator** body so Svelte can
   synthesize its own accumulation) is the architecturally honest treatment. The Solid
   work here must **not** introduce any assumption the neutral producer would inherit
   that makes the pre-accumulator body unrecoverable. Defer to
   `framework-view-ir-plan.md` → "Open questions / risks → SlotChild / IIFE slots."

## Phase 0 - Spike / de-risk (throwaway branch or design note)

Pure validation, **no production code**.

- Hand-write a tiny Solid component as JSX, build it through `vite-plugin-solid` in
  jsdom, confirm render + reactivity.
- Pin the exact JSX dialect the babel plugin expects: `class` vs `className`, event
  naming (`onClick`), `ref={fn}` **and** `ref={obj.member}` (soundness item 1),
  `{...spread}`, `<Show>`/`<For>` imports, `innerHTML`. This pins the target string
  the unparser must emit.
- **Refs spike (soundness item 1):** specifically verify a `Ref[T]`-object member ref
  (`ref={field.ref}`) end-to-end - assignment vs callback path, DOM node actually
  registers.
- Pin the **plugin file-extension trigger** (`.jsx`/`.tsx` vs `.js`): emitting `.js`
  silently skips the babel transform.

## Branch sequence (the View IR plan's, re-homed onto Solid)

These are the View IR plan's branches; the Solid-specific detail lives in 2/3/4/5+.

### Branch 1 - View IR + producer refactor (inert)

Owned by `framework-view-ir-plan.md` (its Branch 1). Add `view_ir.jac`; rewrite
`EsJsxProcessor` to produce a neutral `ViewElement` tree; add
`JsxFamilyBackend.lower_view` reproducing today's `__jacJsx`/`h` calls byte-for-byte
(the old `lower_view_expr` thunk relocates **into** the JS-family `lower_view`:
React = identity, Solid-via-h = `() => expr`). React/Preact/Solid all still emit
hyperscript. **This is where soundness items 2 and 4 are settled in the IR:** decide
the async-boundary neutral shape, and ensure `SlotChild` carries the pre-accumulator
body. **Acceptance: existing ecmascript + jsdom suites unchanged.**

Closed *for free* by the producer refactor (no longer Solid-specific work): the
`Object.assign` spread snapshot (#1), the `on[A-Z]` callback/reactive ambiguity (#2),
and the duplicated host-vs-component tag rule - all collapse into producing
`SpreadAttr` / `EventAttr` / `HostTag`/`ComponentTag` once.

### Branch 2 - estree JSX node types + unparser (inert infra)

Solid's `lower_view` output format. No backend uses it yet; land with a round-trip
unit test asserting the exact strings Phase 0 pinned.

- **estree JSX nodes** (`estree.jac`): `JSXElement`, `JSXFragment`,
  `JSXOpeningElement`, `JSXClosingElement`, `JSXAttribute`, `JSXSpreadAttribute`,
  `JSXExpressionContainer`, `JSXEmptyExpression`, `JSXText`, `JSXIdentifier`,
  `JSXMemberExpression`. Mirror the ESTree-JSX spec so it is not ad hoc. (`estree.jac`
  has **no** JSX node types today; confirmed.)
- **es_unparse JSX emission** (`es_unparse.jac`): `gen_jsx_*` methods + dispatch in
  `JSCodeGenerator.generate`. Attribute quoting, `{expr}` containers, self-closing
  tags, fragments `<>…</>`, correct escaping. Reuse `line_map` for source maps.
  (`es_unparse.jac` has **no** JSX output mode today; confirmed.)

### Branch 3 - `SolidBackend.lower_view` → JSX + shim self-compile (the heart)

The load-bearing branch (View IR plan Branch 3). Solid's `lower_view` flips to build
JSX estree nodes; React/Preact untouched. Because there is **one** Solid backend, its
own runtime shim must compile under JSX emission for the backend to be usable at all -
so the shim work merges here rather than trailing behind a backend that can't build
end-to-end.

- **`SolidBackend.lower_view`** builds JSX estree nodes instead of `h(...)` calls.
  Attribute mapping in the JSX path: `className`→`class`; events pass through;
  `ref={…}` per the Phase 0 refs spike (soundness item 1) - **not** assumed pass-through;
  spreads → native `{...obj}` (closes #1); `unsafe_html`→`innerHTML`. The
  component-callback-vs-reactive-prop ambiguity is already gone (resolved in the
  producer, Branch 1).
- **Every site that constructs hyperscript must move onto `lower_view`, not just user
  JSX.** Until all flip, the `solid-js/h` import cannot be removed (Branch 5+), so
  enumerate them:
  1. User JSX - already routed through the producer → `lower_view` (Branch 1).
  2. `lower_async_boundary` (`solid.impl.jac:195-235`) - today builds `h(Suspense,…)`
     / `h(ErrorBoundary,…)` directly. Must construct `ViewElement`s and call
     `lower_view` (soundness item 2), emitting `<Suspense fallback={…}>…</Suspense>` /
     `<ErrorBoundary>`.
  3. `_jsx_fragment` (inherited from `ReactBackend`) - the async-boundary fallbacks
     route through it; under View IR fragments are `FragmentTag` `ViewElement`s, so this
     helper is removed, not overridden.
  4. **Entry scripts** (`solid_entry.jac`) - string-build `render(() => h(...))`. They
     are raw JS handed to vite, not run through the view pipeline, so they need JSX text
     directly (and the `.jsx` extension / `include` config). Kept as strings this
     program but recorded as estree-bootstrap debt (soundness item 3).
- **Shim self-compilation:** `solid_runtime.cl.jac` is itself compiled by this backend,
  so its own JSX (JacForm, ErrorFallback, errorOverlay) flips to JSX form - verify it
  compiles and runs. The `@solidjs/router` adapters (`Routes`/`Route`/`Outlet`, all
  returning `JsxElement`) likely build JSX in their bodies, so do **not** assume
  "router/form adapters are not JSX-dependent" - verify; if they construct elements they
  flip under self-compile too. Folding this in here removes the window where the backend
  exists but its runtime is unvalidated.
- **Routing / pages path is a second surface.** Rendering is client-side `render` from
  `solid-js/web` - there is **no `hydrate`, so SSR is explicitly out of scope** (no
  `generate: 'ssr'` / hydration modes). The file-based routing entry
  (`build_pages_solid_entry_script`) is a hyperscript site (enumerated above) and the
  `solid_routing` fixtures exercise it. **Acceptance gate: the `solid_routing` fixtures
  stay green.**
- **jsdom harness:** replace the raw `es_to_js` + `import "solid-js/h"` model with a real
  `vite-plugin-solid` build step before mounting (mirrors `jac client build`). Pin the
  output **file extension** the plugin transforms (Phase 0).
- **Test-env deps ≠ emitted deps.** This harness needs `vite-plugin-solid` installed in
  the **repo's** dev/test environment *now* - distinct from the deps the compiler emits
  into a generated project's `package.json` (Branch 5+). The test dep lands here (and in
  Phase 0); the emitted dep later. Trade accepted deliberately: moving from `es_to_js`
  to a full vite build makes these tests heavier/slower and couples the suite to the
  babel toolchain.
- **No control flow yet** - `.map()` / conditionals still render via the JS-family path
  (works, just not keyed/native).

### Branch 4 - native control flow / keyed lists

View IR plan Branch 4. The producer emits neutral `IfChild`/`EachChild` (per the
lifting heuristic in `framework-view-ir-plan.md` → "Control flow & the lifting
heuristic"); Solid's `lower_view` turns them into `<Show>`/`<For>`/`<Index>` and
auto-injects the `solid-js` imports. **Detection is not Solid-specific** - it produces
neutral nodes; the soundness traps (`&&` falsy leak gated on boolean-typed test;
ternary arm shapes; comprehension multiplicities; lift only when provably pure)
live in the View IR plan and are not re-specified here. Can stage Show → For → slot.

### Branch 5+ - bundler/deps, tests/fixtures, delete the `h` route

View IR plan Branch 5+ (Solid plan's old Phases 5–7).

- **Bundler/deps:** `SolidBackend.vite_plugin_lines` →
  `('import solidPlugin from "vite-plugin-solid";', 'solidPlugin()')` (the per-backend
  override at `vite_bundler.impl.jac:395` returns `None` today). `_default_client_deps("solid")`
  dev_deps gains `vite-plugin-solid`; drop the "no vite-plugin-solid" comment in
  `client_deps.impl.jac`. This is the **emitted** dep (distinct from the test dep in
  Branch 3).
- **Tests/fixtures:** rewrite `test_solid_backend.jac` string assertions (currently pin
  `h(...)`) to assert JSX output. New jsdom fixtures for the TODO matrix: dynamic
  prop/child, explicit ref (soundness item 1), component-callback prop, spread
  reactivity, `<For>` list, `<Show>` conditional.
- **Delete the hyperscript path:** the migration is complete only when the old path is
  **gone**, not bypassed. Remove the `solid-js/h` import, the obsolete thunk logic now
  living in the JS-family `lower_view`'s Solid branch, and any dead `h`-construction.
  Gate on the fixture matrix being green. Update contract §8 gap list (refs, spreads,
  control-flow now closed per their actual spike/impl outcomes); flip Solid from
  "experimental subset" toward parity, documenting any residue. Release note with PR
  number.

## Cross-cutting risks

- **Two `lower_view` impls** (call form for React/Preact, JSX-syntax form for Solid) -
  a legitimate per-backend distinction expressed as two implementations of the seam,
  **not** a flag on the shared producer and **not** two Solid lowerings. (Supersedes the
  earlier "two JSX output forms / `emits_jsx_syntax` is permanent" framing.)
- **Async-boundary neutrality** (soundness item 2) - if Suspense/ErrorBoundary do not go
  through View IR they become a Svelte-blocking island. Resolve the neutral shape in
  Branch 1/3.
- **Entry-script string-glue debt** (soundness item 3) - brittle, Svelte-hostile;
  long-term should be estree-built. Named, not fixed, here.
- **Slot neutrality** (soundness item 4) - keep accumulator synthesis behind the
  JS-family `lower_view`; carry the pristine pre-accumulator body. See View IR plan.
- **Version coupling** to `vite-plugin-solid` / dom-expressions.
- **Source maps** now pass through an extra babel layer (our map → JSX text →
  vite-plugin-solid remap); the debugging story changes. Needs an explicit acceptance
  check (breakpoint / stack-trace test) in Branch 3 or 5.
- **Plugin trigger by file extension** - `vite-plugin-solid` transforms `.jsx`/`.tsx` by
  default; our codegen emits `.js`. If unaddressed the transform silently no-ops and
  untransformed JSX ships. Pin in Phase 0, own the fix in Branch 5+.
- **Component-vs-host tag resolution** - resolved **once** in the producer
  (`HostTag`/`ComponentTag`/`FragmentTag`/`DynamicTag`), so it is no longer duplicated
  across call-form and syntax-form paths (View IR plan).
- **Control-flow lifting changes semantics if too eager** - the `{0 && <X/>}` falsy leak
  (renders `0` vs nothing) is the sharp edge; bias toward not lifting. Full treatment in
  the View IR plan.

## Suggested branch order

1. **Branch 1** (View IR + producer refactor, inert) - load-bearing, low-risk, lands
   first; settles async-boundary and slot neutrality in the IR.
2. **Branch 2** (estree JSX nodes + unparser, inert) with a round-trip test.
3. **Branch 3** - the heart: `SolidBackend.lower_view` → JSX **plus** shim
   self-compilation. End-to-end render works here.
4. **Branch 4** - control flow.
5. **Branch 5+** - bundler/deps, tests/fixtures, then delete the hyperscript path and
   flip the docs/default.

Branches 1–2 are low-risk and unlock everything else, so start there after the Phase 0
spike confirms the toolchain (dialect, **refs**, and file-extension trigger).

## Key file map

- `jac/jaclang/compiler/passes/ecmascript/view_ir.jac` - **new** View IR (Branch 1, View IR plan)
- `jac/jaclang/jac0core/passes/ast_gen/impl/jsx_processor.impl.jac` - becomes the View IR producer (Branch 1)
- `jac/jaclang/compiler/passes/ecmascript/framework_backend.jac` - drop `jsx_factory_name`/`lower_view_expr`/`_jsx_fragment`; add `lower_view` (Branch 1/3)
- `jac/jaclang/compiler/passes/ecmascript/backends/impl/react.impl.jac` - host the shared `JsxFamilyBackend.lower_view` (createElement calls)
- `jac/jaclang/compiler/passes/ecmascript/estree.jac` - JSX node defs (Branch 2)
- `jac/jaclang/compiler/passes/ecmascript/es_unparse.jac` - JSX emission (Branch 2)
- `jac/jaclang/compiler/passes/ecmascript/backends/solid.jac` + `impl/solid.impl.jac` - `lower_view` → JSX; delete the `h` path (Branch 3/5+)
- `jac/jaclang/runtimelib/solid_runtime.cl.jac` (+ impl) - shim self-compilation; router adapters (Branch 3)
- `jac/jaclang/runtimelib/solid_entry.jac` - entry scripts; JSX in `render(...)`; estree-bootstrap debt (Branch 3)
- `jac/tests/runtimelib/fixtures/solid_routing/` - routing acceptance gate (Branch 3)
- `jac/jaclang/runtimelib/client/impl/client_deps.impl.jac` - emitted deps (Branch 5+)
- `jac/jaclang/runtimelib/client/impl/vite_bundler.impl.jac` - plugin wiring (Branch 5+)
- `jac/tests/compiler/passes/ecmascript/test_solid_backend.jac`, `jac/tests/runtimelib/test_solid_jsdom.jac` - tests (Branch 5+)
</content>

</invoke>
