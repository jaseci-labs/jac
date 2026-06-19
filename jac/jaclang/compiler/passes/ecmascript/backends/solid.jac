"""Solid backend — fine-grained signals reactivity (contract §5.6, PR 5c).

Unlike React/Preact (re-render model), Solid runs each component body once and
wires a reactive graph: state is an accessor (`count()`) and writes notify
subscribers (`setCount(...)`). SolidBackend reuses ReactBackend's structural
helpers (`_get_setter_name`) and overrides every method whose lowering diverges
from the re-render model.

**View IR / dom-expressions path (Branch 3).** Where React/Preact lower a view to a
`__jacJsx(tag, props, [children])` hyperscript call, `SolidBackend.lower_view`
emits real **JSX syntax** (estree JSX nodes the unparser prints as `<tag …>`),
which `vite-plugin-solid` (`babel-plugin-jsx-dom-expressions`) compiles to
fine-grained reactive DOM. Dynamic positions are **not** thunked (the dom-expressions compiler owns the
reactive read); `lower_view_expr` is not declared on `SolidBackend` — the identity
inherited from `ReactBackend` is never called on the JSX path. Spreads are native
`{...obj}` and refs/events are classified once in the producer (TODO #1/#2). The
`solid-js/h` hyperscript route and its `__jacJsx` factory have been removed from
the runtime shim (Branch 5).

v1 is a best-effort subset over the representative fixtures (contract §7); the
documented gaps live in contract §8 (refs deferred for `useRef`-style fields,
block-shadowing, functional-updater asymmetry, `unsafe_html` on the JSX path,
native control flow).
"""

import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.backends.react { ReactBackend }
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}
# Type-only: `ViewElement` appears solely in `lower_view`'s signature; a runtime
# import would re-enter the compiler bootstrap (see `framework_backend.jac`). The
# View IR records are imported lazily inside the impl bodies that build them.
import type from jaclang.compiler.passes.ecmascript.view_ir { ViewElement }

obj SolidBackend(ReactBackend) {
    def name -> str;
    # Reactive lowering — diverges from the re-render model.
    def lower_state_field(s: StateField) -> list[es.Statement];
    def lower_ref_field(r: RefField) -> list[es.Statement];
    def lower_state_update(u: StateUpdate) -> es.Expression;
    def lower_effect(e: Effect) -> list[es.Statement];
    def lower_async_boundary(a: AsyncBoundary) -> es.Expression;
    # Read seam — the load-bearing signals addition.
    def lower_state_read(name: str) -> es.Expression;
    # View IR seam — Solid emits real JSX *syntax* (estree JSX nodes the unparser
    # prints as `<tag …>`), which `vite-plugin-solid`'s dom-expressions compiler
    # owns reactivity for, rather than the shared `__jacJsx(…)` hyperscript call.
    # This is the divergence from the JS-family `lower_view` (React/Preact).
    def lower_view(view: ViewElement, sync_loc: any) -> es.Expression;
    # JSX-lowering helpers (pure structural transforms over the View IR tree).
    def _jsx_tag_name(
        expr: es.Expression
    ) -> (es.JsxIdentifier | es.JsxMemberExpression | None);

    def _map_attr_name(name: str) -> str;
    def _jsx_attr_str_safe(value: str) -> bool;
    def _jsx_attr(
        attr: any, sync_loc: any
    ) -> (es.JsxAttribute | es.JsxSpreadAttribute);

    def _jsx_child_nodes(children: list, sync_loc: any) -> list;
    # Native control flow (Branch 4): `EachChild` → `<For each>{(item) => …}</For>`,
    # `IfChild` → `<Show when fallback>…</Show>`.
    def _jsx_for(child: any, sync_loc: any) -> es.JsxElement;
    def _jsx_show(child: any, sync_loc: any) -> es.JsxElement;
    # A neutral child list as a single JSX expression: the lone element directly,
    # otherwise a `<>…</>` fragment (the arrow body of `<For>` / `<Show>` fallback).
    def _view_children_as_expr(children: list, sync_loc: any) -> es.Expression;
    # `<For>`/`<Show>` imports a lowered tree references (recursive scan).
    def view_runtime_symbols(view: ViewElement) -> list[str];
    def _jsx_element(
        name_node: any, attrs: list, children: list, jac_node: any, sync_loc: any
    ) -> es.JsxElement;

    def _jsx_dynamic(
        component_expr: es.Expression,
        attrs: list,
        children: list,
        jac_node: any,
        sync_loc: any
    ) -> es.JsxElement;
    # Identity location-stamper for `lower_async_boundary` (which is called
    # without the pass's `sync_loc`); keeps `lower_view`'s `sync_loc(...)` calls
    # uniform when building the async-boundary `ViewElement`s.
    def _noloc(es_node: any, jac_node: any = None) -> any;
    # Runtime symbols required by each lowering (import injection).
    def state_field_symbols(s: StateField) -> list[str];
    def ref_field_symbols(r: RefField) -> list[str];
    def effect_symbols(e: Effect) -> list[str];
    def async_boundary_symbols(a: AsyncBoundary) -> list[str];
    # Runtime/platform surface.
    def import_source(symbol: str) -> str;
    def required_globals -> list[str];
    # Selects the Solid-flavored runtime shim (re-exports the same core, no React,
    # no __jacJsx — the JSX path no longer needs a hyperscript factory).
    def runtime_source_basename -> str;
    def vite_plugin_lines -> (tuple[str, str] | None);
    def build_entry_script(
        entry_module: str, install_global_handlers: bool = True
    ) -> str;

    def build_pages_entry_script(
        entry_module: str, auth_redirect: str, has_app_wrapper: bool
    ) -> str;
    # Names imported from the `solid-js` core (everything else stays runtime).
    def _solid_symbols -> set[str];
}
