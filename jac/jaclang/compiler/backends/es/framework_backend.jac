import jaclang.compiler.backends.es.estree as es;
import from jaclang.compiler.backends.es.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}

import type from jaclang.compiler.backends.es.view_ir { ViewElement }

obj FrameworkBackend {
    def name -> str abst;
    def runtime_module -> str;
    def lower_state_field(s: StateField) -> list[es.Statement] abst;
    def lower_ref_field(r: RefField) -> list[es.Statement] abst;
    def lower_state_update(u: StateUpdate) -> es.Expression abst;
    def lower_effect(e: Effect) -> list[es.Statement] abst;
    def lower_async_boundary(a: AsyncBoundary) -> es.Expression abst;
    def lower_state_read(name: str) -> es.Expression abst;
    def lower_view_expr(expr: es.Expression) -> es.Expression;
    def lower_view(view: ViewElement, sync_loc: any) -> es.Expression abst;
    def _get_setter_name(var_name: str) -> str;
    def state_field_symbols(s: StateField) -> list[str] abst;
    def ref_field_symbols(r: RefField) -> list[str] abst;
    def effect_symbols(e: Effect) -> list[str] abst;
    def async_boundary_symbols(a: AsyncBoundary) -> list[str] abst;
    def view_runtime_symbols(view: ViewElement) -> list[str] abst;
    def jsx_factory_name -> str;
    def import_source(symbol: str) -> str abst;
    def required_globals -> list[str] abst;
    def runtime_source_basename -> str abst;
    def vite_aliases -> dict[str, str];
    def vite_plugin_lines -> (tuple[str, str] | None) abst;
    def build_entry_script(
        entry_module: str, install_global_handlers: bool = True
    ) -> str abst;

    def build_pages_entry_script(
        entry_module: str, auth_redirect: str, has_app_wrapper: bool
    ) -> str abst;
}
