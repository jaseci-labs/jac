"""Solid backend — fine-grained signals reactivity (contract §5.6, PR 5c).

Unlike React/Preact (re-render model), Solid runs each component body once and
wires a reactive graph: state is an accessor (`count()`), writes notify
subscribers (`setCount(...)`), and dynamic view positions must be thunks
(`() => expr`) so the runtime can re-run just that binding. SolidBackend reuses
ReactBackend's structural helpers (`_get_setter_name`, `_jsx_fragment`,
`jsx_factory_name`) and overrides every method whose lowering diverges from the
re-render model.

v1 is a best-effort subset over the representative fixtures (contract §7); the
documented gaps live in contract §8 (refs deferred, block-shadowing, functional-
updater asymmetry, full dom-expressions parity). The shared `__jacJsx` factory is
kept and targets Solid's hyperscript runtime (`solid-js/h`).
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

obj SolidBackend(ReactBackend) {
    def name -> str;
    # Reactive lowering — diverges from the re-render model.
    def lower_state_field(s: StateField) -> list[es.Statement];
    def lower_ref_field(r: RefField) -> list[es.Statement];
    def lower_state_update(u: StateUpdate) -> es.Expression;
    def lower_effect(e: Effect) -> list[es.Statement];
    def lower_async_boundary(a: AsyncBoundary) -> es.Expression;
    # Read seams — the load-bearing signals additions.
    def lower_state_read(name: str) -> es.Expression;
    def lower_view_expr(expr: es.Expression) -> es.Expression;
    # Runtime symbols required by each lowering (import injection).
    def state_field_symbols(s: StateField) -> list[str];
    def ref_field_symbols(r: RefField) -> list[str];
    def effect_symbols(e: Effect) -> list[str];
    def async_boundary_symbols(a: AsyncBoundary) -> list[str];
    # Runtime/platform surface.
    def import_source(symbol: str) -> str;
    # Selects the Solid-flavored runtime shim (re-exports the same core, no React).
    def runtime_source_basename -> str;
    def vite_plugin_lines -> (tuple[str, str] | None);
    def build_entry_script(
        entry_module: str, install_global_handlers: bool = True
    ) -> str;
    # Names imported from the `solid-js` core (everything else stays runtime).
    def _solid_symbols -> set[str];
}
