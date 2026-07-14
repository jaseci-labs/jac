import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}

import type from jaclang.compiler.passes.ecmascript.view_ir { ViewElement }

obj FrameworkBackend {
    def name -> str;
    def runtime_module -> str;
    def lower_state_field(s: StateField) -> list[es.Statement];
    def lower_ref_field(r: RefField) -> list[es.Statement];
    def lower_state_update(u: StateUpdate) -> es.Expression;
    def lower_effect(e: Effect) -> list[es.Statement];
    def lower_async_boundary(a: AsyncBoundary) -> es.Expression;
    def lower_state_read(name: str) -> es.Expression;
    def lower_view_expr(expr: es.Expression) -> es.Expression;
    def lower_view(view: ViewElement, sync_loc: any) -> es.Expression;
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
    def vite_plugin_lines -> (tuple[str, str] | None);
    def build_entry_script(
        entry_module: str, install_global_handlers: bool = True
    ) -> str;

    def build_pages_entry_script(
        entry_module: str, auth_redirect: str, has_app_wrapper: bool
    ) -> str;
}
