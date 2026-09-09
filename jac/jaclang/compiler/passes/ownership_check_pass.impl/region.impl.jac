import from jaclang.compiler.frontend.diagnostics { E1307, E1314, W1310 }
import from jaclang.compiler.expr_keys { is_builtin_region_type }
import from jaclang.compiler.symbol_utils { CallKind, classify_call }
import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }

impl OwnershipCheckPass._partition_sugar_reason(call: FuncCall) -> str {
    _params = [p for p in (call.params or [])];
    if len(_params) != 1 or not isinstance(_params[0], Int) {
        return "a non-literal child count";
    }
    _n = int(_params[0].value);
    asgn = call.parent;
    if not (isinstance(asgn, Assignment) and asgn.value is call) {
        return "use outside a direct tuple-unpack assignment";
    }
    if len(asgn.target) != 1 {
        return "a non-tuple unpack target";
    }
    _tv = asgn.target[0];
    if not isinstance(_tv, TupleVal) {
        return "a non-tuple unpack target";
    }
    _names: list[Name] = [];
    for v in (_tv.values or []) {
        if not isinstance(v, Name) {
            return "a non-name unpack target";
        }
        _names.append(v);
    }
    if len(_names) != _n {
        return f"an unpack arity of {len(_names)} for n={_n}";
    }
    _recv = call.target.target if isinstance(call.target, AtomTrailer) else None;
    if not isinstance(_recv, Name) {
        return "a receiver that is not an owned `Region` handle";
    }
    _rsid = self._sym_id(_recv);
    if _rsid is None or _rsid not in self.owned_decl {
        return "a receiver that is not an owned `Region` handle";
    }
    return "";
}

impl OwnershipCheckPass._process_partition_sugar -> None {
    for call in self.ir_in.get_all_sub_nodes(FuncCall) {
        _tr = call.target;
        if not (
            isinstance(_tr, AtomTrailer)
            and isinstance(_tr.right, Name)
            and _tr.right.sym_name == "partition"
        ) {
            continue;
        }
        if not (call.params or []) {
            continue;
        }
        _psr_recv = _tr.target;
        if not is_builtin_region_type(_psr_recv.type) {
            continue;
        }
        reason = self._partition_sugar_reason(call);
        if reason != "" {
            self.emit(E1314, node_override=call, name=reason);
            continue;
        }
        _ps_asgn = call.parent;
        if not isinstance(_ps_asgn, Assignment) {
            continue;
        }
        _ps_tv = _ps_asgn.target[0];
        if not isinstance(_ps_tv, TupleVal) {
            continue;
        }
        for nmv in (_ps_tv.values or []) {
            if not isinstance(nmv, Name) {
                continue;
            }
            _sid = self._sym_id(nmv);
            if _sid is None or nmv.sym is None {
                continue;
            }
            nmv.sym.ownership = OwnershipKind.OWN;
            nmv.sym.na_region_handle = True;
            self.owned_decl[_sid] = nmv;
        }
    }
}

glob _REGION_SCALARS: tuple = ("int", "float", "bool", "None", "NoneType");

impl OwnershipCheckPass._has_region_blocks -> bool {
    return bool(self.ir_in.get_all_sub_nodes(OpenStmt));
}

impl OwnershipCheckPass._place_of(nd: Expr | None) -> (Name | None) {
    cur = nd;
    if isinstance(cur, UnaryExpr) and is_borrow_kind(cur.ownership) {
        cur = cur.operand;
    }
    while isinstance(cur, AtomTrailer) {
        cur = cur.target;
    }
    if isinstance(cur, Name) and cur.sym {
        return cur;
    }
    return None;
}

