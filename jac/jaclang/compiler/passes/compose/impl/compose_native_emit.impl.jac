import from jaclang.compiler.passes.compose { kotlin_ast as kt }
import from jaclang.compiler.passes.compose.kotlin_unparse { kt_to_source }
import from jaclang.compiler.passes.compose.view_ir {
    ComposeElement,
    ComposeAttr,
    ComposeTextChild,
    ComposeDynamicChild,
    ComposeRawChild,
    ComposeElementChild,
    ComposeIfChild,
    ComposeEachChild
}
import from jaclang.compiler.passes.ecmascript.intent.model { IntentComponent }
import from jaclang.compiler.type_system.compose_signatures {
    ComposeParamKind,
    widget_param_kind_table
}

def _widget_param_kinds -> dict[str, dict[str, ComposeParamKind]] {
    return widget_param_kind_table();
}

def _is_slot_param(widget_name: str, attr_name: str) -> bool {
    kinds = _widget_param_kinds().get(widget_name);
    if kinds is None {
        return False;
    }
    return kinds.get(attr_name) == ComposeParamKind.SLOT;
}

def _is_known_nonslot_param(widget_name: str, attr_name: str) -> bool {
    kinds = _widget_param_kinds().get(widget_name);
    if kinds is None {
        return False;
    }
    kind = kinds.get(attr_name);
    return kind is not None and kind != ComposeParamKind.SLOT;
}

def _named(name: str, value: kt.KtNode) -> kt.KtNamedArg {
    return kt.KtNamedArg(name=name, value=value);
}

def _kt_needs_coroutine(kt_node: any, depth: int = 0) -> bool {
    if kt_node is None or depth > 40 {
        return False;
    }
    if isinstance(kt_node, kt.KtCall) {
        callee = kt_node.callee;
        if isinstance(callee, kt.KtMemberAccess) {
            if (
                isinstance(callee.object, kt.KtIdentifier)
                and callee.object.name == "JacClient"
            ) {
                return True;
            }
        }
    }
    if isinstance(kt_node, kt.KtExprStmt) {
        return _kt_needs_coroutine(kt_node.expression, depth + 1);
    }
    if isinstance(kt_node, kt.KtAssignment) {
        return _kt_needs_coroutine(kt_node.right, depth + 1);
    }
    if isinstance(kt_node, kt.KtLambda) {
        if kt_node.expression_body is not None {
            return _kt_needs_coroutine(kt_node.expression_body, depth + 1);
        }
        for stmt in kt_node.body {
            if _kt_needs_coroutine(stmt, depth + 1) {
                return True;
            }
        }
        return False;
    }
    if isinstance(kt_node, list) or isinstance(kt_node, tuple) {
        for item in kt_node {
            if _kt_needs_coroutine(item, depth + 1) {
                return True;
            }
        }
        return False;
    }
    for attr in (
        "body",
        "expression",
        "argument",
        "arguments",
        "left",
        "right",
        "consequent",
        "alternate",
        "test",
        "try_body",
        "catch_body",
        "elements",
        "entries",
        "named_args",
        "args",
        "content",
        "callee",
        "object",
        "property",
        "expression_body",
        "parts"
    ) {
        child = getattr(kt_node, attr, None);
        if child is not None and _kt_needs_coroutine(child, depth + 1) {
            return True;
        }
    }
    return False;
}

def _as_click_lambda(handler: kt.KtNode, needs_coro: bool = False) -> kt.KtNode {
    lam: kt.KtLambda;
    if isinstance(handler, kt.KtLambda) {
        lam = handler;
    } else {
        lam = kt.KtLambda(params=[], body=[kt.KtExprStmt(expression=handler)]);
    }
    if not needs_coro {
        return lam;
    }
    inner = kt.KtLambda(
        params=list(lam.params),
        body=list(lam.body),
        expression_body=lam.expression_body
    );
    launch = kt.KtCall(
        callee=kt.KtMemberAccess(
            object=kt.KtIdentifier(name="scope"),
            property=kt.KtIdentifier(name="launch")
        ),
        args=[],
        trailing_lambda=inner
    );
    return kt.KtLambda(params=[], body=[kt.KtExprStmt(expression=launch)]);
}

