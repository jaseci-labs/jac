import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.diagnostics { E1307, W1310 }

glob _REGION_SCALARS: tuple = ("int", "float", "bool", "None", "NoneType"),
     _REGION_SAFE_CALLEES: frozenset[str] = frozenset(
         {
             "print",
             "len",
             "repr",
             "str",
             "int",
             "float",
             "bool",
             "isinstance",
             "type",
             "id",
             "hash"
         }
     );

impl OwnershipCheckPass._has_region_blocks -> bool {
    return bool(self.ir_in.get_all_sub_nodes(uni.OpenStmt));
}

impl OwnershipCheckPass._place_of(nd: uni.Expr | None) -> (uni.Name | None) {
    cur = nd;
    if isinstance(cur, uni.UnaryExpr) and is_borrow_kind(cur.ownership) {
        cur = cur.operand;
    }
    while isinstance(cur, uni.AtomTrailer) {
        cur = cur.target;
    }
    if isinstance(cur, uni.Name) and cur.sym {
        return cur;
    }
    return None;
}

impl OwnershipCheckPass._places_reachable(nd: uni.Expr | None) -> list[uni.Name] {
    out: list[uni.Name] = [];
    if nd is None {
        return out;
    }
    place = self._place_of(nd);
    if place is not None {
        out.append(place);
        return out;
    }
    if isinstance(nd, uni.ListVal) or isinstance(nd, uni.SetVal) {
        for v in (nd.values or []) {
            out.extend(self._places_reachable(v));
        }
    } elif isinstance(nd, uni.TupleVal) {
        for v in nd.values {
            if isinstance(v, uni.Expr) {
                out.extend(self._places_reachable(v));
            }
        }
    } elif isinstance(nd, uni.DictVal) {
        for kv in nd.kv_pairs {
            out.extend(self._places_reachable(kv.key));
            out.extend(self._places_reachable(kv.value));
        }
    } elif isinstance(nd, uni.IfElseExpr) {
        out.extend(self._places_reachable(nd.value));
        out.extend(self._places_reachable(nd.else_value));
    } elif isinstance(nd, uni.FuncCall) {
        for p in (nd.params or []) {
            if isinstance(p, uni.KWPair) {
                out.extend(self._places_reachable(p.value));
            } elif isinstance(p, uni.Expr) {
                out.extend(self._places_reachable(p));
            }
        }
        recv = self._place_of(nd.target);
        if recv is not None {
            out.append(recv);
        }
    } else {
        for sub in nd.get_all_sub_nodes(uni.Name) {
            sub_place = self._place_of(sub);
            if sub_place is not None {
                out.append(sub_place);
            }
        }
    }
    return out;
}

