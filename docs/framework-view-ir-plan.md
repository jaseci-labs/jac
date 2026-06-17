# Framework-neutral View IR (Option B) - generalization sketch

> Status: **design sketch.** Primary architecture document; read before
> `solid-dom-expressions-plan.md`, which is **subordinate** and delivers Solid parity
> as the **first consumer** of this seam. This doc defines the View IR (seam ①), the
> branch sequence, and the Svelte-readiness constraints; the Solid-specific work
> (estree JSX nodes, unparser, `SolidBackend.lower_view`, shim self-compile, routing
> gate, Phase 0 spike) is detailed in the subordinate doc and re-homed onto this
> branch sequence.

## Why a boolean (`emits_jsx_syntax`) is not enough

The current abstraction is neutral only among **JS-AST + JSX** frameworks. Two hard
couplings prove it:

1. **The view tree is lowered straight to ESTree, in shared code.**
   `EsJsxProcessor.element` (`jsx_processor.impl.jac`) walks `uni.JsxElement` and
   directly builds `__jacJsx(tag, props, children)` **CallExpression** nodes. The
   backend is consulted only through three thin holes - `jsx_factory_name`,
   `lower_view_expr` (the thunk), `_jsx_fragment`. There is no framework-neutral
   *view* representation; there is only "ESTree calls, with two knobs."

2. **A component is assumed to be a JS function returning a view expression.** The
   whole module lowers to one ESTree `Program` → one `.js` in `/compiled/`. Svelte
   components are a **separate document format** (`.svelte` = `<script>` + template),
   not an expression spliced into a JS module.

Carrying embedded *expressions* as `es.Expression` is **not** a leak: `<script>`
bodies and `{…}` interpolations are JavaScript in React, Solid, **and** Svelte. The
leak is purely in the view **structure** - which is exactly what the View IR
neutralizes.

`emits_jsx_syntax: bool` only toggles coupling #1 between its two JS shapes
(`createElement` calls vs JSX text). It cannot express "emit a template language"
and says nothing about coupling #2. So it is the right *local* fix for Solid and the
wrong *seam* for the stated goal.

## The two seams

Generalization needs exactly two new seams. Reactive-intent lowering
(`lower_state_field`/`lower_effect`/…) already abstracts correctly and is reused
verbatim - Svelte just implements those with runes.

```diagram
        Jac surface AST (uni.JsxElement, uni.Ability, has-state …)
                              │
              ┌───────────────┴────────────────┐
              │  EsastGenPass (shared)          │
              │  • lowers Jac Expr → es.Expr    │  ← reused by ALL targets
              │  • builds reactive_intent recs  │  ← reused by ALL targets
              │  • builds VIEW IR (seam ①)      │  ← NEW: replaces EsJsxProcessor
              └───────────────┬─────────────────┘
                              │  ViewElement tree (framework-neutral)
                              │  + reactive_intent records
                              ▼
              ┌─────────────  FrameworkBackend  ──────────────┐
   seam ②     │ render_component(ComponentIR) -> EmittedUnit  │
 (packaging)  │   ├─ JS family: ESTree Program  → .js         │
              │   └─ Svelte:    .svelte document → .svelte    │
              │ lower_view(ViewElement) -> <target view>      │  ← seam ① consumer
              └───────────────┬───────────────────────────────┘
            ┌─────────────────┼─────────────────┐
            ▼                 ▼                  ▼
     React/Preact          Solid              Svelte
  createElement calls   JSX estree → text   template text
     (es.Expression)     (es.Expression)    (SvelteTemplate)
```

- **Seam ① - View IR (the deliverable now).** A small, output-agnostic view tree
  the shared pass *produces* and each backend *consumes*. This is "Option B."
- **Seam ② - Component packaging (built when Svelte lands).** Lets a backend own how
  a whole component is emitted and what file it becomes. The View IR is **designed to
  be compatible with it now** so it never needs redesigning; only seam ① is built in
  this program.

## Seam ① - the View IR node set

A new module, e.g. `jac/jaclang/compiler/passes/ecmascript/view_ir.jac`, sibling to
`reactive_intent.jac`. Same principle: structural facts, **no** framework lowering.
Dynamic JS is carried as already-lowered `es.Expression` (shared across all targets);
the **structure** stays neutral until a backend lowers it.

