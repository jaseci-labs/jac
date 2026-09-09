import from jaclang.compiler.frontend.diagnostics { E1308, E1313 }

impl OwnershipCheckPass._flow_for_stmts -> list[InForStmt] {
    import from jaclang.compiler.frontend.constant { Tokens as Tok }
    out: list[InForStmt] = [];
    for lp in self.ir_in.get_all_sub_nodes(InForStmt) {
        for k in lp.kid {
            if isinstance(k, Token) and k.name == Tok.KW_FLOW {
                out.append(lp);
                break;
            }
        }
    }
    return out;
}

impl OwnershipCheckPass._flow_reduce_shape(asgn: Assignment, sid: SymId) -> str {
    import from jaclang.compiler.frontend.constant { Tokens as Tok }
    if len(asgn.target) != 1 or not isinstance(asgn.target[0], Name) {
        return "";
    }
    if self._sym_id(asgn.target[0]) != sid {
        return "";
    }
    if asgn.aug_op is not None {
        if asgn.aug_op.name != Tok.ADD_EQ {
            return "";
        }
        _val = asgn.value;
        if _val is None {
            return "";
        }
        _rhs_names = ([_val] if isinstance(_val, Name) else [])
            + list(_val.get_all_sub_nodes(Name));
        for rn in _rhs_names {
            if self._sym_id(rn) == sid {
                return "";
            }
        }
        return "add";
    }
    if not isinstance(asgn.value, FuncCall) {
        return "";
    }
    fc = asgn.value;
    if not isinstance(fc.target, Name) or fc.target.sym_name not in ("min", "max") {
        return "";
    }
    _fcsym = fc.target.sym;
    if _fcsym is not None and _fcsym.decl is not None {
        _fmod = _fcsym.decl.find_parent_of_type(Module);
        if _fmod is None or _fmod.name != "builtins" {
            return "";
        }
    }
    _params = fc.params or [];
    if len(_params) != 2 {
        return "";
    }
    _acc_args = 0;
    for p in _params {
        if not isinstance(p, Expr) or isinstance(p, KWPair) {
            return "";
        }
        if isinstance(p, Name) and self._sym_id(p) == sid {
            _acc_args += 1;
        } else {
            _p_names = ([p] if isinstance(p, Name) else [])
                + list(p.get_all_sub_nodes(Name));
            for pn in _p_names {
                if self._sym_id(pn) == sid {
                    return "";
                }
            }
        }
    }
    if _acc_args != 1 {
        return "";
    }
    return fc.target.sym_name;
}

impl OwnershipCheckPass._collect_flow_reductions(lp: InForStmt) -> dict[SymId, str] {
    _asgns: list[Assignment] = [];
    for st in (lp.body or []) {
        if isinstance(st, Assignment) {
            _asgns.append(st);
        }
        for a in st.get_all_sub_nodes(Assignment) {
            _asgns.append(a);
        }
    }
    _cands: dict[SymId, str] = {};
    _sites: dict[SymId, list[Assignment]] = {};
    _lp_fn = lp.find_parent_of_type(Ability);
    _lp_mc = lp.find_parent_of_type(ModuleCode);
    for a in _asgns {
        if len(a.target) != 1 or not isinstance(a.target[0], Name) {
            continue;
        }
        tgt = a.target[0];
        sid = self._sym_id(tgt);
        if sid is None or tgt.sym is None or tgt.sym.decl is None {
            continue;
        }
        if self._is_ancestor(lp, tgt.sym.decl) {
            continue;
        }
        if tgt.sym.decl.find_parent_of_type(Ability) is not _lp_fn
            or tgt.sym.decl.find_parent_of_type(ModuleCode) is not _lp_mc {
            continue;
        }
        _t = "";
        try {
            _t = tgt.type.mangle() if tgt.type is not None else "";
        } except Exception {
            _t = "";
        }
        if _t != "int" {
            continue;
        }
        if sid in _cands and _cands[sid] == "" {
            continue;
        }
        shape = self._flow_reduce_shape(a, sid);
        if shape == "" {
            _cands[sid] = "";
            continue;
        }
        if sid in _cands and _cands[sid] != shape {
            _cands[sid] = "";
            continue;
        }
        _cands[sid] = shape;
        if sid not in _sites {
            _sites[sid] = [];
        }
        _sites[sid].append(a);
    }
    out: dict[SymId, str] = {};
    for (sid, op) in _cands.items() {
        if op == "" {
            continue;
        }
        _all_inside = True;
        for st in (lp.body or []) {
            _nms = ([st] if isinstance(st, Name) else [])
                + list(st.get_all_sub_nodes(Name));
            for nm in _nms {
                if self._sym_id(nm) != sid {
                    continue;
                }
                _inside = False;
                for a in _sites[sid] {
                    if nm is a or self._is_ancestor(a, nm) {
                        _inside = True;
                        break;
                    }
                }
                if not _inside {
                    _all_inside = False;
                    break;
                }
            }
            if not _all_inside {
                break;
            }
        }
        if _all_inside {
            out[sid] = op;
        }
    }
    for (sid, op) in out.items() {
        for a in _sites[sid] {
            a.na_flow_reduce = op;
        }
    }
    return out;
}

