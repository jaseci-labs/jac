import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.diagnostics { E1301, E1302, E1303, E1304, E1305, E1306 }

impl OwnershipCheckPass.before_pass -> None {
    self.owned_syms = set();
    self.owned_names = {};
    self.owned_decl = {};
    self.consumed_syms = set();
    self.proven_unique_syms = set();
    self.borrow_syms = set();
    self.param_borrow_syms = set();
    self.borrow_names = {};
    self.borrow_owner = {};
    self.borrow_owner_node = {};
    self.borrow_is_mut = {};
    self.e1304_borrow_ids = set();
    self.in_consumed = {};
    self.in_live_borrows = {};
    self.out_live_borrows = {};
    self.in_reaching_borrows = {};

    mod_root = self.ir_in;
    if mod_root is None {
        return;
    }
    self._collect_owned(mod_root);
    self._collect_borrows(mod_root);
    self._collect_params(mod_root);
    if not self.owned_syms and not self.borrow_syms {
        return;
    }

    cfg_nodes = [
        n
        for n in mod_root.flatten()
        if isinstance(n, uni.UniCFGNode)
    ];
    self._run_dataflow(cfg_nodes);
    self._run_borrow_liveness(cfg_nodes);
    self._run_reaching_borrows(cfg_nodes);
    self._compute_proven_unique();
    self._emit_diagnostics(mod_root);
    self._emit_borrow_diagnostics(mod_root);
    self._emit_leak_diagnostics();
    self._emit_escape_diagnostics(mod_root);
}

impl OwnershipCheckPass._is_own_decl(nd: uni.Assignment) -> (uni.Name | None) {
    if not (nd.type_tag and nd.type_tag.is_own) {
        return None;
    }
    if len(nd.target) != 1 {
        return None;
    }
    target = nd.target[0];
    if isinstance(target, uni.Name) and target.sym {
        return target;
    }
    return None;
}

impl OwnershipCheckPass._is_borrow_decl(nd: uni.Assignment) -> (uni.Name | None) {
    if not (nd.type_tag and nd.type_tag.is_borrow) {
        return None;
    }
    if len(nd.target) != 1 {
        return None;
    }
    target = nd.target[0];
    if isinstance(target, uni.Name) and target.sym {
        return target;
    }
    return None;
}

impl OwnershipCheckPass._borrow_target(nd: uni.Assignment) -> (uni.Name | None) {
    decl_target = self._is_borrow_decl(nd);
    if decl_target is not None {
        return decl_target;
    }
    if len(nd.target) != 1 {
        return None;
    }
    target = nd.target[0];
    if isinstance(target, uni.Name)
    and target.sym
    and id(target.sym) in self.borrow_syms {
        return target;
    }
    return None;
}

impl OwnershipCheckPass._borrow_source_owner(nd: uni.Assignment) -> (uni.Name | None) {
    if not isinstance(nd.value, uni.UnaryExpr) {
        return None;
    }
    is_borrow_val = nd.value.is_borrow;

    if not is_borrow_val and len(nd.target) == 1 {
        tgt = nd.target[0];
        if isinstance(tgt, uni.Name) and tgt.sym and id(tgt.sym) in self.borrow_syms {
            is_borrow_val = True;
        }
    }
    if not is_borrow_val {
        return None;
    }
    operand = nd.value.operand;
    if isinstance(operand, uni.Name)
    and operand.sym
    and id(operand.sym) in self.owned_syms {
        return operand;
    }
    return None;
}

impl OwnershipCheckPass._collect_owned(tree: uni.UniNode) -> None {
    for nd in tree.get_all_sub_nodes(uni.Assignment) {
        target = self._is_own_decl(nd);
        if target is not None {
            self.owned_syms.add(id(target.sym));
            self.owned_names[id(target.sym)] = target.sym_name;
            self.owned_decl[id(target.sym)] = target;
        }
    }
}

impl OwnershipCheckPass._collect_borrows(tree: uni.UniNode) -> None {
    for nd in tree.get_all_sub_nodes(uni.Assignment) {
        target = self._is_borrow_decl(nd);
        if target is not None {
            borrow_id = id(target.sym);
            self.borrow_syms.add(borrow_id);
            self.borrow_names[borrow_id] = target.sym_name;
            self.borrow_is_mut[borrow_id] = nd.type_tag.is_mut_borrow
                if nd.type_tag
                else False;
        }
    }
    for nd in tree.get_all_sub_nodes(uni.Assignment) {
        target = self._borrow_target(nd);
        owner = self._borrow_source_owner(nd);
        if target is not None and owner is not None and target.sym and owner.sym {
            borrow_id = id(target.sym);
            owner_id = id(owner.sym);
            self.borrow_syms.add(borrow_id);
            self.borrow_names[borrow_id] = target.sym_name;
            self.borrow_owner[borrow_id] = owner_id;
            self.borrow_owner_node[borrow_id] = owner;
            self.borrow_is_mut[borrow_id] = nd.value.is_mut_borrow;
        }
    }
}

