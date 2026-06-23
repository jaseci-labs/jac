"""Framework-neutral view vocabulary (seam ①).

Sibling to `reactive_intent.jac`: these records hold structural facts about a
JSX view tree with **no** framework-specific lowering. The shared producer
(`EsJsxProcessor`) builds a `ViewElement` tree; the active `FrameworkBackend`
consumes it via `lower_view`. React/Preact/Solid all lower it to a `__jacJsx`
factory call today; a future Svelte backend lowers the same tree to template
text without the producer changing.

**Critical invariant (contract / view-ir-plan):** embedded dynamic values are
carried as *already-lowered* `es.Expression`s, **neutral** — the producer does
**not** pre-apply the Solid view thunk (`() => expr`). Wrapping a dynamic
position is the backend's job inside `lower_view` (no-op on React/Preact, thunk
on Solid). That is what lets the same tree serve a re-render backend, a signals
backend, and a template backend.

Every node carries its originating `jac_node` so a backend can `sync_loc` the
ESTree (or template fragment) it emits and keep source-map provenance — the
producer hands its `sync_loc` to `lower_view`. `jac_node` is `None` for nodes a
backend *synthesizes* (no source span — e.g. the `Suspense`/`ErrorBoundary`
`ViewElement`s built in `lower_async_boundary`); `sync_loc` treats `None` as
"fall back to the pass's current node", so the seam stays uniform.

Scope: the Branch 1 node set (the View IR producer refactor) plus the Branch 4
native control-flow nodes (`IfChild`/`EachChild`). The producer lifts the
idiomatic JSX control-flow shapes — keyed/filtered comprehensions and
view-shaped ternaries — into these neutral nodes; Solid's `lower_view` turns
them into `<For>`/`<Show>` and a future Svelte backend into `{#each}`/`{#if}`.
"""

import jaclang.compiler.passes.ecmascript.estree as es;
import jaclang.jac0core.unitree as uni;

# --- tag, resolved ONCE in the producer (kills the duplicated host-vs-component
#     rule that otherwise gets re-derived per backend) -------------------------
"""A host element tag — `<div>`. Lowered to the tag-name string literal."""
obj HostTag {
    has name: str,
        jac_node: (uni.UniNode | None);
}

"""A component tag — `<App>`, `<Foo.Bar>`. `ref` is the already-built reference
expression (an `Identifier` or member chain) the element name lowered to."""
obj ComponentTag {
    has ref: es.Expression,
        jac_node: (uni.UniNode | None);
}

"""A fragment tag — `<>…</>` (or a nameless element). Lowered to a null tag."""
obj FragmentTag {
    has jac_node: uni.UniNode;
}

"""A dynamic tag — `<@expr …>`. `expr` is the already-built tag expression."""
obj DynamicTag {
    has expr: es.Expression,
        jac_node: (uni.UniNode | None);
}

# --- attributes, classified ONCE in the producer (kills the fragile `on[A-Z]`
#     heuristic + `ref`/spread special-casing re-derived per backend) ----------
"""A static attribute — `class="x"`, `disabled`. `value` is the literal the
producer built (string literals are HTML-unescaped and scoped-style class tokens
are already rewritten); a value-less attribute carries a `true` literal."""
obj StaticAttr {
    has name: str,
        value: es.Expression,
        jac_node: (uni.UniNode | None);
}

"""A dynamic attribute — `value={expr}`. `value` is the neutral, un-thunked
expression; the backend wraps it (Solid) or passes it through (React/Preact)."""
obj DynamicAttr {
    has name: str,
        value: es.Expression,
        jac_node: (uni.UniNode | None);
}

"""An event handler attribute — `onClick={fn}` (the `on[A-Z]…` DOM convention).
Never thunked: wrapping a handler would defer the callback itself, not a read."""
obj EventAttr {
    has name: str,
        handler: es.Expression,
        jac_node: (uni.UniNode | None);
}

"""A ref attribute — `ref={el}`. An imperative element hook, never thunked: the
runtime calls the ref with the DOM node (a thunk would swallow the element)."""
obj RefAttr {
    has name: str,
        value: es.Expression,
        jac_node: (uni.UniNode | None);
}

"""A spread attribute — `{...obj}`. `value` is the already-built object expr."""
obj SpreadAttr {
    has value: es.Expression,
        jac_node: (uni.UniNode | None);
}

# --- children ----------------------------------------------------------------
"""Static text — `Hello`. `value` is the HTML-unescaped string literal."""
obj TextChild {
    has value: es.Expression,
        jac_node: (uni.UniNode | None);
}