impl OwnershipCheckPass._emit_flow_for_diagnostics -> None {
    import from jaclang.compiler.frontend.constant { Tokens as Tok }
    _flows = self._flow_for_stmts();
    if not _flows {
        return;
    }
    _flow_ids = {id(f) for f in _flows};
    for lp in _flows {
        _coll = lp.collection;
        if not (isinstance(_coll, UnaryExpr) and is_borrow_kind(_coll.ownership)) {
            self.emit(
                E1313,
                node_override=_coll,
                name="a non-lent collection (iterate `&xs` or `&mut xs`)"
            );
        }
        _coll_sids: set[int] = set();
        for cn in _coll.get_all_sub_nodes(Name) {
            _cs = self._sym_id(cn);
            if _cs is not None {
                _coll_sids.add(_cs);
            }
        }
        if isinstance(_coll, Name) {
            _cs0 = self._sym_id(_coll);
            if _cs0 is not None {
                _coll_sids.add(_cs0);
            }
        }
        for inner in lp.get_all_sub_nodes(InForStmt) {
            if id(inner) in _flow_ids {
                self.emit(E1313, node_override=inner, name="a nested `flow for`");
            }
        }
        _licensed = self._collect_flow_reductions(lp);
        _flagged: set[int] = set();
        for st in (lp.body or []) {
            _subs: list[UniNode] = (
                [st]
                + list(st.get_all_sub_nodes(ReturnStmt))
                + list(st.get_all_sub_nodes(DisengageStmt))
                + list(st.get_all_sub_nodes(YieldExpr))
                + list(st.get_all_sub_nodes(CtrlStmt))
            );
            for sub in _subs {
                if isinstance(sub, ReturnStmt) {
                    self.emit(
                        E1313, node_override=sub, name="a `return` in the loop body"
                    );
                } elif isinstance(sub, DisengageStmt) {
                    self.emit(
                        E1313, node_override=sub, name="`disengage` in the loop body"
                    );
                } elif isinstance(sub, YieldExpr) {
                    self.emit(
                        E1313, node_override=sub, name="a `yield` in the loop body"
                    );
                } elif isinstance(sub, CtrlStmt)
                    and sub.ctrl is not None
                    and sub.ctrl.name == Tok.KW_BREAK {
                    _enc: (UniNode | None) = sub.parent;
                    while _enc is not None
                        and not isinstance(_enc, (WhileStmt, InForStmt, IterForStmt)) {
                        _enc = _enc.parent;
                    }
                    if _enc is lp {
                        self.emit(
                            E1313,
                            node_override=sub,
                            name="a `break` out of the loop body"
                        );
                    }
                }
            }
            for nm in st.get_all_sub_nodes(Name) {
                sym = nm.sym;
                if sym is None or sym.decl is None {
                    continue;
                }
                if sym.in_stub_scope() {
                    continue;
                }
                if self._is_ancestor(lp, sym.decl) {
                    continue;
                }
                if isinstance(nm.parent, FuncCall) and nm.parent.target is nm {
                    continue;
                }
                _ab = sym.decl.find_parent_of_type(Ability);
                if _ab is not None and _ab.name_ref is sym.decl {
                    continue;
                }
                sid = self._sym_id(nm);
                if sid is None or sid in _flagged or sid in _coll_sids {
                    continue;
                }
                if sid in _licensed {
                    continue;
                }
                _is_write = False;
                _wp = nm.parent;
                if isinstance(_wp, Assignment) {
                    _wt = _wp.target
                        if isinstance(_wp.target, (list, tuple))
                        else [(_wp.target)];
                    for t in _wt {
                        if t is nm {
                            _is_write = True;
                        }
                    }
                }
                if not _is_write {
                    if self._is_deep_immutable_scalar(nm) {
                        continue;
                    }
                    if sym.ownership == OwnershipKind.IMM {
                        continue;
                    }
                }
                _flagged.add(sid);
                self.emit(E1308, node_override=nm, name=nm.sym_name);
            }
        }
    }
}

