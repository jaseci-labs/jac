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
    def element(self: EsJsxProcessor, `node: uni.JsxElement) -> Expression;

    """Process JSX element name."""
    def element_name(self: EsJsxProcessor, `node: uni.JsxElementName) -> Expression;

    """Process JSX spread attribute."""
    def spread_attribute(
        self: EsJsxProcessor, `node: uni.JsxSpreadAttribute
    ) -> Expression;

    """Process JSX normal attribute."""
    def normal_attribute(
        self: EsJsxProcessor, `node: uni.JsxNormalAttribute
    ) -> Property;

    """Process JSX text node."""
    def text(self: EsJsxProcessor, `node: uni.JsxText) -> Expression;

    """Process JSX expression child."""
    def expression(self: EsJsxProcessor, `node: uni.JsxExpression) -> Expression;
}

"""Generate Python AST structures for JSX nodes."""
class PyJsxProcessor {
    def init(self: PyJsxProcessor, pass_ref: PyastGenPass) -> None;
    """Generate Python AST for JSX elements."""
    def element(self: PyJsxProcessor, `node: uni.JsxElement) -> list[ast3.AST];

    """Generate Python AST for JSX element names."""
    def element_name(self: PyJsxProcessor, `node: uni.JsxElementName) -> list[ast3.AST];

    """Generate Python AST for JSX spread attributes."""
    def spread_attribute(
        self: PyJsxProcessor, `node: uni.JsxSpreadAttribute
    ) -> list[ast3.AST];

    """Generate Python AST for JSX normal attributes."""
    def normal_attribute(
        self: PyJsxProcessor, `node: uni.JsxNormalAttribute
    ) -> list[ast3.AST];

    """Generate Python AST for JSX text nodes."""
    def text(self: PyJsxProcessor, `node: uni.JsxText) -> list[ast3.AST];

    """Generate Python AST for JSX expression children."""
    def expression(self: PyJsxProcessor, `node: uni.JsxExpression) -> list[ast3.AST];
}

glob __all__ = ['EsJsxProcessor', 'PyJsxProcessor'];
