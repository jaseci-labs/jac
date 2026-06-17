"""Helpers for generating target-specific JSX AST nodes."""
import ast as ast3;
import from typing { cast }
import jaclang.jac0core.unitree as uni;
import type from jaclang.compiler.passes.ecmascript.esast_gen_pass { EsastGenPass }
import type from jaclang.compiler.passes.ecmascript.estree { Expression }
# Type-only: `jsx_processor` is imported early in the compiler bootstrap (before
# the compiler is fully built), so a runtime import of the `view_ir` pass module
# here would re-enter `get_compiler()`. The producer imports the View IR records
# lazily at runtime (see the impl's `init`); these are for annotations only.
import type from jaclang.compiler.passes.ecmascript.view_ir {
    StaticAttr,
    DynamicAttr,
    EventAttr,
    RefAttr
}
import type from jaclang.jac0core.passes.pyast_gen_pass { PyastGenPass }

"""Generate ESTree structures for JSX nodes."""
class EsJsxProcessor {
    def init(self: EsJsxProcessor, pass_ref: EsastGenPass) -> None;
    """Build the neutral View IR tree for a JSX element, then lower it to the
    active backend's view form (`__jacJsx(...)` for the JS family)."""
    def element(self: EsJsxProcessor, nd: uni.JsxElement) -> Expression;

    """Process JSX element name."""
    def element_name(self: EsJsxProcessor, nd: uni.JsxElementName) -> Expression;

    """Process JSX spread attribute."""
    def spread_attribute(
        self: EsJsxProcessor, nd: uni.JsxSpreadAttribute
    ) -> Expression;

    """Classify a JSX normal attribute into a neutral View IR attribute
    (static / dynamic / event / ref). The dynamic-position thunk is NOT applied
    here — that is the backend's job inside `lower_view`."""
    def normal_attribute(
        self: EsJsxProcessor, nd: uni.JsxNormalAttribute
    ) -> (StaticAttr | DynamicAttr | EventAttr | RefAttr);

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
