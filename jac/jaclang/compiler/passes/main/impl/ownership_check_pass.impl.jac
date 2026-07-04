import from collections.abc { Sequence }
import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.diagnostics { E1301, E1302, E1303, E1304, E1306 }

impl OwnershipCheckPass.before_pass -> None {
    self.owned_syms = set();
    self.owned_decl = {};
    self.consumed_syms = set();
    self.proven_unique_syms = set();
    self.borrow_syms = set();
    self.param_borrow_syms = set();
    self.borrow_meta = {};
    self.e1304_borrow_ids = set();
    self.in_consumed = {};
    self.in_live_borrows = {};
    self.in_reaching_borrows = {};
    self.consumed_at = {};
    self.borrow_created_at = {};
    self.loop_depth_flagged_names = set();
    self.idx_assignments = [];
    self.idx_names = [];
    self.idx_params = [];
    self.idx_returns = [];
    self.idx_concurrent = [];
    self.name_uses_by_sym = {};

    mod_root = self.ir_in;
    if mod_root is None {
        return;
    }
    self._build_index(mod_root);
    self._collect_owned();
    self._collect_borrows();
    self._collect_params();
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
    self._emit_loop_move_diagnostics();
    self._emit_diagnostics();
    self._emit_borrow_diagnostics();
    self._emit_escape_diagnostics();
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
    if isinstance(target, uni.Name) and self._borrow_sym_of(target) is not None {
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
        if isinstance(tgt, uni.Name) and self._borrow_sym_of(tgt) is not None {
            is_borrow_val = True;
        }
    }
    if not is_borrow_val {
        return None;
    }
    operand = nd.value.operand;
    if self._owned_sym_of(operand) is not None and isinstance(operand, uni.Name) {
        return operand;
    }
    return None;
}

impl OwnershipCheckPass._build_index(tree: uni.UniNode) -> None {
    self.idx_assignments = tree.get_all_sub_nodes(uni.Assignment);
    self.idx_names = tree.get_all_sub_nodes(uni.Name);
    self.idx_params = tree.get_all_sub_nodes(uni.ParamVar);
    self.idx_returns = tree.get_all_sub_nodes(uni.ReturnStmt);
    self.idx_concurrent = tree.get_all_sub_nodes(uni.ConcurrentExpr);
    for name in self.idx_names {
        sid = self._sym_id(name);
        if sid is None {
            continue;
        }
        if sid in self.name_uses_by_sym {
            self.name_uses_by_sym[sid].append(name);
        } else {
            self.name_uses_by_sym[sid] = [name];
        }
    }
}

impl OwnershipCheckPass._collect_owned -> None {
    for nd in self.idx_assignments {
        target = self._is_own_decl(nd);
        if target is not None {
            sid = self._name_sym_id(target);
            self.owned_syms.add(sid);
            self.owned_decl[sid] = target;
        }
    }
}

impl OwnershipCheckPass._collect_borrows -> None {
    for nd in self.idx_assignments {
        target = self._is_borrow_decl(nd);
        if target is not None {
            borrow_id = self._name_sym_id(target);
            self.borrow_syms.add(borrow_id);
            self.borrow_meta[borrow_id] = BorrowMeta(
                name=target.sym_name,
                is_mut=nd.type_tag.is_mut_borrow if nd.type_tag else False
            );
            self.borrow_created_at[borrow_id] = nd;
        }
    }
    for nd in self.idx_assignments {
        target = self._borrow_target(nd);
        owner = self._borrow_source_owner(nd);
        if target is not None and owner is not None {
            borrow_id = self._name_sym_id(target);
            owner_id = self._name_sym_id(owner);
            self.borrow_syms.add(borrow_id);
            self.borrow_meta[borrow_id] = BorrowMeta(
                name=target.sym_name,
                owner=owner_id,
                is_mut=nd.value.is_mut_borrow
                    if isinstance(nd.value, uni.UnaryExpr)
                    else False
            );
            self.borrow_created_at[borrow_id] = nd;
        }
    }
}

