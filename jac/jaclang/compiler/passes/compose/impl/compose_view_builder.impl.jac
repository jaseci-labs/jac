import jaclang.jac0core.unitree as uni;
import from jaclang.compiler.passes.compose { kotlin_ast as kt }
import from jaclang.compiler.type_system.compose_signatures {
    ComposeParamKind,
    widget_attr_param_kind
}
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
import from jaclang.compiler.passes.compose.jac_to_kotlin { JacToKotlin }
import from jaclang.compiler.passes.compose.compose_native_emit { ComposeNativeEmitter }

def _tag_name(nd: uni.JsxElement) -> (str | None) {
    if nd.dynamic_tag is not None {
        return None;
    }
    if nd.is_fragment or not nd.name {
        return "";
    }
    parts = nd.name.parts or [];
    if not parts or not isinstance(parts[0], uni.Name) {
        return None;
    }
    return parts[0].value;
}

def _jsx_attr_name(name_nd: any) -> str {
    if isinstance(name_nd, uni.Name) {
        return name_nd.sym_name;
    }
    if isinstance(name_nd, uni.Token) {
        return name_nd.value;
    }
    return str(name_nd);
}

def _kt_string_content(kt_node: kt.KtNode) -> (str | None) {
    if isinstance(kt_node, kt.KtLiteral) and isinstance(kt_node.value, str) {
        return kt_node.value;
    }
    if isinstance(kt_node, kt.KtStringTemplate) {
        parts: list[str] = [];
        for part in kt_node.parts {
            if isinstance(part, str) {
                parts.append(part);
            } else {
                return None;
            }
        }
        return ''.join(parts);
    }
    return None;
}

def _jsx_expr_to_kt(
    expr: (uni.UniNode | None), builder: ComposeViewBuilder
) -> (kt.KtNode | None) {
    if expr is None {
        return None;
    }
    if isinstance(expr, uni.JsxElement) {
        built = builder.build_element(expr);
        if built is None {
            return None;
        }
        return ComposeNativeEmitter()._emit_element(built);
    }
    return builder.lowerer.convert_expr(expr);
}

def _raw_kotlin_from_children(
    children:
        list[
            ComposeTextChild
                | ComposeDynamicChild
                | ComposeRawChild
                | ComposeElementChild
                | ComposeIfChild
                | ComposeEachChild
        ]
) -> (str | None) {
    parts: list[str] = [];
    for child in children {
        if isinstance(child, ComposeTextChild) {
            if isinstance(child.value, kt.KtLiteral)
                and isinstance(child.value.value, str) {
                parts.append(child.value.value);
            }
        }
    }
    if not parts {
        return None;
    }
    return "\n".join(parts);
}

impl ComposeViewBuilder.build_element(nd: uni.JsxElement) -> (ComposeElement | None) {
    cached = self._view_by_node.get(id(nd));
    if cached is not None {
        return cached;
    }
    tag = _tag_name(nd);
    if tag is None {
        self.diagnostics.append(
            "dynamic JSX tags are unsupported in Compose surface v1"
        );
        return None;
    }
    if tag == "" {
        children = self.build_children(list(nd.children or []));
        if len(children) == 1 and isinstance(children[0], ComposeElementChild) {
            return children[0].element;
        }
        elem = ComposeElement(name="Column", attrs=[], children=children, jac_node=nd);
        self._view_by_node[id(nd)] = elem;
        return elem;
    }
    if not tag[0].isupper() {
        self.diagnostics.append(
            f"lowercase host tag <{tag}> is not supported — use Compose primitives (Column, Text, …)"
        );
        return None;
    }
    attrs: list[ComposeAttr] = [];
    for attr in (nd.attributes or []) {
        if isinstance(attr, uni.JsxNormalAttribute) {
            aname = _jsx_attr_name(attr.name);
            if attr.value is None {
                continue;
            }
            kt_val = _jsx_expr_to_kt(attr.value, self);
            if kt_val is None {
                continue;
            }
            param_kind = widget_attr_param_kind(tag, aname);
            attrs.append(
                ComposeAttr(
                    name=aname,
                    value=kt_val,
                    param_kind=param_kind,
                    is_event=param_kind == ComposeParamKind.EVENT,
                    jac_node=attr
                )
            );
        } elif isinstance(attr, uni.JsxSpreadAttribute) {
            self.diagnostics.append(
                "spread attributes are unsupported in Compose surface v1"
            );
        }
    }
    children = self.build_children(list(nd.children or []));
    if tag == "Raw" {
        raw_code: (str | None) = None;
        for attr in attrs {
            if attr.name == "kotlin" {
                raw_code = _kt_string_content(attr.value);
                if raw_code is None and isinstance(attr.value, kt.KtRaw) {
                    raw_code = attr.value.code;
                }
                if raw_code is not None {
                    break;
                }
            }
        }
        if raw_code is None {
            raw_code = _raw_kotlin_from_children(children);
        }
        if raw_code is None {
            self.diagnostics.append(
                "<Raw> requires a kotlin= attribute or raw Kotlin text children"
            );
            return None;
        }
        elem = ComposeElement(
            name="Raw",
            attrs=[
                ComposeAttr(
                    name="kotlin",
                    value=kt.KtRaw(code=raw_code),
                    is_event=False,
                    jac_node=nd
                )
            ],
            children=[ComposeRawChild(code=raw_code, jac_node=nd)],
            jac_node=nd
        );
        self._view_by_node[id(nd)] = elem;
        return elem;
    }
    elem = ComposeElement(name=tag, attrs=attrs, children=children, jac_node=nd);
    self._view_by_node[id(nd)] = elem;
    return elem;
}

