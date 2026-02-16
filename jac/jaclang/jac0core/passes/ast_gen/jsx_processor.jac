"""Helpers for generating target-specific JSX AST nodes."""
import ast as ast3;
import from typing { TYPE_CHECKING, cast }
import jaclang.jac0core.unitree as uni;

with entry {
    if TYPE_CHECKING {
        import from jaclang.compiler.passes.ecmascript.esast_gen_pass { EsastGenPass }
        import from jaclang.compiler.passes.ecmascript.estree {
            Expression,
            Property,
            SpreadElement
        }
        import from jaclang.jac0core.passes.pyast_gen_pass { PyastGenPass }
    }
}

"""Generate ESTree structures for JSX nodes."""
class EsJsxProcessor {
    def init(self: EsJsxProcessor, pass_ref: EsastGenPass) -> None;
    """Process JSX element into __jacJsx(tag, props, children) call."""
    def element(self: EsJsxProcessor, nd: uni.JsxElement) -> Expression;

    """Process JSX element name."""
    def element_name(self: EsJsxProcessor, nd: uni.JsxElementName) -> Expression;

    """Process JSX spread attribute."""
    def spread_attribute(
        self: EsJsxProcessor, nd: uni.JsxSpreadAttribute
    ) -> Expression;

    """Process JSX normal attribute."""
    def normal_attribute(self: EsJsxProcessor, nd: uni.JsxNormalAttribute) -> Property;

    """Process JSX text node."""
    def text(self: EsJsxProcessor, nd: uni.JsxText) -> Expression;

    """Process JSX expression child."""
    def expression(self: EsJsxProcessor, nd: uni.JsxExpression) -> Expression;
}

"""Generate Python AST structures for JSX nodes."""
class PyJsxProcessor {
    def init(self: PyJsxProcessor, pass_ref: PyastGenPass) -> None;
    """Generate Python AST for JSX elements."""
    def element(self: PyJsxProcessor, nd: uni.JsxElement) -> list[ast3.AST];

    """Generate Python AST for JSX element names."""
    def element_name(self: PyJsxProcessor, nd: uni.JsxElementName) -> list[ast3.AST];

    """Generate Python AST for JSX spread attributes."""
    def spread_attribute(
        self: PyJsxProcessor, nd: uni.JsxSpreadAttribute
    ) -> list[ast3.AST];

    """Generate Python AST for JSX normal attributes."""
    def normal_attribute(
        self: PyJsxProcessor, nd: uni.JsxNormalAttribute
    ) -> list[ast3.AST];

    """Generate Python AST for JSX text nodes."""
    def text(self: PyJsxProcessor, nd: uni.JsxText) -> list[ast3.AST];

    """Generate Python AST for JSX expression children."""
    def expression(self: PyJsxProcessor, nd: uni.JsxExpression) -> list[ast3.AST];
}

glob __all__ = ['EsJsxProcessor', 'PyJsxProcessor'];
