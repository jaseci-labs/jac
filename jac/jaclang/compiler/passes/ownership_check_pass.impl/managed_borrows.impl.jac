import from jaclang.compiler.frontend.diagnostics { E1320, E1321, E1322, E1323 }
import from jaclang.compiler.frontend.unitree { ImplDef }
import from jaclang.compiler.types.types { FunctionType }

impl OwnershipCheckPass._stamp_write_effects -> None {
    abilities = [
        ab
        for ab in self.module.get_all_sub_nodes(Ability)
        if ab.body is not None
    ];
    for ab in abilities {
        ab.writes = [];
    }
    changed = True;
    while changed {
        changed = False;
        for ab in abilities {
            new = sorted(self._local_writes(ab));
            if new != ab.writes {
                ab.writes = new;
                changed = True;
            }
        }
    }
}

impl OwnershipCheckPass._local_writes(ab: Ability) -> set[str] {
    out: set[str] = set();
    scope: UniNode = ab.body if isinstance(ab.body, ImplDef) else ab;
    for asgn in scope.get_all_sub_nodes(Assignment) {
        if self._owning_ability(asgn) is ab {
            for tgt in asgn.target {
                self._store_fields(tgt, out);
            }
        }
    }
    for dstmt in scope.get_all_sub_nodes(DeleteStmt) {
        if self._owning_ability(dstmt) is ab {
            for tgt in dstmt.leaf_targets() {
                self._store_fields(tgt, out);
            }
        }
    }
    for call in scope.get_all_sub_nodes(FuncCall) {
        if self._owning_ability(call) is ab {
            out |= self._call_writes(call);
        }
    }
    return out;
}

impl OwnershipCheckPass._owning_ability(nd: UniNode) -> (Ability | None) {
    cur = nd.parent;
    while cur is not None {
        if isinstance(cur, Ability) {
            return cur;
        }
        if isinstance(cur, ImplDef) and isinstance(cur.decl_link, Ability) {
            return cur.decl_link;
        }
        cur = cur.parent;
    }
    return None;
}

impl OwnershipCheckPass._store_fields(tgt: Expr, out: set[str]) -> None {
    if isinstance(tgt, AtomTrailer) {
        field = tgt.right;
        out.add(field.sym_name if tgt.is_attr and isinstance(field, Name) else "[]");
    } elif isinstance(tgt, (TupleVal, ListVal)) {
        for item in tgt.values {
            if isinstance(item, Expr) {
                self._store_fields(item, out);
            }
        }
    }
}

impl OwnershipCheckPass._call_writes(call: FuncCall) -> set[str] {
    callee = self._callee_ability(call);
    if callee is None {
        return {"*"};
    }
    if self._is_builtin_mutator(callee) {
        return {"[]"};
    }
    if str(callee.loc.mod_path).endswith(".pyi") {
        name = callee.name_ref.sym_name if callee.name_ref is not None else "";
        takes_callable = any(
            isinstance(arg, LambdaExpr)
                or (isinstance(arg, Expr) and isinstance(arg.type, FunctionType))
            for arg in self._call_params(call)
        );
        return {"*"} if takes_callable or name in ("setattr", "delattr") else set();
    }
    return {"*"} if callee.writes is None else set(callee.writes);
}

