import jaclang.compiler.backends.es.estree as es;
import type from jaclang.compiler.backends.es.view_ir { ViewChild }
import from jaclang.compiler.backends.es.view_ir {
    DynamicAttr,
    EachChild,
    EventAttr,
    IfChild,
    RefAttr,
    SpreadAttr,
    StaticAttr,
    ViewLocator
}
import from jaclang.compiler.backends.es.reactive_intent {
    StateField,
    RefField,
    StateUpdate,
    Effect,
    AsyncBoundary
}

impl SolidBackend.name -> str {
    return "solid";
}

impl SolidBackend.required_globals -> list[str] {
    return ["__jacSpawn"];
}

impl SolidBackend._solid_symbols -> set[str] {
    return {
        "createSignal",
        "createEffect",
        "createMemo",
        "createResource",
        "onMount",
        "onCleanup",
        "on",
        "Show",
        "For",
        "Index",
        "Suspense",
        "ErrorBoundary"
    };
}

impl SolidBackend.import_source(symbol: str) -> str {
    if symbol == "Dynamic" {
        return "solid-js/web";
    }
    if symbol in self._solid_symbols() {
        return "solid-js";
    }
    return "@jac/runtime";
}

impl SolidBackend.runtime_source_basename -> str {
    return "solid_runtime.jac";
}

impl SolidBackend.vite_plugin_lines -> (tuple[str, str] | None) {
    return ('import solidPlugin from "vite-plugin-solid";', 'solidPlugin()');
}

impl SolidBackend.build_entry_script(
    entry_module: str, install_global_handlers: bool = True
) -> str {
    import from jaclang.client.solid_entry { build_simple_solid_entry_script }
    return build_simple_solid_entry_script(entry_module, install_global_handlers);
}

impl SolidBackend.build_pages_entry_script(
    entry_module: str, auth_redirect: str, has_app_wrapper: bool
) -> str {
    import from jaclang.client.solid_entry { build_pages_solid_entry_script }
    return build_pages_solid_entry_script(entry_module, auth_redirect, has_app_wrapper);
}

impl SolidBackend.lower_state_field(s: StateField) -> list[es.Statement] {
    setter_name = self._get_setter_name(s.name);
    array_pattern = es.ArrayPattern(
        elements=[es.Identifier(name=s.name), es.Identifier(name=setter_name)]
    );
    create_signal_call = es.CallExpression(
        callee=es.Identifier(name='createSignal'), arguments=[s.init_expr]
    );
    declarator = es.VariableDeclarator(id=array_pattern, init=create_signal_call);
    return [es.VariableDeclaration(declarations=[declarator], kind='const')];
}

impl SolidBackend.lower_ref_field(r: RefField) -> list[es.Statement] {
    declarator = es.VariableDeclarator(id=es.Identifier(name=r.name), init=r.init_expr);
    return [es.VariableDeclaration(declarations=[declarator], kind='let')];
}

impl SolidBackend.lower_state_read(name: str) -> es.Expression {
    return es.CallExpression(callee=es.Identifier(name=name), arguments=[]);
}

impl SolidBackend._jsx_tag_name(
    expr: (es.Expression | None)
) -> (es.JsxIdentifier | es.JsxMemberExpression | None) {
    if isinstance(expr, es.Identifier) {
        return es.JsxIdentifier(name=expr.name);
    }
    if isinstance(expr, es.MemberExpression) and not expr.computed {
        obj_expr = expr.object;
        if obj_expr is None {
            return None;
        }
        obj_node = self._jsx_tag_name(obj_expr);
        prop = expr.property;
        if obj_node is not None and isinstance(prop, es.Identifier) {
            return es.JsxMemberExpression(
                object=obj_node, property=es.JsxIdentifier(name=prop.name)
            );
        }
    }
    return None;
}

impl SolidBackend._map_attr_name(name: str) -> str {
    if name == "className" {
        return "class";
    }
    return name;
}

impl SolidBackend._jsx_attr_str_safe(value: str) -> bool {
    for ch in value {
        if ch in '"\\\n\r\t' {
            return False;
        }
    }
    return True;
}