impl ComposeViewBuilder.build_children(
    children: list[uni.UniNode]
) -> list[
    ComposeTextChild
        | ComposeDynamicChild
        | ComposeRawChild
        | ComposeElementChild
        | ComposeIfChild
        | ComposeEachChild
] {
    result:
        list[
            ComposeTextChild
                | ComposeDynamicChild
                | ComposeElementChild
                | ComposeIfChild
                | ComposeEachChild
        ] = [];
    for child in children {
        if isinstance(child, uni.JsxText) {
            text = child.get_normalized_text();
            if not text {
                continue;
            }
            if text.startswith('"') and text.endswith('"') and len(text) >= 2 {
                text = text[1:-1];
            } elif text.startswith("'") and text.endswith("'") and len(text) >= 2 {
                text = text[1:-1];
            }
            result.append(
                ComposeTextChild(value=kt.KtLiteral(value=text), jac_node=child)
            );
        } elif isinstance(child, uni.JsxComment) {
            continue;
        } elif isinstance(child, uni.JsxExpression) {
            lifted = self._lift_control_flow(child);
            if lifted is not None {
                result.append(lifted);
            } else {
                kt_val = self.lowerer.convert_expr(child.expr);
                if kt_val is None {
                    continue;
                }
                if isinstance(kt_val, kt.KtLiteral) and isinstance(kt_val.value, str) {
                    result.append(ComposeTextChild(value=kt_val, jac_node=child));
                } else {
                    result.append(ComposeDynamicChild(value=kt_val, jac_node=child));
                }
            }
        } elif isinstance(child, uni.JsxElement) {
            built = self.build_element(child);
            if built is not None {
                result.append(ComposeElementChild(element=built, jac_node=child));
            }
        }
    }
    return result;
}

impl ComposeViewBuilder._lift_control_flow(
    child: uni.JsxExpression
) -> (ComposeIfChild | ComposeEachChild | None) {
    expr = child.expr;
    if isinstance(expr, uni.ListCompr) {
        return self._lift_each(child, expr);
    }
    if isinstance(expr, uni.IfElseExpr) {
        return self._lift_if(child, expr);
    }
    return None;
}

impl ComposeViewBuilder._lift_each(
    child: uni.JsxExpression, compr: uni.ListCompr
) -> (ComposeEachChild | None) {
    if len(compr.compr) != 1 {
        return None;
    }
    inner = compr.compr[0];
    out_expr = compr.out_expr;
    if not isinstance(out_expr, uni.JsxElement) {
        return None;
    }
    item_name = 'item';
    if isinstance(inner.target, uni.Name) {
        item_name = inner.target.sym_name;
    }
    items = self.lowerer.convert_expr(inner.collection);
    body_elem = self.build_element(out_expr);
    if items is None or body_elem is None {
        return None;
    }
    return ComposeEachChild(
        items=items,
        item_name=item_name,
        body=[ComposeElementChild(element=body_elem, jac_node=out_expr)],
        jac_node=child
    );
}

