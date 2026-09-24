import from jaclang.compiler.frontend.unitree {
    Archetype,
    Assignment,
    AtomTrailer,
    AtomUnit,
    Expr,
    Import,
    UnaryExpr,
    UniNode
}

glob C_BUILTIN_GENERICS: tuple[str, ...] = ("ptr", "PtrView", "Pinned");

def clib_import_of(nd: (UniNode | None)) -> (Import | None) {
    if nd is None {
        return None;
    }
    imp = nd if isinstance(nd, Import) else nd.find_parent_of_type(Import);
    if imp is not None and imp.clib_decls {
        return imp;
    }
    return None;
}

def is_clib_archetype(arch: (UniNode | None)) -> bool {
    return isinstance(arch, Archetype) and clib_import_of(arch) is not None;
}

def is_opaque_c_archetype(arch: (UniNode | None)) -> bool {
    return isinstance(arch, Archetype)
        and is_clib_archetype(arch)
        and arch.body is None;
}

def is_foreign_struct_archetype(arch: (UniNode | None)) -> bool {
    return isinstance(arch, Archetype)
        and is_clib_archetype(arch)
        and arch.body is not None;
}

def _class_shared(t: object) -> any {
    return t?._shared;
}

def clib_archetype_of_type(t: object) -> (Archetype | None) {
    shared = _class_shared(t);
    if shared is None {
        return None;
    }
    arch = shared?.symbol_table;
    if is_clib_archetype(arch) {
        return arch;
    }
    return None;
}

def foreign_struct_of_type(t: object) -> (Archetype | None) {
    arch = clib_archetype_of_type(t);
    return arch if is_foreign_struct_archetype(arch) else None;
}

def opaque_c_of_type(t: object) -> (Archetype | None) {
    arch = clib_archetype_of_type(t);
    return arch if is_opaque_c_archetype(arch) else None;
}

def c_builtin_kind(t: any) -> str {
    shared = _class_shared(t);
    if shared is None or getattr(shared, "class_name", "") not in C_BUILTIN_GENERICS {
        return "";
    }
    if t.is_builtin(list(C_BUILTIN_GENERICS)) {
        return shared.class_name;
    }
    return "";
}

def is_ptr_type(t: object) -> bool {
    return c_builtin_kind(t) == "ptr";
}

def is_ptr_view_type(t: object) -> bool {
    return c_builtin_kind(t) == "PtrView";
}

def is_pinned_type(t: object) -> bool {
    return c_builtin_kind(t) == "Pinned";
}

def c_type_arg(t: object) -> (object | None) {
    if not c_builtin_kind(t) {
        return None;
    }
    import from jaclang.compiler.types.types { ClassType }
    assert isinstance(t, ClassType);
    args = t.private.type_args if t.private else None;
    if not args {
        return None;
    }
    import from jaclang.compiler.types.types { AnyType, UnknownType }
    arg = args[0];
    if isinstance(arg, (AnyType, UnknownType)) {
        return None;
    }
    if isinstance(arg, ClassType) and arg.is_builtin(["object", "Any"]) {
        return None;
    }
    return arg;
}

def reads_foreign_storage(nd: (UniNode | None)) -> bool {
    if not isinstance(nd, AtomTrailer) {
        return False;
    }
    if foreign_struct_of_type(nd?.type) is None {
        return False;
    }
    base_type = nd.target?.type;
    if nd.is_attr {
        return foreign_struct_of_type(base_type) is not None;
    }
    return is_ptr_view_type(base_type);
}

def foreign_read_is_place(nd: UniNode) -> bool {
    cur = nd;
    parent = cur.parent;
    while isinstance(parent, AtomUnit) and parent.value is cur {
        cur = parent;
        parent = cur.parent;
    }
    if isinstance(parent, AtomTrailer) and parent.target is cur {
        return True;
    }
    if isinstance(parent, UnaryExpr) and parent.operand is cur {
        import from jaclang.compiler.frontend.constant { is_borrow_kind }
        return is_borrow_kind(parent.ownership);
    }
    if isinstance(parent, Assignment) {
        for tgt in parent.target {
            if tgt is cur {
                return True;
            }
        }
    }
    return False;
}

