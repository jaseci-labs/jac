impl RcElisionProofPass.postinit -> None {
    super.postinit();
}

impl RcElisionProofPass.transform(ir_in: uni.Module) -> uni.Module {
    cfg_nodes = [
        n
        for n in ir_in.flatten()
        if isinstance(n, uni.UniCFGNode)
    ];
    all_names = ir_in.get_all_sub_nodes(uni.Name);

    uses_by_sym: dict[SymId, list[uni.Name]] = {};
    for nm in all_names {
        if nm.sym is None {
            continue;
        }
        if self._is_def_name(nm) {
            continue;
        }
        sid = id(nm.sym);
        if sid in uses_by_sym {
            uses_by_sym[sid].append(nm);
        } else {
            uses_by_sym[sid] = [nm];
        }
    }

    candidates: list[tuple[uni.Assignment, SymId]] = [];
    tracked: set[SymId] = set();
    for nd in ir_in.get_all_sub_nodes(uni.Assignment) {
        nd.na_move_lowerable = False;
        src = self._move_candidate_source(nd);
        if src is None {
            continue;
        }
        sid = id(src.sym);
        candidates.append((nd, sid));
        tracked.add(sid);
    }
    if not candidates {
        return ir_in;
    }

    qualified: set[SymId] = set();
    for sid in tracked {
        ok = True;
        for u in uses_by_sym.get(sid, []) {
            if not self._is_alias_value(u) {
                ok = False;
                break;
            }
        }
        if ok {
            qualified.add(sid);
        }
    }

    cfg_built = False;
    for n in cfg_nodes {
        if n.bb_in or n.bb_out {
            cfg_built = True;
            break;
        }
    }
    if not cfg_built and len(cfg_nodes) > 1 {
        return ir_in;
    }

    live_in = self._solve_liveness(cfg_nodes, qualified);
    for (nd, sid) in candidates {
        if sid not in qualified {
            continue;
        }
        live_out: set[SymId] = set();
        for succ in nd.bb_out {
            for x in live_in.get(id(succ), set()) {
                live_out.add(x);
            }
        }
        if sid not in live_out {
            nd.na_move_lowerable = True;
        }
    }
    return ir_in;
}

impl RcElisionProofPass._cfg_owner(sub: uni.UniNode) -> (uni.UniCFGNode | None) {
    if isinstance(sub, uni.UniCFGNode) {
        return sub;
    }
    return sub.find_parent_of_type(uni.UniCFGNode);
}

impl RcElisionProofPass._is_def_name(nm: uni.Name) -> bool {
    p = nm.parent;
    if isinstance(p, uni.Assignment) and p.aug_op is None {
        for tgt in p.target {
            if tgt is nm {
                return True;
            }
        }
    }
    return False;
}

impl RcElisionProofPass._is_alias_value(nm: uni.Name) -> bool {
    p = nm.parent;
    if not isinstance(p, uni.Assignment) {
        return False;
    }
    if p.value is not nm or p.aug_op is not None or len(p.target) != 1 {
        return False;
    }
    tgt = p.target[0];
    if not (isinstance(tgt, uni.Name) and tgt.sym is not None) {
        return False;
    }
    if tgt.sym.storage != SymbolStorage.LOCAL {
        return False;
    }
    if p.type_tag is not None
    and (
        is_borrow_kind(p.type_tag.ownership)
        or p.type_tag.ownership == OwnershipKind.VAL
    ) {
        return False;
    }
    return True;
}

impl RcElisionProofPass._move_candidate_source(
    nd: uni.Assignment
) -> (uni.Name | None) {
    if nd.aug_op is not None or len(nd.target) != 1 {
        return None;
    }
    tgt = nd.target[0];
    if not (isinstance(tgt, uni.Name) and tgt.sym is not None) {
        return None;
    }
    if tgt.sym.storage != SymbolStorage.LOCAL {
        return None;
    }
    if nd.type_tag is not None
    and nd.type_tag.ownership != OwnershipKind.NONE
    and nd.type_tag.ownership != OwnershipKind.OWN {
        return None;
    }
    val = nd.value;
    if not (isinstance(val, uni.Name) and val.sym is not None) {
        return None;
    }
    if val.sym.storage != SymbolStorage.LOCAL {
        return None;
    }
    return val;
}

impl RcElisionProofPass._solve_liveness(
    cfg_nodes: list[uni.UniCFGNode], tracked: set[SymId]
) -> dict[int, set[SymId]] {
    node_use: dict[int, set[SymId]] = {};
    node_def: dict[int, set[SymId]] = {};
    for n in cfg_nodes {
        use: set[SymId] = set();
        dfn: set[SymId] = set();
        for nm in n.get_all_sub_nodes(uni.Name) {
            if self._cfg_owner(nm) is not n or nm.sym is None {
                continue;
            }
            sid = id(nm.sym);
            if sid not in tracked {
                continue;
            }
            if self._is_def_name(nm) {
                dfn.add(sid);
            } else {
                use.add(sid);
            }
        }
        node_use[id(n)] = use;
        node_def[id(n)] = dfn;
    }

    live_in: dict[int, set[SymId]] = {};
    for n in cfg_nodes {
        live_in[id(n)] = set();
    }
    worklist = list(cfg_nodes);
    while worklist {
        n = worklist.pop();
        out: set[SymId] = set();
        for succ in n.bb_out {
            for x in live_in.get(id(succ), set()) {
                out.add(x);
            }
        }
        new_in = set(node_use[id(n)]);
        for x in out {
            if x not in node_def[id(n)] {
                new_in.add(x);
            }
        }
        if new_in != live_in.get(id(n), set()) {
            live_in[id(n)] = new_in;
            for pred in n.bb_in {
                worklist.append(pred);
            }
        }
    }
    return live_in;
}
