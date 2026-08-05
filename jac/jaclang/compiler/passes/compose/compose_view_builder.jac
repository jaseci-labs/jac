import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.compose.view_ir {
    ComposeElement,
    ComposeAttr,
    ComposeTextChild,
    ComposeDynamicChild,
    ComposeElementChild,
    ComposeIfChild,
    ComposeEachChild
}
import from jaclang.compiler.passes.compose.jac_to_kotlin { JacToKotlin }

obj ComposeViewBuilder {
    has lowerer: JacToKotlin = JacToKotlin(),
        diagnostics: list[str] = [],
        _view_by_node: dict[int, ComposeElement] = {};

    def build_element(nd: uni.JsxElement) -> (ComposeElement | None);
    def build_children(
        children: list[uni.UniNode]
    ) -> list[
        ComposeTextChild
            | ComposeDynamicChild
            | ComposeElementChild
            | ComposeIfChild
            | ComposeEachChild
    ];

    def _lift_control_flow(
        child: uni.JsxExpression
    ) -> (ComposeIfChild | ComposeEachChild | None);

    def _lift_each(
        child: uni.JsxExpression, compr: uni.ListCompr
    ) -> (ComposeEachChild | None);

    def _lift_if(
        child: uni.JsxExpression, ternary: uni.IfElseExpr
    ) -> (ComposeIfChild | None);

    def lower_component_view(stmts: list[uni.UniNode]) -> (ComposeElement | None);
    def _lower_stmts(stmts: list[uni.UniNode]) -> (list | None);
    def _lower_jsx_value(expr: uni.UniNode) -> (ComposeElementChild | None);
    def _lower_if_stmt(stmt: uni.IfStmt) -> (ComposeIfChild | None);
    def _guard_coverage(
        stmts: list[uni.UniNode], before: set[int], lowered: (list | None)
    ) -> None;
}
