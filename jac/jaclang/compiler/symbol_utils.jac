import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok, SymbolType }

enum CallKind {
    METHOD = "method",
    INSTANTIATION = "instantiation",
    BUILTIN = "builtin",
    CLIB = "clib",
    FUNCTION = "function"
}

def is_builtin_region_name(nm: object) -> bool {
    if not isinstance(nm, uni.Name) or nm.sym_name != "Region" {
        return False;
    }
    if nm.sym is None or nm.sym.decl is None {
        return True;
    }
    _loc = nm.sym.decl.loc;
    _mp = _loc.mod_path if _loc is not None else "";
    return isinstance(_mp, str) and _mp.endswith(".pyi");
}

def resolve_expr_symbol(
    expr: uni.Expr, module: (uni.Module | None) = None
) -> (uni.Symbol | None) {
    if isinstance(expr, uni.AstSymbolNode) and expr.sym {
        return expr.sym;
    }

    if isinstance(expr, uni.AtomTrailer) {
        attrs = expr.as_attr_list;
        if attrs {
            last = attrs[-1];
            if isinstance(last, uni.AstSymbolNode) and last.sym {
                return last.sym;
            }
        }
    }

    if module is not None and isinstance(expr, uni.Name) {
        return module.lookup(expr.sym_name);
    }
    return None;
}

def _is_user_symbol(sym: uni.Symbol) -> bool {
    scope: (uni.UniScopeNode | None) = sym.parent_tab;
    while scope is not None {
        if isinstance(scope, uni.Module) {
            if scope.stub_only {
                return False;
            }
            return not scope.source.file_path.endswith(".pyi");
        }
        scope = scope.parent_scope;
    }
    return False;
}

def classify_call(nd: uni.FuncCall) -> CallKind {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }

    if isinstance(nd.target, uni.AtomTrailer) and nd.target.is_attr {
        return CallKind.METHOD;
    }

    sym = resolve_expr_symbol(nd.target);

    if sym is not None
    and sym.decl is not None
    and sym.sym_type not in (
        SymbolType.OBJECT_ARCH,
        SymbolType.NODE_ARCH,
        SymbolType.EDGE_ARCH,
        SymbolType.WALKER_ARCH,
        SymbolType.ENUM_ARCH
    ) {
        _imp = sym.decl.find_parent_of_type(uni.Import);
        if _imp is not None and _imp.clib_decls {
            return CallKind.CLIB;
        }
    }
    if sym is not None and _is_user_symbol(sym) {
        if sym.sym_type in (
            SymbolType.OBJECT_ARCH,
            SymbolType.NODE_ARCH,
            SymbolType.EDGE_ARCH,
            SymbolType.WALKER_ARCH,
            SymbolType.ENUM_ARCH
        ) {
            return CallKind.INSTANTIATION;
        }
        return CallKind.FUNCTION;
    }

    if isinstance(nd.target, uni.Name)
    and JAC_TYPE_REGISTRY.is_builtin(nd.target.sym_name) {
        return CallKind.BUILTIN;
    }
    return CallKind.FUNCTION;
}

def _ability_of_defn(defn_node: uni.UniNode) -> (uni.Ability | None) {
    if isinstance(defn_node, uni.Ability) {
        return defn_node;
    }
    if isinstance(defn_node.parent, uni.Ability) {
        return defn_node.parent;
    }
    return None;
}

def ability_of_symbol(sym: (uni.Symbol | None)) -> (uni.Ability | None) {
    if sym is None or not sym.defn {
        return None;
    }
    decl = _ability_of_defn(sym.defn[0]);

    if decl is not None and str(decl.loc.mod_path).endswith(".pyi") {
        for alt in sym.defn {
            alt_decl = _ability_of_defn(alt);
            if alt_decl is not None
            and not str(alt_decl.loc.mod_path).endswith(".pyi") {
                return alt_decl;
            }
        }
    }
    return decl;
}

def symbol_owner_archetype(sym: uni.Symbol) -> (uni.Archetype | None) {
    decl = sym.decl;
    if decl is None {
        return None;
    }
    owner = decl?.name_of;
    if isinstance(owner, uni.Archetype) {
        return owner;
    }
    return None;
}

def collect_field_names(
    sym: (uni.Symbol | None), arch_type_filter: (str | None) = None
) -> list[str] {
    if not sym {
        return [];
    }
    arch = symbol_owner_archetype(sym);
    if arch is None {
        return [];
    }
    if arch_type_filter is not None and arch.arch_type.name != arch_type_filter {
        return [];
    }
    return [field.sym_name for field in arch.get_has_vars()];
}

