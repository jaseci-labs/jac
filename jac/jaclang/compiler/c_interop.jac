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
