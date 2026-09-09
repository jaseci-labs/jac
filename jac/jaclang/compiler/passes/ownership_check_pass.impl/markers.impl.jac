import from jaclang.compiler.frontend.diagnostics { E1309 }

impl OwnershipCheckPass._emit_marker_diagnostics -> None {
    if not self.imm_decl {
        return;
    }

    for nd in self.idx_assignments {
        if nd.type_tag is not None and nd.type_tag.ownership == OwnershipKind.IMM {
            continue;
        }
        if isinstance(nd.value, UnaryExpr)
            and nd.value.ownership == OwnershipKind.IMM {
            continue;
        }
        for tgt in nd.target {
            base: Expr = tgt;
            while isinstance(base, AtomTrailer) {
                base = base.target;
            }
            root_sid = self._sym_id(base);
            if root_sid is not None
                and root_sid in self.imm_decl
                and self.imm_decl.get(root_sid) is not tgt {
                self._emit_imm_mutation(root_sid, tgt, self.imm_decl.get(root_sid));
            }
        }
    }

    for sid in self.imm_decl {
        for nm in self.name_uses_by_sym.get(sid, []) {
            cur: UniNode = nm;
            p = cur.parent;
            while isinstance(p, AtomTrailer) and p.target is cur {
                cur = p;
                p = cur.parent;
            }
            if isinstance(p, UnaryExpr) and is_mut_kind(p.ownership) {
                self._emit_imm_mutation(sid, nm, self.imm_decl.get(sid));
            }
        }
    }

    for region in self.ir_in.get_all_sub_nodes(OpenStmt) {
        hnm = self._open_handle_name(region);
        if hnm is None {
            continue;
        }
        hsid = self._sym_id(hnm);
        if hsid is not None and hsid in self.imm_decl {
            self._emit_imm_mutation(hsid, region, self.imm_decl.get(hsid));
        }
    }
}

impl OwnershipCheckPass._emit_imm_mutation(
    sid: SymId, site: UniNode, decl: Name | None
) -> None {
    name = decl.sym_name if decl is not None else "";
    related = [(f"`imm` '{name}' declared here", decl)] if decl is not None else None;
    self.emit(E1309, node_override=site, name=name, related=related);
}

impl OwnershipCheckPass._emit_place_intrinsic_diagnostics -> None {
    import from jaclang.compiler.frontend.diagnostics { E1319 }
    import from jaclang.compiler.types.types { ClassType, TypeBase, UnionType }
    for call in self.ir_in.get_all_sub_nodes(FuncCall) {
        if call.call_kind != "builtin"
            or not isinstance(call.target, Name)
            or call.target.sym_name not in ("take", "swap") {
            continue;
        }
        operation = call.target.sym_name;
        params = list(call.params or []);
        if len(params) != (1 if operation == "take" else 2)
            or any([isinstance(p, KWPair) for p in params]) {
            self.emit(
                E1319,
                node_override=call,
                operation=operation,
                reason="expected positional place arguments"
            );
            continue;
        }
        types: list[TypeBase] = [];
        for param in params {
            place = param.operand if isinstance(param, UnaryExpr) else param;
            if operation == "take" and isinstance(param, UnaryExpr) {
                self.emit(
                    E1319,
                    node_override=param,
                    operation=operation,
                    reason="pass the optional place directly"
                );
                continue;
            }
            if operation == "swap"
                and not (
                    isinstance(param, UnaryExpr)
                    and param.ownership == OwnershipKind.MUT_BORROW
                ) {
                self.emit(
                    E1319,
                    node_override=param,
                    operation=operation,
                    reason="each argument must be an explicit &mut borrow"
                );
                continue;
            }
            if not (
                isinstance(place, Name)
                or (
                    isinstance(place, AtomTrailer)
                    and place.is_attr
                    and isinstance(place.right, Name)
                )
            ) {
                self.emit(
                    E1319,
                    node_override=param,
                    operation=operation,
                    reason="expected a local or an object field"
                );
                continue;
            }
            nm = place if isinstance(place, Name) else place.right;
            if not isinstance(nm, Name) {
                continue;
            }
            decl = nm.sym.decl if nm.sym is not None else None;
            owner = decl.parent if decl is not None else None;
            tag = owner.type_tag
                if isinstance(owner, (Assignment, HasVar, ParamVar))
                else None;
            ty = tag.tag.type if tag is not None else place.type;
            if ty is None {
                continue;
            }
            types.append(ty);
            if operation == "take"
                and not (
                    isinstance(ty, UnionType)
                    and any(
                        [
                            isinstance(t, ClassType)
                                and t.shared.class_name == "NoneType"
                            for t in (ty.types or [])
                        ]
                    )
                ) {
                self.emit(
                    E1319,
                    node_override=param,
                    operation=operation,
                    reason="the place must be optional so it can be replaced with None"
                );
            }
        }
        if operation == "swap"
            and len(types) == 2
            and types[0].mangle() != types[1].mangle() {
            self.emit(
                E1319,
                node_override=call,
                operation=operation,
                reason="the two places have different storage types"
            );
        }
    }
}