def int_subscript_suffix(right: uni.IndexSlice) -> str | None {
    if (not right.is_range and len(right.slices) == 1) {
        idx = right.slices[0];
        if (idx.start is not None and idx.stop is None and idx.step is None) {
            start = idx.start;

            if isinstance(start, uni.Int) {
                return f"[{start.lit_value}]";
            }

            if (
                isinstance(start, uni.UnaryExpr)
                and isinstance(start.op, uni.Token)
                and start.op.name == "MINUS"
                and isinstance(start.operand, uni.Int)
            ) {
                return f"[-{start.operand.lit_value}]";
            }

            if isinstance(start, uni.MultiString)
            and len(start.strings) == 1
            and isinstance(start.strings[0], uni.String) {
                return f'[{start.strings[0].lit_value!r}]';
            }

            if isinstance(start, uni.Name) {
                return f"[{start.value}]";
            }
        }
    }
    return None;
}

def reference_key_deps(expr: uni.Expr) -> set[str] {
    deps: set[str] = set();
    cur: uni.UniNode | None = expr;
    while cur is not None {
        if isinstance(cur, uni.AtomUnit) and cur.value is not None {
            cur = cur.value;
            continue;
        }
        if isinstance(cur, uni.Name) {
            deps.add(cur.value);
            return deps;
        }
        if isinstance(cur, uni.AtomTrailer) {
            if (
                not cur.is_attr
                and isinstance(cur.right, uni.IndexSlice)
                and not cur.right.is_range
                and len(cur.right.slices) == 1
            ) {
                idx = cur.right.slices[0];
                if (
                    idx.start is not None
                    and idx.stop is None
                    and idx.step is None
                    and isinstance(idx.start, uni.Name)
                ) {
                    deps.add(idx.start.value);
                }
            }
            cur = cur.target;
            continue;
        }
        break;
    }
    return deps;
}

def get_expr_key(expr: uni.Expr) -> str | None {
    if isinstance(expr, uni.Name) {
        return expr.value;
    }
    if isinstance(expr, uni.AtomTrailer) and expr.is_attr {
        base = get_expr_key(expr.target);
        if base and isinstance(expr.right, uni.Name) {
            return f"{base}.{expr.right.value}";
        }
    }
    if isinstance(expr, uni.AtomTrailer) and not expr.is_attr {
        base = get_expr_key(expr.target);
        if base and isinstance(expr.right, uni.IndexSlice) {
            suffix = int_subscript_suffix(expr.right);
            if suffix {
                return f"{base}{suffix}";
            }
        }
    }

    if isinstance(expr, uni.AtomUnit) and expr.value {
        return get_expr_key(expr.value);
    }
    return None;
}

def _extract_first_arg_key(arg: uni.Expr) -> str | None {
    if isinstance(arg, uni.AtomUnit) and arg.value {
        arg = arg.value;
    }
    if isinstance(arg, uni.Name) {
        return arg.value;
    }
    if isinstance(arg, uni.AtomTrailer) {
        return get_expr_key(arg);
    }
    if (
        isinstance(arg, uni.BinaryExpr)
        and isinstance(arg.op, uni.Token)
        and arg.op.name == "WALRUS_EQ"
        and isinstance(arg.left, uni.Name)
    ) {
        return arg.left.value;
    }
    return None;
}

def _extract_compare_left_key(left: uni.Expr) -> str | None {
    if isinstance(left, uni.AtomUnit) and left.value {
        left = left.value;
    }
    if isinstance(left, uni.Name) {
        return left.value;
    }
    if isinstance(left, uni.AtomTrailer) {
        return get_expr_key(left);
    }
    if (
        isinstance(left, uni.BinaryExpr)
        and isinstance(left.op, uni.Token)
        and left.op.name == "WALRUS_EQ"
        and isinstance(left.left, uni.Name)
    ) {
        return left.left.value;
    }
    return None;
}