impl OwnershipCheckPass._stamp_managed_borrows -> None {
    defs: dict[SymId, list[Assignment]] = {};
    for nd in self.idx_assignments {
        target = self._borrow_target(nd);
        if target is None or target.sym is None {
            continue;
        }
        sid = self._name_sym_id(target);
        if sid not in self.declared_borrows {
            continue;
        }
        if sid not in defs {
            defs[sid] = [];
        }
        defs[sid].append(nd);
    }
    managed: dict[SymId, list[Assignment]] = {};
    for (sid, binds) in defs.items() {
        if any(self._borrow_source_owner(nd) is not None for nd in binds) {
            continue;
        }
        starts = [
            self._place_of(nd.value)
            for nd in binds
            if self._is_place_borrow(nd)
        ];
        if not starts {
            continue;
        }
        managed[sid] = binds;
        for start in starts {
            if start is not None and not self._managed_start_ok(start) {
                self.ctx.emit(
                    E1323,
                    node_override=start,
                    name=self._borrow_display_name(sid, start.sym_name)
                );
            }
        }
    }
    changed = True;
    while changed {
        changed = False;
        for (sid, binds) in managed.items() {
            meta = self.borrow_meta.get(sid);
            if meta is None {
                continue;
            }
            fields: set[str] = set();
            for nd in binds {
                if not self._is_place_borrow(nd) {
                    continue;
                }
                value = nd.value;
                if isinstance(value, UnaryExpr) {
                    fields |= self._path_fields(value.operand);
                }
                start = self._place_of(value);
                start_meta = self.borrow_meta.get(self._name_sym_id(start))
                    if start is not None
                    else None;
                if start_meta is not None and start_meta.managed {
                    fields |= start_meta.path_fields;
                }
            }
            if not meta.managed or not fields.issubset(meta.path_fields) {
                meta.managed = True;
                meta.path_fields |= fields;
                changed = True;
            }
        }
    }
    for (sid, binds) in managed.items() {
        if all(self._is_place_borrow(nd) or self._is_null_bind(nd) for nd in binds) {
            for nd in binds {
                self.module.managed_borrow_binds.add(id(nd));
            }
        }
    }
}

impl OwnershipCheckPass._is_place_borrow(nd: Assignment) -> bool {
    value = nd.value;
    return isinstance(value, UnaryExpr)
        and is_borrow_kind(value.ownership)
        and self._place_of(value) is not None;
}

impl OwnershipCheckPass._is_null_bind(nd: Assignment) -> bool {
    return isinstance(nd.value, Null);
}

impl OwnershipCheckPass._managed_start_ok(start: Name) -> bool {
    sym = start.sym;
    if sym is None {
        return False;
    }
    if start.sym_name == "self" or self._borrow_sym_of(start) is not None {
        return True;
    }
    if sym.ownership in (OwnershipKind.OWN, OwnershipKind.IMM) {
        return True;
    }
    return sym.storage == SymbolStorage.PARAM and sym.ownership != OwnershipKind.OWN;
}

impl OwnershipCheckPass._path_fields(expr: Expr) -> set[str] {
    fields: set[str] = set();
    cur = expr;
    while isinstance(cur, AtomTrailer) {
        self._store_fields(cur, fields);
        cur = cur.target;
    }
    return fields;
}

impl OwnershipCheckPass._emit_shared_write_diagnostics -> None {
    for nd in self.idx_assignments {
        for tgt in nd.target {
            if not isinstance(tgt, AtomTrailer) {
                continue;
            }
            base = self._place_of(tgt);
            borrow_id = self._borrow_sym_of(base) if base is not None else None;
            if base is None
                or borrow_id is None
                or borrow_id not in self.declared_borrows
                or self._borrow_is_mut_of(borrow_id) {
                continue;
            }
            fields: set[str] = set();
            self._store_fields(tgt, fields);
            self.ctx.emit(
                E1320,
                node_override=tgt,
                field=sorted(fields)[0],
                name=self._borrow_display_name(borrow_id, base.sym_name)
            );
        }
    }
}

impl OwnershipCheckPass._emit_managed_borrow_diagnostics(
    cfg_nodes: list[UniCFGNode]
) -> None {
    managed = {
        sid: meta
        for (sid, meta) in self.borrow_meta.items()
        if meta.managed
    };
    if not managed {
        return;
    }
    for n in cfg_nodes {
        active = [
            sid
            for sid in self._active_borrows_at(n)
            if sid in managed
        ];
        if not active {
            continue;
        }
        if isinstance(n, Assignment) {
            for tgt in n.target {
                written: set[str] = set();
                self._store_fields(tgt, written);
                for sid in active {
                    hit = sorted(written & managed[sid].path_fields);
                    if hit {
                        self.ctx.emit(
                            E1321,
                            node_override=tgt,
                            field=hit[0],
                            name=managed[sid].name
                        );
                    }
                }
            }
        }
        for call in n.get_all_sub_nodes(FuncCall) {
            if self._cfg_owner(call) is not n {
                continue;
            }
            writes = self._call_writes(call);
            for sid in active {
                hit = sorted(writes & managed[sid].path_fields);
                if "*" in writes or hit {
                    self.ctx.emit(
                        E1322,
                        node_override=call,
                        callee=self._place_text(call.target),
                        field=hit[0] if hit else "any field",
                        name=managed[sid].name
                    );
                }
            }
        }
    }
}