def _normalize_click_handler(handler: kt.KtNode) -> kt.KtLambda {
    if isinstance(handler, kt.KtLambda) {
        return handler;
    }
    return kt.KtLambda(params=[], body=[kt.KtExprStmt(expression=handler)]);
}

impl ComposeNativeEmitter._event_needs_coroutine(attr: ComposeAttr) -> bool {
    handler = _normalize_click_handler(attr.value);
    if _kt_needs_coroutine(handler) {
        return True;
    }
    return "JacClient" in kt_to_source(handler);
}

impl ComposeNativeEmitter._scan_coroutine_need(elem: ComposeElement) -> None {
    for attr in elem.attrs {
        if attr.is_event and self._event_needs_coroutine(attr) {
            self.needs_coroutine_scope = True;
        }
    }
    for child in (elem.children or []) {
        if isinstance(child, ComposeElementChild) {
            self._scan_coroutine_need(child.element);
        } elif isinstance(child, ComposeIfChild) {
            for sub in (child.consequent or []) {
                if isinstance(sub, ComposeElementChild) {
                    self._scan_coroutine_need(sub.element);
                }
            }
            for sub in (child.alternate or []) {
                if isinstance(sub, ComposeElementChild) {
                    self._scan_coroutine_need(sub.element);
                }
            }
        } elif isinstance(child, ComposeEachChild) {
            for sub in (child.body or []) {
                if isinstance(sub, ComposeElementChild) {
                    self._scan_coroutine_need(sub.element);
                }
            }
        }
    }
}

def _text_call(expr: kt.KtNode) -> kt.KtComposableCall {
    if isinstance(expr, kt.KtLiteral) and isinstance(expr.value, str) {
        return kt.KtComposableCall(
            name="Text", args=[_named("text", kt.KtLiteral(value=expr.value))]
        );
    }
    text_expr = expr;
    if not (isinstance(expr, kt.KtLiteral) and isinstance(expr.value, str)) {
        text_expr = kt.KtRaw(code=f"({kt_to_source(expr)}).toString()");
    }
    return kt.KtComposableCall(name="Text", args=[_named("text", text_expr)]);
}