impl OwnershipCheckPass._places_reachable(nd: Expr | None) -> list[Name] {
    out: list[Name] = [];
    if nd is None {
        return out;
    }
    place = self._place_of(nd);
    if place is not None {
        out.append(place);
        return out;
    }
    if isinstance(nd, ListVal) or isinstance(nd, SetVal) {
        for v in (nd.values or []) {
            out.extend(self._places_reachable(v));
        }
    } elif isinstance(nd, TupleVal) {
        for v in nd.values {
            if isinstance(v, Expr) {
                out.extend(self._places_reachable(v));
            }
        }
    } elif isinstance(nd, DictVal) {
        for kv in nd.kv_pairs {
            out.extend(self._places_reachable(kv.key));
            out.extend(self._places_reachable(kv.value));
        }
    } elif isinstance(nd, IfElseExpr) {
        out.extend(self._places_reachable(nd.value));
        out.extend(self._places_reachable(nd.else_value));
    } elif isinstance(nd, FuncCall) {
        for p in (nd.params or []) {
            if isinstance(p, KWPair) {
                out.extend(self._places_reachable(p.value));
            } elif isinstance(p, Expr) {
                out.extend(self._places_reachable(p));
            }
        }
        recv = self._place_of(nd.target);
        if recv is not None {
            out.append(recv);
        }
    } else {
        for sub in nd.get_all_sub_nodes(Name) {
            sub_place = self._place_of(sub);
            if sub_place is not None {
                out.append(sub_place);
            }
        }
    }
    return out;
}

impl OwnershipCheckPass._region_escapee_roots(
    expr: Expr | None, region: OpenStmt
) -> list[Name] {
    out: list[Name] = [];
    seen: set[SymId] = set();
    for root_nm in self._places_reachable(expr) {
        sid = self._name_sym_id(root_nm);
        if sid in seen {
            continue;
        }
        if self._borrow_sym_of(root_nm) is None
            and self._is_region_local(root_nm, region) {
            seen.add(sid);
            out.append(root_nm);
        }
    }
    return out;
}

impl OwnershipCheckPass._is_region_local(nd: Name, region: OpenStmt) -> bool {
    if nd.sym is None or nd.sym.decl is None {
        return False;
    }
    return self._is_ancestor(region, nd.sym.decl);
}

impl OwnershipCheckPass._seal_connect_handle(bx: BinaryExpr) -> (Name | None) {
    co = bx.op;
    if not isinstance(co, ConnectOp) {
        return None;
    }
    region = bx.find_parent_of_type(OpenStmt);
    if region is None {
        return None;
    }
    _dir = int(co.edge_dir.value);
    if _dir == 3 {
        return None;
    }
    _lroot = self._place_of(bx.left);
    _rroot = self._place_of(bx.right);
    if _lroot is None or _rroot is None {
        return None;
    }
    _l_in = self._is_region_local(_lroot, region);
    _r_in = self._is_region_local(_rroot, region);
    if _l_in == _r_in {
        return None;
    }
    _tgt_in = _l_in if _dir == 1 else _r_in;
    if not _tgt_in {
        return None;
    }
    if self._region_handle_kind(region) != "own" {
        return None;
    }
    return self._open_handle_name(region);
}

impl OwnershipCheckPass._seal_arch_ctor(fc: FuncCall) -> bool {
    if not isinstance(fc.target, Name) {
        return False;
    }
    sym = fc.target.sym;
    if sym is None or sym.decl is None {
        return False;
    }
    decl = sym.decl;
    arch = decl if isinstance(decl, Archetype) else decl.find_parent_of_type(Archetype);
    return arch is not None and arch.name.value == fc.target.sym_name;
}

