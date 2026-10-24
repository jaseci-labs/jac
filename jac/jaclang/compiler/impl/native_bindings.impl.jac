impl _param_names(decl: Ability) -> tuple[list[str], bool] {
    names: list[str] = [];
    variadic = False;
    sig = decl.signature;
    if not isinstance(sig, FuncSignature) {
        return (names, True);
    }
    for p in sig.get_parameters() {
        if p.unpack is not None {
            variadic = True;
            continue;
        }
        if p.name.value in ("self", "cls") {
            continue;
        }
        names.append(p.name.value);
    }
    return (names, variadic);
}

impl _constructor_params(arch: Archetype) -> tuple[list[str], bool] {
    fields: list[str] = [];
    for stmt in (ModuleFacts.unwrap_body(arch) or []) {
        if isinstance(stmt, Ability)
            and stmt.name_ref is not None
            and stmt.name_ref.sym_name in ("init", "__init__") {
            return _param_names(stmt);
        }
        for field in stmt.get_all_sub_nodes(HasVar) {
            if not field.defer {
                fields.append(field.name.value);
            }
        }
    }
    return (fields, bool(arch.base_classes));
}

impl _field_names(arch: Archetype) -> set[str] {
    out: set[str] = set();
    for stmt in (ModuleFacts.unwrap_body(arch) or []) {
        for field in stmt.get_all_sub_nodes(HasVar) {
            out.add(field.name.value);
        }
    }
    return out;
}

impl _member_names(arch: Archetype) -> set[str] {
    out: set[str] = set();
    body = ModuleFacts.unwrap_body(arch);
    if body is None {
        return out;
    }
    for stmt in body {
        if isinstance(stmt, Ability) and stmt.name_ref is not None {
            out.add(stmt.name_ref.sym_name);
        }
        for field in stmt.get_all_sub_nodes(HasVar) {
            out.add(field.name.value);
        }
    }
    return out;
}

impl is_owning_scope(scope: UniScopeNode) -> bool {
    return UniScopeNode.is_python_scoping(scope) or isinstance(scope, CatScope);
}

impl is_public_glob(stmt: GlobalVars) -> bool {
    access = stmt.access;
    return access is not None and access.tag.name == Tok.KW_PUB;
}