impl OwnershipCheckPass._emit_sendability_diagnostics -> None {
    tracked = set(self.owned_decl);
    tracked.update(self.borrow_meta);
    tracked.update(self.imm_decl);
    for nd in self.idx_assignments {
        for tgt in nd.target {
            if isinstance(tgt, Name) and tgt.sym {
                tracked.add(id(tgt.sym));
            }
        }
    }
    for param in self.idx_params {
        if isinstance(param.name, Name) and param.name.sym {
            tracked.add(id(param.name.sym));
        }
    }

    import from jaclang.compiler.frontend.constant { Tokens as Tok }
    for cexpr in self.idx_concurrent {
        if cexpr.tok is not None and cexpr.tok.name == Tok.KW_WAIT {
            continue;
        }
        names: list[Name] = [];
        if isinstance(cexpr.target, Name) {
            names.append(cexpr.target);
        }
        for nm in cexpr.target.get_all_sub_nodes(Name) {
            names.append(nm);
        }
        for nm in names {
            if not self._is_read_name(nm) {
                continue;
            }
            sid = self._sym_id(nm);
            if sid is None or sid not in tracked or nm.sym is None {
                continue;
            }
            if self._is_deep_immutable_scalar(nm) {
                continue;
            }
            ownership = nm.sym.ownership;
            if ownership == OwnershipKind.IMM {
                continue;
            }
            if ownership == OwnershipKind.OWN and self._is_move_producing_use(nm) {
                continue;
            }
            if ownership == OwnershipKind.OWN
                and isinstance(nm.parent, UnaryExpr)
                and is_borrow_kind(nm.parent.ownership)
                and self._flow_lend_joined(cexpr, sid) {
                continue;
            }
            if nm.find_parent_of_type(OpenStmt) is not None {
                continue;
            }
            if self._borrow_sym_of(nm) is not None {
                owner = self._escaping_borrow_owner(nm);
                if owner is not None {
                    borrow_id = self._borrow_sym_of(nm);
                    related = self._owner_decl_related(borrow_id, owner);
                    self.emit(E1308, node_override=nm, name=owner, related=related);
                } else {
                    self.emit(E1308, node_override=nm, name=nm.sym_name);
                }
            } else {
                self.emit(E1308, node_override=nm, name=nm.sym_name);
            }
            break;
        }
    }
}

