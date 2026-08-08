import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { GraphBreakKind }
import from jaclang.compiler.passes.main.graphmend.torch_attr_table {
    has_torch_compile_decorator,
    is_dynamic_torch_attr,
    is_side_effect_name,
    is_torch_attr_target
}

impl GraphBreakDetectPass.before_pass -> None {
    self._enabled = self.prog._compile_options.graphmend;
    if not self._enabled {
        self.prune_signal = True;
        return;
    }
    self._whole_module = self.prog.graphmend_scoped_compile;
    if self._whole_module {
        return;
    }
    self._entry_ids = self._collect_entry_points();
    if not self._entry_ids {
        self._enabled = False;
        self.prune_signal = True;
    }
}

impl GraphBreakDetectPass._collect_entry_points -> set[int] {
    ids: set[int] = set();
    for ab in self.ir_in.get_all_sub_nodes(uni.Ability) {
        if has_torch_compile_decorator(ab) {
            ids.add(id(ab));
        }
    }
    for arch in self.ir_in.get_all_sub_nodes(uni.Archetype) {
        if has_torch_compile_decorator(arch) {
            ids.add(id(arch));
        }
    }
    for call in self.ir_in.get_all_sub_nodes(uni.FuncCall) {
        if is_torch_attr_target(call.target, 'compile') {
            entry = self._resolve_wrapped_entry(call);
            if entry is not None {
                ids.add(id(entry));
            }
        }
    }
    return ids;
}

impl GraphBreakDetectPass._resolve_wrapped_entry(
    call: uni.FuncCall
) -> (uni.UniNode | None) {
    arg: (uni.Expr | None) = None;
    for p in (call.params or []) {
        if not isinstance(p, uni.KWPair) {
            arg = p;
            break;
        }
    }
    if arg is None {
        return None;
    }
    inner = arg.target if isinstance(arg, uni.FuncCall) else arg;
    if not isinstance(inner, uni.Name) {
        return None;
    }
    resolved = self._def_node(inner.value, call);
    if resolved is not None {
        return resolved;
    }
    assign = self._var_assignment(inner.value, call);
    if (assign is not None) and (assign.value is not None) {
        v = assign.value;
        cls = v.target if isinstance(v, uni.FuncCall) else v;
        if isinstance(cls, uni.Name) {
            return self._def_node(cls.value, call);
        }
    }
    return None;
}

impl GraphBreakDetectPass._def_node(
    name: str, ctx: uni.UniNode
) -> (uni.UniNode | None) {
    st = ctx.sym_tab;
    if not st {
        return None;
    }
    sym = st.lookup(name, deep=True);
    if (not sym) or (not sym.defn) {
        return None;
    }
    cur: (uni.UniNode | None) = sym.defn[0];
    while cur {
        if isinstance(cur, (uni.Ability, uni.Archetype)) {
            return cur;
        }
        cur = cur.parent;
    }
    return None;
}

impl GraphBreakDetectPass._var_assignment(
    name: str, ctx: uni.UniNode
) -> (uni.Assignment | None) {
    st = ctx.sym_tab;
    if not st {
        return None;
    }
    sym = st.lookup(name, deep=True);
    if not sym {
        return None;
    }
    return self._defining_assignment(sym);
}

impl GraphBreakDetectPass._in_torch_compiled_scope(nd: uni.UniNode) -> bool {
    if self._whole_module {
        return True;
    }
    cur = nd.parent;
    while cur {
        if id(cur) in self._entry_ids {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

impl GraphBreakDetectPass.enter_func_call(nd: uni.FuncCall) -> None {
    if not self._enabled {
        return;
    }
    if not self._in_torch_compiled_scope(nd) {
        return;
    }
    name = self._call_name(nd);
    if (name is not None) and is_side_effect_name(name) {
        if self._is_user_defined(nd, name) {
            return;
        }
        self.prog.graphmend_breaks[id(nd)] = GraphBreakKind.SIDE_EFFECT;
    }
}

impl GraphBreakDetectPass._call_name(nd: uni.FuncCall) -> (str | None) {
    target = nd.target;
    if isinstance(target, uni.Name) {
        return target.value;
    }
    if (
        isinstance(target, uni.AtomTrailer) and isinstance(target.right, uni.Name)
    ) {
        return target.right.value;
    }
    return None;
}

impl GraphBreakDetectPass._is_user_defined(nd: uni.FuncCall, name: str) -> bool {
    st = nd.sym_tab;
    if not st {
        return False;
    }
    sym = st.lookup(name, deep=True);
    return bool(sym and sym.defn);
}

impl GraphBreakDetectPass.enter_if_stmt(nd: uni.IfStmt) -> None {
    if not self._enabled {
        return;
    }
    if isinstance(nd, uni.ElseIf) {
        return;
    }
    if not self._in_torch_compiled_scope(nd) {
        return;
    }
    if not self._condition_is_data_dependent(nd.condition) {
        return;
    }
    if self._body_is_only_raise(nd.body) {
        self.prog.graphmend_breaks[id(nd)] = GraphBreakKind.VAL_GUARD;
    } else {
        self.prog.graphmend_breaks[id(nd)] = GraphBreakKind.DYN_CTRL_FL;
    }
}

impl GraphBreakDetectPass._body_is_only_raise(
    body: Sequence[uni.CodeBlockStmt]
) -> bool {
    if (not body) or (len(body) != 1) {
        return False;
    }
    return isinstance(body[0], uni.RaiseStmt);
}

impl GraphBreakDetectPass._condition_is_data_dependent(cond: uni.Expr) -> bool {
    if self._expr_uses_dynamic_attr(cond) {
        return True;
    }
    st = cond.sym_tab;
    if not st {
        return False;
    }
    visited: set[str] = set();
    for nm in cond.get_all_sub_nodes(uni.Name) {
        sym = st.lookup(nm.value, deep=True);
        if sym and self._trace_symbol(sym, visited, 0) {
            return True;
        }
    }
    return False;
}

impl GraphBreakDetectPass._expr_uses_dynamic_attr(expr: uni.Expr) -> bool {
    for tr in expr.get_all_sub_nodes(uni.AtomTrailer) {
        if tr.is_attr and isinstance(tr.right, uni.Name) {
            if is_dynamic_torch_attr(tr.right.value) {
                return True;
            }
        }
    }
    return False;
}

impl GraphBreakDetectPass._trace_symbol(
    sym: uni.Symbol, visited: set[str], depth: int
) -> bool {
    if (depth > 10) or (sym.sym_name in visited) {
        return False;
    }
    visited.add(sym.sym_name);
    assign = self._defining_assignment(sym);
    if (assign is None) or (assign.value is None) {
        return False;
    }
    if self._expr_uses_dynamic_attr(assign.value) {
        return True;
    }
    st = assign.sym_tab;
    if not st {
        return False;
    }
    for nm in assign.value.get_all_sub_nodes(uni.Name) {
        dep = st.lookup(nm.value, deep=True);
        if dep and (dep.sym_name not in visited) {
            if self._trace_symbol(dep, visited, depth + 1) {
                return True;
            }
        }
    }
    return False;
}

impl GraphBreakDetectPass._defining_assignment(
    sym: uni.Symbol
) -> (uni.Assignment | None) {
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