```jac
"""Framework-neutral view vocabulary. Embedded expressions are already lowered
to ESTree (shared across targets); structure is lowered by the active backend."""

obj ViewElement {
    has tag: ViewTag,
        attrs: list[ViewAttr],
        children: list[ViewChild],
        is_self_closing: bool = False;
}

# --- tag, resolved ONCE (kills the duplicated host-vs-component rule) ---
obj HostTag      { has name: str; }                    # <div>
obj ComponentTag { has ref: es.Expression; }           # <App>, <Foo.Bar>
obj FragmentTag  {}                                     # <>…</>
obj DynamicTag   { has expr: es.Expression; }           # <@expr …>
# ViewTag = HostTag | ComponentTag | FragmentTag | DynamicTag

# --- attributes, classified ONCE (kills the fragile on[A-Z] heuristic) ---
obj StaticAttr  { has name: str, value: (str | bool); }       # class="x", disabled
obj DynamicAttr { has name: str, value: es.Expression; }      # value={expr}
obj EventAttr   { has name: str, handler: es.Expression; }    # onClick={fn}
obj RefAttr     { has target: es.Expression; }                # ref={el}
obj SpreadAttr  { has value: es.Expression; }                 # {...obj}
# ViewAttr = StaticAttr | DynamicAttr | EventAttr | RefAttr | SpreadAttr

# --- children ---
obj TextChild    { has value: str; }
obj DynamicChild { has value: es.Expression; }                # {expr}
obj ElementChild { has element: ViewElement; }
obj SlotChild    { has body: list[es.Statement], result_is_fragment: bool; }  # imperative slot
# Phase-4 control flow lives here as NEUTRAL nodes - the one place where Solid's
# <Show>/<For> and Svelte's {#if}/{#each} diverge cleanly per backend:
obj IfChild   { has test: es.Expression, consequent: list[ViewChild],
                alternate: (list[ViewChild] | None) = None; }
obj EachChild { has items: es.Expression, item: str, key: (es.Expression | None),
                body: list[ViewChild]; }
# ViewChild = TextChild | DynamicChild | ElementChild | SlotChild | IfChild | EachChild
```

**Critical invariant:** the View IR carries the dynamic value as a *neutral*
`es.Expression` - it does **not** pre-apply `lower_view_expr` thunking. The thunk
(or `{expr}` JSX, or `{expr}` Svelte interpolation) is the backend's job. That is
what makes the same tree serviceable by React (use as-is), Solid (auto-wrap), and
Svelte (template interpolation). `lower_state_read` stays where it is (expression
lowering), untouched.

**`SlotChild` is the least-neutral node - keep its accumulator synthesis behind
`lower_view`, not in the IR.** A `JsxSlot` (`{ stmt; … }` statement-form child) lowers
*today* to an accumulator IIFE: `(() => { let __jac_view_kids = []; …push…; return
<fragment>; })()`, synthesized in `EsastGenPass.exit_jsx_slot`/`_build_view_iife`. That
`push`-accumulator model is a **JS-family lowering detail**, not a neutral fact - and
it is exactly what Svelte templates cannot consume. The IR's `SlotChild` should carry
the body as close to the author's pristine statements as the JS-family lowering allows;
the IIFE/accumulator construction belongs in the JS-family `lower_view`. See the
three-tier slot analysis under *Open questions / risks*.

## Seam ① - backend interface change

`FrameworkBackend` (`framework_backend.jac`) **loses** the three JSX-shaped holes
and **gains** one view consumer:

```jac
# REMOVE: def jsx_factory_name -> str;
# REMOVE: def lower_view_expr(expr: es.Expression) -> es.Expression;
# REMOVE: def _jsx_fragment(children) -> es.CallExpression;   (ReactBackend helper)

# ADD: lower a neutral view tree to this backend's target view form.
def lower_view(node: ViewElement) -> ViewOutput;
```

Removal timing: keep the three holes through Branch 1 (the inert producer refactor)
because `lower_async_boundary`/`_jsx_fragment` still build `h(...)` directly and are
not refactored until Branch 3. Delete them in Branch 3/Phase 7, where the Solid plan
already removes the thunk. The `lower_view_expr` thunk relocates **into** the
JS-family `lower_view` (React = identity, Solid-via-hyperscript = `() => expr`); it is
not lost in Branch 1, only moved off the public interface.

`ViewOutput` is the one place the JS-family / Svelte split surfaces. Two honest
options - pick when Svelte actually lands, **not** now:

