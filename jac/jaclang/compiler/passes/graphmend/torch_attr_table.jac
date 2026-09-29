import jaclang.compiler.frontend.unitree as uni;

glob DYNAMIC_TORCH_ATTRS: set[str] = {
         'item',
         'tolist',
         'sum',
         'max',
         'min',
         'mean',
         'prod',
         'argmax',
         'argmin',
         'nonzero',
         'count_nonzero',
         'all',
         'any',
         'equal',
         'allclose',
         'unique'
     },
     SCALAR_TORCH_ATTRS: set[str] = {'item', 'tolist', 'equal', 'allclose'},
     LOGGING_PATTERNS: list[str] = ['logger', 'logging', 'warn', 'critical'],
     SIDE_EFFECT_CALLS: set[str] = {'print'},
     AUTOGRAD_SIGNAL_ATTRS: set[str] = {
         'autograd',
         'backward',
         'enable_grad',
         'grad',
         'requires_grad',
         'requires_grad_',
         'set_grad_enabled',
         'train',
         'training',
         'zero_grad'
     },
     AUTOGRAD_MODULE_PATHS: list[str] = ['torch.autograd', 'torch.optim'],
     AUTOGRAD_ITEM_NAMES: set[str] = {'autograd', 'optim'},
     OPTIM_RECEIVER_PATTERNS: list[str] = ['optim', 'sched'],
     GRAD_OFF_CTX_ATTRS: set[str] = {'no_grad', 'inference_mode'};

def symbol_is_builtin(sym: uni.Symbol) -> bool {
    return (sym?.parent_tab?.scope_name or '') == 'builtins';
}

def cond_is_data_dependent(cond: uni.Expr) -> bool {
    return cond_traces_attr(cond, DYNAMIC_TORCH_ATTRS, False);
}

def cond_materializes_scalar(cond: uni.Expr) -> bool {
    return cond_traces_attr(cond, SCALAR_TORCH_ATTRS, True);
}

def cond_traces_attr(cond: uni.Expr, attrs: set[str], on_exhaust: bool) -> bool {
    if expr_uses_attr(cond, attrs) {
        return True;
    }
    st = cond.sym_tab;
    if not st {
        return False;
    }
    visited: set[str] = set();
    for nm in cond.get_all_sub_nodes(uni.Name) {
        sym = st.lookup(nm.value, deep=True);
        if (sym is not None) and symbol_is_builtin(sym) {
            continue;
        }
        if sym and trace_symbol_attr(sym, attrs, visited, 0, on_exhaust) {
            return True;
        }
    }
    return False;
}

def expr_uses_attr(expr: uni.UniNode, attrs: set[str]) -> bool {
    for tr in expr.get_all_sub_nodes(uni.AtomTrailer) {
        if tr.is_attr and isinstance(tr.right, uni.Name) {
            if tr.right.value in attrs {
                return True;
            }
        }
    }
    return False;
}

def trace_symbol_attr(
    sym: uni.Symbol, attrs: set[str], visited: set[str], depth: int, on_exhaust: bool
) -> bool {
    if depth > 10 {
        return on_exhaust;
    }
    if len(sym.defn) > 1 {
        return on_exhaust;
    }
    if sym.sym_name in visited {
        return False;
    }
    visited.add(sym.sym_name);
    assign = defining_assignment(sym);
    if (assign is None) or (assign.value is None) {
        return False;
    }
    if expr_uses_attr(assign.value, attrs) {
        return True;
    }
    st = assign.sym_tab;
    if not st {
        return False;
    }
    deps = list(assign.value.get_all_sub_nodes(uni.Name));
    if isinstance(assign.value, uni.Name) {
        deps.append(assign.value);
    }
    for nm in deps {
        dep = st.lookup(nm.value, deep=True);
        if (dep is not None) and symbol_is_builtin(dep) {
            continue;
        }
        if dep and (dep.sym_name not in visited) {
            if trace_symbol_attr(dep, attrs, visited, depth + 1, on_exhaust) {
                return True;
            }
        }
    }
    return False;
}

def defining_assignment(sym: uni.Symbol) -> (uni.Assignment | None) {
    if not sym.defn {
        return None;
    }
    cur = sym.defn[-1].parent;
    while cur and (not isinstance(cur, uni.Assignment)) {
        cur = cur.parent;
    }
    if isinstance(cur, uni.Assignment) {
        return cur;
    }
    return None;
}

def is_side_effect_name(name: str) -> bool {
    if name in SIDE_EFFECT_CALLS {
        return True;
    }
    lowered = name.lower();
    for pattern in LOGGING_PATTERNS {
        if pattern in lowered {
            return True;
        }
    }
    return False;
}

def is_torch_attr_target(target: (uni.Expr | None), attr: str) -> bool {
    return (
        isinstance(target, uni.AtomTrailer)
        and isinstance(target.right, uni.Name)
        and (target.right.value == attr)
        and isinstance(target.target, uni.Name)
        and (target.target.value == 'torch')
    );
}

def decorator_base(dec: uni.Expr) -> uni.Expr {
    return dec.target if isinstance(dec, uni.FuncCall) else dec;
}

def has_torch_compile_decorator(nd: uni.UniNode) -> bool {
    for dec in (nd?.decorators or []) {
        if is_torch_attr_target(decorator_base(dec), 'compile') {
            return True;
        }
    }
    return False;
}
