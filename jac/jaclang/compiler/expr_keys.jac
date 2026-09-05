import from jaclang.compiler.frontend.unitree {
    Assignment,
    AtomTrailer,
    AtomUnit,
    BinaryExpr,
    BoolExpr,
    CfgExpr,
    CompareExpr,
    Expr,
    FuncCall,
    InForStmt,
    IndexSlice,
    Int,
    KWPair,
    ListVal,
    MultiString,
    Name,
    String,
    Token,
    TupleVal,
    UnaryExpr,
    UniNode
}
import from jaclang.compiler.frontend.constant { Tokens as Tok }

def int_subscript_suffix(right: IndexSlice) -> str | None {
    if (not right.is_range and len(right.slices) == 1) {
        idx = right.slices[0];
        if (idx.start is not None and idx.stop is None and idx.step is None) {
            start = idx.start;

            if isinstance(start, Int) {
                return f"[{start.lit_value}]";
            }

            if (
                isinstance(start, UnaryExpr)
                and isinstance(start.op, Token)
                and start.op.name == "MINUS"
                and isinstance(start.operand, Int)
            ) {
                return f"[-{start.operand.lit_value}]";
            }

            if isinstance(start, MultiString)
                and len(start.strings) == 1
                and isinstance(start.strings[0], String) {
                return f'[{start.strings[0].lit_value!r}]';
            }

            if isinstance(start, Name) {
                return f"[{start.value}]";
            }
        }
    }
    return None;
}