- **Now (JS family only):** `lower_view -> es.Expression`. A `JsxFamilyBackend` mixin
  holds the shared "build createElement calls" default; Solid overrides to build JSX
  estree nodes. EsastGenPass splices the returned `es.Expression` into the component
  function exactly as today.
- **When Svelte lands:** widen via seam ② (below). `lower_view` returns a
  backend-associated artifact (`es.Expression` for JS family, a `SvelteTemplate`
  fragment for Svelte), and EsastGenPass hands component emission to the backend.

Keeping `ViewOutput = es.Expression` until Svelte means **zero speculative
generality** today while the node set above is already Svelte-shaped.

## Seam ② - component packaging (sketch only; built with Svelte)

Today EsastGenPass owns "module → one ESTree Program → one `.js`." Svelte breaks
that. The minimal future seam:

```jac
obj ComponentIR {            # what the shared pass already computes per component
    has name: str,
        state: list[StateField], refs: list[RefField],
        effects: list[Effect], handlers: list[...],   # lowered es statements
        view: ViewElement;                            # seam ① output, pre-lowering
}

# FrameworkBackend gains:
def render_component(c: ComponentIR) -> EmittedUnit;   # (filename, source_text)
```

- **JS family** `render_component`: assemble the function body from the
  reactive-intent lowerings + `lower_view(view)` expression → ESTree → `.js`
  (literally what EsastGenPass does inline today, lifted behind the seam).
- **Svelte** `render_component`: emit `<script>` from the same lowered statements
  (runes), `lower_view(view)` → template text, write `Name.svelte`.

This doc does **not** build seam ② - it exists so seam ①'s View IR is provably
sufficient (it carries everything `render_component` needs) and so we don't paint the
View IR into a "JS-expression only" corner.

## What seam ① fixes for free (beyond enabling Svelte)

- **One tag-resolution rule.** `HostTag/ComponentTag/FragmentTag/DynamicTag` is
  computed once in the producer - retires "component-vs-host resolution … must derive
  from one rule, not duplicated across call-form and syntax-form paths."
- **One attribute-classification rule.** The fragile `on[A-Z]` heuristic + the
  `ref`/spread special-cases in `normal_attribute` collapse into producing
  `EventAttr`/`RefAttr`/`SpreadAttr`/`DynamicAttr` once. Backends never re-sniff names.
  Closes TODO #2's "component callback vs reactive prop" ambiguity structurally.
- **Control flow has a home.** `IfChild`/`EachChild` give Phase 4 (Show/For) and
  future Svelte `{#if}`/`{#each}` a single neutral representation instead of
  per-backend JS pattern-matching.
- **Spreads stop being snapshotted in shared code.** The `Object.assign({}, …)` in
  `EsJsxProcessor.element` disappears; `SpreadAttr` is lowered natively per backend
  (`{...obj}` JSX for Solid, merged props object for React).

## Control flow & the lifting heuristic (Phase 4)

Phase 4 produces the `IfChild`/`EachChild` nodes. For React/Solid this is **optional
polish** - `&&`/`?:`/`.map()`/the slot IIFE already render correctly; lifting just
buys `<Show>`/`<For>` keyed reconciliation. For **Svelte it is mandatory coverage**:
there is no `&&`/`.map()`/IIFE *in markup*, so anything not lifted into
`IfChild`/`EachChild` becomes residue Svelte cannot render idiomatically. The size of
the Svelte-impossible set is therefore exactly what the lifting heuristic fails to
recognize.

### Two doors, partitioned by the parser

`parse_jsx_child` (`parser.impl.jac`) already splits view control flow by leading
token. Detection runs in the producer, on the **Jac AST** (where an `IfStmt` or a
comprehension is unambiguous - after lowering, a `for` and a `.map` blur together):

| Source form | AST node | lowers today to | Phase-4 target |
|---|---|---|---|
| `{[<li key=…> for x in xs]}` | comprehension in `JsxExpression` | `xs.map(...)` | `EachChild` |
| `{cond ? <A/> : <B/>}`, `{cond and <X/>}` | ternary / bool-expr | `?:` / `&&` | `IfChild` |
| `{ if c { <X/> } }`, `{ for x in xs { <li> } }` | `JsxSlot.body` statements | accumulator IIFE | `IfChild` / `EachChild` |

**Expression-form (the dominant idiom here - keyed, sometimes-filtered
comprehensions).** Two details fall out for free:

