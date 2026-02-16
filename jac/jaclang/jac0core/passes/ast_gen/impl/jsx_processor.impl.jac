"""Implementation for jsx_processor constructs."""

impl EsJsxProcessor.init(self: EsJsxProcessor, pass_ref: EsastGenPass) -> None {
    self.pass_ref = pass_ref;
    import from jaclang.compiler.passes.ecmascript { estree as es }
    self.es = es;
}

"""Process JSX element into __jacJsx(tag, props, children) call."""
impl EsJsxProcessor.element(self: EsJsxProcessor, nd: uni.JsxElement) -> Expression {
    es = self.es;
    if (nd.is_fragment or not nd.name) {
        tag_expr: Expression = self.pass_ref.sync_loc(
            es.Literal(value=None), jac_node=nd
        );
    } else {
        tag_expr = cast(
            'Expression',
            nd.name.gen.es_ast
            or self.pass_ref.sync_loc(es.Literal(value=None), jac_node=nd.name)
        );
    }
    attributes = nd.attributes or [];
    has_spread = `any(isinstance(attr, uni.JsxSpreadAttribute) for attr in attributes);
    if not attributes {
        props_expr: Expression = self.pass_ref.sync_loc(
            es.ObjectExpression(properties=[]), jac_node=nd
        );
    } elif has_spread {
        segments: list[Expression] = [];
        for attr in attributes {
            if isinstance(attr, uni.JsxSpreadAttribute) {
                exp = attr.gen.es_ast;
                if isinstance(exp, es.Expression) {
                    segments.append(exp);
                }
            } elif isinstance(attr, uni.JsxNormalAttribute) {
                prop = attr.gen.es_ast;
                if isinstance(prop, es.Property) {
                    segments.append(
                        self.pass_ref.sync_loc(
                            es.ObjectExpression(properties=[prop]), jac_node=attr
                        )
                    );
                }
            }
        }
        if segments {
            assign_member = self.pass_ref.sync_loc(
                es.MemberExpression(
                    object=self.pass_ref.sync_loc(
                        es.Identifier(name='Object'), jac_node=nd
                    ),
                    property=self.pass_ref.sync_loc(
                        es.Identifier(name='assign'), jac_node=nd
                    ),
                    computed=False,
                    optional=False
                ),
                jac_node=nd
            );
            props_expr = self.pass_ref.sync_loc(
                es.CallExpression(
                    callee=assign_member,
                    arguments=[
                        self.pass_ref.sync_loc(
                            es.ObjectExpression(properties=[]), jac_node=nd
                        ),
                        *segments
                    ]
                ),
                jac_node=nd
            );
        } else {
            props_expr = self.pass_ref.sync_loc(
                es.ObjectExpression(properties=[]), jac_node=nd
            );
        }
    } else {
        properties: list[Property] = [];
        for attr in attributes {
            prop = attr.gen.es_ast;
            if isinstance(prop, es.Property) {
                properties.append(prop);
            }
        }
        props_expr = self.pass_ref.sync_loc(
            es.ObjectExpression(properties=properties), jac_node=nd
        );
    }
    children_elements: list[Expression | SpreadElement | None] = [];
    for child in (nd.children or []) {
        child_expr = child.gen.es_ast;
        if (child_expr is None) {
            continue;
        }
        if isinstance(child_expr, `list) {
            children_elements.extend(cast('Expression', expr) for expr in child_expr);
        } else {
            children_elements.append(cast('Expression', child_expr));
        }
    }
    children_expr = self.pass_ref.sync_loc(
        es.ArrayExpression(elements=children_elements), jac_node=nd
    );
    call_expr = self.pass_ref.sync_loc(
        es.CallExpression(
            callee=self.pass_ref.sync_loc(es.Identifier(name='__jacJsx'), jac_node=nd),
            arguments=[tag_expr, props_expr, children_expr]
        ),
        jac_node=nd
    );
    return call_expr;
}

