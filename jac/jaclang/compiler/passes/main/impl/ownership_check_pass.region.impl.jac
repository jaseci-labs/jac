import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.diagnostics { E1307 }

impl OwnershipCheckPass._has_region_blocks -> bool {
    return bool(self.ir_in.get_all_sub_nodes(uni.RegionStmt));
}

impl OwnershipCheckPass._region_root_name(nd: uni.Expr | None) -> (uni.Name | None) {
    cur = nd;
    if isinstance(cur, uni.UnaryExpr) and (cur.is_borrow or cur.is_mut_borrow) {
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

impl OwnershipCheckPass._region_escapees(
    expr: uni.Expr | None, region: uni.RegionStmt
) -> list[uni.Name] {
    out: list[uni.Name] = [];
    if expr is None {
        return out;
    }
    root_nm = self._region_root_name(expr);
    if root_nm is not None {
        if self._borrow_sym_of(root_nm) is None
        and self._is_region_local(root_nm, region) {
            out.append(root_nm);
        }
        return out;
    }
    if isinstance(expr, uni.ListVal) or isinstance(expr, uni.SetVal) {
        for v in (expr.values or []) {
            out.extend(self._region_escapees(v, region));
        }
    } elif isinstance(expr, uni.TupleVal) {
        for v in expr.values {
            if isinstance(v, uni.Expr) {
                out.extend(self._region_escapees(v, region));
            }
        }
    } elif isinstance(expr, uni.DictVal) {
        for kv in expr.kv_pairs {
            out.extend(self._region_escapees(kv.key, region));
            out.extend(self._region_escapees(kv.value, region));
        }
    }
    return out;
}

impl OwnershipCheckPass._is_region_local(nd: uni.Name, region: uni.RegionStmt) -> bool {
    if nd.sym is None or nd.sym.decl is None {
        return False;
    }
    return self._is_ancestor(region, nd.sym.decl);
}

impl OwnershipCheckPass._concurrent_payload_names(
    cexpr: uni.ConcurrentExpr
) -> list[uni.Name] {
    names: list[uni.Name] = [];
    if isinstance(cexpr.target, uni.Name) {
        names.append(cexpr.target);
    }
    for nm in cexpr.target.get_all_sub_nodes(uni.Name) {
        names.append(nm);
    }
    return names;
}

impl OwnershipCheckPass._emit_region_escape(
    nm: uni.Name, region: uni.RegionStmt
) -> None {
    self.emit(
        E1307,
        node_override=nm,
        name=nm.sym_name,
        related=[("escapes this `region` block", region)]
    );
}

impl OwnershipCheckPass._emit_region_escape_diagnostics -> None {
    regions = self.ir_in.get_all_sub_nodes(uni.RegionStmt);
    if not regions {
        return;
    }
    seen: set[tuple[int, int]] = set();
    for region in regions {
        for ret in self.idx_returns {
            for root_nm in self._region_escapees(ret.expr, region) {
                key = (id(ret), self._name_sym_id(root_nm));
                if key in seen {
                    continue;
                }
                seen.add(key);
                self._emit_region_escape(root_nm, region);
            }
        }
        for cexpr in self.idx_concurrent {
            for nm in self._concurrent_payload_names(cexpr) {
                if self._borrow_sym_of(nm) is not None {
                    continue;
                }
                if not self._is_region_local(nm, region) {
                    continue;
                }
                key = (id(cexpr), self._name_sym_id(nm));
                if key in seen {
                    continue;
                }
                seen.add(key);
                self._emit_region_escape(nm, region);
                break;
            }
        }
        for asn in self.idx_assignments {
            if asn.aug_op is not None {
                continue;
            }
            escapees = self._region_escapees(asn.value, region);
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
                key = (id(asn), self._name_sym_id(root_nm));
                if key in seen {
                    continue;
                }
                seen.add(key);
                self._emit_region_escape(root_nm, region);
            }
        }
    }
}
