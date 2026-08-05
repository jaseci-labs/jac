import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { CodeContext, Tokens as Tok }
import from jaclang.compiler.passes.ecmascript.intent.semantics {
    IntentLeaf,
    StateField,
    RefField,
    StateUpdate,
    Effect
}

impl ref_head_name(expr: (uni.UniNode | None)) -> (str | None) {
    cur = expr;
    while True {
        if isinstance(cur, uni.FuncCall) {
            cur = cur.target;
        } elif isinstance(cur, uni.AtomTrailer) {
            cur = cur.target;
        } else {
            break;
        }
    }
    return cur.value if isinstance(cur, uni.Name) else None;
}

impl arch_has_owner(nd: uni.ArchHas) -> (uni.UniNode | None) {
    owner: (uni.UniNode | None) = nd.parent;
    while owner is not None and not isinstance(owner, (uni.Ability, uni.Archetype)) {
        owner = owner.parent;
    }
    return owner;
}

impl arch_has_applicable(nd: uni.ArchHas, strict_client: bool = False) -> bool {
    owner = arch_has_owner(nd);
    if isinstance(owner, uni.Archetype) {
        return False;
    }
    if strict_client {
        if not nd.in_client_context() {
            return False;
        }
    } elif not nd.in_client_context() and owner is None {
        return False;
    }
    return True;
}

impl is_ref_field(has_var: uni.HasVar) -> tuple[bool, bool] {
    ref_ctor = (
        isinstance(has_var.value, uni.FuncCall)
        and ref_head_name(has_var.value.target) == 'Ref'
    );
    ref_typed = (
        has_var.type_tag is not None and ref_head_name(has_var.type_tag.tag) == 'Ref'
    );
    return (ref_ctor, ref_typed);
}

impl assignment_aug_op(nd: uni.Assignment) -> (str | None) {
    if nd.aug_op and nd.aug_op.name {
        return ASSIGNMENT_AUG_OPS.get(nd.aug_op.name);
    }
    return None;
}

impl assignment_kt_op(nd: uni.Assignment) -> str {
    if nd.aug_op and nd.aug_op.name {
        return ASSIGNMENT_KT_OPS.get(nd.aug_op.name, '=');
    }
    return '=';
}

impl return_type_includes(rt: uni.Expr, component_types: Sequence[str]) -> bool {
    if (
        isinstance(rt, uni.BinaryExpr)
        and isinstance(rt.op, uni.Token)
        and rt.op.name == Tok.BW_OR.name
    ) {
        return (
            return_type_includes(rt.left, component_types)
            or return_type_includes(rt.right, component_types)
        );
    }
    return isinstance(rt, uni.Name) and rt.value in component_types;
}

impl return_type_route_role(rt: uni.Expr) -> (str | None) {
    if (
        isinstance(rt, uni.BinaryExpr)
        and isinstance(rt.op, uni.Token)
        and rt.op.name == Tok.BW_OR.name
    ) {
        left_role = return_type_route_role(rt.left);
        return left_role or return_type_route_role(rt.right);
    }
    if isinstance(rt, uni.Name) {
        if rt.value == 'JsxPage' {
            return 'page';
        }
        if rt.value == 'JsxLayout' {
            return 'layout';
        }
    }
    return None;
}

impl screen_meta_for_component(
    name: str, return_type: (uni.Expr | None)
) -> tuple[bool, (str | None)] {
    if name in HOME_COMPONENT_NAMES {
        return (True, "/");
    }
    if return_type is not None and return_type_route_role(return_type) == "page" {
        return (True, None);
    }
    return (False, None);
}

impl component_name_from_ability(
    nd: uni.Ability, component_types: Sequence[str]
) -> (str | None) {
    if nd.code_context != CodeContext.CLIENT or nd.is_method {
        return None;
    }
    if not isinstance(nd.signature, uni.FuncSignature) {
        return None;
    }
    if nd.signature.return_type is None {
        return None;
    }
    if not return_type_includes(nd.signature.return_type, component_types) {
        return None;
    }
    if nd.name_ref is None {
        return None;
    }
    return nd.name_ref.sym_name;
}

impl unwrap_ability_body(nd: uni.Ability) -> (list[uni.UniNode] | None) {
    body = nd.body;
    if isinstance(body, uni.ImplDef) {
        return list(body.body) if body.body else [];
    }
    if isinstance(body, list) {
        return body;
    }
    return None;
}

impl scan_arch_has(
    nd: uni.ArchHas, skip_existing: set[str], conv: LeafConverter
) -> ArchHasScanResult {
    result = ArchHasScanResult();
    for has_var in nd.vars {
        var_name = has_var.name.sym_name;
        if var_name in skip_existing {
            continue;
        }
        (ref_ctor, ref_typed) = is_ref_field(has_var);
        if ref_ctor or ref_typed {
            if ref_typed and not ref_ctor {
                result.typed_ref_only.append(has_var);
            }
            init_expr: IntentLeaf = conv.null_expr;
            if isinstance(has_var.value, uni.FuncCall) and has_var.value.params {
                seed = has_var.value.params[0];
                seed_expr = seed.value if isinstance(seed, uni.KWPair) else seed;
                init_expr = conv.convert_ref_seed(seed_expr);
            }
            result.ref_fields.append(RefField(name=var_name, init_expr=init_expr));
            skip_existing.add(var_name);
            continue;
        }
        init_expr = conv.fallback_expr;
        if has_var.value {
            converted = conv.convert_expr(has_var.value);
            if converted is not None {
                init_expr = converted;
            }
        }
        result.state_fields.append(StateField(name=var_name, init_expr=init_expr));
        skip_existing.add(var_name);
    }
    return result;
}

impl scan_state_update(
    nd: uni.Assignment,
    conv: LeafConverter,
    convert_value:
        (Callable[[uni.Expr | uni.YieldExpr], (IntentLeaf | None)] | None) = None
) -> (StateUpdate | None) {
    if len(nd.target) != 1 or not isinstance(nd.target[0], uni.Name) {
        return None;
    }
    name = nd.target[0].sym_name;
    if name not in conv.reactive_vars {
        return None;
    }
    if convert_value is not None {
        if nd.value is None {
            return None;
        }
        value_expr = convert_value(nd.value);
    } elif nd.value is not None {
        value_expr = conv.convert_assignment_value(nd, nd.value);
    } else {
        return None;
    }
    if value_expr is None {
        return None;
    }
    return StateUpdate(name=name, value=value_expr, aug_op=assignment_aug_op(nd));
}

impl effect_from_ability(
    nd: uni.Ability, body: list[IntentLeaf], deps: list[IntentLeaf]
) -> Effect {
    is_entry = (
        isinstance(nd.signature, uni.EventSignature)
        and nd.signature.event.name == Tok.KW_ENTRY
    );
    is_async = nd.is_async;
    return Effect(body=body, deps=deps, is_entry=is_entry, is_async=is_async);
}