impl OwnershipCheckPass._emit_post_seal_diagnostics(region: OpenStmt) -> None {
    if not isinstance(region.body, (list, tuple)) {
        return;
    }
    _stmts: list[UniNode] = [s for s in getattr(region, "body", [])];
    _ridx: dict[int, int] = {};
    for (i2, s2) in enumerate(_stmts) {
        _ridx[id(s2)] = i2;
    }
    _seal_idx = -1;
    _seal_site: UniNode = region;
    for bx in region.get_all_sub_nodes(BinaryExpr) {
        if self._seal_connect_handle(bx) is None {
            continue;
        }
        _cur: (UniNode | None) = bx;
        while _cur is not None and id(_cur) not in _ridx {
            _cur = _cur.parent;
        }
        if _cur is None {
            continue;
        }
        _bi = _ridx[id(_cur)];
        if _seal_idx < 0 or _bi < _seal_idx {
            _seal_idx = _bi;
            _seal_site = bx;
        }
    }
    if _seal_idx < 0 {
        return;
    }
    for (_si3, s3) in enumerate(_stmts) {
        if _si3 == _seal_idx {
            for bx3 in s3.get_all_sub_nodes(BinaryExpr) {
                if isinstance(bx3.op, ConnectOp)
                    and bx3 is not _seal_site
                    and self._seal_connect_handle(bx3) is not None {
                    self.emit(
                        E1307,
                        node_override=bx3,
                        name="connect",
                        related=[("second seal of this region", _seal_site)]
                    );
                }
            }
        }
        if _si3 <= _seal_idx {
            continue;
        }
        for fc in s3.get_all_sub_nodes(FuncCall) {
            if self._seal_arch_ctor(fc) {
                self.emit(
                    E1307,
                    node_override=fc,
                    name=fc.target.sym_name
                        if isinstance(fc.target, Name)
                        else "<expression>",
                    related=[
                        ("allocated after this seal closed the region", _seal_site)
                    ]
                );
            }
        }
        for bx2 in s3.get_all_sub_nodes(BinaryExpr) {
            if isinstance(bx2.op, ConnectOp) {
                self.emit(
                    E1307,
                    node_override=bx2,
                    name="connect",
                    related=[("wired after this seal closed the region", _seal_site)]
                );
            }
        }
    }
}

impl OwnershipCheckPass._emit_region_escape(nm: Name, region: OpenStmt) -> None {
    self.emit(
        E1307,
        node_override=nm,
        name=nm.sym_name,
        related=[("escapes this `region` block", region)]
    );
}

impl OwnershipCheckPass._open_handle_name(region: OpenStmt) -> (Name | None) {
    tgt = region.target;
    if isinstance(tgt, Name) and tgt.sym {
        return tgt;
    }
    return None;
}

impl OwnershipCheckPass._region_handle_sid(region: OpenStmt) -> (SymId | None) {
    nm = self._open_handle_name(region);
    if nm is None {
        return None;
    }
    return self._name_sym_id(nm);
}

impl OwnershipCheckPass._param_is_region_borrow(param: ParamVar) -> bool {
    tag = param.type_tag;
    if tag is None or not is_borrow_kind(tag.ownership) {
        return False;
    }
    _expr = tag.tag;
    while isinstance(_expr, AtomTrailer) {
        _expr = _expr.target;
    }
    return isinstance(_expr, Expr)
        and is_builtin_region_type(_expr.type, allow_class=True);
}

impl OwnershipCheckPass._region_handle_kind(region: OpenStmt) -> str {
    nm = self._open_handle_name(region);
    if nm is None or nm.sym is None or nm.sym.decl is None {
        return "";
    }
    sid = self._name_sym_id(nm);
    if sid in self.owned_decl {
        return "own";
    }
    _pv = nm.sym.decl.find_parent_of_type(ParamVar);
    if _pv is not None and self._param_is_region_borrow(_pv) {
        return "param";
    }
    return "";
}

impl OwnershipCheckPass._region_param_count(region: OpenStmt) -> int {
    _ab = region.find_parent_of_type(Ability);
    if _ab is None {
        return 0;
    }
    n = 0;
    for p in self.idx_params {
        if p.find_parent_of_type(Ability) is _ab and self._param_is_region_borrow(p) {
            n += 1;
        }
    }
    return n;
}

impl OwnershipCheckPass._call_borrows_handle(expr: Expr | None, hsid: SymId) -> bool {
    if not isinstance(expr, FuncCall) {
        return False;
    }
    for p in (expr.params or []) {
        _arg = p.value if isinstance(p, KWPair) else p;
        _root = self._place_of(_arg if isinstance(_arg, Expr) else None);
        if _root is not None and self._name_sym_id(_root) == hsid {
            return True;
        }
    }
    return False;
}