impl OwnershipCheckPass._collect_params(tree: uni.UniNode) -> None {
    for param in tree.get_all_sub_nodes(uni.ParamVar) {
        tag = param.type_tag;
        if tag is None {
            continue;
        }
        name = param.name;
        if not (isinstance(name, uni.Name) and name.sym) {
            continue;
        }
        sid = id(name.sym);
        if tag.is_borrow or tag.is_mut_borrow {
            self.borrow_syms.add(sid);
            self.param_borrow_syms.add(sid);
            self.borrow_names[sid] = name.sym_name;
            self.borrow_is_mut[sid] = tag.is_mut_borrow;
        } elif tag.is_own {
            self.owned_syms.add(sid);
            self.owned_names[sid] = name.sym_name;
            self.owned_decl[sid] = name;
        }
    }
}

impl OwnershipCheckPass._return_roots_at_param_borrow(nd: uni.Expr | None) -> bool {
    cur = nd;
    if isinstance(cur, uni.UnaryExpr) and (cur.is_borrow or cur.is_mut_borrow) {
        cur = cur.operand;
    }
    while isinstance(cur, uni.AtomTrailer) {
        cur = cur.target;
    }
    if isinstance(cur, uni.Name)
    and cur.sym
    and id(cur.sym) in self.param_borrow_syms {
        return True;
    }
    return False;
}

impl OwnershipCheckPass._borrow_region(sym_id: int) -> (uni.UniScopeNode | None) {
    owner_id = self.borrow_owner.get(sym_id);
    if owner_id is not None and owner_id in self.owned_decl {
        return self._nearest_scope(self.owned_decl[owner_id]);
    }
    return None;
}

impl OwnershipCheckPass._region_strictly_outlives(
    dest: uni.UniScopeNode | None, region: uni.UniScopeNode | None
) -> bool {
    if dest is None or region is None {
        return False;
    }
    if dest is region {
        return False;
    }
    return self._is_ancestor(dest, region);
}

impl OwnershipCheckPass._compute_proven_unique -> None {
    borrowed_owners: set[int] = set();
    for owner_id in self.borrow_owner.values() {
        borrowed_owners.add(owner_id);
    }
    for owner_id in self.owned_syms {
        if owner_id in self.consumed_syms and owner_id not in borrowed_owners {
            self.proven_unique_syms.add(owner_id);
        }
    }
    for owner_id in self.proven_unique_syms {
        decl = self.owned_decl.get(owner_id);
        if decl is not None and decl.sym is not None {
            decl.sym.is_proven_unique = True;
        }
    }
}

impl OwnershipCheckPass._assign_kill_gen(
    nd: uni.Assignment
) -> tuple[set[int], set[int]] {
    kill: set[int] = set();
    gen: set[int] = set();
    if nd.aug_op is not None {
        return (kill, gen);
    }
    decl_target = self._is_own_decl(nd);
    if decl_target is not None {
        kill.add(id(decl_target.sym));
    } else {
        for tgt in nd.target {
            if isinstance(tgt, uni.Name)
            and tgt.sym
            and id(tgt.sym) in self.owned_syms {
                kill.add(id(tgt.sym));
            }
        }
    }
    if isinstance(nd.value, uni.Name)
    and nd.value.sym
    and id(nd.value.sym) in self.owned_syms {
        gen.add(id(nd.value.sym));
    }
    return (kill, gen);
}

impl OwnershipCheckPass._call_params(
    call: uni.FuncCall
) -> Sequence[uni.Expr | uni.KWPair] {
    return call.params or [];
}

impl OwnershipCheckPass._call_move_gen(nd: uni.UniCFGNode) -> set[int] {
    gen: set[int] = set();
    for call in nd.get_all_sub_nodes(uni.FuncCall) {
        for param in self._call_params(call) {
            arg: uni.Expr | None = None;
            if isinstance(param, uni.KWPair) {
                arg = param.value;
            } elif isinstance(param, uni.Expr) {
                arg = param;
            }
            if isinstance(arg, uni.Name)
            and arg.sym
            and id(arg.sym) in self.owned_syms {
                gen.add(id(arg.sym));
            }
        }
    }
    return gen;
}

