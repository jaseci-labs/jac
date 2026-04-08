"""Shared symbol resolution utilities for all Jac compiler backends.

Centralizes symbol lookup patterns that were previously duplicated across
the ES backend (_resolve_expr_symbol), CFG pass (_collect_narrowing_symbols,
_collect_assigned_symbols), and Native backend (inline name lookups).

All functions are free-standing — no pass or backend state required.
"""
import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { Tokens as Tok }

"""Symbol scope category."""
enum SymbolCategory {
    LOCAL = "local",
    PARAM = "param",
    CAPTURED = "captured",
    GLOBAL = "global",
    BUILTIN = "builtin",
    IMPORTED = "imported"
}

"""Resolve a symbol from an arbitrary expression.

Handles three patterns:
1. Direct AstSymbolNode with resolved sym
2. AtomTrailer chains (a.b.c) — returns last symbol
3. Fallback to module-level lookup for simple Names
"""
def resolve_expr_symbol(
    expr: uni.Expr, module: (uni.Module | None) = None
) -> (uni.Symbol | None) {
    # Direct symbol node
    if isinstance(expr, uni.AstSymbolNode) and expr.sym {
        return expr.sym;
    }
    # Dotted attribute access chain
    if isinstance(expr, uni.AtomTrailer) {
        attrs = expr.as_attr_list;
        if attrs {
            last = attrs[-1];
            if isinstance(last, uni.AstSymbolNode) and last.sym {
                return last.sym;
            }
        }
    }
    # Fallback: simple Name looked up in module scope
    if module is not None and isinstance(expr, uni.Name) {
        return module.lookup(expr.sym_name);
    }
    return None;
}

"""Resolve an attribute chain (a.b.c) to list of resolved symbols."""
def resolve_attr_chain(expr: uni.AtomTrailer) -> list[uni.Symbol] {
    result: list[uni.Symbol] = [];
    attrs = expr.as_attr_list;
    if attrs {
        for attr in attrs {
            if isinstance(attr, uni.AstSymbolNode) and attr.sym {
                result.append(attr.sym);
            }
        }
    }
    return result;
}

"""Get the archetype that owns/defines a symbol (if any)."""
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

"""Collect field names from an archetype symbol.

Generalized from ES backend's _collect_walker_field_names.
Works for any archetype type (walker, node, edge, object).
Optionally filter by arch_type (e.g., Tok.KW_WALKER).
"""
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

"""Build a dotted key string from a Name or AtomTrailer expression.

Returns keys like "x" or "obj.speed" for use in affected_symbols.
Returns None for expressions that cannot be represented as a key.
"""
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
    # Unwrap parentheses
    if isinstance(expr, uni.AtomUnit) and expr.value {
        return get_expr_key(expr.value);
    }
    return None;
}