impl OwnershipCheckPass._stamp_region_borrows -> None {
    regions = self.ir_in.get_all_sub_nodes(OpenStmt);
    if not regions {
        return;
    }
    for region in regions {
        if not self._region_handle_kind(region) {
            continue;
        }
        hsid = self._region_handle_sid(region);
        hnm = self._open_handle_name(region);
        if hsid is None or hnm is None or hnm.sym is None or hnm.sym.decl is None {
            continue;
        }
        hscope = hnm.sym.decl.find_parent_of_type(UniScopeNode);
        if hscope is None {
            continue;
        }
        for asn in self.idx_assignments {
            if len(asn.target) != 1 or not isinstance(asn.target[0], Name) {
                continue;
            }
            tgt = asn.target[0];
            if tgt.sym is None or tgt.sym.decl is None {
                continue;
            }
            tsid = self._name_sym_id(tgt);
            if tsid == hsid or tsid in self.borrow_meta or tsid in self.owned_decl {
                continue;
            }
            if isinstance(asn.value, UnaryExpr)
                and asn.value.ownership == OwnershipKind.IMM {
                continue;
            }
            if self._region_expr_is_scalar(asn.value) {
                continue;
            }
            _rooted = bool(self._region_escapee_roots(asn.value, region));
            if not _rooted {
                _rooted = self._call_borrows_handle(asn.value, hsid);
            }
            if not _rooted {
                continue;
            }
            if self._is_region_local(tgt, region) {
                continue;
            }
            dest = tgt.sym.decl.find_parent_of_type(UniScopeNode);
            if dest is None or self._region_strictly_outlives(dest, hscope) {
                continue;
            }
            tgt.sym.ownership = OwnershipKind.BORROW;
            self.borrow_meta[tsid] = BorrowMeta(
                name=tgt.sym_name, owner=hsid, is_mut=False
            );
            self.borrow_created_at[tsid] = asn;
        }
    }
}

impl OwnershipCheckPass._region_expr_is_scalar(expr: Expr | None) -> bool {
    if not isinstance(expr, Expr) {
        return False;
    }
    if isinstance(expr, UnaryExpr) and expr.ownership == OwnershipKind.OWN {
        _op = expr.operand;
        if isinstance(_op, Expr) and _op.type is not None {
            _om = "";
            try {
                _om = _op.type.mangle();
            } except Exception {
                _om = "";
            }
            if _om in _REGION_SCALARS or _om in ("str", "LiteralString", "bytes") {
                return True;
            }
        }
        return False;
    }
    if expr.type is None {
        return False;
    }
    _m = "";
    try {
        _m = expr.type.mangle();
    } except Exception {
        return False;
    }
    return _m in _REGION_SCALARS;
}

impl OwnershipCheckPass._region_callee_is_safe(
    call: FuncCall, region: OpenStmt
) -> bool {
    _callee = call.target;

    if isinstance(_callee, AtomTrailer) {
        _recv = self._place_of(_callee.target);
        if _recv is not None and self._is_region_local(_recv, region) {
            return True;
        }
        return False;
    }
    _kind = classify_call(call);
    if _kind == CallKind.INSTANTIATION {
        return True;
    }
    if _kind == CallKind.BUILTIN and isinstance(_callee, Name) {
        return JAC_TYPE_REGISTRY.is_non_retaining_builtin(_callee.sym_name);
    }
    return False;
}

