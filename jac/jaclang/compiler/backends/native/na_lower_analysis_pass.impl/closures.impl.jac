impl NativeLowering._scan_closure_escapes(
    nd: uni.UniNode, body: Sequence[uni.UniNode]
) -> None {
    def nearest_scope(n: uni.UniNode) -> (uni.UniNode | None) {
        p = n.parent;
        while p is not None {
            if isinstance(
                p,
                (
                    uni.Ability,
                    uni.ImplDef,
                    uni.LambdaExpr,
                    uni.Test,
                    uni.ModuleCode,
                    uni.Module
                )
            ) {
                return p;
            }
            p = p.parent;
        }
        return None;
    }
    if not body {
        return;
    }
    direct_names: list[uni.Name] = [];
    for nm in nd.get_all_sub_nodes(typ=uni.Name) {
        if nearest_scope(nm) is nd {
            direct_names.append(nm);
        }
    }
    for sub in nd.get_all_sub_nodes(typ=uni.Ability) {
        if nearest_scope(sub) is not nd or self._ability_is_generator(sub) {
            continue;
        }
        sname = sub.name_ref.sym_name if sub.name_ref else None;
        if sname is None {
            continue;
        }
        escapes = False;
        for nm in direct_names {
            if nm.value != sname {
                continue;
            }
            _np = nm.parent;
            if not (isinstance(_np, uni.FuncCall) and _np.target is nm) {
                escapes = True;
                break;
            }
        }
        if not escapes {
            continue;
        }
        for cap_sym in sub.get_enclosing_captures() {
            if uni.same_lexical_scope(cap_sym.parent_tab, nd) {
                self.closure_cell_vars.add(cap_sym.sym_name);
            }
        }
    }
    for lam in nd.get_all_sub_nodes(typ=uni.LambdaExpr) {
        if nearest_scope(lam) is not nd {
            continue;
        }
        for cap_sym in lam.captures {
            if uni.same_lexical_scope(cap_sym.parent_tab, nd) {
                self.closure_cell_vars.add(cap_sym.sym_name);
            }
        }
    }
}

impl NativeLowering._emit_closure_escape_error(var_name: str, nd: uni.UniNode) -> None {
    self.emit(
        E5092,
        node_override=nd,
        kind="expression",
        name=f"'{var_name}' (capturing closure used as a value)",
        help_text="This closure's captured variables could not be promoted to shared heap cells in this frame (e.g. the capture is itself borrowed from an outer function, or the closure is a generator), so it can only be called directly here. Move the captured state into this frame, or use an object holding the state."
    );
}