impl ComposeViewBuilder._lift_if(
    child: uni.JsxExpression, ternary: uni.IfElseExpr
) -> (ComposeIfChild | None) {
    cons_inner = ternary.value;
    alt_inner = ternary.else_value;
    if not isinstance(cons_inner, uni.JsxElement) {
        return None;
    }
    cons = self.build_element(cons_inner);
    if cons is None {
        return None;
    }
    alt_children: list = [];
    if isinstance(alt_inner, uni.JsxElement) {
        alt_elem = self.build_element(alt_inner);
        if alt_elem is not None {
            alt_children = [ComposeElementChild(element=alt_elem, jac_node=alt_inner)];
        }
    }
    test = self.lowerer.convert_expr(ternary.condition);
    if test is None {
        return None;
    }
    return ComposeIfChild(
        `test=test,
        consequent=[ComposeElementChild(element=cons, jac_node=cons_inner)],
        alternate=alt_children,
        jac_node=child
    );
}

def _is_real_jsx(nd: uni.JsxElement) -> bool {
    parent = nd.parent;
    if isinstance(parent, uni.JsxElement) {
        siblings = parent.children or [];
        if not any([sib is nd for sib in siblings]) {
            return False;
        }
    }
    return True;
}

def _collect_real_jsx(nd: uni.UniNode, out: list) {
    if isinstance(nd, uni.JsxElement) and _is_real_jsx(nd) {
        out.append(nd);
    }
    for child in (nd.kid or []) {
        if isinstance(child, uni.LambdaExpr) {
            continue;
        }
        _collect_real_jsx(child, out);
    }
}

def _contains_real_jsx(nd: uni.UniNode) -> bool {
    found: list = [];
    _collect_real_jsx(nd, found);
    return len(found) > 0;
}

def _ends_in_return(stmts: list) -> bool {
    if not stmts {
        return False;
    }
    last = stmts[-1];
    if isinstance(last, uni.ReturnStmt) {
        return True;
    }
    if isinstance(last, uni.IfStmt) {
        alt = last.else_body;
        return _ends_in_return(list(last.body or []))
            and isinstance(alt, uni.ElseStmt)
            and _ends_in_return(list(alt.body or []));
    }
    return False;
}

def _if_returns_on_all_paths(stmt: uni.IfStmt) -> bool {
    alt = stmt.else_body;
    return _ends_in_return(list(stmt.body or []))
        and isinstance(alt, uni.ElseStmt)
        and _ends_in_return(list(alt.body or []));
}

impl ComposeViewBuilder.lower_component_view(
    stmts: list[uni.UniNode]
) -> (ComposeElement | None) {
    before = set(self._view_by_node.keys());
    items = self._lower_stmts(stmts);
    self._guard_coverage(stmts, before, items);
    if items is None or len(items) == 0 {
        return None;
    }

    first = items[0];
    if len(items) == 1 and isinstance(first, ComposeElementChild) {
        return first.element;
    }
    return ComposeElement(name="", attrs=[], children=items, jac_node=None);
}

impl ComposeViewBuilder._lower_stmts(stmts: list[uni.UniNode]) -> (list | None) {
    items: list = [];
    for stmt in stmts {
        if isinstance(stmt, uni.ReturnStmt) {
            if stmt.expr is None {
                break;
            }
            child = self._lower_jsx_value(stmt.expr);
            if child is None {
                return None;
            }
            items.append(child);
            break;
        }
        if isinstance(stmt, uni.IfStmt) {
            if not _contains_real_jsx(stmt) {
                continue;
            }
            ifchild = self._lower_if_stmt(stmt);
            if ifchild is None {
                return None;
            }
            items.append(ifchild);
            if _if_returns_on_all_paths(stmt) {
                break;
            }
            continue;
        }
    }
    return items;
}

impl ComposeViewBuilder._lower_jsx_value(
    expr: uni.UniNode
) -> (ComposeElementChild | None) {
    if not isinstance(expr, uni.JsxElement) {
        return None;
    }
    built = self.build_element(expr);
    if built is None {
        return None;
    }
    return ComposeElementChild(element=built, jac_node=expr);
}

impl ComposeViewBuilder._lower_if_stmt(stmt: uni.IfStmt) -> (ComposeIfChild | None) {
    test = self.lowerer.convert_expr(stmt.condition);
    if test is None {
        return None;
    }
    cons = self._lower_stmts(list(stmt.body or []));
    if cons is None {
        return None;
    }
    alternate: (list | None) = None;
    alt = stmt.else_body;
    if isinstance(alt, uni.ElseStmt) {
        alt_items = self._lower_stmts(list(alt.body or []));
        if alt_items is None {
            return None;
        }
        alternate = alt_items;
    }
    return ComposeIfChild(
        `test=test, consequent=cons, alternate=alternate, jac_node=stmt
    );
}

impl ComposeViewBuilder._guard_coverage(
    stmts: list[uni.UniNode], before: set[int], lowered: (list | None)
) -> None {
    all_jsx: list = [];
    for stmt in stmts {
        _collect_real_jsx(stmt, all_jsx);
    }
    if len(all_jsx) == 0 {
        return;
    }
    if lowered is None {
        self.diagnostics.append(
            "Compose view: the component body contains JSX but it could not be "
            "lowered into the screen (e.g. a non-JSX return, or JSX inside a "
            "loop/match). Restructure to a direct or if/else JSX return, or use "
            "<Raw kotlin=\"...\"> for verbatim Kotlin."
        );
        return;
    }
    built = set(self._view_by_node.keys()) - before;
    uncovered = [
        j
        for j in all_jsx
        if id(j) not in built
    ];
    if len(uncovered) > 0 {
        self.diagnostics.append(
            "Compose view: some JSX was not lowered (found JSX in a branch not "
            "all paths return, after an early return, or in a loop/match). "
            "Restructure so all JSX is reachable from a single return path."
        );
    }
}