impl SolidBackend._jsx_attr(
    attr: (StaticAttr | DynamicAttr | EventAttr | RefAttr | SpreadAttr),
    locator: ViewLocator
) -> (es.JsxAttribute | es.JsxSpreadAttribute) {
    if isinstance(attr, SpreadAttr) {
        return locator.at(
            es.JsxSpreadAttribute(argument=attr.value), jac_node=attr.jac_node
        );
    }
    if isinstance(attr, StaticAttr) {
        literal = attr.value;
        raw = literal.value;
        value: (es.Literal | es.JsxExpressionContainer | None) = literal;
        if raw is True {
            value = None;
        } elif isinstance(raw, str) and not self._jsx_attr_str_safe(raw) {
            value = locator.at(
                es.JsxExpressionContainer(expression=literal), jac_node=attr.jac_node
            );
        }
        return self._jsx_named_attr(attr.name, value, attr.jac_node, locator);
    }
    if isinstance(attr, EventAttr) {
        return self._jsx_named_attr(
            attr.name,
            locator.at(
                es.JsxExpressionContainer(expression=attr.handler),
                jac_node=attr.jac_node
            ),
            attr.jac_node,
            locator
        );
    }
    if isinstance(attr, DynamicAttr) {
        return self._jsx_named_attr(
            attr.name,
            locator.at(
                es.JsxExpressionContainer(expression=attr.value), jac_node=attr.jac_node
            ),
            attr.jac_node,
            locator
        );
    }
    return self._jsx_named_attr(
        attr.name,
        locator.at(
            es.JsxExpressionContainer(expression=attr.value), jac_node=attr.jac_node
        ),
        attr.jac_node,
        locator
    );
}

impl SolidBackend._jsx_named_attr(
    name: str,
    value: (es.Literal | es.JsxExpressionContainer | None),
    jac_node: (uni.UniNode | None),
    locator: ViewLocator
) -> es.JsxAttribute {
    name_node = locator.at(
        es.JsxIdentifier(name=self._map_attr_name(name)), jac_node=jac_node
    );
    return locator.at(es.JsxAttribute(name=name_node, value=value), jac_node=jac_node);
}

impl SolidBackend._jsx_child_nodes(
    children: list[ViewChild], locator: ViewLocator
) -> list[any] {
    import from jaclang.compiler.backends.es.view_ir {
        TextChild,
        DynamicChild,
        ElementChild,
        FragmentTag,
        IfChild,
        EachChild
    }
    out = [];
    for child in children {
        if isinstance(child, EachChild) {
            out.append(self._jsx_for(child, locator));
            continue;
        }
        if isinstance(child, IfChild) {
            out.append(self._jsx_show(child, locator));
            continue;
        }
        if isinstance(child, TextChild) {
            out.append(
                locator.at(
                    es.JsxExpressionContainer(expression=child.value),
                    jac_node=child.jac_node
                )
            );
        } elif isinstance(child, DynamicChild) {
            out.append(
                locator.at(
                    es.JsxExpressionContainer(expression=child.value),
                    jac_node=child.jac_node
                )
            );
        } elif isinstance(child, ElementChild) {
            el = child.element;
            if isinstance(el.tag, FragmentTag) {
                for sub in self._jsx_child_nodes(el.children, locator) {
                    out.append(sub);
                }
            } else {
                out.append(self.lower_view(el, locator));
            }
        } else {
            out.append(
                locator.at(
                    es.JsxExpressionContainer(expression=child.expr),
                    jac_node=child.jac_node
                )
            );
        }
    }
    return out;
}

impl SolidBackend._view_children_as_expr(
    children: list[ViewChild], locator: ViewLocator
) -> es.Expression {
    import from jaclang.compiler.backends.es.view_ir { ElementChild, FragmentTag }
    if (
        len(children) == 1
        and isinstance(children[0], ElementChild)
        and not isinstance(children[0].element.tag, FragmentTag)
    ) {
        return self.lower_view(children[0].element, locator);
    }
    return locator.at(
        es.JsxFragment(children=self._jsx_child_nodes(children, locator)), jac_node=None
    );
}

impl SolidBackend._jsx_for(child: EachChild, locator: ViewLocator) -> es.JsxElement {
    each_attr = locator.at(
        es.JsxAttribute(
            name=locator.at(es.JsxIdentifier(name="each"), jac_node=child.jac_node),
            value=locator.at(
                es.JsxExpressionContainer(expression=child.items),
                jac_node=child.jac_node
            )
        ),
        jac_node=child.jac_node
    );
    arrow = locator.at(
        es.ArrowFunctionExpression(
            params=[es.Identifier(name=child.item)],
            body=self._view_children_as_expr(child.body, locator),
            async_=False,
            expression=True
        ),
        jac_node=child.jac_node
    );
    callback = locator.at(
        es.JsxExpressionContainer(expression=arrow), jac_node=child.jac_node
    );
    name_node = locator.at(es.JsxIdentifier(name="For"), jac_node=child.jac_node);
    return self._jsx_element(
        name_node, [each_attr], [callback], child.jac_node, locator
    );
}

