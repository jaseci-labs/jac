"""Helpers for generating target-specific JSX AST nodes."""

from __future__ import annotations

import ast as ast3
from typing import Optional, TYPE_CHECKING, Union, cast

import jaclang.compiler.unitree as uni

if TYPE_CHECKING:
    from jaclang.compiler.passes.ecmascript.esast_gen_pass import EsastGenPass
    from jaclang.compiler.passes.ecmascript.estree import (
        Expression,
        Property,
        SpreadElement,
    )
    from jaclang.compiler.passes.main.pyast_gen_pass import PyastGenPass


class EsJsxProcessor:
    """Generate ESTree structures for JSX nodes."""

    def __init__(self, pass_ref: EsastGenPass) -> None:
        self.pass_ref = pass_ref
        # Import estree at runtime to access AST node classes
        from jaclang.compiler.passes.ecmascript import estree as es

        self.es = es

    def element(self, node: uni.JsxElement) -> Expression:
        """Process JSX element into __jacJsx(tag, props, children) call."""
        es = self.es
        if node.is_fragment or not node.name:
            tag_expr: Expression = self.pass_ref.sync_loc(
                es.Literal(value=None), jac_node=node
            )
        else:
            tag_expr = (
                node.name.gen.es_ast
                if node.name.gen.es_ast
                else self.pass_ref.sync_loc(es.Literal(value=None), jac_node=node.name)
            )

        attributes = node.attributes or []
        has_spread = any(
            isinstance(attr, uni.JsxSpreadAttribute) for attr in attributes
        )
        if not attributes:
            props_expr: Expression = self.pass_ref.sync_loc(
                es.ObjectExpression(properties=[]), jac_node=node
            )
        elif has_spread:
            segments: list[Expression] = []
            for attr in attributes:
                if isinstance(attr, uni.JsxSpreadAttribute):
                    exp = getattr(attr.gen, "es_ast", None)
                    if isinstance(exp, es.Expression):
                        segments.append(exp)
                elif isinstance(attr, uni.JsxNormalAttribute):
                    prop = getattr(attr.gen, "es_ast", None)
                    if isinstance(prop, es.Property):
                        segments.append(
                            self.pass_ref.sync_loc(
                                es.ObjectExpression(properties=[prop]), jac_node=attr
                            )
                        )
            if segments:
                assign_member = self.pass_ref.sync_loc(
                    es.MemberExpression(
                        object=self.pass_ref.sync_loc(
                            es.Identifier(name="Object"), jac_node=node
                        ),
                        property=self.pass_ref.sync_loc(
                            es.Identifier(name="assign"), jac_node=node
                        ),
                        computed=False,
                        optional=False,
                    ),
                    jac_node=node,
                )
                props_expr = self.pass_ref.sync_loc(
                    es.CallExpression(
                        callee=assign_member,
                        arguments=[
                            self.pass_ref.sync_loc(
                                es.ObjectExpression(properties=[]), jac_node=node
                            ),
                            *segments,
                        ],
                    ),
                    jac_node=node,
                )
            else:
                props_expr = self.pass_ref.sync_loc(
                    es.ObjectExpression(properties=[]), jac_node=node
                )
        else:
            properties: list[Property] = []
            for attr in attributes:
                prop = getattr(attr.gen, "es_ast", None)
                if isinstance(prop, es.Property):
                    properties.append(prop)
            props_expr = self.pass_ref.sync_loc(
                es.ObjectExpression(properties=properties), jac_node=node
            )

        children_elements: list[Optional[Union[Expression, SpreadElement]]] = []
        for child in node.children or []:
            child_expr = getattr(child.gen, "es_ast", None)
            if child_expr is None:
                continue
            if isinstance(child_expr, list):
                children_elements.extend(child_expr)  # type: ignore[arg-type]
            else:
                children_elements.append(child_expr)
        children_expr = self.pass_ref.sync_loc(
            es.ArrayExpression(elements=children_elements), jac_node=node
        )

        call_expr = self.pass_ref.sync_loc(
            es.CallExpression(
                callee=self.pass_ref.sync_loc(
                    es.Identifier(name="__jacJsx"), jac_node=node
                ),
                arguments=[tag_expr, props_expr, children_expr],
            ),
            jac_node=node,
        )
        return call_expr

    def element_name(self, node: uni.JsxElementName) -> Expression:
        """Process JSX element name."""
        es = self.es
        if not node.parts:
            expr = self.pass_ref.sync_loc(es.Literal(value=None), jac_node=node)
        else:
            parts = [part.value for part in node.parts]
            first = parts[0]
            if first and first[0].isupper():
                expr = self.pass_ref.sync_loc(
                    es.Identifier(name=first), jac_node=node.parts[0]
                )
                for idx, part in enumerate(parts[1:], start=1):
                    expr = self.pass_ref.sync_loc(
                        es.MemberExpression(
                            object=expr,
                            property=self.pass_ref.sync_loc(
                                es.Identifier(name=part), jac_node=node.parts[idx]
                            ),
                            computed=False,
                            optional=False,
                        ),
                        jac_node=node,
                    )
            else:
                expr = self.pass_ref.sync_loc(
                    es.Literal(value=".".join(parts)), jac_node=node
                )
        node.gen.es_ast = expr
        return expr

    def spread_attribute(self, node: uni.JsxSpreadAttribute) -> Expression:
        """Process JSX spread attribute."""
        es = self.es
        expr = (
            node.expr.gen.es_ast
            if node.expr and node.expr.gen.es_ast
            else self.pass_ref.sync_loc(
                es.ObjectExpression(properties=[]), jac_node=node
            )
        )
        node.gen.es_ast = expr
        return expr

    def normal_attribute(self, node: uni.JsxNormalAttribute) -> Property:
        """Process JSX normal attribute."""
        es = self.es
        key_expr = self.pass_ref.sync_loc(
            es.Literal(value=node.name.value), jac_node=node.name
        )
        if node.value is None:
            value_expr = self.pass_ref.sync_loc(es.Literal(value=True), jac_node=node)
        elif isinstance(node.value, uni.String):
            value_expr = self.pass_ref.sync_loc(
                es.Literal(value=node.value.lit_value), jac_node=node.value
            )
        else:
            value_expr = (
                node.value.gen.es_ast
                if node.value.gen.es_ast
                else self.pass_ref.sync_loc(es.Literal(value=None), jac_node=node.value)
            )

        prop = self.pass_ref.sync_loc(
            es.Property(
                key=key_expr,
                value=value_expr,
                kind="init",
                method=False,
                shorthand=False,
                computed=False,
            ),
            jac_node=node,
        )
        node.gen.es_ast = prop
        return prop

    def text(self, node: uni.JsxText) -> Expression:
        """Process JSX text node."""
        es = self.es
        raw_value = node.value.value if hasattr(node.value, "value") else node.value
        expr = self.pass_ref.sync_loc(es.Literal(value=str(raw_value)), jac_node=node)
        node.gen.es_ast = expr
        return expr

    def expression(self, node: uni.JsxExpression) -> Expression:
        """Process JSX expression child."""
        es = self.es
        expr = (
            node.expr.gen.es_ast
            if node.expr and node.expr.gen.es_ast
            else self.pass_ref.sync_loc(es.Literal(value=None), jac_node=node.expr)
        )
        node.gen.es_ast = expr
        return expr


