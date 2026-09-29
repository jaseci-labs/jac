import from jaclang.compiler.frontend.unitree {
    Archetype,
    Assignment,
    AtomTrailer,
    AtomUnit,
    Expr,
    GlobalVars,
    Import,
    Name,
    ParamVar,
    Symbol,
    UnaryExpr,
    resolved_decl_of,
    UniNode
}

import type from jaclang.compiler.types.types { ClassType, TypeBase }

glob C_BUILTIN_TYPES: tuple[str, ...] = ("ptr", "PtrView", "Pinned", "VaList");

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

def _class_of(t: (TypeBase | None)) -> (ClassType | None) {
    return t.as_class() if t is not None else None;
}

def clib_archetype_of_type(t: (TypeBase | None)) -> (Archetype | None) {
    cls = _class_of(t);
    if cls is None {
        return None;
    }
    arch = cls.shared.symbol_table;
    if isinstance(arch, Archetype) and is_clib_archetype(arch) {
        return arch;
    }
    return None;
}

def foreign_struct_of_type(t: (TypeBase | None)) -> (Archetype | None) {
    arch = clib_archetype_of_type(t);
    return arch if is_foreign_struct_archetype(arch) else None;
}

def opaque_c_of_type(t: (TypeBase | None)) -> (Archetype | None) {
    arch = clib_archetype_of_type(t);
    return arch if is_opaque_c_archetype(arch) else None;
}

def c_builtin_kind(t: (TypeBase | None)) -> str {
    cls = _class_of(t);
    if cls is None or cls.shared.class_name not in C_BUILTIN_TYPES {
        return "";
    }
    if cls.is_builtin(list(C_BUILTIN_TYPES)) {
        return cls.shared.class_name;
    }
    return "";
}

def is_ptr_type(t: (TypeBase | None)) -> bool {
    return c_builtin_kind(t) == "ptr";
}

def is_ptr_view_type(t: (TypeBase | None)) -> bool {
    return c_builtin_kind(t) == "PtrView";
}

def is_pinned_type(t: (TypeBase | None)) -> bool {
    return c_builtin_kind(t) == "Pinned";
}

def is_va_list_type(t: (TypeBase | None)) -> bool {
    return c_builtin_kind(t) == "VaList";
}

def c_variadic_param(sig: (UniNode | None)) -> (ParamVar | None) {
    import from jaclang.compiler.frontend.unitree { FuncSignature }
    if not isinstance(sig, FuncSignature) or sig.varargs is None {
        return None;
    }
    tag = sig.varargs.type_tag.tag if sig.varargs.type_tag else None;
    tag_type = tag.type if tag is not None else None;
    return sig.varargs if is_va_list_type(tag_type) else None;
}

