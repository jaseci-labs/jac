impl NativeLowering._class_expr_bound(
    expr: (uni.UniNode | None), unbounded: (str | None) = None
) -> (str | None) {
    while isinstance(expr, uni.AtomUnit) {
        expr = expr.value;
    }
    if not isinstance(expr, uni.Expr) or not isinstance(expr.type, ClassType) {
        return None;
    }
    typ = expr.type;
    if typ.is_builtin("type") {
        import from jaclang.compiler.types.types { TypeVarType }
        args = typ.private.type_args or [];
        arg = args[0] if args else None;
        if isinstance(arg, TypeVarType) {
            arg = arg.bound;
        }
        if not isinstance(arg, ClassType) {
            return unbounded;
        }
        typ = arg;
    } elif not typ.is_instantiable() or typ.is_instance() {
        return None;
    }
    import from jaclang.compiler.passes.layout_pass { class_type_native_name }
    return class_type_native_name(typ);
}

impl NativeLowering._class_ancestors(type_name: str) -> list[str] {
    ancestors: list[str] = [type_name];
    index = 0;
    while index < len(ancestors) {
        for step in self._mro_of(ancestors[index]) {
            if step not in ancestors {
                ancestors.append(step);
            }
        }
        index += 1;
    }
    return ancestors;
}
