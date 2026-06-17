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
producer hands its `sync_loc` to `lower_view`.

Scope: this is the Branch 1 node set (the View IR producer refactor). Native
control-flow nodes (`IfChild`/`EachChild` → Solid `<Show>`/`<For>`, Svelte
`{#if}`/`{#each}`) are deferred to the control-flow branch and intentionally not
defined here yet — the producer does not emit them.
"""

import jaclang.compiler.passes.ecmascript.estree as es;
import jaclang.jac0core.unitree as uni;

# --- tag, resolved ONCE in the producer (kills the duplicated host-vs-component
#     rule that otherwise gets re-derived per backend) -------------------------
"""A host element tag — `<div>`. Lowered to the tag-name string literal."""
obj HostTag {
    has name: str,
        jac_node: uni.UniNode;
}

"""A component tag — `<App>`, `<Foo.Bar>`. `ref` is the already-built reference
expression (an `Identifier` or member chain) the element name lowered to."""
obj ComponentTag {
    has ref: es.Expression,
        jac_node: uni.UniNode;
}

"""A fragment tag — `<>…</>` (or a nameless element). Lowered to a null tag."""
obj FragmentTag {
    has jac_node: uni.UniNode;
}

"""A dynamic tag — `<@expr …>`. `expr` is the already-built tag expression."""
obj DynamicTag {
    has expr: es.Expression,
        jac_node: uni.UniNode;
}

# --- attributes, classified ONCE in the producer (kills the fragile `on[A-Z]`
#     heuristic + `ref`/spread special-casing re-derived per backend) ----------
"""A static attribute — `class="x"`, `disabled`. `value` is the literal the
producer built (string literals are HTML-unescaped and scoped-style class tokens
are already rewritten); a value-less attribute carries a `true` literal."""
obj StaticAttr {
    has name: str,
        value: es.Expression,
        jac_node: uni.UniNode;
}

"""A dynamic attribute — `value={expr}`. `value` is the neutral, un-thunked
expression; the backend wraps it (Solid) or passes it through (React/Preact)."""
obj DynamicAttr {
    has name: str,
        value: es.Expression,
        jac_node: uni.UniNode;
}

"""An event handler attribute — `onClick={fn}` (the `on[A-Z]…` DOM convention).
Never thunked: wrapping a handler would defer the callback itself, not a read."""
obj EventAttr {
    has name: str,
        handler: es.Expression,
        jac_node: uni.UniNode;
}

"""A ref attribute — `ref={el}`. An imperative element hook, never thunked: the
runtime calls the ref with the DOM node (a thunk would swallow the element)."""
obj RefAttr {
    has name: str,
        value: es.Expression,
        jac_node: uni.UniNode;
}

"""A spread attribute — `{...obj}`. `value` is the already-built object expr."""
obj SpreadAttr {
    has value: es.Expression,
        jac_node: uni.UniNode;
}

# --- children ----------------------------------------------------------------
"""Static text — `Hello`. `value` is the HTML-unescaped string literal."""
obj TextChild {
    has value: es.Expression,
        jac_node: uni.UniNode;
}

"""A dynamic child — `{expr}`. `value` is the neutral, un-thunked expression;
the backend wraps it (Solid) or passes it through (React/Preact)."""
obj DynamicChild {
    has value: es.Expression,
        jac_node: uni.UniNode;
}

"""A nested element child — the producer carries the child's `ViewElement` so the
backend lowers the whole tree in one pass (rather than splicing pre-lowered
sub-expressions, which would freeze each child to the first backend that ran)."""
obj ElementChild {
    has element: ViewElement,
        jac_node: uni.UniNode;
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
        jac_node: uni.UniNode;
}

# --- the element -------------------------------------------------------------
"""A framework-neutral view element: a resolved tag, classified attributes (in
source order — spread ordering is load-bearing), and children (in source order,
structural whitespace and comments already dropped by the producer)."""
obj ViewElement {
    has tag: (HostTag | ComponentTag | FragmentTag | DynamicTag),
        attrs: list[StaticAttr | DynamicAttr | EventAttr | RefAttr | SpreadAttr],
        children: list[TextChild | DynamicChild | ElementChild | SlotChild],
        jac_node: uni.UniNode;
}