impl OwnershipCheckPass._return_move_gen(nd: uni.UniCFGNode) -> set[int] {
    gen: set[int] = set();
    returns: list[uni.ReturnStmt] = [];
    if isinstance(nd, uni.ReturnStmt) {
        returns.append(nd);
    }
    for ret in nd.get_all_sub_nodes(uni.ReturnStmt) {
        returns.append(ret);
    }
    for ret in returns {
        expr = ret.expr;
        if isinstance(expr, uni.Name)
        and expr.sym
        and id(expr.sym) in self.owned_syms {
            gen.add(id(expr.sym));
        }
    }
    return gen;
}

impl OwnershipCheckPass._transfer(nd: uni.UniCFGNode, in_set: set[int]) -> set[int] {
    out = set(in_set);
    if isinstance(nd, uni.Assignment) {
        (kill, gen) = self._assign_kill_gen(nd);
        for k in kill {
            out.discard(k);
        }
        for g in gen {
            out.add(g);
        }
    }
    for g in self._call_move_gen(nd) {
        out.add(g);
    }
    for g in self._return_move_gen(nd) {
        out.add(g);
    }
    return out;
}

impl OwnershipCheckPass._run_dataflow(cfg_nodes: list[uni.UniCFGNode]) -> None {
    for n in cfg_nodes {
        self.in_consumed[id(n)] = set();
    }
    worklist = list(cfg_nodes);
    while worklist {
        n = worklist.pop();
        new_in: set[int] = set();
        for pred in n.bb_in {
            pred_out = self._transfer(pred, self.in_consumed.get(id(pred), set()));
            for c in pred_out {
                new_in.add(c);
            }
        }
        if new_in != self.in_consumed.get(id(n), set()) {
            self.in_consumed[id(n)] = new_in;
            for succ in n.bb_out {
                worklist.append(succ);
            }
        }
    }
    self.consumed_syms = set();
    for n in cfg_nodes {
        out = self._transfer(n, self.in_consumed.get(id(n), set()));
        for consumed in out {
            self.consumed_syms.add(consumed);
        }
    }
}

impl OwnershipCheckPass._borrow_read_gen(nd: uni.UniCFGNode) -> set[int] {
    gen: set[int] = set();
    for name in nd.get_all_sub_nodes(uni.Name) {
        if name.sym and id(name.sym) in self.borrow_syms and self._is_read_name(name) {
            gen.add(id(name.sym));
        }
    }
    return gen;
}

impl OwnershipCheckPass._borrow_assign_kill_gen(
    nd: uni.UniCFGNode
) -> tuple[set[int], set[int]] {
    kill: set[int] = set();
    gen: set[int] = set();
    if isinstance(nd, uni.Assignment) {
        target = self._borrow_target(nd);
        if target is not None and target.sym {
            borrow_id = id(target.sym);
            kill.add(borrow_id);
            if self._borrow_source_owner(nd) is not None {
                gen.add(borrow_id);
            }
        }
    }
    return (kill, gen);
}

impl OwnershipCheckPass._run_borrow_liveness(cfg_nodes: list[uni.UniCFGNode]) -> None {
    for n in cfg_nodes {
        self.in_live_borrows[id(n)] = set();
        self.out_live_borrows[id(n)] = set();
    }
    worklist = list(cfg_nodes);
    while worklist {
        n = worklist.pop();
        new_out: set[int] = set();
        for succ in n.bb_out {
            for b in self.in_live_borrows.get(id(succ), set()) {
                new_out.add(b);
            }
        }
        (kill, _) = self._borrow_assign_kill_gen(n);
        new_in = set(new_out);
        for k in kill {
            new_in.discard(k);
        }
        for g in self._borrow_read_gen(n) {
            new_in.add(g);
        }
        if (
            new_in != self.in_live_borrows.get(id(n), set())
            or new_out != self.out_live_borrows.get(id(n), set())
        ) {
            self.in_live_borrows[id(n)] = new_in;
            self.out_live_borrows[id(n)] = new_out;
            for pred in n.bb_in {
                worklist.append(pred);
            }
        }
    }
}

