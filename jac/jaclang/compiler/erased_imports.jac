import from jaclang.compiler.frontend.unitree {
    Ability,
    Expr,
    FuncCall,
    ImplDef,
    Import,
    Module,
    ModuleItem,
    Name,
    UniNode
}

def erased_import_binds(
    nd: UniNode, name: str, imported_name: str | None = None
) -> bool {
    import from jaclang.compiler.frontend.codeinfo { NATIVE_ERASED_IMPORTS }
    mod = nd.find_parent_of_type(Module);
    if mod is None {
        return False;
    }
    for imp in mod.get_all_sub_nodes(Import) {
        if imp.from_loc is None or imp.is_absorb {
            continue;
        }
        allowed = NATIVE_ERASED_IMPORTS.get(imp.from_loc.dot_path_str.lstrip('.'));
        if allowed is None {
            continue;
        }
        for item in imp.items {
            if not isinstance(item, ModuleItem) {
                continue;
            }
            bound = item.alias if item.alias is not None else item.name;
            if isinstance(bound, Name)
                and bound.value == name
                and item.name.value in allowed
                and (imported_name is None or item.name.value == imported_name) {
                return True;
            }
        }
    }
    return False;
}

def erased_identity_call_arg(nd: FuncCall) -> (Expr | None) {
    import from jaclang.compiler.frontend.codeinfo { NATIVE_ERASED_IDENTITY_CALLS }
    tgt = nd.target;
    if not isinstance(tgt, Name) or tgt.sym_name not in NATIVE_ERASED_IDENTITY_CALLS {
        return None;
    }
    params: Sequence[any] = nd.params or [];
    if len(params) != 2
        or not isinstance(params[0], Expr)
        or not isinstance(params[1], Expr) {
        return None;
    }
    if not erased_import_binds(nd, tgt.sym_name) {
        return None;
    }
    return params[1];
}

def is_contextmanager_decorator(
    expr: UniNode, anchor: (UniNode | None) = None
) -> bool {
    if not isinstance(expr, Name) {
        return False;
    }
    if erased_import_binds(expr, expr.value, "contextmanager") {
        return True;
    }
    return anchor is not None
        and erased_import_binds(anchor, expr.value, "contextmanager");
}

def contextmanager_ability(ab: (UniNode | None)) -> bool {
    if not isinstance(ab, Ability) {
        return False;
    }
    decorators: list[UniNode] = list(ab.decorators or []);
    if isinstance(ab.body, ImplDef) {
        decorators.extend(ab.body.decorators or []);
    }
    if not decorators {
        return False;
    }
    for dec in decorators {
        if not is_contextmanager_decorator(dec, ab) {
            return False;
        }
    }
    return True;
}