class PyJsxProcessor:
    """Generate Python AST structures for JSX nodes."""

    def __init__(self, pass_ref: PyastGenPass) -> None:
        self.pass_ref = pass_ref

    def element(self, node: uni.JsxElement) -> list[ast3.AST]:
        """Generate Python AST for JSX elements."""
        if node.is_fragment or not node.name:
            tag_arg: ast3.expr = self.pass_ref.sync(ast3.Constant(value=None), node)
        else:
            tag_arg = cast(ast3.expr, node.name.gen.py_ast[0])

        if not node.attributes:
            attrs_expr = self.pass_ref.sync(ast3.Dict(keys=[], values=[]), node)
        elif any(isinstance(attr, uni.JsxSpreadAttribute) for attr in node.attributes):
            attrs_expr = self.pass_ref.sync(ast3.Dict(keys=[], values=[]), node)
            for attr in node.attributes:
                attr_ast = cast(ast3.expr, attr.gen.py_ast[0])
                if isinstance(attr, uni.JsxSpreadAttribute):
                    attrs_expr = self.pass_ref.sync(
                        ast3.Dict(keys=[None, None], values=[attrs_expr, attr_ast]),
                        attr,
                    )
                elif isinstance(attr, uni.JsxNormalAttribute):
                    key_ast, value_ast = attr_ast.elts  # type: ignore[attr-defined]
                    attrs_expr = self.pass_ref.sync(
                        ast3.Dict(
                            keys=[None, key_ast],
                            values=[attrs_expr, cast(ast3.expr, value_ast)],
                        ),
                        attr,
                    )
        else:
            keys: list[ast3.expr | None] = []
            values: list[ast3.expr] = []
            for attr in node.attributes:
                if isinstance(attr, uni.JsxNormalAttribute):
                    attr_ast = attr.gen.py_ast[0]
                    key_ast, value_ast = attr_ast.elts  # type: ignore[attr-defined]
                    keys.append(cast(ast3.expr, key_ast))
                    values.append(cast(ast3.expr, value_ast))
            attrs_expr = self.pass_ref.sync(ast3.Dict(keys=keys, values=values), node)

        if node.children:
            children_arg = self.pass_ref.sync(
                ast3.List(
                    elts=[cast(ast3.expr, c.gen.py_ast[0]) for c in node.children],
                    ctx=ast3.Load(),
                ),
                node,
            )
        else:
            children_arg = self.pass_ref.sync(ast3.List(elts=[], ctx=ast3.Load()), node)

        call = self.pass_ref.sync(
            ast3.Call(
                func=self.pass_ref.jaclib_obj("jsx"),
                args=[tag_arg, attrs_expr, children_arg],
                keywords=[],
            ),
            node,
        )
        node.gen.py_ast = [call]
        return node.gen.py_ast

    def element_name(self, node: uni.JsxElementName) -> list[ast3.AST]:
        """Generate Python AST for JSX element names."""
        name_str = ".".join(part.value for part in node.parts)
        if node.parts and node.parts[0].value[0].isupper():
            expr = self.pass_ref.sync(
                ast3.Name(id=name_str, ctx=ast3.Load()),
                node,
            )
        else:
            expr = self.pass_ref.sync(ast3.Constant(value=name_str), node)
        node.gen.py_ast = [expr]
        return node.gen.py_ast

    def spread_attribute(self, node: uni.JsxSpreadAttribute) -> list[ast3.AST]:
        """Generate Python AST for JSX spread attributes."""
        node.gen.py_ast = [cast(ast3.expr, node.expr.gen.py_ast[0])]
        return node.gen.py_ast

    def normal_attribute(self, node: uni.JsxNormalAttribute) -> list[ast3.AST]:
        """Generate Python AST for JSX normal attributes."""
        if not node.name:
            node.gen.py_ast = []
            return node.gen.py_ast

        key_ast = self.pass_ref.sync(ast3.Constant(value=node.name.value), node.name)
        value_ast = (
            cast(ast3.expr, node.value.gen.py_ast[0])  # type: ignore[index]
            if node.value
            else self.pass_ref.sync(ast3.Constant(value=True), node)
        )
        node.gen.py_ast = [
            self.pass_ref.sync(
                ast3.Tuple(elts=[key_ast, value_ast], ctx=ast3.Load()),
                node,
            )
        ]
        return node.gen.py_ast

    def text(self, node: uni.JsxText) -> list[ast3.AST]:
        """Generate Python AST for JSX text nodes."""
        expr = self.pass_ref.sync(ast3.Constant(value=node.value.value), node)
        node.gen.py_ast = [expr]
        return node.gen.py_ast

    def expression(self, node: uni.JsxExpression) -> list[ast3.AST]:
        """Generate Python AST for JSX expression children."""
        node.gen.py_ast = [cast(ast3.expr, node.expr.gen.py_ast[0])]
        return node.gen.py_ast


__all__ = ["EsJsxProcessor", "PyJsxProcessor"]