def c_type_arg(t: (TypeBase | None)) -> (TypeBase | None) {
    cls = _class_of(t);
    if cls is None or not c_builtin_kind(cls) {
        return None;
    }
    args = cls.private.type_args if cls.private else None;
    if not args {
        return None;
    }
    import from jaclang.compiler.types.types { AnyType, ClassType, UnknownType }
    arg = args[0];
    if isinstance(arg, AnyType) or isinstance(arg, UnknownType) {
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
    if foreign_struct_of_type(nd.type) is None {
        return False;
    }
    base_type = nd.target.type;
    if nd.is_attr {
        return foreign_struct_of_type(base_type) is not None;
    }
    return is_ptr_view_type(base_type);
}

"""The foreign struct and field index an attribute read names
(`rec.view(1)[0].destructor`), or None."""
def foreign_field_of(nd: (UniNode | None)) -> (tuple[Archetype, int] | None) {
    while isinstance(nd, AtomUnit) and isinstance(nd.value, Expr) {
        nd = nd.value;
    }
    if not isinstance(nd, AtomTrailer) or not nd.is_attr {
        return None;
    }
    arch = foreign_struct_of_type(nd.target.type);
    name = nd.right.sym_name if isinstance(nd.right, Name) else None;
    if arch is None or name is None {
        return None;
    }
    for (index, field) in enumerate(arch.get_has_vars()) {
        if field.name.sym_name == name {
            return (arch, index);
        }
    }
    return None;
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

def _ambient_c_call_returns(
    call: (UniNode | None), name: str
) -> list[(TypeBase | None)] {
    import from jaclang.compiler.frontend.unitree { FuncCall, Name }
    if not isinstance(call, FuncCall)
        or not isinstance(call.target, Name)
        or call.target.value != name {
        return [];
    }
    import from jaclang.compiler.types.types { FunctionType, OverloadedType }
    tgt = call.target;
    decl = tgt.sym.decl if tgt.sym is not None else None;
    if decl is not None
        and decl.loc is not None
        and str(decl.loc.mod_path).endswith(".jac") {
        return [];
    }
    fn_type = tgt.type;
    if isinstance(fn_type, FunctionType) {
        return [fn_type.return_type];
    }
    if isinstance(fn_type, OverloadedType) {
        return [o.return_type for o in fn_type.overloads];
    }
    return [];
}

def is_builtin_pin_call(call: (UniNode | None)) -> bool {
    returns = _ambient_c_call_returns(call, "pin");
    return bool(returns) and all(is_pinned_type(r) for r in returns);
}

def is_builtin_addressof_call(call: (UniNode | None)) -> bool {
    returns = _ambient_c_call_returns(call, "addressof");
    return bool(returns) and all(is_ptr_type(r) for r in returns);
}

def is_c_value_type(t: (TypeBase | None)) -> bool {
    return c_builtin_kind(t) in ("ptr", "PtrView", "VaList");
}

def c_call_borrows_args(call: (UniNode | None)) -> bool {
    import from jaclang.compiler.frontend.unitree { FuncCall }
    if not isinstance(call, FuncCall) {
        return False;
    }
    if call.call_kind == "clib" or is_builtin_pin_call(call) {
        return True;
    }
    return is_ptr_type(call.target.type);
}

glob _SPEC_SCALAR_ALIASES: dict[str, str] = {"int": "i64", "float": "f64"};

def c_type_spec(
    t: (TypeBase | None), annotation: (UniNode | None) = None
) -> list[any] {
    import from jaclang.compiler.types.types { ClassType, FunctionType, UnionType }
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
        elem = c_array_elem(t);
        if elem is not None {
            return ["array", c_type_spec(elem, None)];
        }
        kind = c_builtin_kind(t);
        if kind == "VaList" {
            return ["va_list"];
        }
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

def clib_global_assignment(decl: (UniNode | None)) -> (Assignment | None) {
    assign = decl if isinstance(decl, Assignment) else None;
    if assign is None and decl is not None {
        assign = decl.find_parent_of_type(Assignment);
    }
    if assign is None or not isinstance(assign.parent, GlobalVars) {
        return None;
    }
    return assign if clib_import_of(assign.parent) is not None else None;
}

def clib_global_of_symbol(sym: (Symbol | None)) -> (Assignment | None) {
    return clib_global_assignment(resolved_decl_of(sym)) if sym is not None else None;
}

"""The function `expr` names, following imports, or None. A callback field and
`ptr(f)` take a named function: its address is a C constant."""
def named_function(expr: (UniNode | None)) -> (Ability | None) {
    import from jaclang.compiler.frontend.unitree { Ability, Name }
    while isinstance(expr, AtomUnit) and isinstance(expr.value, Expr) {
        expr = expr.value;
    }
    if not isinstance(expr, Name) or expr.sym is None {
        return None;
    }
    decl = resolved_decl_of(expr.sym);
    owner = decl.name_of if decl is not None else None;
    return owner if isinstance(owner, Ability) else None;
}

def c_string_literal(expr: (UniNode | None)) -> (str | None) {
    import from jaclang.compiler.frontend.unitree {
        FString,
        MultiString,
        literal_string_value
    }
    if expr is None
        or (
            isinstance(expr, MultiString)
            and any(isinstance(part, FString) for part in expr.strings)
        ) {
        return None;
    }
    return literal_string_value(expr);
}

def final_glob_value(nd: (UniNode | None)) -> (Expr | None) {
    import from jaclang.compiler.frontend.unitree { Name }
    if not isinstance(nd, Name) or nd.sym is None {
        return None;
    }
    decl = resolved_decl_of(nd.sym);
    assign = decl if isinstance(decl, Assignment) else None;
    if assign is None and decl is not None {
        assign = decl.find_parent_of_type(Assignment);
    }
    if assign is None
        or not isinstance(assign.parent, GlobalVars)
        or clib_import_of(assign.parent) is not None
        or len(assign.target) != 1
        or assign.type_tag is None {
        return None;
    }
    tag = assign.type_tag.tag;
    if isinstance(tag, AtomTrailer) and not tag.is_attr {
        tag = tag.target;
    }
    if not isinstance(tag, Name) or tag.value != "Final" {
        return None;
    }
    return assign.value;
}

def c_scalar_constant(expr: (UniNode | None), depth: int = 0) -> tuple[bool, any] {
    import from jaclang.compiler.frontend.unitree { BinaryExpr, FuncCall, Name }
    import from jaclang.compiler.frontend.const_fold { fold_const }
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    if depth > 32 {
        return (False, None);
    }
    while isinstance(expr, AtomUnit) and isinstance(expr.value, Expr) {
        expr = expr.value;
    }
    if isinstance(expr, FuncCall)
        and isinstance(expr.target, Name)
        and JAC_TYPE_REGISTRY.is_numeric(expr.target.value)
        and len(expr.params or []) == 1 {
        return c_scalar_constant((expr.params or [])[0], depth + 1);
    }
    if isinstance(expr, Name) {
        value = final_glob_value(expr);
        return c_scalar_constant(value, depth + 1)
            if value is not None
            else (False, None);
    }
    folded = fold_const(expr);
    if not folded[0] and isinstance(expr, (BinaryExpr, UnaryExpr)) {
        return _fold_with_finals(expr, depth);
    }
    return folded;
}

def _fold_with_finals(expr: UniNode, depth: int) -> tuple[bool, any] {
    import from jaclang.compiler.frontend.unitree { BinaryExpr }
    if isinstance(expr, UnaryExpr) {
        (ok, value) = c_scalar_constant(expr.operand, depth + 1);
        if not ok or not isinstance(value, int) or isinstance(value, bool) {
            return (False, None);
        }
        op = expr.op.value;
        if op == "-" {
            return (True, -value);
        }
        if op == "~" {
            return (True, ~value);
        }
        return (True, value) if op == "+" else (False, None);
    }
    if not isinstance(expr, BinaryExpr) {
        return (False, None);
    }
    (lok, left) = c_scalar_constant(expr.left, depth + 1);
    (rok, right) = c_scalar_constant(expr.right, depth + 1);
    if not lok
        or not rok
        or not isinstance(left, int)
        or not isinstance(right, int)
        or isinstance(left, bool)
        or isinstance(right, bool) {
        return (False, None);
    }
    op = expr.op?.value or "";
    if op == "+" {
        return (True, left + right);
    }
    if op == "-" {
        return (True, left - right);
    }
    if op == "*" {
        return (True, left * right);
    }
    if op == "|" {
        return (True, left | right);
    }
    if op == "&" {
        return (True, left & right);
    }
    if op == "^" {
        return (True, left ^ right);
    }
    if op == "<<" and 0 <= right and right < 64 {
        return (True, left << right);
    }
    if op == ">>" and 0 <= right and right < 64 {
        return (True, left >> right);
    }
    return (False, None);
}

def c_array_elem(t: (TypeBase | None)) -> (TypeBase | None) {
    cls = _class_of(t);
    if cls is None or cls._shared is None or not cls.is_builtin("list") {
        return None;
    }
    args = cls.private.type_args if cls.private else None;
    return args[0] if args else None;
}