"""A dynamic child — `{expr}`. `value` is the neutral, un-thunked expression;
the backend wraps it (Solid) or passes it through (React/Preact)."""
obj DynamicChild {
    has value: es.Expression,
        jac_node: (uni.UniNode | None);
}

"""A nested element child — the producer carries the child's `ViewElement` so the
backend lowers the whole tree in one pass (rather than splicing pre-lowered
sub-expressions, which would freeze each child to the first backend that ran)."""
obj ElementChild {
    has element: ViewElement,
        jac_node: (uni.UniNode | None);
}

"""A statement-form slot child — `{ stmt; … }`.

The accumulator IIFE is synthesized in `EsastGenPass` *before* the view producer
runs, so `expr` here is the already-built IIFE `es.Expression`, emitted verbatim
(never thunked). **Debt (view-ir-plan soundness item 4):** the IIFE/accumulator
shape is a JS-family lowering detail, not a neutral fact — a template backend
(Svelte) cannot consume it. The honest end state carries the *pristine
pre-accumulator* body here and synthesizes accumulation behind the JS-family
`lower_view`; that refactor of the slot pipeline is deferred (it is not inert)
and tracked with the Svelte/slot work, not forced into this producer refactor."""
obj SlotChild {
    has expr: es.Expression,
        jac_node: (uni.UniNode | None);
}

# --- native control flow (Branch 4) -----------------------------------------
# The one place where Solid's `<Show>`/`<For>` and Svelte's `{#if}`/`{#each}`
# diverge cleanly per backend. The producer lifts only the *idiomatic, provably
# pure* shapes here (view-shaped ternaries, keyed/filtered comprehensions);
# everything else stays a `DynamicChild`/`SlotChild` and renders via the
# author's original expression. Both nodes carry `js_fallback` — the already
# lowered `?:`/`.map()` `es.Expression` the producer would otherwise have
# emitted — so a JS-family backend (React/Preact) renders it **verbatim**
# (byte-for-byte unchanged), while Solid/Svelte consume the neutral
# decomposition. This mirrors `SlotChild` carrying its prebuilt accumulator
# IIFE: a JS-family lowering artifact riding alongside the neutral facts, never
# consumed by a template backend.
"""A conditional view child — `{<A/> if cond else <B/>}` (a view-shaped ternary).
`test` is the neutral condition expression; `consequent`/`alternate` are neutral
child lists (`alternate` is `None` for a `… else None` arm). Solid lowers this to
`<Show when={test} fallback={…}>…</Show>`; Svelte to `{#if}`. The `&&` short-form
is intentionally NOT lifted (its falsy-value rendering — `{0 && <X/>}` shows `0`
in JSX but nothing under `{#if}` — would silently change), so it stays a
`DynamicChild`."""
obj IfChild {
    has test: es.Expression,
        consequent:
            list[
                TextChild | DynamicChild | ElementChild | SlotChild | IfChild | EachChild
            ],
        alternate:
            (
                list[
                    TextChild | DynamicChild | ElementChild | SlotChild | IfChild | EachChild
                ] | None
            ),
        js_fallback: es.Expression,
        jac_node: (uni.UniNode | None);
}

"""A keyed-list view child — `{[<li key={x.id}> for x in xs if pred]}` (a
comprehension whose element is a JSX element). `items` is the neutral iterable
with any comprehension filter already folded in (`xs.filter(x => pred)`); `item`
is the loop-variable name; `key` is the authored `key=` value lifted off the
element (carried for Svelte's `{#each … as item (key)}`; Solid's `<For>` keys by
reference and ignores it); `body` is the element's neutral children with the
`key` attribute removed. Solid lowers this to
`<For each={items}>{(item) => …}</For>`; Svelte to `{#each}`."""
obj EachChild {
    has items: es.Expression,
        item: str,
        key: (es.Expression | None),
        body:
            list[
                TextChild | DynamicChild | ElementChild | SlotChild | IfChild | EachChild
            ],
        js_fallback: es.Expression,
        jac_node: (uni.UniNode | None);
}

# --- the element -------------------------------------------------------------
"""A framework-neutral view element: a resolved tag, classified attributes (in
source order — spread ordering is load-bearing), and children (in source order,
structural whitespace and comments already dropped by the producer)."""
obj ViewElement {
    has tag: (HostTag | ComponentTag | FragmentTag | DynamicTag),
        attrs: list[StaticAttr | DynamicAttr | EventAttr | RefAttr | SpreadAttr],
        children:
            list[
                TextChild | DynamicChild | ElementChild | SlotChild | IfChild | EachChild
            ],
        jac_node: (uni.UniNode | None);
}