- The **key is already authored** on the child (`<li key={item.id}>`); the producer
  lifts it onto `EachChild.key` → `{#each items as item (item.id)}` (Svelte) / keyed
  `<For>` (Solid). The key is never lost.
- A **filter folds into `items`**: `… for x in xs if pred` → `xs.filter(x => pred)` as
  `EachChild.items` (no filter field needed; `{#each}` has no filter clause).

**Statement-form (`JsxSlot`).** Lift to `IfChild`/`EachChild` **only** when the body is
*exactly one* control-flow statement (`IfStmt` / `InForStmt`) whose every branch's
**only leaf action is emitting JSX** - no assignment, no non-JSX call, no
declared-and-reused local, no `skip`/early-exit. Anything else stays `SlotChild`
(tier 3). `while` has no declarative `{#each}` form and never lifts.

### Lift only when provably pure - the asymmetry

The two failure modes are wildly asymmetric, so the matcher must be strict and boring:

- **False lift** (lifting an impure body) = a **semantic bug** - drops a side effect or
  changes rendering.
- **False non-lift** (leaving a liftable shape as a slot) = **tier-3 residue** - works
  *perfectly* on React/Solid via the IIFE; only costs Svelte idiomaticity.

Bias hard toward not lifting. This also makes Phase 4 safely incremental (Show, then
For, then slot-lifting): each step only *adds* recognized shapes.

### Soundness traps to pin

- **The `&&` falsy leak.** `{0 && <X/>}` renders `0` in JSX/React; `{#if 0}` renders
  nothing in Svelte. Lifting `cond and <X/>` → `IfChild` → `{#if}` silently changes
  falsy-value rendering. **Guard:** only lift `&&` when `test` is boolean-typed;
  otherwise leave it as a `DynamicChild` (or document the divergence). Ternary has no
  such trap (explicit arms), so prefer ternary detection and be cautious with `&&`.
- **Ternary arm shapes.** Lift to `IfChild` only when both arms are view-shaped
  (`null`/text arms are fine → empty/`TextChild`). `cond ? x : y` over arbitrary
  expressions stays a `DynamicChild`.
- **Comprehension multiplicities.** Nested `for`s → nested `EachChild` (the matcher
  must recurse); a comprehension whose element is not view-shaped stays a
  `DynamicChild`.

Net: conservative lifting catches the idiomatic ~90% (keyed/filtered comprehensions,
ternaries, single-`if`/single-`for` slots). The residue is *genuinely imperative view
code* - fair to document as a Svelte limitation or route through a generated
child-component escape hatch.

## Branch sequence

`solid-dom-expressions-plan.md` Phases 1–2 (JSX estree nodes + `es_unparse` JSX
emission) **stay**, but their role changes: no longer "a second global output form
bolted to the shared JSX pass" - they become **the Solid backend's `lower_view`
implementation detail**. `emits_jsx_syntax` is **deleted, not introduced**: the
call-vs-syntax distinction is now just two `lower_view` impls.

- **Branch 1 - View IR + producer refactor (inert).** Add `view_ir.jac`; rewrite
  `EsJsxProcessor` to emit View IR; add `JsxFamilyBackend.lower_view` reproducing
  today's `__jacJsx` calls byte-for-byte (thunk re-applied here for Solid-via-h).
  React/Preact/Solid all still emit hyperscript. **Acceptance: existing ecmascript +
  jsdom suites unchanged.** Load-bearing, low-risk, lands first.
- **Branch 2 - JSX estree nodes + unparser** (Solid plan Phases 1–2) with a round-trip
  unit test. Inert (no backend uses it yet).
- **Branch 3 - `SolidBackend.lower_view` → JSX** (Solid plan Phase 3 + shim
  self-compile). Solid flips to JSX; React/Preact untouched. Delete `jsx_factory_name`/
  `lower_view_expr`/`_jsx_fragment`; async-boundary and fragment construct
  `ViewElement`s and call `lower_view`; only the string-built entry scripts remain a
  separate hand-emit.
- **Branch 4 - control flow.** `IfChild`/`EachChild` per the lifting heuristic above
  (Solid plan Phase 4).
- **Branch 5+ - bundler/deps, then delete the old Solid `h` route** (Solid plan
  Phases 5–7).
- **Later - Svelte.** Add seam ② (`render_component` + `EmittedUnit`), a `SvelteBackend`
  implementing `lower_view -> SvelteTemplate` and runes-based reactive-intent lowering,
  and `.svelte` output wiring in the bundler. The View IR, the reactive-intent records,
  and the Jac→ES expression lowering are all reused.