def classify_condition_key(condition: uni.Expr) -> str | None {
    if isinstance(condition, uni.FuncCall) and isinstance(condition.target, uni.Name) {
        if (
            condition.target.value in ("isinstance", "callable", "hasattr")
            and len(condition.params) >= 1
        ) {
            return _extract_first_arg_key(condition.params[0]);
        }
    }

    if isinstance(condition, uni.CompareExpr) {
        return _extract_compare_left_key(condition.left);
    }

    if isinstance(condition, uni.Name) {
        return condition.value;
    }
    if isinstance(condition, uni.AtomTrailer) and condition.is_attr {
        return get_expr_key(condition);
    }

    if (
        isinstance(condition, uni.BinaryExpr)
        and isinstance(condition.op, uni.Token)
        and condition.op.name == "WALRUS_EQ"
        and isinstance(condition.left, uni.Name)
    ) {
        return condition.left.value;
    }
    return None;
}

def collect_narrowing_symbols(condition: uni.Expr) -> set[str] {
    symbols: set[str] = set();

    if isinstance(condition, uni.CfgExpr) {
        symbols.update(collect_narrowing_symbols(condition.expr));
    } elif isinstance(condition, uni.AtomUnit)
    and isinstance(condition.value, uni.Expr) {
        symbols.update(collect_narrowing_symbols(condition.value));
    } elif isinstance(condition, uni.UnaryExpr) {
        symbols.update(collect_narrowing_symbols(condition.operand));
    } elif isinstance(condition, uni.BoolExpr) {
        for val in condition.values {
            symbols.update(collect_narrowing_symbols(val));
        }
    } else {
        key = classify_condition_key(condition);
        if key is not None {
            symbols.add(key);
        }
    }
    return symbols;
}

def find_destructure_index_path(target: uni.UniNode, key: str) -> list[int] | None {
    if isinstance(target, uni.Name) {
        return [] if target.value == key else None;
    }
    if isinstance(target, uni.AtomTrailer) and target.is_attr {
        matched_key = get_expr_key(target);
        return [] if matched_key == key else None;
    }
    if isinstance(target, uni.AtomUnit) and isinstance(target.value, uni.UniNode) {
        return find_destructure_index_path(target.value, key);
    }
    if isinstance(target, (uni.TupleVal, uni.ListVal)) and target.values {
        for (i, sub) in enumerate(target.values) {
            if not isinstance(sub, uni.UniNode) {
                continue;
            }

            if (
                isinstance(sub, uni.UnaryExpr)
                and isinstance(sub.op, uni.Token)
                and sub.op.name == Tok.STAR_MUL
            ) {
                continue;
            }
            sub_path = find_destructure_index_path(sub, key);
            if sub_path is not None {
                return [i] + sub_path;
            }
        }
    }
    return None;
}

def collect_assignment_target_keys(target: uni.UniNode) -> set[str] {
    keys: set[str] = set();
    if isinstance(target, uni.Name) {
        keys.add(target.value);
    } elif isinstance(target, uni.AtomTrailer) {
        if key := get_expr_key(target) {
            keys.add(key);
        }
    } elif isinstance(target, (uni.TupleVal, uni.ListVal)) {
        if target.values {
            for sub in target.values {
                if isinstance(sub, uni.UniNode) {
                    keys.update(collect_assignment_target_keys(sub));
                }
            }
        }
    } elif (
        isinstance(target, uni.UnaryExpr)
        and isinstance(target.op, uni.Token)
        and target.op.name == Tok.STAR_MUL
    ) {
        keys.update(collect_assignment_target_keys(target.operand));
    } elif isinstance(target, uni.AtomUnit) and isinstance(target.value, uni.UniNode) {
        keys.update(collect_assignment_target_keys(target.value));
    }
    return keys;
}

def collect_assigned_symbols(nd: uni.UniNode) -> set[str] {
    symbols: set[str] = set();

    if isinstance(nd, uni.Assignment) {
        for target in nd.target {
            symbols.update(collect_assignment_target_keys(target));
        }
    } elif isinstance(nd, uni.InForStmt) {
        if isinstance(nd.target, uni.Name) {
            symbols.add(nd.target.value);
        }
    } elif isinstance(nd, uni.AssignCompr) {
        if isinstance(nd.target, uni.Name) {
            symbols.add(nd.target.value);
        }
    }
    return symbols;
}

def collect_method_names(arch: uni.Archetype) -> set[str] {
    names: set[str] = set();
    if arch.body is not None and isinstance(arch.body, Sequence) {
        for stmt in arch.body {
            if isinstance(stmt, uni.Ability) {
                mn = stmt.name_ref.sym_name if stmt.name_ref else None;
                if mn is not None {
                    names.add(mn);
                }
            }
        }
    }
    return names;
}