impl OwnershipCheckPass._run_reaching_borrows(cfg_nodes: list[uni.UniCFGNode]) -> None {
    for n in cfg_nodes {
        self.in_reaching_borrows[id(n)] = set();
    }
    worklist = list(cfg_nodes);
    while worklist {
        n = worklist.pop();
        new_in: set[int] = set();
        for pred in n.bb_in {
            pred_out = set(self.in_reaching_borrows.get(id(pred), set()));
            (kill, gen) = self._borrow_assign_kill_gen(pred);
            for k in kill {
                pred_out.discard(k);
            }
            for g in gen {
                pred_out.add(g);
            }
            for b in pred_out {
                new_in.add(b);
            }
        }
        if new_in != self.in_reaching_borrows.get(id(n), set()) {
            self.in_reaching_borrows[id(n)] = new_in;
            for succ in n.bb_out {
                worklist.append(succ);
            }
        }
    }
}

impl OwnershipCheckPass._nearest_cfg(nd: uni.UniNode) -> (uni.UniCFGNode | None) {
    cur = nd.parent;
    while cur is not None {
        if isinstance(cur, uni.UniCFGNode) {
            return cur;
        }
        cur = cur.parent;
    }
    return None;
}

impl OwnershipCheckPass._nearest_scope(nd: uni.UniNode) -> (uni.UniScopeNode | None) {
    cur = nd.parent;
    while cur is not None {
        if isinstance(cur, uni.UniScopeNode) {
            return cur;
        }
        cur = cur.parent;
    }
    return None;
}

impl OwnershipCheckPass._is_ancestor(ancestor: uni.UniNode, nd: uni.UniNode) -> bool {
    cur: uni.UniNode | None = nd;
    while cur is not None {
        if cur is ancestor {
            return True;
        }
        cur = cur.parent;
    }
    return False;
}

impl OwnershipCheckPass._is_write_target(nd: uni.Name) -> bool {
    parent = nd.parent;
    if isinstance(parent, uni.Assignment) {
        for tgt in parent.target {
            if tgt is nd {
                return True;
            }
        }
    }
    return False;
}

impl OwnershipCheckPass._is_read_name(nd: uni.Name) -> bool {
    return not self._is_write_target(nd);
}

impl OwnershipCheckPass._target_owner_sym(nd: uni.Expr) -> (int | None) {
    if isinstance(nd, uni.Name) and nd.sym and id(nd.sym) in self.owned_syms {
        return id(nd.sym);
    }
    if isinstance(nd, uni.AtomTrailer)
    and nd.is_attr
    and isinstance(nd.target, uni.Name)
    and nd.target.sym
    and id(nd.target.sym) in self.owned_syms {
        return id(nd.target.sym);
    }
    return None;
}

impl OwnershipCheckPass._emit_diagnostics(tree: uni.UniNode) -> None {
    for nd in tree.get_all_sub_nodes(uni.Name) {
        if nd.sym is None or id(nd.sym) not in self.owned_syms {
            continue;
        }
        if self._is_write_target(nd) {
            continue;
        }
        owner = self._nearest_cfg(nd);
        if owner is None {
            continue;
        }
        consumed = self.in_consumed.get(id(owner), set());
        if id(nd.sym) in consumed {
            self.emit(
                E1301,
                node_override=nd,
                name=self.owned_names.get(id(nd.sym), nd.sym_name)
            );
        }
    }
}

impl OwnershipCheckPass._emit_borrow_diagnostics(tree: uni.UniNode) -> None {
    emitted_e1304: set[int] = set();
    for nd in tree.get_all_sub_nodes(uni.Assignment) {
        owner = self._borrow_source_owner(nd);
        target = self._borrow_target(nd);

        cfg = nd;
        if owner is not None and target is not None and target.sym and owner.sym {
            borrow_id = id(target.sym);
            owner_id = id(owner.sym);
            active = self.in_live_borrows.get(id(cfg), set()).intersection(
                self.in_reaching_borrows.get(id(cfg), set())
            );
            for other in active {
                if self.borrow_owner.get(other) != owner_id {
                    continue;
                }
                if nd.value
                and isinstance(nd.value, uni.UnaryExpr)
                and (nd.value.is_mut_borrow or self.borrow_is_mut.get(other, False)) {
                    self.emit(
                        E1302,
                        node_override=owner,
                        name=self.owned_names.get(owner_id, owner.sym_name)
                    );
                    break;
                }
            }
            owner_scope = self._nearest_scope(self.owned_decl.get(owner_id, owner));
            if owner_scope is not None and borrow_id not in emitted_e1304 {
                for use in tree.get_all_sub_nodes(uni.Name) {
                    if use.sym
                    and id(use.sym) == borrow_id
                    and self._is_read_name(use)
                    and not self._is_ancestor(owner_scope, use) {
                        self.emit(
                            E1304,
                            node_override=owner,
                            name=self.owned_names.get(owner_id, owner.sym_name)
                        );
                        emitted_e1304.add(borrow_id);
                        self.e1304_borrow_ids.add(borrow_id);
                        break;
                    }
                }
            }
        }
        for tgt in nd.target {
            owner_id = self._target_owner_sym(tgt);
            if owner_id is None {
                continue;
            }
            active = self.in_live_borrows.get(id(cfg), set()).intersection(
                self.in_reaching_borrows.get(id(cfg), set())
            );
            for borrow_id in active {
                if (
                    self.borrow_owner.get(borrow_id) == owner_id
                    and not self.borrow_is_mut.get(borrow_id, False)
                ) {
                    self.emit(
                        E1303,
                        node_override=tgt,
                        name=self.owned_names.get(owner_id, "")
                    );
                    break;
                }
            }
        }
    }
}