"""Process JSX element name."""
impl EsJsxProcessor.element_name(
    self: EsJsxProcessor, nd: uni.JsxElementName
) -> Expression {
    es = self.es;
    if not nd.parts {
        expr = self.pass_ref.sync_loc(es.Literal(value=None), jac_node=nd);
    } else {
        parts = [part.value for part in nd.parts];
        first = parts[0];
        if (len(parts) > 1) {
            expr = self.pass_ref.sync_loc(
                es.Identifier(name=first), jac_node=nd.parts[0]
            );
            for (idx, part) in enumerate(parts[1:], start=1) {
                expr = self.pass_ref.sync_loc(
                    es.MemberExpression(
                        object=expr,
                        property=self.pass_ref.sync_loc(
                            es.Identifier(name=part), jac_node=nd.parts[idx]
                        ),
                        computed=False,
                        optional=False
                    ),
                    jac_node=nd
                );
            }
        } elif (first and first[0].isupper()) {
            expr = self.pass_ref.sync_loc(
                es.Identifier(name=first), jac_node=nd.parts[0]
            );
        } else {
            expr = self.pass_ref.sync_loc(es.Literal(value=first), jac_node=nd);
        }
    }
    nd.gen.es_ast = expr;
    return expr;
}

"""Process JSX spread attribute."""
impl EsJsxProcessor.spread_attribute(
    self: EsJsxProcessor, nd: uni.JsxSpreadAttribute
) -> Expression {
    es = self.es;
    expr: Expression = cast('Expression', nd.expr.gen.es_ast)
    if (nd.expr and nd.expr.gen.es_ast)
    else self.pass_ref.sync_loc(es.ObjectExpression(properties=[]), jac_node=nd);
    nd.gen.es_ast = expr;
    return expr;
}

"""Process JSX normal attribute."""
impl EsJsxProcessor.normal_attribute(
    self: EsJsxProcessor, nd: uni.JsxNormalAttribute
) -> Property {
    es = self.es;
    key_expr = self.pass_ref.sync_loc(
        es.Literal(value=nd.name.value), jac_node=nd.name
    );
    if (nd.value is None) {
        value_expr = self.pass_ref.sync_loc(es.Literal(value=True), jac_node=nd);
    } elif isinstance(nd.value, uni.String) {
        value_expr = self.pass_ref.sync_loc(
            es.Literal(value=nd.value.lit_value), jac_node=nd.value
        );
    } else {
        value_expr = nd.value.gen.es_ast
        or self.pass_ref.sync_loc(es.Literal(value=None), jac_node=nd.value);
    }
    prop = self.pass_ref.sync_loc(
        es.Property(
            key=key_expr,
            value=value_expr,
            kind='init',
            method=False,
            shorthand=False,
            computed=False
        ),
        jac_node=nd
    );
    nd.gen.es_ast = prop;
    return prop;
}

"""Process JSX text node."""
impl EsJsxProcessor.text(self: EsJsxProcessor, nd: uni.JsxText) -> Expression {
    es = self.es;
    expr = self.pass_ref.sync_loc(
        es.Literal(value=nd.get_normalized_text()), jac_node=nd
    );
    nd.gen.es_ast = expr;
    return expr;
}

"""Process JSX expression child."""
impl EsJsxProcessor.expression(
    self: EsJsxProcessor, nd: uni.JsxExpression
) -> Expression {
    es = self.es;
    expr: Expression = cast('Expression', nd.expr.gen.es_ast)
    if (nd.expr and nd.expr.gen.es_ast)
    else self.pass_ref.sync_loc(es.Literal(value=None), jac_node=nd.expr);
    nd.gen.es_ast = expr;
    return expr;
}

impl PyJsxProcessor.init(self: PyJsxProcessor, pass_ref: PyastGenPass) -> None {
    self.pass_ref = pass_ref;
}

