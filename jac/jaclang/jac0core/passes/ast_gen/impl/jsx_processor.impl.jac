"""Implementation for jsx_processor constructs."""

impl EsJsxProcessor.init(self: EsJsxProcessor, pass_ref: EsastGenPass) -> None {
    self.pass_ref = pass_ref;
    import from jaclang.compiler.passes.ecmascript { estree as es }
    self.es = es;
    # Memoizes each element's built `ViewElement` by node id, so a parent's
    # `ElementChild` can carry its child's neutral tree (rather than splicing the
    # child's already-lowered expression, which would freeze the child to the
    # backend that lowered it first and break a future per-backend `lower_view`).
    self._view_by_node = {};
}

"""Build the neutral View IR tree for a JSX element, then lower it.

Replaces the former direct ESTree-call construction: this resolves the tag
(host / component / fragment / dynamic) and classifies the attributes and
children ONCE into a framework-neutral `ViewElement`, then hands it to the
active backend's `lower_view`. The JS-family backends rebuild the same
`__jacJsx(tag, props, [children])` call from the tree (Solid additionally
thunks dynamic positions); a future Svelte backend lowers it to template text.
The dynamic-position thunk is no longer pre-applied here (contract §4.2 view
seam moved into `lower_view`)."""
impl EsJsxProcessor.element(self: EsJsxProcessor, nd: uni.JsxElement) -> Expression {
    es = self.es;
    # Deferred runtime import — see the type-only note in `jsx_processor.jac`.
    import from jaclang.compiler.passes.ecmascript.view_ir {
        ViewElement,
        HostTag,
        ComponentTag,
        FragmentTag,
        DynamicTag,
        SpreadAttr,
        TextChild,
        DynamicChild,
        ElementChild,
        SlotChild
    }
    # --- tag, resolved once ---
    if nd.dynamic_tag is not None {
        # Dynamic tag `<@expr ...>` — the tag is the expression's value
        # (a host-tag string, a view reference, or a `str | type`).
        dyn_expr: Expression = cast(
            'Expression',
            nd.dynamic_tag.gen.es_ast
            or self.pass_ref.sync_loc(es.Literal(value=None), jac_node=nd)
        );
        tag = DynamicTag(expr=dyn_expr, jac_node=nd);
    } elif (nd.is_fragment or not nd.name) {
        tag = FragmentTag(jac_node=nd);
    } else {
        parts = nd.name.parts or [];
        first_val = parts[0].value if parts else None;
        # Mirror `element_name`'s rule: a single lowercase part is a host tag
        # (`<div>` → string literal); dotted names and Capitalized names are
        # component references (the `Identifier`/member chain already built).
        is_host = bool(parts)
        and (len(parts) == 1)
        and bool(first_val)
        and not first_val[0].isupper();
        if is_host {
            tag = HostTag(name=first_val, jac_node=nd.name);
        } else {
            ref: Expression = cast(
                'Expression',
                nd.name.gen.es_ast
                or self.pass_ref.sync_loc(es.Literal(value=None), jac_node=nd.name)
            );
            tag = ComponentTag(ref=ref, jac_node=nd.name);
        }
    }
    # --- attributes, classified once (in source order) ---
    attrs = [];
    for attr in (nd.attributes or []) {
        if isinstance(attr, uni.JsxSpreadAttribute) {
            spread_val: Expression = cast(
                'Expression',
                attr.gen.es_ast
                or self.pass_ref.sync_loc(
                    es.ObjectExpression(properties=[]), jac_node=attr
                )
            );
            attrs.append(SpreadAttr(value=spread_val, jac_node=attr));
        } elif isinstance(attr, uni.JsxNormalAttribute) {
            attrs.append(self.normal_attribute(attr));
        }
    }
    # --- children, in source order (structural whitespace + comments dropped) ---
    children = [];
    for child in (nd.children or []) {
        # Drop JsxText nodes whose normalized text is empty (structural
        # whitespace such as the newline+indent between `}` and the next
        # `{`). Same-line whitespace ` ` between adjacent expressions is
        # NOT empty after normalization and is preserved as a child.
        if isinstance(child, uni.JsxText) and not child.get_normalized_text() {
            continue;
        }
        # JsxComment nodes render nothing — they exist only so the formatter
        # can round-trip `{#* ... *#}` source.
        if isinstance(child, uni.JsxComment) {
            continue;
        }
        if isinstance(child, uni.JsxText) {
            children.append(
                TextChild(value=cast('Expression', child.gen.es_ast), jac_node=child)
            );
        } elif isinstance(child, uni.JsxExpression) {
            # Lift the idiomatic, provably-pure control-flow shapes (view-shaped
            # ternaries, keyed/filtered comprehensions) to neutral `IfChild`/
            # `EachChild` so Solid can render `<Show>`/`<For>`; everything else
            # stays the raw, un-thunked expression that `lower_view` wraps.
            lifted = self._lift_control_flow(child);
            if lifted is not None {
                children.append(lifted);
            } else {
                children.append(
                    DynamicChild(
                        value=cast('Expression', child.gen.es_ast), jac_node=child
                    )
                );
            }
        } elif isinstance(child, uni.JsxElement) {
            # Carry the child's neutral tree, not its already-lowered expression.
            # The exit pass is post-order, so the child element's `element()` ran
            # first and memoized its `ViewElement`; a missing entry means that
            # invariant broke and the child would otherwise silently vanish from
            # the output. Fail loudly instead of dropping it.
            child_ve = self._view_by_node.get(id(child));
            assert child_ve is not None , "child JsxElement has no memoized ViewElement (post-order invariant broken)";
            children.append(ElementChild(element=child_ve, jac_node=child));
        } else {
            # A statement-form slot (or any other pre-lowered child): its value
            # is an already-built expression (the accumulator IIFE) emitted
            # verbatim — never thunked. A list-valued child expands in place.
            child_expr = child.gen.es_ast;
            if (child_expr is None) {
                continue;
            }
            if isinstance(child_expr, `list) {
                for sub in child_expr {
                    children.append(
                        SlotChild(expr=cast('Expression', sub), jac_node=child)
                    );
                }
            } else {
                children.append(
                    SlotChild(expr=cast('Expression', child_expr), jac_node=child)
                );
            }
        }
    }
    view = ViewElement(tag=tag, attrs=attrs, children=children, jac_node=nd);
    self._view_by_node[id(nd)] = view;
    self.pass_ref._ensure_backend();
    return self.pass_ref.backend.lower_view(view, self.pass_ref.sync_loc);
}

"""Lift a control-flow JSX expression child to a neutral node, or `None`.

Detection runs on the **Jac AST** (where a comprehension and a ternary are
unambiguous — after lowering, a `for` and a `.map` blur together). Only the
idiomatic, provably-pure shapes lift; the `&&` short-form is intentionally left
as a `DynamicChild` (its falsy-value rendering would silently change under a
`{#if}`-style backend)."""
impl EsJsxProcessor._lift_control_flow(
    self: EsJsxProcessor, child: uni.JsxExpression
) -> (IfChild | EachChild | None) {
    expr = child.expr;
    # `ListCompr` covers list/set/generator comprehensions (`GenCompr`/`SetCompr`
    # subclass it) — i.e. both the `[<li> for …]` and `{{ <li> for … }}` forms.
    if isinstance(expr, uni.ListCompr) {
        return self._lift_each(child, expr);
    }
    if isinstance(expr, uni.IfElseExpr) {
        return self._lift_if(child, expr);
    }
    return None;
}

"""Lift `{[<el key={…}> for item in coll if pred]}` to an `EachChild`.

Conservative: only a *single*-clause comprehension whose loop variable is a plain
name and whose output is a JSX element lifts; anything else returns `None` (stays
a `DynamicChild`, rendered by the comprehension's own `.map()` lowering). Filters
fold into `items` as `coll.filter(item => pred)` (Svelte's `{#each}` has no filter
clause; Solid's `<For>` takes the filtered iterable directly), the authored `key=`
lifts onto `EachChild.key`, and the body element is carried with `key` removed."""
impl EsJsxProcessor._lift_each(
    self: EsJsxProcessor, child: uni.JsxExpression, compr: uni.ListCompr
) -> (EachChild | None) {
    es = self.es;
    import from jaclang.compiler.passes.ecmascript.view_ir {
        ViewElement,
        ElementChild,
        EachChild
    }
    if len(compr.compr) != 1 {
        # Nested `for`s (`for a in A for b in B`) would need nested `EachChild`s;
        # not yet recognised — fall back to the `.map()` lowering.
        return None;
    }
    inner = compr.compr[0];
    out_expr = compr.out_expr;
    if not isinstance(out_expr, uni.JsxElement) {
        return None;
    }
    if not isinstance(inner.target, uni.Name) {
        return None;
    }
    out_ve = self._view_by_node.get(id(out_expr));
    if out_ve is None {
        return None;
    }
    item_name = inner.target.value;
    items_expr = inner.collection.gen.es_ast;
    if items_expr is None {
        return None;
    }
    items_expr = cast('Expression', items_expr);
    for cond in (inner.conditional or []) {
        pred = cond.gen.es_ast;
        if pred is None {
            return None;
        }
        filter_arrow = es.ArrowFunctionExpression(
            params=[es.Identifier(name=item_name)],
            body=cast('Expression', pred),
            async_=False,
            expression=True
        );
        items_expr = es.CallExpression(
            callee=es.MemberExpression(
                object=items_expr, property=es.Identifier(name='filter'), computed=False
            ),
            arguments=[filter_arrow]
        );
    }
    (key_expr, body_attrs) = self._split_key(out_ve);
    body_ve = ViewElement(
        tag=out_ve.tag,
        attrs=body_attrs,
        children=out_ve.children,
        jac_node=out_ve.jac_node
    );
    return EachChild(
        items=items_expr,
        item=item_name,
        key=key_expr,
        body=[ElementChild(element=body_ve, jac_node=out_expr)],
        js_fallback=cast('Expression', child.gen.es_ast),
        jac_node=child
    );
}

"""Lift `{<A/> if cond else <B/>}` (a view-shaped ternary) to an `IfChild`.

Lifts only when the consequent is a JSX element and the alternate is either a JSX
element (→ fallback) or the literal `None` (→ no fallback); an arbitrary-expression
alternate returns `None` so it stays a `DynamicChild` (the ternary renders as-is).
The `js_fallback` is the already-built `ConditionalExpression`, so a JS-family
backend emits the identical `?:`."""
impl EsJsxProcessor._lift_if(
    self: EsJsxProcessor, child: uni.JsxExpression, ternary: uni.IfElseExpr
) -> (IfChild | None) {
    es = self.es;
    import from jaclang.compiler.passes.ecmascript.view_ir { IfChild }
    # The arms are wrapped in `CfgExpr`; unwrap to the authored expression.
    cons_inner = ternary.value.expr;
    alt_inner = ternary.else_value.expr;
    if not isinstance(cons_inner, uni.JsxElement) {
        return None;
    }
    consequent = self._view_arm(cons_inner);
    if consequent is None {
        return None;
    }
    if isinstance(alt_inner, uni.JsxElement) {
        alternate = self._view_arm(alt_inner);
        if alternate is None {
            return None;
        }
    } else {
        # A non-JSX alternate lifts only when it is the literal `None`
        # (`… else None` → a `<Show>` with no fallback). Any other expression is
        # not view-shaped, so leave the whole ternary as a `DynamicChild`.
        alt_es = alt_inner.gen.es_ast;
        if isinstance(alt_es, es.Literal) and alt_es.value is None {
            alternate = None;
        } else {
            return None;
        }
    }
    test = ternary.condition.gen.es_ast;
    if test is None {
        return None;
    }
    return IfChild(
        test=cast('Expression', test),
        consequent=consequent,
        alternate=alternate,
        js_fallback=cast('Expression', child.gen.es_ast),
        jac_node=child
    );
}

"""The neutral child list for a ternary/comprehension arm that is a JSX element."""
impl EsJsxProcessor._view_arm(
    self: EsJsxProcessor, nd: uni.JsxElement
) -> (list | None) {
    import from jaclang.compiler.passes.ecmascript.view_ir { ElementChild }
    ve = self._view_by_node.get(id(nd));
    if ve is None {
        return None;
    }
    return [ElementChild(element=ve, jac_node=nd)];
}

"""Split a list element's authored `key=` off its attributes."""
impl EsJsxProcessor._split_key(self: EsJsxProcessor, ve: ViewElement) -> tuple {
    import from jaclang.compiler.passes.ecmascript.view_ir { StaticAttr, DynamicAttr }
    key_expr = None;
    kept = [];
    for a in ve.attrs {
        if isinstance(a, (StaticAttr, DynamicAttr)) and a.name == "key" {
            key_expr = a.value;
        } else {
            kept.append(a);
        }
    }
    return (key_expr, kept);
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

"""Classify a JSX normal attribute into a neutral View IR attribute.

Resolves the attribute kind ONCE (the classification the backends used to
re-sniff): a value-less attribute and a string literal are `StaticAttr` (string
literals are HTML-unescaped, and `className`/`class` tokens rewritten against the
module's scoped `.style.css` annex); `on[A-Z]…` is an `EventAttr` (the React DOM
convention — `onClick`, `onInput`); `ref` is a `RefAttr` (an imperative element
hook); everything else is a `DynamicAttr`. The dynamic-position thunk (contract
§4.2) is NOT applied here — `lower_view` owns it (no-op on hooks backends, a
`() => expr` thunk on signals backends), keying off the attribute kind rather
than re-deriving the fragile `on[A-Z]`/`ref` heuristic per backend."""
impl EsJsxProcessor.normal_attribute(
    self: EsJsxProcessor, nd: uni.JsxNormalAttribute
) -> (StaticAttr | DynamicAttr | EventAttr | RefAttr) {
    es = self.es;
    # Deferred runtime import — see the type-only note in `jsx_processor.jac`.
    import from jaclang.compiler.passes.ecmascript.view_ir {
        StaticAttr,
        DynamicAttr,
        EventAttr,
        RefAttr
    }
    attr_name = nd.name.value;
    if (nd.value is None) {
        value_expr = self.pass_ref.sync_loc(es.Literal(value=True), jac_node=nd);
        return StaticAttr(name=attr_name, value=value_expr, jac_node=nd);
    } elif isinstance(nd.value, uni.String) {
        import html;
        attr_value = html.unescape(nd.value.lit_value);
        # Rewrite `className`/`class` literals against the module's scoped
        # `.style.css` annex (if any): declared class tokens are hashed to
        # match the rewritten CSS selectors.
        sheet = self.pass_ref.scoped_styles;
        if (sheet is not None and attr_name in ('className', 'class')) {
            attr_value = sheet.rewrite_class_value(attr_value);
        }
        value_expr = self.pass_ref.sync_loc(
            es.Literal(value=attr_value), jac_node=nd.value
        );
        return StaticAttr(name=attr_name, value=value_expr, jac_node=nd);
    }
    value_expr = nd.value.gen.es_ast
    or self.pass_ref.sync_loc(es.Literal(value=None), jac_node=nd.value);
    value_expr = cast('Expression', value_expr);
    # NOTE the event heuristic's fragility (contract §4.2): it keys on an
    # uppercase third char, so a lowercase custom prop like `onfoo` is NOT
    # recognized as a handler and falls through to `DynamicAttr` (and is thunked).
    is_event = attr_name.startswith('on')
    and len(attr_name) > 2
    and attr_name[2].isupper();
    if is_event {
        return EventAttr(name=attr_name, handler=value_expr, jac_node=nd);
    }
    if attr_name == 'ref' {
        return RefAttr(name=attr_name, value=value_expr, jac_node=nd);
    }
    return DynamicAttr(name=attr_name, value=value_expr, jac_node=nd);
}

"""Process JSX text node."""
impl EsJsxProcessor.text(self: EsJsxProcessor, nd: uni.JsxText) -> Expression {
    import html;
    es = self.es;
    expr = self.pass_ref.sync_loc(
        es.Literal(value=html.unescape(nd.get_normalized_text())), jac_node=nd
    );
    nd.gen.es_ast = expr;
    return expr;
}

"""Process JSX expression child `{expr}` — store the raw, un-thunked expression.

The View IR seam moved the dynamic-position thunk into `lower_view` (contract
§4.2), so this only resolves the embedded expression; `element` wraps it in a
`DynamicChild` and the backend thunks it (no-op on hooks, `() => expr` on
signals) when lowering."""
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
impl PyJsxProcessor.element(
    self: PyJsxProcessor, nd: uni.JsxElement
) -> list[ast3.AST] {
    if nd.dynamic_tag is not None {
        tag_arg: ast3.expr = cast(ast3.expr, nd.dynamic_tag.gen.py_ast[0]);
    } elif (nd.is_fragment or not nd.name) {
        tag_arg = self.pass_ref.sync(ast3.Constant(value=None), nd);
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
        # Drop JsxText nodes whose normalized text is empty (structural
        # whitespace) and JsxComment nodes (Jac-native JSX block comments
        # render nothing), matching the client-side codegen behavior so
        # server-rendered JSX produces the same children list.
        kept_children = [
            c
            for c in nd.children
            if not isinstance(c, uni.JsxComment)
            and not (isinstance(c, uni.JsxText) and not c.get_normalized_text())
        ];
        children_arg = self.pass_ref.sync(
            ast3.List(
                elts=[cast(ast3.expr, c.gen.py_ast[0]) for c in kept_children],
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
    if (nd.value and isinstance(nd.value, uni.String)) {
        import html;
        value_ast = self.pass_ref.sync(
            ast3.Constant(value=html.unescape(nd.value.lit_value)), nd.value
        );
    } elif (nd.value and nd.value.gen.py_ast) {
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
    import html;
    expr = self.pass_ref.sync(
        ast3.Constant(value=html.unescape(nd.get_normalized_text())), nd
    );
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