impl OwnershipCheckPass._emit_leak_diagnostics -> None {
    for owner_id in self.owned_syms {
        if owner_id not in self.consumed_syms and owner_id in self.owned_decl {
            self.emit(
                E1305,
                node_override=self.owned_decl[owner_id],
                name=self.owned_names.get(owner_id, "")
            );
        }
    }
}

impl OwnershipCheckPass._escaping_borrow_owner(nd: uni.Expr | None) -> (str | None) {
    if nd is None {
        return None;
    }
    if isinstance(nd, uni.UnaryExpr) and nd.op.name == Tok.BW_AND {
        operand = nd.operand;
        if isinstance(operand, uni.Name) and operand.sym {
            if nd.is_borrow or id(operand.sym) in self.owned_syms {
                return operand.sym_name;
            }
        }
        return None;
    }
    if isinstance(nd, uni.Name) and nd.sym and id(nd.sym) in self.borrow_syms {
        owner_id = self.borrow_owner.get(id(nd.sym));
        if owner_id is not None {
            return self.owned_names.get(owner_id, nd.sym_name);
        }
        return self.borrow_names.get(id(nd.sym), nd.sym_name);
    }
    return None;
}

impl OwnershipCheckPass._emit_escape_diagnostics(tree: uni.UniNode) -> None {
    for ret in tree.get_all_sub_nodes(uni.ReturnStmt) {
        owner = self._escaping_borrow_owner(ret.expr);
        if owner is not None and not self._return_roots_at_param_borrow(ret.expr) {
            self.emit(E1306, node_override=ret.expr, name=owner);
        }
    }

    for cexpr in tree.get_all_sub_nodes(uni.ConcurrentExpr) {
        names: list[uni.Name] = [];
        if isinstance(cexpr.target, uni.Name) {
            names.append(cexpr.target);
        }
        for nm in cexpr.target.get_all_sub_nodes(uni.Name) {
            names.append(nm);
        }
        for nm in names {
            if nm.sym is None or id(nm.sym) not in self.borrow_syms {
                continue;
            }
            if not self._is_read_name(nm) {
                continue;
            }
            owner = self._escaping_borrow_owner(nm);
            if owner is not None {
                self.emit(E1306, node_override=nm, name=owner);
                break;
            }
        }
    }
    for nd in tree.get_all_sub_nodes(uni.Assignment) {
        if nd.aug_op is not None {
            continue;
        }
        stores_to_managed = False;
        for tgt in nd.target {
            if isinstance(tgt, uni.AtomTrailer) {
                stores_to_managed = True;
            }
        }
        if stores_to_managed {
            owner = self._escaping_borrow_owner(nd.value);
            if owner is not None {
                self.emit(E1306, node_override=nd.value, name=owner);
            }
            continue;
        }

        for tgt in nd.target {
            if not (isinstance(tgt, uni.Name) and tgt.sym) {
                continue;
            }
            tgt_id = id(tgt.sym);
            if tgt_id not in self.borrow_syms or tgt_id in self.e1304_borrow_ids {
                continue;
            }
            source_owner = self._borrow_source_owner(nd);
            if source_owner is None or source_owner.sym is None {
                continue;
            }
            region = self._nearest_scope(source_owner.sym.decl);
            dest = self._nearest_scope(tgt.sym.decl);
            if self._region_strictly_outlives(dest, region) {
                self.emit(
                    E1306,
                    node_override=nd.value,
                    name=self.owned_names.get(id(source_owner.sym), tgt.sym_name)
                );
            }
        }
    }
}
