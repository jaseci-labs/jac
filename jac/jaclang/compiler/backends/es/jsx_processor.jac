import from typing { cast }

obj EsJsxProcessor {
    has pass_ref: EsastGenPass,
        _view_by_node: dict[int, ViewElement] = {};

    def element(nd: uni.JsxElement) -> Expression;
    def element_name(nd: uni.JsxElementName) -> Expression;
    def spread_attribute(nd: uni.JsxSpreadAttribute) -> Expression;
    def normal_attribute(
        nd: uni.JsxNormalAttribute
    ) -> (StaticAttr | DynamicAttr | EventAttr | RefAttr);

    def text(nd: uni.JsxText) -> Expression;
    def expression(nd: uni.JsxExpression) -> Expression;
    def _lift_control_flow(child: uni.JsxExpression) -> (IfChild | EachChild | None);
    def _lift_each(
        child: uni.JsxExpression, compr: uni.ListCompr
    ) -> (EachChild | None);

    def _lift_if(
        child: uni.JsxExpression, ternary: uni.IfElseExpr
    ) -> (IfChild | None);

    def _view_arm(nd: uni.JsxElement) -> (list[ViewChild] | None);
    def _split_key(
        ve: ViewElement
    ) -> tuple[
        Expression | None,
        list[StaticAttr | DynamicAttr | EventAttr | RefAttr | SpreadAttr]
    ];
}

glob __all__ = ['EsJsxProcessor'];