impl OwnershipCheckPass._region_escapee_roots(
    expr: uni.Expr | None, region: uni.OpenStmt
) -> list[uni.Name] {
    out: list[uni.Name] = [];
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

impl OwnershipCheckPass._is_region_local(nd: uni.Name, region: uni.OpenStmt) -> bool {
    if nd.sym is None or nd.sym.decl is None {
        return False;
    }
    return self._is_ancestor(region, nd.sym.decl);
}

impl OwnershipCheckPass._emit_region_escape(
    nm: uni.Name, region: uni.OpenStmt
) -> None {
    self.emit(
        E1307,
        node_override=nm,
        name=nm.sym_name,
        related=[("escapes this `region` block", region)]
    );
}

impl OwnershipCheckPass._open_handle_name(region: uni.OpenStmt) -> (uni.Name | None) {
    tgt = region.target;
    if isinstance(tgt, uni.Name) and tgt.sym {
        return tgt;
    }
    return None;
}

impl OwnershipCheckPass._region_handle_sid(region: uni.OpenStmt) -> (SymId | None) {
    nm = self._open_handle_name(region);
    if nm is None {
        return None;
    }
    return self._name_sym_id(nm);
}

impl OwnershipCheckPass._param_is_region_borrow(param: uni.ParamVar) -> bool {
    tag = param.type_tag;
    if tag is None or not is_borrow_kind(tag.ownership) {
        return False;
    }
    _expr = tag.tag;
    while isinstance(_expr, uni.AtomTrailer) {
        _expr = _expr.target;
    }
    import from jaclang.compiler.symbol_utils { is_builtin_region_name }
    return is_builtin_region_name(_expr);
}

impl OwnershipCheckPass._region_handle_kind(region: uni.OpenStmt) -> str {
    nm = self._open_handle_name(region);
    if nm is None or nm.sym is None or nm.sym.decl is None {
        return "";
    }
    sid = self._name_sym_id(nm);
    if sid in self.owned_decl {
        return "own";
    }
    _pv = nm.sym.decl.find_parent_of_type(uni.ParamVar);
    if _pv is not None and self._param_is_region_borrow(_pv) {
        return "param";
    }
    return "";
}

impl OwnershipCheckPass._region_param_count(region: uni.OpenStmt) -> int {
    _ab = region.find_parent_of_type(uni.Ability);
    if _ab is None {
        return 0;
    }
    n = 0;
    for p in self.idx_params {
        if p.find_parent_of_type(uni.Ability) is _ab
        and self._param_is_region_borrow(p) {
            n += 1;
        }
    }
    return n;
}

impl OwnershipCheckPass._call_borrows_handle(
    expr: uni.Expr | None, hsid: SymId
) -> bool {
    if not isinstance(expr, uni.FuncCall) {
        return False;
    }
    for p in (expr.params or []) {
        _arg = p.value if isinstance(p, uni.KWPair) else p;
        _root = self._place_of(_arg if isinstance(_arg, uni.Expr) else None);
        if _root is not None and self._name_sym_id(_root) == hsid {
            return True;
        }
    }
    return False;
}

impl OwnershipCheckPass._stamp_region_borrows -> None {
    regions = self.ir_in.get_all_sub_nodes(uni.OpenStmt);
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
        hscope = hnm.sym.decl.find_parent_of_type(uni.UniScopeNode);
        if hscope is None {
            continue;
        }
        for asn in self.idx_assignments {
            if len(asn.target) != 1 or not isinstance(asn.target[0], uni.Name) {
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
            dest = tgt.sym.decl.find_parent_of_type(uni.UniScopeNode);
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

impl OwnershipCheckPass._region_expr_is_scalar(expr: uni.Expr | None) -> bool {
    if not isinstance(expr, uni.Expr) {
        return False;
    }
    if isinstance(expr, uni.UnaryExpr) and expr.ownership == OwnershipKind.OWN {
        _op = expr.operand;
        if isinstance(_op, uni.Expr) and _op.type is not None {
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
    call: uni.FuncCall, region: uni.OpenStmt
) -> bool {
    _callee = call.target;

    if isinstance(_callee, uni.AtomTrailer) {
        _recv = self._place_of(_callee.target);
        if _recv is not None and self._is_region_local(_recv, region) {
            return True;
        }
        return False;
    }
    if isinstance(_callee, uni.Name) {
        if _callee.sym_name in _REGION_SAFE_CALLEES {
            return True;
        }

        if _callee.sym is not None and _callee.sym.decl is not None {
            _decl = _callee.sym.decl;
            if isinstance(_decl.find_parent_of_type(uni.Archetype), uni.Archetype) {
                return True;
            }
        }
    }
    return False;
}

impl OwnershipCheckPass._emit_region_escape_diagnostics -> None {
    regions = self.ir_in.get_all_sub_nodes(uni.OpenStmt);
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
                and ret.find_parent_of_type(uni.OpenStmt) is region
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
            if not escapees {
                continue;
            }
            escapes = False;
            for tgt in asn.target {
                if isinstance(tgt, uni.AtomTrailer) {
                    escapes = True;
                } elif isinstance(tgt, uni.Name) and tgt.sym and tgt.sym.decl {
                    tsid = self._name_sym_id(tgt);
                    if (
                        _hsid is not None
                        and tsid in self.borrow_meta
                        and self.borrow_meta[tsid].owner == _hsid
                    ) {
                        continue;
                    }
                    dest = tgt.sym.decl.find_parent_of_type(uni.UniScopeNode);
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
        }

        for call in region.get_all_sub_nodes(uni.FuncCall) {
            if self._region_callee_is_safe(call, region) {
                continue;
            }
            if _hsid is not None and self._call_borrows_handle(call, _hsid) {
                continue;
            }
            for p in (call.params or []) {
                _arg = p.value if isinstance(p, uni.KWPair) else p;
                if not isinstance(_arg, uni.Expr)
                or self._region_expr_is_scalar(_arg) {
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
            }
        }

        for bexpr in region.get_all_sub_nodes(uni.BinaryExpr) {
            if not isinstance(bexpr.op, uni.ConnectOp) {
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

        if _hsid is None {
            continue;
        }
        _ab = region.find_parent_of_type(uni.Ability);
        if _ab is None {
            continue;
        }
        for call in _ab.get_all_sub_nodes(uni.FuncCall) {
            if self._region_callee_is_safe(call, region)
            or self._call_borrows_handle(call, _hsid) {
                continue;
            }
            for p in (call.params or []) {
                _arg = p.value if isinstance(p, uni.KWPair) else p;
                if not isinstance(_arg, uni.Expr)
                or self._region_expr_is_scalar(_arg) {
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
