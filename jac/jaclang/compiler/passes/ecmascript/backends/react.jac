"""React backend — lowers reactive-intent records to React hook ESTree."""

import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.framework_backend { FrameworkBackend }
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}
# Type-only (see `framework_backend.jac`): `ViewElement` annotates `lower_view`;
# the impl imports the View IR records lazily for runtime isinstance/construction.
import type from jaclang.compiler.passes.ecmascript.view_ir { ViewElement }

obj ReactBackend(FrameworkBackend) {
    def name -> str;
    def runtime_module -> str;
    def lower_state_field(s: StateField) -> list[es.Statement];
    def lower_ref_field(r: RefField) -> list[es.Statement];
    def lower_state_update(u: StateUpdate) -> es.Expression;
    def lower_effect(e: Effect) -> list[es.Statement];
    def lower_async_boundary(a: AsyncBoundary) -> es.Expression;
    def lower_state_read(name: str) -> es.Expression;
    def lower_view_expr(expr: es.Expression) -> es.Expression;
    # JS-family View IR lowering — shared by React/Preact/Solid (all build a
    # `__jacJsx(tag, props, [children])` factory call). Solid diverges only via
    # its `lower_view_expr` thunk, applied here for dynamic positions.
    def lower_view(view: ViewElement, sync_loc: any) -> es.Expression;
    # Per-attribute helper: build the factory-call `Property` for one classified
    # attribute (thunking dynamic values via `lower_view_expr`).
    def _view_attr_property(attr: any, sync_loc: any) -> es.Property;
    def state_field_symbols(s: StateField) -> list[str];
    def ref_field_symbols(r: RefField) -> list[str];
    def effect_symbols(e: Effect) -> list[str];
    def async_boundary_symbols(a: AsyncBoundary) -> list[str];
    def view_runtime_symbols(view: ViewElement) -> list[str];
    def jsx_factory_name -> str;
    def import_source(symbol: str) -> str;
    def required_globals -> list[str];
    def runtime_source_basename -> str;
    def vite_aliases -> dict[str, str];
    def build_entry_script(
        entry_module: str, install_global_handlers: bool = True
    ) -> str;

    def build_pages_entry_script(
        entry_module: str, auth_redirect: str, has_app_wrapper: bool
    ) -> str;
    # Vite plugin — returns (import_line, plugin_call) or None to skip plugin
    def vite_plugin_lines -> (tuple[str, str] | None);
    # Helpers reused across lower_* methods
    def _hook_symbols -> set[str];
    def _get_setter_name(var_name: str) -> str;
    def _jsx_fragment(children: list[es.Expression]) -> es.CallExpression;
}