def foreign_read_copies(nd: (UniNode | None)) -> bool {
    return nd is not None
        and reads_foreign_storage(nd)
        and not foreign_read_is_place(nd);
}

def is_builtin_pin_call(call: (UniNode | None)) -> bool {
    import from jaclang.compiler.frontend.unitree { FuncCall, Name }
    if not isinstance(call, FuncCall) or not isinstance(call.target, Name) {
        return False;
    }
    tgt = call.target;
    if tgt.value != "pin" {
        return False;
    }
    import from jaclang.compiler.types.types { FunctionType }
    decl = tgt.sym.decl if tgt.sym is not None else None;
    if decl is not None and decl.loc is not None {
        if str(decl.loc.mod_path).endswith(".jac") {
            return False;
        }
    }
    fn_type = tgt.type;
    return isinstance(fn_type, FunctionType) and is_pinned_type(fn_type.return_type);
}

def is_c_value_type(t: object) -> bool {
    return c_builtin_kind(t) in ("ptr", "PtrView");
}

def c_call_borrows_args(call: (UniNode | None)) -> bool {
    import from jaclang.compiler.frontend.unitree { FuncCall }
    if not isinstance(call, FuncCall) {
        return False;
    }
    if call.call_kind == "clib" or is_builtin_pin_call(call) {
        return True;
    }
    target_type = call.target?.type;
    return is_ptr_type(target_type);
}

glob _SPEC_SCALAR_ALIASES: dict[str, str] = {"int": "i64", "float": "f64"};

def c_type_spec(t: object, annotation: (UniNode | None) = None) -> list[any] {
    import from jaclang.compiler.types.types { ClassType, FunctionType, UnionType }
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if isinstance(t, UnionType) {
        members = [
            m
            for m in (t.types or [])
            if not (
                isinstance(m, ClassType) and m.shared.class_name in ("NoneType", "None")
            )
        ];
        if len(members) == 1 {
            inner = c_type_spec(members[0], None);
            return ["opt", inner] if len(members) < len(t.types or []) else inner;
        }
        return ["any"];
    }
    if isinstance(t, FunctionType) {
        return [
            "fn",
            [c_type_spec(p.param_type, None) for p in (t.parameters or [])],
            c_type_spec(t.return_type, None)
        ];
    }
    if isinstance(t, ClassType) and t._shared is not None {
        kind = c_builtin_kind(t);
        if kind == "ptr" {
            arg = c_type_arg(t);
            return ["ptr", None if arg is None else c_type_spec(arg, None)];
        }
        if kind == "Pinned" {
            return ["pinned", c_type_spec(c_type_arg(t), None)];
        }
        name = t.shared.class_name;
        if name in ("NoneType", "None") {
            return ["void"];
        }
        arch = clib_archetype_of_type(t);
        if arch is not None {
            return [
                "opaque" if is_opaque_c_archetype(arch) else "struct",
                arch.name.value
            ];
        }
        if t.is_builtin() {
            return _spec_for_name(name) or ["any"];
        }
        return ["any"];
    }
    written = _annotation_name(annotation);
    if written is not None {
        return _spec_for_name(written) or ["any"];
    }
    return ["any"];
}

def _spec_for_name(name: str) -> (list[any] | None) {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if name == "str" {
        return ["str"];
    }
    if name in ("bytes", "bytearray") {
        return ["bytes"];
    }
    if name == "None" {
        return ["void"];
    }
    if JAC_TYPE_REGISTRY.is_numeric(name) {
        return ["s", _SPEC_SCALAR_ALIASES.get(name, name)];
    }
    return None;
}

def _annotation_name(annotation: (UniNode | None)) -> (str | None) {
    import from jaclang.compiler.frontend.unitree { Name, Null }
    if isinstance(annotation, Null) {
        return "None";
    }
    if isinstance(annotation, Name) {
        return annotation.value;
    }
    return None;
}
