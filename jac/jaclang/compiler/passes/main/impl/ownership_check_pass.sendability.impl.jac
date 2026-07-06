import from jaclang.jac0core.diagnostics { E1308 }

impl OwnershipCheckPass._emit_sendability_diagnostics -> None {
    for cexpr in self.idx_concurrent {
        names: list[uni.Name] = [];
        if isinstance(cexpr.target, uni.Name) {
            names.append(cexpr.target);
        }
        for nm in cexpr.target.get_all_sub_nodes(uni.Name) {
            names.append(nm);
        }
        for nm in names {
            if not self._is_read_name(nm) {
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
                break;
            }
        }
    }
}
