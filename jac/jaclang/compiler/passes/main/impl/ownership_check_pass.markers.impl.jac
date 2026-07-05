import jaclang.jac0core.unitree as uni;
import from jaclang.jac0core.diagnostics { E1305, E1309 }

impl OwnershipCheckPass._emit_marker_diagnostics -> None {
    if not self.val_syms and not self.linear_syms {
        return;
    }

    val_decl: dict[SymId, uni.Name] = {};
    linear_decl: dict[SymId, uni.Name] = {};
    for nd in self.idx_assignments {
        tag = nd.type_tag;
        if tag is None or len(nd.target) != 1 {
            continue;
        }
        target = nd.target[0];
        if not (isinstance(target, uni.Name) and target.sym) {
            continue;
        }
        sid = self._name_sym_id(target);
        if tag.is_val {
            val_decl[sid] = target;
        }
        if tag.is_linear {
            linear_decl[sid] = target;
        }
    }
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
        if tag.is_val {
            val_decl[sid] = name;
        }
        if tag.is_linear {
            linear_decl[sid] = name;
        }
    }

    for nd in self.idx_assignments {
        if nd.type_tag is not None and nd.type_tag.is_val {
            continue;
        }
        for tgt in nd.target {
            root: uni.Expr = tgt;
            while isinstance(root, uni.AtomTrailer) {
                root = root.target;
            }
            root_sid = self._sym_id(root);
            if root_sid is not None and root_sid in self.val_syms {
                self._emit_val_mutation(root_sid, tgt, val_decl.get(root_sid));
            }
        }
    }

    for sid in self.val_syms {
        for nm in self.name_uses_by_sym.get(sid, []) {
            cur: uni.UniNode = nm;
            p = cur.parent;
            while isinstance(p, uni.AtomTrailer) and p.target is cur {
                cur = p;
                p = cur.parent;
            }
            if isinstance(p, uni.UnaryExpr) and p.is_mut_borrow {
                self._emit_val_mutation(sid, nm, val_decl.get(sid));
            }
        }
    }

    for sid in self.linear_syms {
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
        decl = linear_decl.get(sid);
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
