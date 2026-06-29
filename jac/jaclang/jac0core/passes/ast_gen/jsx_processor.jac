import ast as ast3;
import from typing { cast }
import jaclang.jac0core.unitree as uni;
import type from jaclang.compiler.passes.ecmascript.esast_gen_pass { EsastGenPass }
import type from jaclang.compiler.passes.ecmascript.estree { Expression }

import type from jaclang.compiler.passes.ecmascript.view_ir {
    StaticAttr,
    DynamicAttr,
    EventAttr,
    RefAttr,
    ViewElement,
    IfChild,
    EachChild
}
import type from jaclang.jac0core.passes.pyast_gen_pass { PyastGenPass }

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

class PyJsxProcessor {
    def init(self: PyJsxProcessor, pass_ref: PyastGenPass) -> None;
    def element(self: PyJsxProcessor, nd: uni.JsxElement) -> list[ast3.AST];
    def element_name(self: PyJsxProcessor, nd: uni.JsxElementName) -> list[ast3.AST];
    def spread_attribute(
        self: PyJsxProcessor, nd: uni.JsxSpreadAttribute
    ) -> list[ast3.AST];

    def normal_attribute(
        self: PyJsxProcessor, nd: uni.JsxNormalAttribute
    ) -> list[ast3.AST];

    def text(self: PyJsxProcessor, nd: uni.JsxText) -> list[ast3.AST];
    def expression(self: PyJsxProcessor, nd: uni.JsxExpression) -> list[ast3.AST];
}

glob __all__ = ['EsJsxProcessor', 'PyJsxProcessor'];