"""Extract narrowing key from the first argument of a builtin call (isinstance/callable).

Handles unwrapping parentheses, Name, AtomTrailer, and walrus expressions.
"""
def _extract_first_arg_key(arg: uni.Expr) -> str | None {
    if isinstance(arg, uni.AtomUnit) and arg.value {
        arg = arg.value;
    }
    if isinstance(arg, uni.Name) {
        return arg.value;
    }
    if isinstance(arg, uni.AtomTrailer) and arg.is_attr {
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

"""Extract narrowing key from the left side of a CompareExpr.

Handles unwrapping parentheses, Name, AtomTrailer, and walrus expressions.
"""
def _extract_compare_left_key(left: uni.Expr) -> str | None {
    if isinstance(left, uni.AtomUnit) and left.value {
        left = left.value;
    }
    if isinstance(left, uni.Name) {
        return left.value;
    }
    if isinstance(left, uni.AtomTrailer) and left.is_attr {
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

"""Classify a leaf condition and extract its narrowing key (type-free).

Free-standing function for use in symbol_utils where TypeEvaluator is unavailable.
Returns the narrowing key or None.
"""
def classify_condition_key(condition: uni.Expr) -> str | None {
    # isinstance(x, T) or callable(x)
    if isinstance(condition, uni.FuncCall) and isinstance(condition.target, uni.Name) {
        if (
            condition.target.value in ("isinstance", "callable")
            and len(condition.params) >= 1
        ) {
            return _extract_first_arg_key(condition.params[0]);
        }
    }
    # CompareExpr: x is None, x == literal, etc.
    if isinstance(condition, uni.CompareExpr) {
        return _extract_compare_left_key(condition.left);
    }
    # Truthiness: x / x.attr
    if isinstance(condition, uni.Name) {
        return condition.value;
    }
    if isinstance(condition, uni.AtomTrailer) and condition.is_attr {
        return get_expr_key(condition);
    }
    # Walrus: (x := expr)
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

"""Collect symbols narrowed by a condition expression.

Extracted from CFGBuildPass._collect_narrowing_symbols.
Structural wrappers (parens, NOT, AND/OR) recurse; leaf conditions
are classified via classify_condition_key.
"""
def collect_narrowing_symbols(condition: uni.Expr) -> set[str] {
    symbols: set[str] = set();
    # Structural wrappers — recurse
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
        # Leaf classification — single dispatch point
        key = classify_condition_key(condition);
        if key is not None {
            symbols.add(key);
        }
    }
    return symbols;
}

"""Collect all symbols assigned/bound in a statement.

Extracted from CFGBuildPass._collect_assigned_symbols.
Handles assignments, for-loops, and walrus operators.
"""
def collect_assigned_symbols(nd: uni.UniNode) -> set[str] {
    symbols: set[str] = set();
    # Assignment: x = ...
    if isinstance(nd, uni.Assignment) {
        for target in nd.target {
            if isinstance(target, uni.Name) {
                symbols.add(target.value);
            } elif isinstance(target, uni.AtomTrailer) and target.is_attr {
                if key := get_expr_key(target) {
                    symbols.add(key);
                }
            }
        }
    }
    # For loop: for x in ...
    elif isinstance(nd, uni.InForStmt) {
        if isinstance(nd.target, uni.Name) {
            symbols.add(nd.target.value);
        }
    }
    # Walrus operator / assignment comprehension: (x := ...)
    elif isinstance(nd, uni.AssignCompr) {
        if isinstance(nd.target, uni.Name) {
            symbols.add(nd.target.value);
        }
    }
    return symbols;
}

"""Collect method names from an archetype's raw body (no ImplDef resolution).

Used by native backend where raw body iteration is intentional.
"""
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

"""Categorize a symbol's scope: local, param, captured, global, builtin, imported."""
def categorize_symbol(sym: uni.Symbol, ref_scope: uni.UniScopeNode) -> SymbolCategory {
    if sym.imported {
        return SymbolCategory.IMPORTED;
    }
    # Check if the symbol's defining scope is the reference scope or an ancestor
    def_scope = sym.parent_tab;
    if def_scope is None {
        return SymbolCategory.GLOBAL;
    }
    # If defined in the same function/scope
    if def_scope is ref_scope {
        # Check if it's a parameter (defined in a function scope directly)
        if isinstance(def_scope, uni.Ability) {
            sig = def_scope?.signature;
            if sig is not None and isinstance(sig, uni.FuncSignature) {
                param_names = [
                    p.name.sym_name
                    for p in sig.params
                    if isinstance(p, uni.ParamVar) and p.name
                ];
                if sym.sym_name in param_names {
                    return SymbolCategory.PARAM;
                }
            }
        }
        return SymbolCategory.LOCAL;
    }
    # Walk up from ref_scope to find if def_scope is a parent
    current = ref_scope.parent_scope;
    while current is not None {
        if current is def_scope {
            # Defined in an outer scope — check if module-level
            if isinstance(def_scope, uni.Module) {
                return SymbolCategory.GLOBAL;
            }
            return SymbolCategory.CAPTURED;
        }
        current = current.parent_scope;
    }
    return SymbolCategory.GLOBAL;
}
