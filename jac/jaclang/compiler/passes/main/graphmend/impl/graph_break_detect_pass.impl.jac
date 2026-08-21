import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.constant { GraphBreakKind }
import from jaclang.compiler.passes.main.graphmend.ast_edit { facts_for }
import from jaclang.compiler.passes.main.graphmend.scope_facts {
    body_is_only,
    collect_wrap_entries,
    compiled_region_ids,
    materialize_claim_chain,
    module_has_wrap_site,
    register_claim
}
import from jaclang.compiler.passes.main.graphmend.torch_attr_table {
    cond_is_data_dependent,
    defining_assignment,
    is_side_effect_name
}

impl GraphBreakDetectPass.before_pass -> None {
    self._enabled = self.prog._compile_options.graphmend is True;
    if not self._enabled {
        self.prune_signal = True;
        return;
    }
    register_claim(self.prog, self.ir_in, self._mat_seen);
    materialize_claim_chain(self.prog, self.ir_in.loc.mod_path, self._mat_seen);
    self._saw_compile_call = module_has_wrap_site(self.ir_in);
    wrapped = collect_wrap_entries(
        self.prog, self.ir_in, self._mat_seen, facts_for(self.ir_in).wrapped_keys
    );
    self._entry_ids = set();
    for e in wrapped {
        if isinstance(e, uni.Ability) {
            self._entry_ids.add(id(e));
        }
    }
    self._entry_ids |= compiled_region_ids(
        self.prog, self.ir_in, self._mat_seen, wrapped
    );
    members: list[uni.UniNode] = [];
    members.extend(self.ir_in.get_all_sub_nodes(uni.Ability));
    members.extend(self.ir_in.get_all_sub_nodes(uni.Archetype));
    local = False;
    for member in members {
        if id(member) in self._entry_ids {
            local = True;
            break;
        }
    }
    self._record_noop(local);
    if not local {
        self._enabled = False;
        self.prune_signal = True;
        return;
    }
    self._spine_ids = set();
    for member in members {
        if id(member) in self._entry_ids {
            cur: (uni.UniNode | None) = member.parent;
            while cur is not None {
                self._spine_ids.add(id(cur));
                cur = cur.parent;
            }
        }
    }
}

impl GraphBreakDetectPass._record_noop(local: bool) -> None {
    facts_for(self.ir_in).noop = (not local) and (not self._saw_compile_call);
}

impl GraphBreakDetectPass.enter_ability(nd: uni.Ability) -> None {
    if not self._enabled {
        return;
    }
    if (id(nd) in self._entry_ids) or (id(nd) in self._spine_ids) {
        return;
    }
    if self._in_torch_compiled_scope(nd) {
        return;
    }
    self.prune_signal = True;
}

impl GraphBreakDetectPass._in_torch_compiled_scope(nd: uni.UniNode) -> bool {
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
        target = nd.target;
        if isinstance(target, uni.AtomTrailer) {
            if not self._base_binds_logger(target) {
                return;
            }
        } elif name != 'print' {
            return;
        }
        facts_for(nd).breaks[nd] = GraphBreakKind.SIDE_EFFECT;
    }
}

impl GraphBreakDetectPass._base_binds_logger(t: uni.AtomTrailer) -> bool {
    base = t.target;
    if not isinstance(base, uni.Name) {
        return False;
    }
    st = base.sym_tab;
    sym = st.lookup(base.value, deep=True) if st else None;
    if sym is None {
        return False;
    }
    decl = sym.decl;
    if decl is not None {
        mi = decl.find_parent_of_type(uni.ModuleItem);
        if (mi is not None) and isinstance(mi.name, uni.Name) {
            local = mi.alias.value if (mi.alias is not None) else mi.name.value;
            if local == 'logging' {
                return True;
            }
        }
        mp = decl.find_parent_of_type(uni.ModulePath);
        if (mp is not None)
            and (mp.dot_path_str.lstrip('.').split('.')[-1] == 'logging') {
            return True;
        }
    }
    assign = defining_assignment(sym);
    v = assign.value if (assign is not None) else None;
    if not isinstance(v, uni.FuncCall) {
        return False;
    }
    leaf = v.target.right if isinstance(v.target, uni.AtomTrailer) else v.target;
    return isinstance(leaf, uni.Name) and (leaf.value in {'getLogger', 'get_logger'});
}

impl GraphBreakDetectPass._call_name(nd: uni.FuncCall) -> (str | None) {
    target = nd.target;
    if isinstance(target, uni.Name) {
        return target.value;
    }
    if (isinstance(target, uni.AtomTrailer) and isinstance(target.right, uni.Name)) {
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
    if not cond_is_data_dependent(nd.condition) {
        return;
    }
    if body_is_only(nd.body, uni.RaiseStmt) {
        facts_for(nd).breaks[nd] = GraphBreakKind.VAL_GUARD;
    } else {
        facts_for(nd).breaks[nd] = GraphBreakKind.DYN_CTRL_FL;
    }
}
