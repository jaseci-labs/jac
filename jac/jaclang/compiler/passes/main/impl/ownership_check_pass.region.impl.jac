import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.diagnostics { E1307 }

glob _REGION_SCALARS: tuple = ("int", "float", "bool", "None", "NoneType");

glob _REGION_SAFE_CALLEES: frozenset[str] = frozenset(
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

impl OwnershipCheckPass._region_expr_is_scalar(expr: uni.Expr | None) -> bool {
    # Scalar-typed values copy by value at the region boundary, so letting
    # them out can never dangle. An unknown/untyped expression is treated as
    # heap-shaped (conservative). `str` stays heap-shaped until the `own`
    # rebox lands: today region-object string fields are managed refs, but
    # keeping them in is the forward-compatible default for decision #7.
    if not isinstance(expr, uni.Expr) or expr.type is None {
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
    # A method whose receiver is rooted in the region stores, at worst, into
    # region-resident state: the reference cannot outlive the arena.
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
        # A constructor call allocates under the open, so feeding it
        # region-locals creates region-internal refs (decision #7 allows
        # these); if the fresh object itself escapes, the return/store
        # rules flag it at that site.
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
    # Dedup per (region, symbol): one report per escaping binding, however
    # many sites it leaks through.
    seen: set[tuple[int, int]] = set();
    for region in regions {
        for ret in self.idx_returns {
            if self._region_expr_is_scalar(ret.expr) {
                continue;
            }
            for root_nm in self._region_escapee_roots(ret.expr, region) {
                key = (id(region), self._name_sym_id(root_nm));
                if key in seen {
                    continue;
                }
                seen.add(key);
                self._emit_region_escape(root_nm, region);
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
        # Default-deny call laundering: symbol-level tracking cannot see
        # what a callee does with a region-rooted heap argument (it may
        # store it in managed state that outlives the arena), so any such
        # argument escapes unless the callee provably keeps it region-local.
        for call in region.get_all_sub_nodes(uni.FuncCall) {
            if self._region_callee_is_safe(call, region) {
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
    }
}
