import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.diagnostics { E1305, E1309 }

impl OwnershipCheckPass._emit_marker_diagnostics -> None {
    if not self.val_decl and not self.linear_decl {
        return;
    }

    for nd in self.idx_assignments {
        if nd.type_tag is not None and nd.type_tag.ownership == OwnershipKind.VAL {
            continue;
        }
        for tgt in nd.target {
            base: uni.Expr = tgt;
            while isinstance(base, uni.AtomTrailer) {
                base = base.target;
            }
            root_sid = self._sym_id(base);
            if root_sid is not None and root_sid in self.val_decl {
                self._emit_val_mutation(root_sid, tgt, self.val_decl.get(root_sid));
            }
        }
    }

    for sid in self.val_decl {
        for nm in self.name_uses_by_sym.get(sid, []) {
            cur: uni.UniNode = nm;
            p = cur.parent;
            while isinstance(p, uni.AtomTrailer) and p.target is cur {
                cur = p;
                p = cur.parent;
            }
            if isinstance(p, uni.UnaryExpr) and is_mut_kind(p.ownership) {
                self._emit_val_mutation(sid, nm, self.val_decl.get(sid));
            }
        }
    }

    for sid in self.linear_decl {
        consumed = False;
        for nm in self.name_uses_by_sym.get(sid, []) {
            if self._is_move_producing_use(nm) {
                consumed = True;
                break;
            }
        }
        if consumed {
            continue;
        }
        decl = self.linear_decl.get(sid);
        if decl is None {
            continue;
        }
        related = [(f"`linear` '{decl.sym_name}' declared here", decl)];
        self.emit(E1305, node_override=decl, name=decl.sym_name, related=related);
    }
}

impl OwnershipCheckPass._emit_val_mutation(
    sid: SymId, site: uni.UniNode, decl: uni.Name | None
) -> None {
    name = decl.sym_name if decl is not None else "";
    related = [(f"`val` '{name}' declared here", decl)] if decl is not None else None;
    self.emit(E1309, node_override=site, name=name, related=related);
}
