import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.backends.react { ReactBackend }
import from jaclang.compiler.passes.ecmascript.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}

import type from jaclang.compiler.passes.ecmascript.view_ir { ViewElement }

obj SolidBackend(ReactBackend) {
    def name -> str;
    def lower_state_field(s: StateField) -> list[es.Statement];
    def lower_ref_field(r: RefField) -> list[es.Statement];
    def lower_state_update(u: StateUpdate) -> es.Expression;
    def lower_effect(e: Effect) -> list[es.Statement];
    def lower_async_boundary(a: AsyncBoundary) -> es.Expression;
    def lower_state_read(name: str) -> es.Expression;
    def lower_view(view: ViewElement, sync_loc: any) -> es.Expression;
    def _jsx_tag_name(
        expr: es.Expression
    ) -> (es.JsxIdentifier | es.JsxMemberExpression | None);

    def _map_attr_name(name: str) -> str;
    def _jsx_attr_str_safe(value: str) -> bool;
    def _jsx_attr(
        attr: any, sync_loc: any
    ) -> (es.JsxAttribute | es.JsxSpreadAttribute);

    def _jsx_child_nodes(children: list, sync_loc: any) -> list;
    def _jsx_for(child: any, sync_loc: any) -> es.JsxElement;
    def _jsx_show(child: any, sync_loc: any) -> es.JsxElement;
    def _view_children_as_expr(children: list, sync_loc: any) -> es.Expression;
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

    def _noloc(es_node: any, jac_node: any = None) -> any;
    def state_field_symbols(s: StateField) -> list[str];
    def ref_field_symbols(r: RefField) -> list[str];
    def effect_symbols(e: Effect) -> list[str];
    def async_boundary_symbols(a: AsyncBoundary) -> list[str];
    def import_source(symbol: str) -> str;
    def required_globals -> list[str];
    def runtime_source_basename -> str;
    def vite_plugin_lines -> (tuple[str, str] | None);
    def build_entry_script(
        entry_module: str, install_global_handlers: bool = True
    ) -> str;

    def build_pages_entry_script(
        entry_module: str, auth_redirect: str, has_app_wrapper: bool
    ) -> str;

    def _solid_symbols -> set[str];
}