"""Generate Python AST for JSX elements."""
impl PyJsxProcessor.element(self: PyJsxProcessor, nd: uni.JsxElement) -> list[ast3.AST] {
    if (nd.is_fragment or not nd.name) {
        tag_arg: ast3.expr = self.pass_ref.sync(ast3.Constant(value=None), nd);
    } else {
        tag_arg = cast(ast3.expr, nd.name.gen.py_ast[0]);
    }
    if not nd.attributes {
        attrs_expr = self.pass_ref.sync(ast3.Dict(keys=[], values=[]), nd);
    } elif `any(isinstance(attr, uni.JsxSpreadAttribute) for attr in nd.attributes) {
        attrs_expr = self.pass_ref.sync(ast3.Dict(keys=[], values=[]), nd);
        for attr in nd.attributes {
            if isinstance(attr, uni.JsxSpreadAttribute) {
                attr_ast = cast(ast3.expr, attr.gen.py_ast[0]);
                attrs_expr = self.pass_ref.sync(
                    ast3.Dict(keys=[None, None], values=[attrs_expr, attr_ast]), attr
                );
            } elif isinstance(attr, uni.JsxNormalAttribute) {
                attr_tuple = cast(ast3.Tuple, attr.gen.py_ast[0]);
                (key_ast, value_ast) = attr_tuple.elts;
                attrs_expr = self.pass_ref.sync(
                    ast3.Dict(
                        keys=[None, key_ast],
                        values=[attrs_expr, cast(ast3.expr, value_ast)]
                    ),
                    attr
                );
            }
        }
    } else {
        keys: list[(ast3.expr | None)] = [];
        values: list[ast3.expr] = [];
        for attr in nd.attributes {
            if isinstance(attr, uni.JsxNormalAttribute) {
                attr_ast = cast(ast3.Tuple, attr.gen.py_ast[0]);
                (key_ast, value_ast) = attr_ast.elts;
                keys.append(cast(ast3.expr, key_ast));
                values.append(cast(ast3.expr, value_ast));
            }
        }
        attrs_expr = self.pass_ref.sync(ast3.Dict(keys=keys, values=values), nd);
    }
    if nd.children {
        children_arg = self.pass_ref.sync(
            ast3.List(
                elts=[cast(ast3.expr, c.gen.py_ast[0]) for c in nd.children],
                ctx=ast3.Load()
            ),
            nd
        );
    } else {
        children_arg = self.pass_ref.sync(ast3.List(elts=[], ctx=ast3.Load()), nd);
    }
    call = self.pass_ref.sync(
        ast3.Call(
            func=self.pass_ref.jaclib_obj('jsx'),
            args=[tag_arg, attrs_expr, children_arg],
            keywords=[]
        ),
        nd
    );
    nd.gen.py_ast = [call];
    return nd.gen.py_ast;
}

"""Generate Python AST for JSX element names."""
impl PyJsxProcessor.element_name(
    self: PyJsxProcessor, nd: uni.JsxElementName
) -> list[ast3.AST] {
    name_str = '.'.join(part.value for part in nd.parts);
    expr: ast3.expr;
    if (nd.parts and nd.parts[0].value[0].isupper()) {
        expr = self.pass_ref.sync(ast3.Name(id=name_str, ctx=ast3.Load()), nd);
    } else {
        expr = self.pass_ref.sync(ast3.Constant(value=name_str), nd);
    }
    nd.gen.py_ast = [expr];
    return nd.gen.py_ast;
}

"""Generate Python AST for JSX spread attributes."""
impl PyJsxProcessor.spread_attribute(
    self: PyJsxProcessor, nd: uni.JsxSpreadAttribute
) -> list[ast3.AST] {
    nd.gen.py_ast = [cast(ast3.expr, nd.expr.gen.py_ast[0])];
    return nd.gen.py_ast;
}

"""Generate Python AST for JSX normal attributes."""
impl PyJsxProcessor.normal_attribute(
    self: PyJsxProcessor, nd: uni.JsxNormalAttribute
) -> list[ast3.AST] {
    if not nd.name {
        nd.gen.py_ast = [];
        return nd.gen.py_ast;
    }
    key_ast = self.pass_ref.sync(ast3.Constant(value=nd.name.value), nd.name);
    value_ast: ast3.expr;
    if (nd.value and nd.value.gen.py_ast) {
        value_ast = cast(ast3.expr, nd.value.gen.py_ast[0]);
    } else {
        value_ast = self.pass_ref.sync(ast3.Constant(value=True), nd);
    }
    nd.gen.py_ast = [
        self.pass_ref.sync(ast3.Tuple(elts=[key_ast, value_ast], ctx=ast3.Load()), nd)
    ];
    return nd.gen.py_ast;
}

"""Generate Python AST for JSX text nodes."""
impl PyJsxProcessor.text(self: PyJsxProcessor, nd: uni.JsxText) -> list[ast3.AST] {
    expr = self.pass_ref.sync(ast3.Constant(value=nd.get_normalized_text()), nd);
    nd.gen.py_ast = [expr];
    return nd.gen.py_ast;
}

"""Generate Python AST for JSX expression children."""
impl PyJsxProcessor.expression(
    self: PyJsxProcessor, nd: uni.JsxExpression
) -> list[ast3.AST] {
    nd.gen.py_ast = [cast(ast3.expr, nd.expr.gen.py_ast[0])];
    return nd.gen.py_ast;
}