impl SolidBackend._jsx_show(child: IfChild, locator: ViewLocator) -> es.JsxElement {
    when_attr = locator.at(
        es.JsxAttribute(
            name=locator.at(es.JsxIdentifier(name="when"), jac_node=child.jac_node),
            value=locator.at(
                es.JsxExpressionContainer(expression=child.`test),
                jac_node=child.jac_node
            )
        ),
        jac_node=child.jac_node
    );
    attrs = [when_attr];
    if child.alternate is not None {
        fallback_attr = locator.at(
            es.JsxAttribute(
                name=locator.at(
                    es.JsxIdentifier(name="fallback"), jac_node=child.jac_node
                ),
                value=locator.at(
                    es.JsxExpressionContainer(
                        expression=self._view_children_as_expr(child.alternate, locator)
                    ),
                    jac_node=child.jac_node
                )
            ),
            jac_node=child.jac_node
        );
        attrs.append(fallback_attr);
    }
    name_node = locator.at(es.JsxIdentifier(name="Show"), jac_node=child.jac_node);
    return self._jsx_element(
        name_node,
        attrs,
        self._jsx_child_nodes(child.consequent, locator),
        child.jac_node,
        locator
    );
}

impl SolidBackend.view_runtime_symbols(view: ViewElement) -> list[str] {
    import from jaclang.compiler.backends.es.view_ir {
        ElementChild,
        IfChild,
        EachChild
    }
    syms = [];
    stack = list(view.children);
    while stack {
        child = stack.pop();
        if isinstance(child, EachChild) {
            syms.append("For");
            stack.extend(child.body);
        } elif isinstance(child, IfChild) {
            syms.append("Show");
            stack.extend(child.consequent);
            if child.alternate is not None {
                stack.extend(child.alternate);
            }
        } elif isinstance(child, ElementChild) {
            stack.extend(child.element.children);
        }
    }
    return syms;
}

impl SolidBackend._jsx_element(
    name_node: (es.JsxIdentifier | es.JsxMemberExpression),
    attrs: list[es.JsxAttribute | es.JsxSpreadAttribute],
    children: list[any],
    jac_node: (uni.UniNode | None),
    locator: ViewLocator
) -> es.JsxElement {
    self_closing = len(children) == 0;
    opening = locator.at(
        es.JsxOpeningElement(
            name=name_node, attributes=attrs, selfClosing=self_closing
        ),
        jac_node=jac_node
    );
    if self_closing {
        return locator.at(es.JsxElement(openingElement=opening), jac_node=jac_node);
    }
    closing = locator.at(es.JsxClosingElement(name=name_node), jac_node=jac_node);
    return locator.at(
        es.JsxElement(
            openingElement=opening, children=children, closingElement=closing
        ),
        jac_node=jac_node
    );
}

impl SolidBackend._jsx_dynamic(
    component_expr: es.Expression,
    attrs: list[es.JsxAttribute | es.JsxSpreadAttribute],
    children: list[any],
    jac_node: (uni.UniNode | None),
    locator: ViewLocator
) -> es.JsxElement {
    comp_attr = locator.at(
        es.JsxAttribute(
            name=locator.at(es.JsxIdentifier(name="component"), jac_node=jac_node),
            value=locator.at(
                es.JsxExpressionContainer(expression=component_expr), jac_node=jac_node
            )
        ),
        jac_node=jac_node
    );
    name_node = locator.at(es.JsxIdentifier(name="Dynamic"), jac_node=jac_node);
    return self._jsx_element(
        name_node, [comp_attr] + attrs, children, jac_node, locator
    );
}

impl SolidBackend.lower_view(view: ViewElement, locator: ViewLocator) -> es.Expression {
    import from jaclang.compiler.backends.es.view_ir {
        HostTag,
        ComponentTag,
        FragmentTag
    }
    tag = view.tag;
    children_nodes = self._jsx_child_nodes(view.children, locator);

    if isinstance(tag, FragmentTag) {
        return locator.at(
            es.JsxFragment(children=children_nodes), jac_node=tag.jac_node
        );
    }
    attr_nodes = [self._jsx_attr(a, locator) for a in view.attrs];
    name_node: (es.JsxIdentifier | es.JsxMemberExpression);
    if isinstance(tag, HostTag) {
        name_node = locator.at(es.JsxIdentifier(name=tag.name), jac_node=tag.jac_node);
    } elif isinstance(tag, ComponentTag) {
        resolved = self._jsx_tag_name(tag.ref);
        assert resolved is not None , "ComponentTag.ref did not resolve to a JSX tag name (producer invariant broken)";
        name_node = locator.at(resolved, jac_node=tag.jac_node);
    } else {
        return self._jsx_dynamic(
            tag.expr, attr_nodes, children_nodes, view.jac_node, locator
        );
    }
    return self._jsx_element(
        name_node, attr_nodes, children_nodes, view.jac_node, locator
    );
}

impl SolidBackend.lower_state_update(u: StateUpdate) -> es.Expression {
    setter_name = self._get_setter_name(u.name);
    if u.aug_op {
        updater_body = es.BinaryExpression(
            operator=u.aug_op, left=es.Identifier(name='prev'), right=u.value
        );
        updater = es.ArrowFunctionExpression(
            params=[es.Identifier(name='prev')],
            body=updater_body,
            async_=False,
            expression=True
        );
        return es.CallExpression(
            callee=es.Identifier(name=setter_name), arguments=[updater]
        );
    }
    return es.CallExpression(
        callee=es.Identifier(name=setter_name), arguments=[u.value]
    );
}

impl SolidBackend.lower_effect(e: Effect) -> list[es.Statement] {
    if not e.is_entry {
        cleanup_callback = es.ArrowFunctionExpression(
            params=[],
            body=es.BlockStatement(body=e.body),
            async_=False,
            expression=False
        );
        cleanup_call = es.CallExpression(
            callee=es.Identifier(name='onCleanup'), arguments=[cleanup_callback]
        );
        return [es.ExpressionStatement(expression=cleanup_call)];
    }
    effect_body: list[es.Statement] = [];
    if e.is_async {
        async_arrow = es.ArrowFunctionExpression(
            params=[],
            body=es.BlockStatement(body=e.body),
            async_=True,
            expression=False
        );
        iife_call = es.CallExpression(callee=async_arrow, arguments=[]);
        effect_body.append(es.ExpressionStatement(expression=iife_call));
    } else {
        setup = es.ArrowFunctionExpression(
            params=[],
            body=es.BlockStatement(body=e.body),
            async_=False,
            expression=False
        );
        effect_body = [
            es.VariableDeclaration(
                kind='const',
                declarations=[
                    es.VariableDeclarator(
                        id=es.Identifier(name='__jacCleanup'),
                        init=es.CallExpression(callee=setup, arguments=[])
                    )
                ]
            ),
            es.IfStatement(
                `test=es.BinaryExpression(
                    operator='===',
                    left=es.UnaryExpression(
                        operator='typeof',
                        prefix=True,
                        argument=es.Identifier(name='__jacCleanup')
                    ),
                    right=es.Literal(value='function')
                ),
                consequent=es.BlockStatement(
                    body=[
                        es.ExpressionStatement(
                            expression=es.CallExpression(
                                callee=es.Identifier(name='onCleanup'),
                                arguments=[es.Identifier(name='__jacCleanup')]
                            )
                        )
                    ]
                )
            )
        ];
    }
    effect_callback = es.ArrowFunctionExpression(
        params=[],
        body=es.BlockStatement(body=effect_body),
        async_=False,
        expression=False
    );
    effect_call = es.CallExpression(
        callee=es.Identifier(name='createEffect'), arguments=[effect_callback]
    );
    return [es.ExpressionStatement(expression=effect_call)];
}

impl SolidBackend.lower_async_boundary(a: AsyncBoundary) -> es.Expression {
    import from jaclang.compiler.backends.es.view_ir {
        ViewElement,
        ComponentTag,
        DynamicAttr,
        DynamicChild,
        ElementChild
    }