impl OwnershipCheckPass._collect_params -> None {
    for param in self.idx_params {
        tag = param.type_tag;
        if tag is None {
            continue;
        }
        name = param.name;
        if not (isinstance(name, uni.Name) and name.sym) {
            continue;
        }
        sid = self._name_sym_id(name);
        if tag.is_borrow or tag.is_mut_borrow {
            self.borrow_syms.add(sid);
            self.param_borrow_syms.add(sid);
            self.borrow_meta[sid] = BorrowMeta(
                name=name.sym_name, is_mut=tag.is_mut_borrow
            );
            self.borrow_created_at[sid] = param;
        } elif tag.is_own {
            self.owned_syms.add(sid);
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
    if isinstance(cur, uni.Name) and self._sym_id(cur) in self.param_borrow_syms {
        return True;
    }
    return False;
}

impl OwnershipCheckPass._borrow_region(sym_id: SymId) -> (uni.UniScopeNode | None) {
    owner_id = self._borrow_owner_of(sym_id);
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
    borrowed_owners: set[SymId] = set();
    for meta in self.borrow_meta.values() {
        if meta.owner is not None {
            borrowed_owners.add(meta.owner);
        }
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
) -> tuple[set[SymId], set[SymId]] {
    kill: set[SymId] = set();
    gen: set[SymId] = set();
    if nd.aug_op is not None {
        return (kill, gen);
    }
    decl_target = self._is_own_decl(nd);
    if decl_target is not None {
        kill.add(self._name_sym_id(decl_target));
    } else {
        for tgt in nd.target {
            owned = self._owned_sym_of(tgt);
            if owned is not None {
                kill.add(owned);
            }
        }
    }
    val_owned = self._owned_sym_of(nd.value);
    if val_owned is not None {
        gen.add(val_owned);
    }
    return (kill, gen);
}

impl OwnershipCheckPass._call_params(
    call: uni.FuncCall
) -> Sequence[uni.Expr | uni.KWPair] {
    return call.params or [];
}

impl OwnershipCheckPass._cfg_owner(sub: uni.UniNode) -> (uni.UniCFGNode | None) {
    if isinstance(sub, uni.UniCFGNode) {
        return sub;
    }
    return self._nearest_cfg(sub);
}

impl OwnershipCheckPass._call_move_gen(nd: uni.UniCFGNode) -> set[SymId] {
    gen: set[SymId] = set();
    for call in nd.get_all_sub_nodes(uni.FuncCall) {
        if self._cfg_owner(call) is not nd {
            continue;
        }
        for param in self._call_params(call) {
            arg: uni.Expr | None = None;
            if isinstance(param, uni.KWPair) {
                arg = param.value;
            } elif isinstance(param, uni.Expr) {
                arg = param;
            }
            owned = self._owned_sym_of(arg);
            if owned is not None {
                gen.add(owned);
            }
        }
    }
    return gen;
}

impl OwnershipCheckPass._return_move_gen(nd: uni.UniCFGNode) -> set[SymId] {
    gen: set[SymId] = set();
    returns: list[uni.ReturnStmt] = [];
    if isinstance(nd, uni.ReturnStmt) {
        returns.append(nd);
    }
    for ret in nd.get_all_sub_nodes(uni.ReturnStmt) {
        returns.append(ret);
    }
    for ret in returns {
        if self._cfg_owner(ret) is not nd {
            continue;
        }
        owned = self._owned_sym_of(ret.expr);
        if owned is not None {
            gen.add(owned);
        }
    }
    return gen;
}

impl OwnershipCheckPass._transfer(
    nd: uni.UniCFGNode, in_set: set[SymId]
) -> set[SymId] {
    out = set(in_set);
    if isinstance(nd, uni.Assignment) {
        (kill, gen) = self._assign_kill_gen(nd);
        for k in kill {
            out.discard(k);
        }
        for g in gen {
            out.add(g);
            if g not in self.consumed_at {
                self.consumed_at[g] = nd.value if nd.value is not None else nd;
            }
        }
    }
    for g in self._call_move_gen(nd) {
        out.add(g);
        if g not in self.consumed_at {
            self.consumed_at[g] = nd;
        }
    }
    for g in self._return_move_gen(nd) {
        out.add(g);
        if g not in self.consumed_at {
            self.consumed_at[g] = nd;
        }
    }
    return out;
}

impl OwnershipCheckPass._solve_forward_dataflow(
    cfg_nodes: list[uni.UniCFGNode], transfer: DataflowTransfer
) -> dict[int, set[SymId]] {
    state: dict[int, set[SymId]] = {};
    for n in cfg_nodes {
        state[id(n)] = set();
    }
    worklist = list(cfg_nodes);
    while worklist {
        n = worklist.pop();
        new_state: set[SymId] = set();
        for pred in n.bb_in {
            for x in transfer(pred, state.get(id(pred), set())) {
                new_state.add(x);
            }
        }
        if new_state != state.get(id(n), set()) {
            state[id(n)] = new_state;
            for nb in n.bb_out {
                worklist.append(nb);
            }
        }
    }
    return state;
}

impl OwnershipCheckPass._solve_backward_dataflow(
    cfg_nodes: list[uni.UniCFGNode], transfer: DataflowTransfer
) -> dict[int, set[SymId]] {
    state: dict[int, set[SymId]] = {};
    for n in cfg_nodes {
        state[id(n)] = set();
    }
    worklist = list(cfg_nodes);
    while worklist {
        n = worklist.pop();
        joined: set[SymId] = set();
        for succ in n.bb_out {
            for x in state.get(id(succ), set()) {
                joined.add(x);
            }
        }
        new_state = transfer(n, joined);
        if new_state != state.get(id(n), set()) {
            state[id(n)] = new_state;
            for nb in n.bb_in {
                worklist.append(nb);
            }
        }
    }
    return state;
}

impl OwnershipCheckPass._run_dataflow(cfg_nodes: list[uni.UniCFGNode]) -> None {
    self.in_consumed = self._solve_forward_dataflow(cfg_nodes, self._transfer);
    self.consumed_syms = set();
    for n in cfg_nodes {
        out = self._transfer(n, self.in_consumed.get(id(n), set()));
        for consumed in out {
            self.consumed_syms.add(consumed);
        }
    }
}

impl OwnershipCheckPass._borrow_read_gen(nd: uni.UniCFGNode) -> set[SymId] {
    gen: set[SymId] = set();
    for name in nd.get_all_sub_nodes(uni.Name) {
        borrow = self._borrow_sym_of(name);
        if borrow is not None and self._is_read_name(name) {
            gen.add(borrow);
        }
    }
    return gen;
}

impl OwnershipCheckPass._borrow_assign_kill_gen(
    nd: uni.UniCFGNode
) -> tuple[set[SymId], set[SymId]] {
    kill: set[SymId] = set();
    gen: set[SymId] = set();
    if isinstance(nd, uni.Assignment) {
        target = self._borrow_target(nd);
        if target is not None {
            borrow_id = self._name_sym_id(target);
            kill.add(borrow_id);
            if self._borrow_source_owner(nd) is not None {
                gen.add(borrow_id);
            }
        }
    }
    return (kill, gen);
}

impl OwnershipCheckPass._live_transfer(
    nd: uni.UniCFGNode, out_set: set[SymId]
) -> set[SymId] {
    (kill, _) = self._borrow_assign_kill_gen(nd);
    new_in = set(out_set);
    for k in kill {
        new_in.discard(k);
    }
    for g in self._borrow_read_gen(nd) {
        new_in.add(g);
    }
    return new_in;
}

impl OwnershipCheckPass._run_borrow_liveness(cfg_nodes: list[uni.UniCFGNode]) -> None {
    self.in_live_borrows = self._solve_backward_dataflow(
        cfg_nodes, self._live_transfer
    );
}

impl OwnershipCheckPass._reaching_transfer(
    nd: uni.UniCFGNode, in_set: set[SymId]
) -> set[SymId] {
    out = set(in_set);
    (kill, gen) = self._borrow_assign_kill_gen(nd);
    for k in kill {
        out.discard(k);
    }
    for g in gen {
        out.add(g);
    }
    return out;
}

impl OwnershipCheckPass._run_reaching_borrows(cfg_nodes: list[uni.UniCFGNode]) -> None {
    self.in_reaching_borrows = self._solve_forward_dataflow(
        cfg_nodes, self._reaching_transfer
    );
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

impl OwnershipCheckPass._classify_access(nd: uni.Name) -> AccessKind {
    parent = nd.parent;
    if isinstance(parent, uni.Assignment) {
        for tgt in parent.target {
            if tgt is nd {
                return AccessKind.ASSIGN_TARGET;
            }
            if not self._is_ancestor(tgt, nd) {
                continue;
            }
            held = nd.parent;
            if isinstance(held, uni.AtomTrailer) {
                if held.right is nd {
                    return (
                        AccessKind.ATTR_TARGET
                            if held.is_attr
                            else AccessKind.SUBSCRIPT_TARGET
                    );
                }
                return AccessKind.READ;
            }
            return AccessKind.DESTRUCTURE_TARGET;
        }
        return AccessKind.READ;
    }
    if isinstance(parent, uni.DeleteStmt) {
        return AccessKind.DELETE_TARGET;
    }
    if isinstance(parent, uni.ReturnStmt) {
        return AccessKind.RETURN_VALUE;
    }
    if isinstance(parent, uni.KWPair) or isinstance(parent, uni.FuncCall) {
        return AccessKind.CALL_ARG;
    }
    return AccessKind.READ;
}

impl OwnershipCheckPass._is_write_target(nd: uni.Name) -> bool {
    kind = self._classify_access(nd);
    return kind == AccessKind.ASSIGN_TARGET or kind == AccessKind.DESTRUCTURE_TARGET;
}

impl OwnershipCheckPass._is_read_name(nd: uni.Name) -> bool {
    return not self._is_write_target(nd);
}

impl OwnershipCheckPass._is_move_producing_use(nd: uni.Name) -> bool {
    kind = self._classify_access(nd);
    if kind == AccessKind.CALL_ARG or kind == AccessKind.RETURN_VALUE {
        return True;
    }
    parent = nd.parent;
    if isinstance(parent, uni.Assignment)
    and parent.aug_op is None
    and parent.value is nd {
        return True;
    }
    return False;
}

impl OwnershipCheckPass._sym_id(nd: uni.UniNode | None) -> (SymId | None) {
    if isinstance(nd, uni.Name) and nd.sym {
        return id(nd.sym);
    }
    return None;
}

impl OwnershipCheckPass._name_sym_id(nd: uni.Name) -> SymId {
    return id(nd.sym);
}

impl OwnershipCheckPass._owned_sym_of(nd: uni.UniNode | None) -> (SymId | None) {
    sid = self._sym_id(nd);
    if sid is not None and sid in self.owned_syms {
        return sid;
    }
    return None;
}

impl OwnershipCheckPass._borrow_sym_of(nd: uni.UniNode | None) -> (SymId | None) {
    sid = self._sym_id(nd);
    if sid is not None and sid in self.borrow_syms {
        return sid;
    }
    return None;
}

impl OwnershipCheckPass._owned_name(sym_id: SymId, fallback: str) -> str {
    decl = self.owned_decl.get(sym_id);
    if decl is not None {
        return decl.sym_name;
    }
    return fallback;
}

impl OwnershipCheckPass._borrow_owner_of(borrow_id: SymId) -> (SymId | None) {
    meta = self.borrow_meta.get(borrow_id);
    if meta is not None {
        return meta.owner;
    }
    return None;
}

impl OwnershipCheckPass._borrow_is_mut_of(borrow_id: SymId) -> bool {
    meta = self.borrow_meta.get(borrow_id);
    if meta is not None {
        return meta.is_mut;
    }
    return False;
}

impl OwnershipCheckPass._borrow_display_name(borrow_id: SymId, fallback: str) -> str {
    meta = self.borrow_meta.get(borrow_id);
    if meta is not None {
        return meta.name;
    }
    return fallback;
}

impl OwnershipCheckPass._target_owner_sym(nd: uni.Expr) -> (SymId | None) {
    direct = self._owned_sym_of(nd);
    if direct is not None {
        return direct;
    }
    if isinstance(nd, uni.AtomTrailer) and nd.is_attr {
        return self._owned_sym_of(nd.target);
    }
    return None;
}

impl OwnershipCheckPass._loop_depth(nd: uni.UniNode) -> int {
    depth = 0;
    cur = nd.parent;
    while cur is not None {
        if isinstance(cur, (uni.WhileStmt, uni.InForStmt, uni.IterForStmt)) {
            depth += 1;
        }
        cur = cur.parent;
    }
    return depth;
}

impl OwnershipCheckPass._emit_loop_move_diagnostics -> None {
    for nd in self.idx_names {
        owned = self._owned_sym_of(nd);
        if owned is None {
            continue;
        }
        if not self._is_read_name(nd) {
            continue;
        }

        if not self._is_move_producing_use(nd) {
            continue;
        }
        decl = self.owned_decl.get(owned);
        if decl is None {
            continue;
        }
        cfg_nd = self._nearest_cfg(nd);
        if cfg_nd is not None and owned in self.in_consumed.get(id(cfg_nd), set()) {
            continue;
        }
        if self._loop_depth(nd) > self._loop_depth(decl) {
            sym_name = self._owned_name(owned, nd.sym_name);
            self.emit(
                E1301,
                node_override=nd,
                name=sym_name,
                related=[(f"'{sym_name}' declared here, outside the loop", decl)]
            );
            self.loop_depth_flagged_names.add(id(nd));
        }
    }
}

impl OwnershipCheckPass._emit_diagnostics -> None {
    for nd in self.idx_names {
        if self._owned_sym_of(nd) is None {
            continue;
        }
        if self._is_write_target(nd) {
            continue;
        }
        if id(nd) in self.loop_depth_flagged_names {
            continue;
        }
        owner = self._nearest_cfg(nd);
        if owner is None {
            continue;
        }
        consumed = self.in_consumed.get(id(owner), set());
        sid = self._name_sym_id(nd);
        if sid in consumed {
            sym_name = self._owned_name(sid, nd.sym_name);
            move_site = self.consumed_at.get(sid);
            move_related = [(f"'{sym_name}' was moved here", move_site)]
                if move_site is not None
                else None;
            self.emit(E1301, node_override=nd, name=sym_name, related=move_related);
        }
    }
}

impl OwnershipCheckPass._emit_borrow_diagnostics -> None {
    emitted_e1304: set[SymId] = set();
    for nd in self.idx_assignments {
        owner = self._borrow_source_owner(nd);
        target = self._borrow_target(nd);

        cfg = nd;
        if owner is not None and target is not None {
            borrow_id = self._name_sym_id(target);
            owner_id = self._name_sym_id(owner);
            active = self.in_live_borrows.get(id(cfg), set()).intersection(
                self.in_reaching_borrows.get(id(cfg), set())
            );
            for other in active {
                if self._borrow_owner_of(other) != owner_id {
                    continue;
                }
                if nd.value
                and isinstance(nd.value, uni.UnaryExpr)
                and (nd.value.is_mut_borrow or self._borrow_is_mut_of(other)) {
                    other_site = self.borrow_created_at.get(other);
                    other_name = self._borrow_display_name(other, "");
                    e1302_related = [
                        (f"existing borrow of '{other_name}' created here", other_site)
                    ]
                        if other_site is not None
                        else None;
                    self.emit(
                        E1302,
                        node_override=owner,
                        name=self._owned_name(owner_id, owner.sym_name),
                        related=e1302_related
                    );
                    break;
                }
            }
            owner_scope = self._nearest_scope(self.owned_decl.get(owner_id, owner));
            if owner_scope is not None and borrow_id not in emitted_e1304 {
                borrow_site = self.borrow_created_at.get(borrow_id);
                borrow_name = self._borrow_display_name(borrow_id, "");
                for use in self.name_uses_by_sym.get(borrow_id, []) {
                    if self._is_read_name(use)
                    and not self._is_ancestor(owner_scope, use) {
                        e1304_related = [
                            (f"borrow of '{borrow_name}' created here", borrow_site)
                        ]
                            if borrow_site is not None
                            else None;
                        self.emit(
                            E1304,
                            node_override=owner,
                            name=self._owned_name(owner_id, owner.sym_name),
                            related=e1304_related
                        );
                        emitted_e1304.add(borrow_id);
                        self.e1304_borrow_ids.add(borrow_id);
                        break;
                    }
                }
            }
        }
        for tgt in nd.target {
            tgt_owner_id = self._target_owner_sym(tgt);
            if tgt_owner_id is None {
                continue;
            }
            active = self.in_live_borrows.get(id(cfg), set()).intersection(
                self.in_reaching_borrows.get(id(cfg), set())
            );
            for borrow_id in active {
                if (
                    self._borrow_owner_of(borrow_id) == tgt_owner_id
                    and not self._borrow_is_mut_of(borrow_id)
                ) {
                    borrow_site = self.borrow_created_at.get(borrow_id);
                    borrow_name = self._borrow_display_name(borrow_id, "");
                    e1303_related = [
                        (f"shared borrow of '{borrow_name}' created here", borrow_site)
                    ]
                        if borrow_site is not None
                        else None;
                    self.emit(
                        E1303,
                        node_override=tgt,
                        name=self._owned_name(tgt_owner_id, ""),
                        related=e1303_related
                    );
                    break;
                }
            }
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
            if nd.is_borrow or self._sym_id(operand) in self.owned_syms {
                return operand.sym_name;
            }
        }
        return None;
    }
    borrow_id = self._borrow_sym_of(nd);
    if borrow_id is not None and isinstance(nd, uni.Name) {
        owner_id = self._borrow_owner_of(borrow_id);
        if owner_id is not None {
            return self._owned_name(owner_id, nd.sym_name);
        }
        return self._borrow_display_name(borrow_id, nd.sym_name);
    }
    return None;
}

impl OwnershipCheckPass._owner_decl_related(
    borrow_id: (SymId | None), owner_name: str
) -> (list[tuple[str, uni.UniNode]] | None) {
    if borrow_id is not None {
        owner_id = self._borrow_owner_of(borrow_id);
        if owner_id is not None {
            owner_decl = self.owned_decl.get(owner_id);
            if owner_decl is not None {
                return [(f"owner '{owner_name}' declared here", owner_decl)];
            }
        }
    }
    return None;
}

impl OwnershipCheckPass._emit_escape_diagnostics -> None {
    for ret in self.idx_returns {
        owner = self._escaping_borrow_owner(ret.expr);
        if owner is not None and not self._return_roots_at_param_borrow(ret.expr) {
            borrow_id = self._borrow_sym_of(ret.expr);
            e1306_related = self._owner_decl_related(borrow_id, owner);
            self.emit(E1306, node_override=ret.expr, name=owner, related=e1306_related);
        }
    }

    for cexpr in self.idx_concurrent {
        names: list[uni.Name] = [];
        if isinstance(cexpr.target, uni.Name) {
            names.append(cexpr.target);
        }
        for nm in cexpr.target.get_all_sub_nodes(uni.Name) {
            names.append(nm);
        }
        for nm in names {
            if self._borrow_sym_of(nm) is None {
                continue;
            }
            if not self._is_read_name(nm) {
                continue;
            }
            owner = self._escaping_borrow_owner(nm);
            if owner is not None {
                borrow_id = self._borrow_sym_of(nm);
                e1306_related = self._owner_decl_related(borrow_id, owner);
                self.emit(E1306, node_override=nm, name=owner, related=e1306_related);
                break;
            }
        }
    }
    for nd in self.idx_assignments {
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
                borrow_id = self._borrow_sym_of(nd.value);
                e1306_related = self._owner_decl_related(borrow_id, owner);
                self.emit(
                    E1306, node_override=nd.value, name=owner, related=e1306_related
                );
            }
            continue;
        }

        for tgt in nd.target {
            if not (isinstance(tgt, uni.Name) and tgt.sym) {
                continue;
            }
            borrow = self._borrow_sym_of(tgt);
            if borrow is None or borrow in self.e1304_borrow_ids {
                continue;
            }
            source_owner = self._borrow_source_owner(nd);
            if source_owner is None or source_owner.sym is None {
                continue;
            }
            region = self._nearest_scope(source_owner.sym.decl);
            dest = self._nearest_scope(tgt.sym.decl);
            if self._region_strictly_outlives(dest, region) {
                owner_id = self._name_sym_id(source_owner);
                owner_name = self._owned_name(owner_id, tgt.sym_name);
                owner_decl = self.owned_decl.get(owner_id);
                e1306_related = [(f"owner '{owner_name}' declared here", owner_decl)]
                    if owner_decl is not None
                    else None;
                self.emit(
                    E1306,
                    node_override=nd.value,
                    name=owner_name,
                    related=e1306_related
                );
            }
        }
    }
}
