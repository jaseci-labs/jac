import from typing { cast }
import jaclang.compiler.frontend.unitree as uni;
import type from jaclang.compiler.backends.es.esast_gen_pass { EsastGenPass }
import type from jaclang.compiler.backends.es.estree { Expression }

import type from jaclang.compiler.backends.es.view_ir {
    StaticAttr,
    DynamicAttr,
    EventAttr,
    RefAttr,
    ViewElement,
    IfChild,
    EachChild
}

class EsJsxProcessor {
    def init(self: EsJsxProcessor, pass_ref: EsastGenPass) -> None;
    def element(self: EsJsxProcessor, nd: uni.JsxElement) -> Expression;
    def element_name(self: EsJsxProcessor, nd: uni.JsxElementName) -> Expression;
    def spread_attribute(
        self: EsJsxProcessor, nd: uni.JsxSpreadAttribute
    ) -> Expression;

    def normal_attribute(
        self: EsJsxProcessor, nd: uni.JsxNormalAttribute
    ) -> (StaticAttr | DynamicAttr | EventAttr | RefAttr);

    def text(self: EsJsxProcessor, nd: uni.JsxText) -> Expression;
    def expression(self: EsJsxProcessor, nd: uni.JsxExpression) -> Expression;
    def _lift_control_flow(
        self: EsJsxProcessor, child: uni.JsxExpression
    ) -> (IfChild | EachChild | None);

    def _lift_each(
        self: EsJsxProcessor, child: uni.JsxExpression, compr: uni.ListCompr
    ) -> (EachChild | None);

    def _lift_if(
        self: EsJsxProcessor, child: uni.JsxExpression, ternary: uni.IfElseExpr
    ) -> (IfChild | None);

    def _view_arm(self: EsJsxProcessor, nd: uni.JsxElement) -> (list | None);
    def _split_key(self: EsJsxProcessor, ve: ViewElement) -> tuple;
}

glob __all__ = ['EsJsxProcessor'];