def reference_key_deps(expr: Expr) -> set[str] {
    deps: set[str] = set();
    cur: UniNode | None = expr;
    while cur is not None {
        if isinstance(cur, AtomUnit) and cur.value is not None {
            cur = cur.value;
            continue;
        }
        if isinstance(cur, Name) {
            deps.add(cur.value);
            return deps;
        }
        if isinstance(cur, AtomTrailer) {
            if (
                not cur.is_attr
                and isinstance(cur.right, IndexSlice)
                and not cur.right.is_range
                and len(cur.right.slices) == 1
            ) {
                idx = cur.right.slices[0];
                if (
                    idx.start is not None
                    and idx.stop is None
                    and idx.step is None
                    and isinstance(idx.start, Name)
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

def get_expr_key(expr: Expr) -> str | None {
    if isinstance(expr, Name) {
        return expr.value;
    }
    if isinstance(expr, AtomTrailer) and expr.is_attr {
        base = get_expr_key(expr.target);
        if base and isinstance(expr.right, Name) {
            return f"{base}.{expr.right.value}";
        }
    }
    if isinstance(expr, AtomTrailer) and not expr.is_attr {
        base = get_expr_key(expr.target);
        if base and isinstance(expr.right, IndexSlice) {
            suffix = int_subscript_suffix(expr.right);
            if suffix {
                return f"{base}{suffix}";
            }
        }
    }

    if isinstance(expr, AtomUnit) and isinstance(expr.value, Expr) {
        return get_expr_key(expr.value);
    }
    return None;
}

def _extract_first_arg_key(arg: Expr) -> str | None {
    inner: Expr = arg;
    if isinstance(inner, AtomUnit) and isinstance(inner.value, Expr) {
        inner = inner.value;
    }
    if isinstance(inner, Name) {
        return inner.value;
    }
    if isinstance(inner, AtomTrailer) {
        return get_expr_key(inner);
    }
    if (
        isinstance(inner, BinaryExpr)
        and isinstance(inner.op, Token)
        and inner.op.name == "WALRUS_EQ"
        and isinstance(inner.left, Name)
    ) {
        return inner.left.value;
    }
    return None;
}

def _extract_compare_left_key(left: Expr) -> str | None {
    inner: Expr = left;
    if isinstance(inner, AtomUnit) and isinstance(inner.value, Expr) {
        inner = inner.value;
    }
    if isinstance(inner, Name) {
        return inner.value;
    }
    if isinstance(inner, AtomTrailer) {
        return get_expr_key(inner);
    }
    if (
        isinstance(inner, BinaryExpr)
        and isinstance(inner.op, Token)
        and inner.op.name == "WALRUS_EQ"
        and isinstance(inner.left, Name)
    ) {
        return inner.left.value;
    }
    return None;
}

def classify_condition_key(condition: Expr) -> str | None {
    if isinstance(condition, FuncCall) and isinstance(condition.target, Name) {
        args = condition.params;
        if (
            condition.target.value in ("isinstance", "callable", "hasattr")
            and args is not None
            and len(args) >= 1
        ) {
            first = args[0];
            return _extract_first_arg_key(first) if isinstance(first, Expr) else None;
        }
    }

    if isinstance(condition, CompareExpr) {
        return _extract_compare_left_key(condition.left);
    }

    if isinstance(condition, Name) {
        return condition.value;
    }
    if isinstance(condition, AtomTrailer) and condition.is_attr {
        return get_expr_key(condition);
    }

    if (
        isinstance(condition, BinaryExpr)
        and isinstance(condition.op, Token)
        and condition.op.name == "WALRUS_EQ"
        and isinstance(condition.left, Name)
    ) {
        return condition.left.value;
    }
    return None;
}

def _predicate_call_keys(condition: FuncCall) -> set[str] {
    keys: set[str] = set();
    positional = [
        arg
        for arg in condition.params
        if not isinstance(arg, KWPair)
    ];
    if not positional {
        return keys;
    }
    first_key = _extract_first_arg_key(positional[0]);
    if first_key is None {
        return keys;
    }
    if first_key == "self" and len(positional) > 1 {
        second_key = _extract_first_arg_key(positional[1]);
        if second_key is not None {
            keys.add(second_key);
        }
    }
    keys.add(first_key);
    return keys;
}

def collect_narrowing_symbols(condition: Expr) -> set[str] {
    symbols: set[str] = set();

    if isinstance(condition, CfgExpr) {
        symbols.update(collect_narrowing_symbols(condition.expr));
    } elif isinstance(condition, AtomUnit) and isinstance(condition.value, Expr) {
        symbols.update(collect_narrowing_symbols(condition.value));
    } elif isinstance(condition, UnaryExpr) {
        symbols.update(collect_narrowing_symbols(condition.operand));
    } elif isinstance(condition, BoolExpr) {
        for val in condition.values {
            symbols.update(collect_narrowing_symbols(val));
        }
    } else {
        key = classify_condition_key(condition);
        if key is not None {
            symbols.add(key);
        } elif isinstance(condition, FuncCall) {
            symbols.update(_predicate_call_keys(condition));
        }
    }
    return symbols;
}

def find_destructure_index_path(target: UniNode, key: str) -> list[int] | None {
    if isinstance(target, Name) {
        return [] if target.value == key else None;
    }
    if isinstance(target, AtomTrailer) and target.is_attr {
        matched_key = get_expr_key(target);
        return [] if matched_key == key else None;
    }
    if isinstance(target, AtomUnit) {
        return find_destructure_index_path(target.value, key);
    }
    if isinstance(target, (TupleVal, ListVal)) and target.values {
        for (i, sub) in enumerate(target.values) {
            if (
                isinstance(sub, UnaryExpr)
                and isinstance(sub.op, Token)
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

def collect_assignment_target_keys(target: UniNode) -> set[str] {
    keys: set[str] = set();
    if isinstance(target, Name) {
        keys.add(target.value);
    } elif isinstance(target, AtomTrailer) {
        if key := get_expr_key(target) {
            keys.add(key);
        }
    } elif isinstance(target, (TupleVal, ListVal)) {
        if target.values {
            for sub in target.values {
                if isinstance(sub, UniNode) {
                    keys.update(collect_assignment_target_keys(sub));
                }
            }
        }
    } elif (
        isinstance(target, UnaryExpr)
        and isinstance(target.op, Token)
        and target.op.name == Tok.STAR_MUL
    ) {
        keys.update(collect_assignment_target_keys(target.operand));
    } elif isinstance(target, AtomUnit) and isinstance(target.value, UniNode) {
        keys.update(collect_assignment_target_keys(target.value));
    }
    return keys;
}

def collect_assigned_symbols(nd: UniNode) -> set[str] {
    symbols: set[str] = set();

    if isinstance(nd, Assignment) {
        for target in nd.target {
            symbols.update(collect_assignment_target_keys(target));
        }
    } elif isinstance(nd, InForStmt) {
        if isinstance(nd.target, Name) {
            symbols.add(nd.target.value);
        }
    }
    return symbols;
}

def is_builtin_region_type(t: (object | None), allow_class: bool = False) -> bool {
    import from jaclang.compiler.types.types { ClassType }
    import from jaclang.compiler.frontend.unitree { Archetype }
    if not isinstance(t, ClassType) or t.shared is None {
        return False;
    }
    if t.shared.class_name != "Region" {
        return False;
    }
    if not allow_class and t.is_instantiable() and not t.is_instance() {
        return False;
    }
    owner = t.shared.symbol_table;
    if isinstance(owner, Archetype) {
        _loc = owner.loc;
        return _loc is not None and str(_loc.mod_path).endswith(".pyi");
    }
    return True;
}

def expr_is_builtin_region(expr: (UniNode | None)) -> bool {
    return isinstance(expr, Expr) and is_builtin_region_type(expr.type);
}


def type_tag_borrows(expr: (UniNode | None)) -> bool {
    import from jaclang.compiler.frontend.unitree { SubTag, UnaryExpr }
    import from jaclang.compiler.frontend.constant { is_borrow_kind }
    if expr is None {
        return False;
    }
    if isinstance(expr, SubTag) and is_borrow_kind(expr.ownership) {
        return True;
    }
    for un in expr.get_all_sub_nodes(UnaryExpr) {
        if is_borrow_kind(un.ownership) {
            return True;
        }
    }
    return isinstance(expr, UnaryExpr) and is_borrow_kind(expr.ownership);
}
