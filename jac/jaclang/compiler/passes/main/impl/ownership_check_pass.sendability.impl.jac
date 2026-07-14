import from jaclang.jac0core.diagnostics { E1308 }

impl OwnershipCheckPass._emit_sendability_diagnostics -> None {
    tracked = set(self.owned_decl);
    tracked.update(self.borrow_meta);
    tracked.update(self.val_decl);
    for nd in self.idx_assignments {
        for tgt in nd.target {
            if isinstance(tgt, uni.Name) and tgt.sym {
                tracked.add(id(tgt.sym));
            }
        }
    }
    for param in self.idx_params {
        if isinstance(param.name, uni.Name) and param.name.sym {
            tracked.add(id(param.name.sym));
        }
    }

    import from jaclang.jac0core.constant { Tokens as Tok }
    for cexpr in self.idx_concurrent {
        if cexpr.tok is not None and cexpr.tok.name == Tok.KW_WAIT {
            continue;
        }
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
            sid = self._sym_id(nm);
            if sid is None or sid not in tracked or nm.sym is None {
                continue;
            }
            if self._is_deep_immutable_scalar(nm) {
                continue;
            }
            ownership = nm.sym.ownership;
            if ownership == OwnershipKind.VAL {
                continue;
            }
            if ownership == OwnershipKind.OWN and self._is_move_producing_use(nm) {
                continue;
            }
            if nm.find_parent_of_type(uni.RegionStmt) is not None {
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

impl OwnershipCheckPass._is_deep_immutable_scalar(nm: uni.Name) -> bool {
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