impl OwnershipCheckPass._region_call_result_rooted(
    expr: (Expr | None), region: OpenStmt, hsid: (SymId | None)
) -> bool {
    if not isinstance(expr, FuncCall) or expr.type is None {
        return False;
    }
    if expr.find_parent_of_type(OpenStmt) is not region {
        return False;
    }
    if self._region_expr_is_scalar(expr) or is_builtin_region_type(expr.type) {
        return False;
    }
    if hsid is not None and self._call_borrows_handle(expr, hsid) {
        return False;
    }
    if (
        classify_call(expr) == CallKind.BUILTIN
        and isinstance(expr.target, Name)
        and JAC_TYPE_REGISTRY.is_non_retaining_builtin(expr.target.sym_name)
    ) {
        return False;
    }
    return True;
}

impl OwnershipCheckPass._emit_region_call_escape(call: Expr, region: OpenStmt) -> None {
    self.emit(
        E1307,
        node_override=call,
        name="call result",
        related=[("escapes this region open", region)]
    );
}

impl OwnershipCheckPass._emit_region_escape_diagnostics -> None {
    regions = self.ir_in.get_all_sub_nodes(OpenStmt);
    if not regions {
        return;
    }

    seen: set[tuple[int, int]] = set();
    for region in regions {
        if not region.body {
            _w_nm = self._open_handle_name(region);
            self.emit(
                W1310,
                node_override=region,
                name=_w_nm.sym_name if _w_nm is not None else "Region()"
            );
        }
        _hkind = self._region_handle_kind(region);
        _hsid = self._region_handle_sid(region);

        _elide_returns = _hkind == "param" and self._region_param_count(region) == 1;
        for ret in self.idx_returns {
            if _elide_returns {
                break;
            }
            if self._region_expr_is_scalar(ret.expr) {
                continue;
            }
            _flagged_root = False;
            for root_nm in self._region_escapee_roots(ret.expr, region) {
                key = (id(region), self._name_sym_id(root_nm));
                _flagged_root = True;
                if key in seen {
                    continue;
                }
                seen.add(key);
                self._emit_region_escape(root_nm, region);
            }

            if (
                not _flagged_root
                and ret.expr is not None
                and ret.find_parent_of_type(OpenStmt) is region
            ) {
                key = (id(region), id(ret));
                if key not in seen {
                    seen.add(key);
                    self.emit(
                        E1307,
                        node_override=ret.expr,
                        name="return value",
                        related=[("escapes this region open", region)]
                    );
                }
            }
        }
        for cexpr in self.idx_concurrent {
            for nm in self._region_escapee_roots(cexpr.target, region) {
                key = (id(region), self._name_sym_id(nm));
                if key in seen {
                    continue;
                }
                seen.add(key);
                self._emit_region_escape(nm, region);
                break;
            }
            if isinstance(cexpr.target, FuncCall) {
                for _cp in (cexpr.target.params or []) {
                    _carg = _cp.value if isinstance(_cp, KWPair) else _cp;
                    if not isinstance(_carg, Expr)
                        or not self._region_call_result_rooted(_carg, region, _hsid) {
                        continue;
                    }
                    key = (id(region), id(_carg));
                    if key in seen {
                        continue;
                    }
                    seen.add(key);
                    self._emit_region_call_escape(_carg, region);
                }
            }

            if _hsid is None {
                continue;
            }
            _sends_handle = False;
            for root_nm in self._places_reachable(cexpr.target) {
                if self._name_sym_id(root_nm) == _hsid {
                    _sends_handle = True;
                    break;
                }
            }
            if not _sends_handle {
                continue;
            }
            _has_borrows = False;
            for (_bsid, _bm) in self.borrow_meta.items() {
                if _bm.owner == _hsid {
                    _has_borrows = True;
                    break;
                }
            }
            if _has_borrows {
                key = (id(region), _hsid);
                if key not in seen {
                    seen.add(key);
                    _hnm = self._open_handle_name(region);
                    if _hnm is not None {
                        self._emit_region_escape(_hnm, region);
                    }
                }
            }
        }
        for asn in self.idx_assignments {
            if self._region_expr_is_scalar(asn.value) {
                continue;
            }
            escapees = self._region_escapee_roots(asn.value, region);
            _call_rooted = self._region_call_result_rooted(asn.value, region, _hsid);
            if not escapees and not _call_rooted {
                continue;
            }
            escapes = False;
            for tgt in asn.target {
                if isinstance(tgt, AtomTrailer) {
                    escapes = True;
                } elif isinstance(tgt, Name) and tgt.sym and tgt.sym.decl {
                    tsid = self._name_sym_id(tgt);
                    if (
                        _hsid is not None
                        and tsid in self.borrow_meta
                        and self.borrow_meta[tsid].owner == _hsid
                    ) {
                        continue;
                    }
                    dest = tgt.sym.decl.find_parent_of_type(UniScopeNode);
                    if self._region_strictly_outlives(dest, region) {
                        escapes = True;
                    }
                }
            }
            if not escapes {
                continue;
            }
            for root_nm in escapees {
                key = (id(region), self._name_sym_id(root_nm));
                if key in seen {
                    continue;
                }
                seen.add(key);
                self._emit_region_escape(root_nm, region);
            }
            if _call_rooted and isinstance(asn.value, FuncCall) {
                key = (id(region), id(asn.value));
                if key not in seen {
                    seen.add(key);
                    self._emit_region_call_escape(asn.value, region);
                }
            }
        }

        for call in region.get_all_sub_nodes(FuncCall) {
            if self._region_callee_is_safe(call, region) {
                continue;
            }
            if _hsid is not None and self._call_borrows_handle(call, _hsid) {
                continue;
            }
            for p in (call.params or []) {
                _arg = p.value if isinstance(p, KWPair) else p;
                if not isinstance(_arg, Expr) or self._region_expr_is_scalar(_arg) {
                    continue;
                }
                for root_nm in self._region_escapee_roots(_arg, region) {
                    key = (id(region), self._name_sym_id(root_nm));
                    if key in seen {
                        continue;
                    }
                    seen.add(key);
                    self._emit_region_escape(root_nm, region);
                }
                if self._region_call_result_rooted(_arg, region, _hsid) {
                    key = (id(region), id(_arg));
                    if key not in seen {
                        seen.add(key);
                        self._emit_region_call_escape(_arg, region);
                    }
                }
            }
        }

        for bexpr in region.get_all_sub_nodes(BinaryExpr) {
            if not isinstance(bexpr.op, ConnectOp) {
                continue;
            }
            if self._seal_connect_handle(bexpr) is not None {
                continue;
            }
            _lroot = self._place_of(bexpr.left);
            _rroot = self._place_of(bexpr.right);
            if _lroot is None or _rroot is None {
                continue;
            }
            _l_in = self._is_region_local(_lroot, region);
            _r_in = self._is_region_local(_rroot, region);
            if _l_in == _r_in {
                continue;
            }
            _mix_root = _lroot if _l_in else _rroot;
            key = (id(region), self._name_sym_id(_mix_root));
            if key in seen {
                continue;
            }
            seen.add(key);
            self._emit_region_escape(_mix_root, region);
        }
        self._emit_post_seal_diagnostics(region);

        if _hsid is None {
            continue;
        }
        _ab = region.find_parent_of_type(Ability);
        if _ab is None {
            continue;
        }
        for call in _ab.get_all_sub_nodes(FuncCall) {
            if self._region_callee_is_safe(call, region)
                or self._call_borrows_handle(call, _hsid) {
                continue;
            }
            for p in (call.params or []) {
                _arg = p.value if isinstance(p, KWPair) else p;
                if not isinstance(_arg, Expr) or self._region_expr_is_scalar(_arg) {
                    continue;
                }
                _root = self._place_of(_arg);
                if _root is None {
                    continue;
                }
                _rsid = self._name_sym_id(_root);
                if _rsid not in self.borrow_meta
                    or self.borrow_meta[_rsid].owner != _hsid {
                    continue;
                }
                key = (id(region), _rsid);
                if key in seen {
                    continue;
                }
                seen.add(key);
                self._emit_region_escape(_root, region);
            }
        }
    }
}
