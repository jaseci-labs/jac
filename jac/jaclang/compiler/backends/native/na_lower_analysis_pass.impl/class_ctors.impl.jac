import from jaclang.compiler.frontend.constant { SymbolType }

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

impl NativeLowering._is_runtime_class_value_shape(
    target: (uni.UniNode | None), in_scope: bool, class_symbols: tuple[SymbolType, ...]
) -> bool {
    if isinstance(target, uni.Name) {
        if not in_scope {
            return False;
        }
        if self._arch_alias_target(target) is not None {
            return False;
        }
    } elif isinstance(target, uni.AtomTrailer) {
        if target.is_attr {
            attr = target.right;
            sym = attr.sym if isinstance(attr, uni.AstSymbolNode) else None;
            if sym is None or sym.sym_type in class_symbols {
                return False;
            }
        } elif self._class_expr_bound(target.target) is not None {
            return False;
        }
    } elif not isinstance(target, uni.FuncCall) {
        return False;
    }
    return self._class_expr_bound(target, unbounded="type") is not None;
}

impl NativeLowering._bind_class_ctor_args_plan(
    nd: uni.FuncCall,
    args: list[uni.Expr | uni.KWPair],
    params: list[tuple[str, bool, bool]],
    bound: str
) -> (tuple[list[tuple[int, uni.Expr]], uni.Expr | None] | None) {
    positional = [
        i
        for (i, p) in enumerate(params)
        if p[1]
    ];
    bound_args: list[tuple[int, uni.Expr]] = [];
    spread: (uni.Expr | None) = None;
    taken: set[int] = set();
    next_positional = 0;
    problem: (str | None) = None;
    for arg in args {
        index = -1;
        value: (uni.Expr | None) = None;
        if isinstance(arg, uni.KWPair) {
            key = arg.key.sym_name if arg.key is not None else None;
            if key is None {
                if spread is not None {
                    problem = "only one `**` mapping can be unpacked into a class-value constructor";
                    break;
                }
                spread = arg.value;
                continue;
            }
            for (i, p) in enumerate(params) {
                if p[0] == key {
                    index = i;
                }
            }
            if index < 0 {
                problem = f"'{self._arch_display(
                    bound
                )}' has no constructor parameter named '{key}'";
                break;
            }
            value = arg.value;
        } elif isinstance(arg, uni.UnaryExpr)
            and isinstance(arg.op, uni.Token)
            and arg.op.name == Tok.STAR_POW {
            if spread is not None {
                problem = "only one `**` mapping can be unpacked into a class-value constructor";
                break;
            }
            spread = arg.operand;
            continue;
        } elif isinstance(arg, uni.UnaryExpr)
            and isinstance(arg.op, uni.Token)
            and arg.op.name == Tok.STAR_MUL {
            problem = "`*` unpacking into a class-value constructor is not lowered natively; pass the arguments explicitly";
            break;
        } else {
            if next_positional >= len(positional) {
                problem = f"too many positional arguments for the '{self._arch_display(
                    bound
                )}' constructor";
                break;
            }
            index = positional[next_positional];
            next_positional += 1;
            value = arg;
        }
        if value is None {
            continue;
        }
        if index in taken {
            problem = f"constructor parameter '{params[index][0]}' is given twice";
            break;
        }
        taken.add(index);
        bound_args.append((index, value));
    }
    if problem is None and spread is None {
        for (i, p) in enumerate(params) {
            if p[2] and i not in taken {
                problem = f"missing required '{self._arch_display(
                    bound
                )}' constructor argument '{p[0]}'";
                break;
            }
        }
    }
    if problem is not None {
        self.ctx.emit(
            E5092,
            node_override=nd,
            kind="class value construction",
            name=f"type[{self._arch_display(bound)}]",
            help_text=f"Construction through a class value binds its arguments against the '{self._arch_display(
                bound
            )}' constructor signature: {problem}."
        );
        return None;
    }
    return (bound_args, spread);
}
