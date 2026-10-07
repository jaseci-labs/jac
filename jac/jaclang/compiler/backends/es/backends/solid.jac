import jaclang.compiler.backends.es.estree as es;
import from jaclang.compiler.backends.es.framework_backend { FrameworkBackend }
import from jaclang.compiler.backends.es.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}

import jaclang.compiler.frontend.unitree as uni;
import type from jaclang.compiler.backends.es.view_ir {
    DynamicAttr,
    EachChild,
    EventAttr,
    IfChild,
    RefAttr,
    SpreadAttr,
    StaticAttr,
    ViewElement,
    ViewChild,
    ViewLocator
}

obj SolidBackend(FrameworkBackend) {
    def name -> str;
    def lower_state_field(s: StateField) -> list[es.Statement];
    def lower_ref_field(r: RefField) -> list[es.Statement];
    def lower_state_update(u: StateUpdate) -> es.Expression;
    def lower_effect(e: Effect) -> list[es.Statement];
    def lower_async_boundary(a: AsyncBoundary) -> es.Expression;
    def lower_state_read(name: str) -> es.Expression;
    def lower_view(view: ViewElement, locator: ViewLocator) -> es.Expression;
    def _jsx_tag_name(
        expr: (es.Expression | None)
    ) -> (es.JsxIdentifier | es.JsxMemberExpression | None);

    def _map_attr_name(name: str) -> str;
    def _jsx_attr_str_safe(value: str) -> bool;
    def _jsx_attr(
        attr: (StaticAttr | DynamicAttr | EventAttr | RefAttr | SpreadAttr),
        locator: ViewLocator
    ) -> (es.JsxAttribute | es.JsxSpreadAttribute);

    def _jsx_named_attr(
        name: str,
        value: (es.Literal | es.JsxExpressionContainer | None),
        jac_node: (uni.UniNode | None),
        locator: ViewLocator
    ) -> es.JsxAttribute;

    def _jsx_child_nodes(children: list[ViewChild], locator: ViewLocator) -> list[any];
    def _jsx_for(child: EachChild, locator: ViewLocator) -> es.JsxElement;
    def _jsx_show(child: IfChild, locator: ViewLocator) -> es.JsxElement;
    def _view_children_as_expr(
        children: list[ViewChild], locator: ViewLocator
    ) -> es.Expression;

    def view_runtime_symbols(view: ViewElement) -> list[str];
    def _jsx_element(
        name_node: (es.JsxIdentifier | es.JsxMemberExpression),
        attrs: list[es.JsxAttribute | es.JsxSpreadAttribute],
        children: list[any],
        jac_node: (uni.UniNode | None),
        locator: ViewLocator
    ) -> es.JsxElement;

    def _jsx_dynamic(
        component_expr: es.Expression,
        attrs: list[es.JsxAttribute | es.JsxSpreadAttribute],
        children: list[any],
        jac_node: (uni.UniNode | None),
        locator: ViewLocator
    ) -> es.JsxElement;

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