impl OwnershipCheckPass._flow_lend_joined(
    cexpr: ConcurrentExpr, owner_sid: SymId
) -> bool {
    import from jaclang.compiler.frontend.constant { Tokens as Tok }
    asgn = cexpr.find_parent_of_type(Assignment);
    if asgn is None
        or asgn.value is not cexpr
        or len(asgn.target) != 1
        or not isinstance(asgn.target[0], Name)
        or asgn.target[0].sym is None {
        return False;
    }
    handle_sid = self._name_sym_id(asgn.target[0]);
    container = asgn.parent;
    _cbody = container?.body;
    if not isinstance(_cbody, (list, tuple)) or asgn not in _cbody {
        return False;
    }
    body: list[UniNode] = [s for s in _cbody];
    idx = body.index(asgn);
    for st in body[idx + 1:] {
        _wait_found = False;
        _wait_nodes: list[ConcurrentExpr] = [];
        for wc in st.get_all_sub_nodes(ConcurrentExpr) {
            if wc.tok is not None and wc.tok.name == Tok.KW_WAIT {
                for wn in ([wc.target] if isinstance(wc.target, Name) else [])
                    + list(wc.target.get_all_sub_nodes(Name)) {
                    if self._sym_id(wn) == handle_sid {
                        _wait_found = True;
                        _wait_nodes.append(wc);
                    }
                }
            }
        }
        _owner_touched = False;
        for on in st.get_all_sub_nodes(Name) {
            if self._sym_id(on) == owner_sid {
                _owner_touched = True;
            }
        }
        _exits: list[UniNode] = (
            ([st] if isinstance(st, (ReturnStmt, RaiseStmt, CtrlStmt)) else [])
            + list(st.get_all_sub_nodes(ReturnStmt))
            + list(st.get_all_sub_nodes(RaiseStmt))
            + list(st.get_all_sub_nodes(CtrlStmt))
            + list(st.get_all_sub_nodes(YieldExpr))
        );
        _side_exit = False;
        for ex in _exits {
            _joins_first = False;
            for w in _wait_nodes {
                if ex is w or self._is_ancestor(ex, w) {
                    _joins_first = True;
                }
            }
            if not _joins_first {
                _side_exit = True;
            }
        }
        if _wait_found and not _side_exit {
            return not _owner_touched;
        }
        if _side_exit or _owner_touched {
            return False;
        }
    }
    return False;
}

impl OwnershipCheckPass._is_deep_immutable_scalar(nm: Name) -> bool {
    t = nm.type;
    if t is None {
        return False;
    }
    _mangled = "";
    try {
        _mangled = t.mangle();
    } except Exception {
        return False;
    }
    return _mangled in ("int", "float", "bool", "str", "bytes");
}

impl OwnershipCheckPass._chunks_shape_of(expr: Expr | None) -> (tuple | None) {
    if not isinstance(expr, FuncCall) {
        return None;
    }
    _fcx: FuncCall = expr;
    _t = _fcx.target;
    if not (
        isinstance(_t, AtomTrailer)
        and _t.is_attr
        and isinstance(_t.right, Name)
        and _t.right.sym_name == "chunks"
    ) {
        return None;
    }
    _m = "";
    try {
        _m = _t.target.type.mangle() if _t.target.type is not None else "";
    } except Exception {
        return None;
    }
    if _m != "list" and not _m.startswith("list[") {
        return None;
    }
    _params = [(p.value if isinstance(p, KWPair) else p) for p in (_fcx.params or [])];
    if len(_params) != 1 {
        return None;
    }
    return (_t.target, _params[0]);
}

impl OwnershipCheckPass._emit_chunk_view_diagnostics -> None {
    _licensed: set[int] = set();
    _chunk_vars: dict[SymId, InForStmt] = {};
    for st in self.ir_in.get_all_sub_nodes(InForStmt) {
        coll = st.collection;
        if isinstance(coll, UnaryExpr)
            and is_borrow_kind(coll.ownership)
            and self._chunks_shape_of(coll.operand) is not None {
            _licensed.add(id(coll.operand));
            tgt = st.target;
            if isinstance(tgt, Name) and tgt.sym is not None {
                _chunk_vars[self._name_sym_id(tgt)] = st;
            }
        }
    }
    for fc in self.ir_in.get_all_sub_nodes(FuncCall) {
        if self._chunks_shape_of(fc) is not None and id(fc) not in _licensed {
            self.emit(
                E1313,
                node_override=fc,
                name="`chunks()` outside a lent `for` collection"
            );
        }
    }
    for (sid, st) in _chunk_vars.items() {
        for use in self.name_uses_by_sym.get(sid, []) {
            _p = use.parent;
            if isinstance(_p, AtomTrailer)
                and _p.target is use
                and _p.is_attr
                and isinstance(_p.right, Name)
                and _p.right.sym_name
                    in (
                        "append",
                        "insert",
                        "extend",
                        "pop",
                        "remove",
                        "clear",
                        "sort",
                        "reverse"
                    ) {
                self.emit(
                    E1313,
                    node_override=_p,
                    name=f"structural mutation of a chunk view"
                    f" ({_p.right.sym_name}())"
                );
            }
        }
    }
}