    jn = None;
    awaiting_fallback: es.Expression = a.awaiting_expr
        if a.awaiting_expr is not None
        else es.Literal(value=None, raw='null');
    suspense_view = ViewElement(
        tag=ComponentTag(ref=es.Identifier(name='Suspense'), jac_node=jn),
        attrs=[DynamicAttr(name='fallback', value=awaiting_fallback, jac_node=jn)],
        children=[DynamicChild(value=a.try_expr, jac_node=jn)],
        jac_node=jn
    );
    if not a.except_exprs {
        return self.lower_view(suspense_view, ViewLocator(locate=False));
    }
    if len(a.except_exprs) == 1 {
        except_fallback: es.Expression = a.except_exprs[0];
    } else {
        except_fallback = self._view_children_as_expr(
            [DynamicChild(value=ex, jac_node=jn) for ex in a.except_exprs],
            ViewLocator(locate=False)
        );
    }
    error_view = ViewElement(
        tag=ComponentTag(ref=es.Identifier(name='ErrorBoundary'), jac_node=jn),
        attrs=[DynamicAttr(name='fallback', value=except_fallback, jac_node=jn)],
        children=[ElementChild(element=suspense_view, jac_node=jn)],
        jac_node=jn
    );
    return self.lower_view(error_view, ViewLocator(locate=False));
}

impl SolidBackend.state_field_symbols(s: StateField) -> list[str] {
    return ["createSignal"];
}

impl SolidBackend.ref_field_symbols(r: RefField) -> list[str] {
    return [];
}

impl SolidBackend.effect_symbols(e: Effect) -> list[str] {
    if not e.is_entry {
        return ["onCleanup"];
    }
    return ["createEffect"] if e.is_async else ["createEffect", "onCleanup"];
}

impl SolidBackend.async_boundary_symbols(a: AsyncBoundary) -> list[str] {
    syms = ["Suspense"];
    if a.except_exprs {
        syms.append("ErrorBoundary");
    }
    return syms;
}
