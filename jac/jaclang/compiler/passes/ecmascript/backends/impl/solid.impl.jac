import jaclang.compiler.passes.ecmascript.estree as es;
import from jaclang.compiler.passes.ecmascript.reactive_intent {
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
    return "solid_runtime.cl.jac";
}

impl SolidBackend.vite_plugin_lines -> (tuple[str, str] | None) {
    return ('import solidPlugin from "vite-plugin-solid";', 'solidPlugin()');
}

impl SolidBackend.build_entry_script(
    entry_module: str, install_global_handlers: bool = True
) -> str {
    import from jaclang.runtimelib.solid_entry { build_simple_solid_entry_script }
    return build_simple_solid_entry_script(entry_module, install_global_handlers);
}

impl SolidBackend.build_pages_entry_script(
    entry_module: str, auth_redirect: str, has_app_wrapper: bool
) -> str {
    import from jaclang.runtimelib.solid_entry { build_pages_solid_entry_script }
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

impl SolidBackend._noloc(es_node: any, jac_node: any = None) -> any {
    return es_node;
}

impl SolidBackend._jsx_tag_name(
    expr: es.Expression
) -> (es.JsxIdentifier | es.JsxMemberExpression | None) {
    if isinstance(expr, es.Identifier) {
        return es.JsxIdentifier(name=expr.name);
    }
    if isinstance(expr, es.MemberExpression) and not expr.computed {
        obj_node = self._jsx_tag_name(expr.object);
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
    attr: any, sync_loc: any
) -> (es.JsxAttribute | es.JsxSpreadAttribute) {
    import from jaclang.compiler.passes.ecmascript.view_ir {
        StaticAttr,
        EventAttr,
        SpreadAttr
    }
    if isinstance(attr, SpreadAttr) {
        return sync_loc(
            es.JsxSpreadAttribute(argument=attr.value), jac_node=attr.jac_node
        );
    }
    name_node = sync_loc(
        es.JsxIdentifier(name=self._map_attr_name(attr.name)), jac_node=attr.jac_node
    );
    if isinstance(attr, StaticAttr) {
        if isinstance(attr.value, es.Literal) and attr.value.value is True {
            value: (es.Literal | es.JsxExpressionContainer | None) = None;
        } elif (
            isinstance(attr.value, es.Literal)
            and isinstance(attr.value.value, str)
            and not self._jsx_attr_str_safe(attr.value.value)
        ) {
            value = sync_loc(
                es.JsxExpressionContainer(expression=attr.value), jac_node=attr.jac_node
            );
        } else {
            value = attr.value;
        }
    } elif isinstance(attr, EventAttr) {
        value = sync_loc(
            es.JsxExpressionContainer(expression=attr.handler), jac_node=attr.jac_node
        );
    } else {
        value = sync_loc(
            es.JsxExpressionContainer(expression=attr.value), jac_node=attr.jac_node
        );
    }
    return sync_loc(
        es.JsxAttribute(name=name_node, value=value), jac_node=attr.jac_node
    );
}

impl SolidBackend._jsx_child_nodes(children: list, sync_loc: any) -> list {
    import from jaclang.compiler.passes.ecmascript.view_ir {
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
            out.append(self._jsx_for(child, sync_loc));
            continue;
        }
        if isinstance(child, IfChild) {
            out.append(self._jsx_show(child, sync_loc));
            continue;
        }
        if isinstance(child, TextChild) {
            out.append(
                sync_loc(
                    es.JsxExpressionContainer(expression=child.value),
                    jac_node=child.jac_node
                )
            );
        } elif isinstance(child, DynamicChild) {
            out.append(
                sync_loc(
                    es.JsxExpressionContainer(expression=child.value),
                    jac_node=child.jac_node
                )
            );
        } elif isinstance(child, ElementChild) {
            el = child.element;
            if isinstance(el.tag, FragmentTag) {
                for sub in self._jsx_child_nodes(el.children, sync_loc) {
                    out.append(sub);
                }
            } else {
                out.append(self.lower_view(el, sync_loc));
            }
        } else {
            out.append(
                sync_loc(
                    es.JsxExpressionContainer(expression=child.expr),
                    jac_node=child.jac_node
                )
            );
        }
    }
    return out;
}

impl SolidBackend._view_children_as_expr(
    children: list, sync_loc: any
) -> es.Expression {
    import from jaclang.compiler.passes.ecmascript.view_ir { ElementChild, FragmentTag }
    if (
        len(children) == 1
        and isinstance(children[0], ElementChild)
        and not isinstance(children[0].element.tag, FragmentTag)
    ) {
        return self.lower_view(children[0].element, sync_loc);
    }
    return sync_loc(
        es.JsxFragment(children=self._jsx_child_nodes(children, sync_loc)),
        jac_node=None
    );
}

impl SolidBackend._jsx_for(child: any, sync_loc: any) -> es.JsxElement {
    each_attr = sync_loc(
        es.JsxAttribute(
            name=sync_loc(es.JsxIdentifier(name="each"), jac_node=child.jac_node),
            value=sync_loc(
                es.JsxExpressionContainer(expression=child.items),
                jac_node=child.jac_node
            )
        ),
        jac_node=child.jac_node
    );
    arrow = sync_loc(
        es.ArrowFunctionExpression(
            params=[es.Identifier(name=child.item)],
            body=self._view_children_as_expr(child.body, sync_loc),
            async_=False,
            expression=True
        ),
        jac_node=child.jac_node
    );
    callback = sync_loc(
        es.JsxExpressionContainer(expression=arrow), jac_node=child.jac_node
    );
    name_node = sync_loc(es.JsxIdentifier(name="For"), jac_node=child.jac_node);
    return self._jsx_element(
        name_node, [each_attr], [callback], child.jac_node, sync_loc
    );
}

impl SolidBackend._jsx_show(child: any, sync_loc: any) -> es.JsxElement {
    when_attr = sync_loc(
        es.JsxAttribute(
            name=sync_loc(es.JsxIdentifier(name="when"), jac_node=child.jac_node),
            value=sync_loc(
                es.JsxExpressionContainer(expression=child.test),
                jac_node=child.jac_node
            )
        ),
        jac_node=child.jac_node
    );
    attrs = [when_attr];
    if child.alternate is not None {
        fallback_attr = sync_loc(
            es.JsxAttribute(
                name=sync_loc(
                    es.JsxIdentifier(name="fallback"), jac_node=child.jac_node
                ),
                value=sync_loc(
                    es.JsxExpressionContainer(
                        expression=self._view_children_as_expr(
                            child.alternate, sync_loc
                        )
                    ),
                    jac_node=child.jac_node
                )
            ),
            jac_node=child.jac_node
        );
        attrs.append(fallback_attr);
    }
    name_node = sync_loc(es.JsxIdentifier(name="Show"), jac_node=child.jac_node);
    return self._jsx_element(
        name_node,
        attrs,
        self._jsx_child_nodes(child.consequent, sync_loc),
        child.jac_node,
        sync_loc
    );
}

impl SolidBackend.view_runtime_symbols(view: ViewElement) -> list[str] {
    import from jaclang.compiler.passes.ecmascript.view_ir {
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
    name_node: any, attrs: list, children: list, jac_node: any, sync_loc: any
) -> es.JsxElement {
    self_closing = len(children) == 0;
    opening = sync_loc(
        es.JsxOpeningElement(
            name=name_node, attributes=attrs, selfClosing=self_closing
        ),
        jac_node=jac_node
    );
    if self_closing {
        return sync_loc(es.JsxElement(openingElement=opening), jac_node=jac_node);
    }
    closing = sync_loc(es.JsxClosingElement(name=name_node), jac_node=jac_node);
    return sync_loc(
        es.JsxElement(
            openingElement=opening, children=children, closingElement=closing
        ),
        jac_node=jac_node
    );
}

impl SolidBackend._jsx_dynamic(
    component_expr: es.Expression,
    attrs: list,
    children: list,
    jac_node: any,
    sync_loc: any
) -> es.JsxElement {
    comp_attr = sync_loc(
        es.JsxAttribute(
            name=sync_loc(es.JsxIdentifier(name="component"), jac_node=jac_node),
            value=sync_loc(
                es.JsxExpressionContainer(expression=component_expr), jac_node=jac_node
            )
        ),
        jac_node=jac_node
    );
    name_node = sync_loc(es.JsxIdentifier(name="Dynamic"), jac_node=jac_node);
    return self._jsx_element(
        name_node, [comp_attr] + attrs, children, jac_node, sync_loc
    );
}

impl SolidBackend.lower_view(view: ViewElement, sync_loc: any) -> es.Expression {
    import from jaclang.compiler.passes.ecmascript.view_ir {
        HostTag,
        ComponentTag,
        FragmentTag
    }
    tag = view.tag;
    children_nodes = self._jsx_child_nodes(view.children, sync_loc);

    if isinstance(tag, FragmentTag) {
        return sync_loc(es.JsxFragment(children=children_nodes), jac_node=tag.jac_node);
    }
    attr_nodes = [self._jsx_attr(a, sync_loc) for a in view.attrs];
    if isinstance(tag, HostTag) {
        name_node = sync_loc(es.JsxIdentifier(name=tag.name), jac_node=tag.jac_node);
    } elif isinstance(tag, ComponentTag) {
        resolved = self._jsx_tag_name(tag.ref);
        assert resolved is not None , "ComponentTag.ref did not resolve to a JSX tag name (producer invariant broken)";
        name_node = sync_loc(resolved, jac_node=tag.jac_node);
    } else {
        return self._jsx_dynamic(
            tag.expr, attr_nodes, children_nodes, view.jac_node, sync_loc
        );
    }
    return self._jsx_element(
        name_node, attr_nodes, children_nodes, view.jac_node, sync_loc
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
        effect_body = e.body;
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
    import from jaclang.compiler.passes.ecmascript.view_ir {
        ViewElement,
        ComponentTag,
        FragmentTag,
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
        return self.lower_view(suspense_view, self._noloc);
    }
    if len(a.except_exprs) == 1 {
        except_fallback: es.Expression = a.except_exprs[0];
    } else {
        except_fragment = ViewElement(
            tag=FragmentTag(jac_node=jn),
            attrs=[],
            children=[DynamicChild(value=ex, jac_node=jn) for ex in a.except_exprs],
            jac_node=jn
        );
        except_fallback = self.lower_view(except_fragment, self._noloc);
    }
    error_view = ViewElement(
        tag=ComponentTag(ref=es.Identifier(name='ErrorBoundary'), jac_node=jn),
        attrs=[DynamicAttr(name='fallback', value=except_fallback, jac_node=jn)],
        children=[ElementChild(element=suspense_view, jac_node=jn)],
        jac_node=jn
    );
    return self.lower_view(error_view, self._noloc);
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
    return ["createEffect"];
}

impl SolidBackend.async_boundary_symbols(a: AsyncBoundary) -> list[str] {
    syms = ["Suspense"];
    if a.except_exprs {
        syms.append("ErrorBoundary");
    }
    return syms;
}