impl ComposeNativeEmitter._emit_children(children: list) -> list[kt.KtNode] {
    nodes: list[kt.KtNode] = [];
    for child in children {
        if isinstance(child, ComposeTextChild) {
            nodes.append(_text_call(child.value));
        } elif isinstance(child, ComposeDynamicChild) {
            nodes.append(_text_call(child.value));
        } elif isinstance(child, ComposeRawChild) {
            nodes.append(kt.KtRaw(code=child.code));
        } elif isinstance(child, ComposeElementChild) {
            nodes.append(self._emit_element(child.element));
        } elif isinstance(child, ComposeIfChild) {
            cons = self._emit_child_list(child.consequent);
            alt = self._emit_child_list(child.alternate or []);
            nodes.append(kt.KtIf(`test=child.test, consequent=cons, alternate=alt));
        } elif isinstance(child, ComposeEachChild) {
            body_nodes = self._emit_child_list(child.body);
            nodes.append(
                kt.KtRaw(
                    code=(
                        f"{kt_to_source(child.items)}.forEach {{ {child.item_name} ->\n"
                        + "\n".join([f"    {kt_to_source(n)}" for n in body_nodes])
                        + "\n}"
                    )
                )
            );
        }
    }
    return nodes;
}

impl ComposeNativeEmitter._emit_child_list(children: list) -> list[kt.KtNode] {
    return self._emit_children(children);
}

def _placeholder_lambda(expr: kt.KtNode) -> kt.KtNode {
    text_arg: kt.KtNode = expr;
    if isinstance(expr, kt.KtLiteral) and isinstance(expr.value, str) {
        text_arg = kt.KtLiteral(value=expr.value);
    }
    return kt.KtLambda(
        params=[],
        body=[kt.KtComposableCall(name="Text", args=[_named("text", text_arg)])]
    );
}

def _wrap_text_field_args(name: str, args: list[kt.KtNamedArg]) -> list[kt.KtNamedArg] {
    if name not in ("OutlinedTextField", "TextField") {
        return args;
    }
    out: list[kt.KtNamedArg] = [];
    for a in args {
        if a.name == "placeholder"
            and a.value is not None
            and not isinstance(a.value, kt.KtLambda) {
            out.append(_named("placeholder", _placeholder_lambda(a.value)));
        } else {
            out.append(a);
        }
    }
    return out;
}

def _slot_wrap(value: kt.KtNode, widget_name: str, attr_name: str) -> kt.KtNode {
    if not isinstance(value, kt.KtComposableCall) {
        return value;
    }
    if _is_known_nonslot_param(widget_name, attr_name) {
        return value;
    }
    return kt.KtLambda(params=[], body=[value]);
}

impl ComposeNativeEmitter._emit_element(elem: ComposeElement) -> kt.KtNode {
    if elem.name == "Raw" {
        for attr in elem.attrs {
            if attr.name == "kotlin" {
                return kt.KtRaw(
                    code=kt_to_source(attr.value)
                        if not isinstance(attr.value, kt.KtRaw)
                        else attr.value.code
                );
            }
        }
        if elem.children {
            for child in elem.children {
                if isinstance(child, ComposeRawChild) {
                    return kt.KtRaw(code=child.code);
                }
            }
        }
        return kt.KtRaw(code="/* empty Raw */");
    }
    args: list[kt.KtNamedArg] = [];
    content: list[kt.KtNode] = [];
    for attr in elem.attrs {
        if attr.is_event {
            needs_coro = self._event_needs_coroutine(attr);
            if needs_coro {
                self.needs_coroutine_scope = True;
            }
            handler = _normalize_click_handler(attr.value);
            args.append(_named(attr.name, _as_click_lambda(handler, needs_coro)));
        } else {
            args.append(
                _named(attr.name, _slot_wrap(attr.value, elem.name, attr.name))
            );
        }
    }
    if elem.children {
        content = self._emit_children(elem.children);
    }
    if elem.name == "Text" {
        text_expr: (kt.KtNode | None) = None;
        for child in (elem.children or []) {
            if isinstance(child, ComposeTextChild) {
                text_expr = child.value;
                break;
            }
            if isinstance(child, ComposeDynamicChild) {
                text_expr = child.value;
                break;
            }
        }
        text_args: list[kt.KtNamedArg] = [];
        for a in args {
            if a.name != "text" {
                text_args.append(a);
            }
        }
        if text_expr is None {
            text_args.insert(0, _named("text", kt.KtLiteral(value="")));
        } else {
            if isinstance(text_expr, kt.KtLiteral)
                and isinstance(text_expr.value, str) {
                text_args.insert(0, _named("text", text_expr));
            } else {
                text_args.insert(
                    0,
                    _named(
                        "text", kt.KtRaw(code=f"({kt_to_source(text_expr)}).toString()")
                    )
                );
            }
        }
        return kt.KtComposableCall(name="Text", args=text_args, content=[]);
    }
    args = _wrap_text_field_args(elem.name, args);
    return kt.KtComposableCall(name=elem.name, args=args, content=content);
}

impl ComposeNativeEmitter.emit_view(view: (ComposeElement | None)) -> str {
    if view is None {
        return f"{self.indent}Column(modifier = Modifier.fillMaxSize()) {{\n{self.indent}}}";
    }

    if view.name == "" {
        nodes = self._emit_children(view.children or []);
    } else {
        nodes = [self._emit_element(view)];
    }
    indented: list[str] = [];
    for node in nodes {
        for line in kt_to_source(node).split("\n") {
            if line.strip() {
                indented.append(f"{self.indent}{line}");
            } else {
                indented.append("");
            }
        }
    }
    return "\n".join(indented);
}

impl ComposeNativeEmitter.emit_component_view(
    model: ComposeModule, comp: IntentComponent
) -> str {
    view = model.compose_view_for(comp.name);
    if view is not None {
        self._scan_coroutine_need(view);
        return self.emit_view(view);
    }
    return self.emit_view(None);
}