## Open questions / risks

- **Async boundaries must flow through the View IR (open design question).**
  `lower_async_boundary` (`solid.impl.jac:195-235`, mirrored on React) today builds
  `Suspense`/`ErrorBoundary` JSX **directly** as call expressions from an
  `AsyncBoundary` reactive-intent record whose `try`/`fallback`/`except` are view
  fragments - bypassing the producer entirely. If those fragments do **not** become
  View IR (`ComponentTag` `ViewElement`s, or a dedicated `AsyncBoundaryChild` node),
  Suspense/ErrorBoundary stay a per-backend JSX-construction island that will **not**
  generalize to Svelte's `{#await}` / error boundaries. **Decide the neutral shape in
  Branch 1** (dedicated node vs `ComponentTag` elements) so Branch 3 can route
  async-boundary lowering through `lower_view` like everything else. See
  `solid-dom-expressions-plan.md` → soundness item 2.
- **`ViewOutput` widening timing.** Keeping it `es.Expression` until Svelte is the
  no-speculation choice, but it means seam ② is a real (small) refactor of EsastGenPass
  when Svelte lands. Acceptable: the View IR node set is the expensive part and it is
  built Svelte-ready now.
- **`SlotChild` / IIFE slots in Svelte - the one place "carry structure neutrally"
  needs active discipline.** Jac's `{ stmt; … }` slot lowers to an accumulator IIFE on
  JS targets; Svelte markup has no expression-statement-in-template equivalent. The
  risk decomposes into three tiers:
  1. **single expression** - already a `JsxExpression`, never a slot → `{expr}`,
     trivial.
  2. **disguised declarative** (`if c { <X/> }`, `for x in xs { <li> }`) - lifted by
     Phase 4 into `IfChild`/`EachChild` → `{#if}`/`{#each}`, clean on every backend.
     Phase 4 is what *shrinks* this tier; it is load-bearing for Svelte, not a Solid
     nicety.
  3. **genuinely imperative** (local mutation, `while`, `try`/`await`/`except`
     accumulation) - no declarative Svelte form. Maps, in decreasing fidelity, to
     `{@const}`/`$derived` (compute-then-use only), `{#snippet}`+`{@render}`, a
     generated child component, or a documented Svelte-target limitation.

  This never blocks React/Solid (the IIFE is a valid expression). It is **bounded and
  non-poisoning**: `SlotChild` is the correct neutral node *for the JS family*. But
  "not a View IR change" is optimistic for tier 3 - Svelte will likely need `SlotChild`
  to carry the **pristine, pre-accumulator** body so each backend synthesizes its own
  accumulation. Decision for now: keep accumulator/IIFE synthesis behind the JS-family
  `lower_view`, not in the IR.
- **Source maps** still pass `Jac → es → (Solid) JSX text → vite-plugin-solid`;
  unchanged from the Solid plan. Svelte adds its own map layer later.
- **Producer/consumer line-map ownership.** `sync_loc` currently tags ESTree nodes in
  the producer; with the split, the producer tags View IR nodes and each backend must
  carry `jac_node` provenance into its target. Keep `jac_node` on every View IR node so
  backends can `sync_loc` on lowering.

## Key file map

- `jac/jaclang/compiler/passes/ecmascript/view_ir.jac` - **new** View IR (seam ①)
- `jac/jaclang/jac0core/passes/ast_gen/impl/jsx_processor.impl.jac` - becomes the View
  IR producer (`ViewBuilder`); stops building ESTree calls
- `jac/jaclang/compiler/passes/ecmascript/framework_backend.jac` - drop
  `jsx_factory_name`/`lower_view_expr`/`_jsx_fragment` (Branch 3); add `lower_view`
- `jac/jaclang/compiler/passes/ecmascript/backends/impl/react.impl.jac` - host the
  shared `JsxFamilyBackend.lower_view` (createElement calls)
- `jac/jaclang/compiler/passes/ecmascript/backends/impl/solid.impl.jac` -
  `lower_view` → JSX estree nodes
- `jac/jaclang/compiler/passes/ecmascript/estree.jac` / `es_unparse.jac` - JSX node
  types + emission (Solid plan Phases 1–2), now scoped as Solid's `lower_view` impl
- *(later)* `…/backends/svelte.jac` + seam ② (`render_component`/`EmittedUnit`)
