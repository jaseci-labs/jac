impl NativeLowering._get_or_register_exc_type(exc_name: str) -> int {
    if exc_name in self._exc_type_registry {
        return self._exc_type_registry[exc_name];
    }
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    type_id = JAC_TYPE_REGISTRY.exception_type_id(exc_name);
    self._exc_type_registry[exc_name] = type_id;
    return type_id;
}

impl NativeLowering._get_exc_descendants(type_name: str) -> list[str] {
    import from jaclang.compiler.type_registry { JAC_TYPE_REGISTRY }
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    roots = [type_name] + JAC_TYPE_REGISTRY.exception_descendants(type_name);
    descendants = roots[1:];
    for cls in get_layout_registry(self.module, self.prog).mro_order {
        if cls in roots or cls in descendants {
            continue;
        }
        if any(anc in roots for anc in self._mro_of(cls)[1:]) {
            descendants.append(cls);
        }
    }
    for desc_name in descendants {
        self._get_or_register_exc_type(desc_name);
    }
    return descendants;
}

impl NativeLowering._exception_member_name(member: uni.UniNode) -> (str | None) {
    name: str | None = None;
    if isinstance(member, uni.Name) {
        name = member.value;
    } elif isinstance(member, uni.AtomTrailer) and isinstance(member.right, uni.Name) {
        name = member.right.value;
    }
    if name is None {
        return None;
    }
    arch_key = self._arch_ref_key(member);
    if arch_key is not None {
        return arch_key;
    }
    import from jaclang.compiler.types.types { ClassType }
    import from jaclang.compiler.passes.layout_pass { class_type_native_name }
    if isinstance(member, uni.Expr) and isinstance(member.type, ClassType) {
        name = class_type_native_name(member.type) or name;
    }
    return name;
}

impl NativeLowering._exception_handler_targets(ex: uni.Expr | None) -> (list[str] | None) {
    if ex is None {
        return None;
    }
    members = list(ex.values) if isinstance(ex, uni.TupleVal) else [ex];
    targets: list[str] = [];
    for member in members {
        name = self._exception_member_name(member);
        if name is None {
            self.ctx.emit(
                E5090,
                node_override=member,
                kind="exception handler",
                name="dynamic exception type"
            );
            continue;
        }
        if name in ("Exception", "BaseException") {
            return None;
        }
        for candidate in [name] + self._get_exc_descendants(name) {
            if candidate not in targets {
                targets.append(candidate);
            }
        }
    }
    return targets;
}

impl NativeLowering._exc_message_slot(type_name: str) -> (int | None) {
    import from jaclang.compiler.passes.layout_pass { EXC_MESSAGE_FIELD }
    return self.struct_field_indices.get(type_name, {}).get(EXC_MESSAGE_FIELD);
}

impl NativeLowering._raise_has_frame_handler(nd: uni.RaiseStmt) -> bool {
    _child: uni.UniNode = nd;
    _cur = nd.parent;
    while _cur is not None {
        if isinstance(_cur, uni.TryStmt) and _child in list(_cur.body) {
            return True;
        }
        if isinstance(_cur, (uni.Ability, uni.LambdaExpr, uni.Module)) {
            return False;
        }
        _child = _cur;
        _cur = _cur.parent;
    }
    return False;
}

impl NativeLowering._exception_match_isa_names(targets: list[str]) -> list[str] {
    import from jaclang.compiler.passes.layout_pass { get_layout_registry }
    known: set[str] = set();
    for mro in get_layout_registry(self.module, self.prog).mro_order.values() {
        known.update(mro);
    }
    isa_names = [
        name
        for name in targets
        if name in known
    ];
    return isa_names;
}

impl NativeLowering._register_exc_lineage_ancestors(
    cause: (uni.Expr | None), type_id: int
) -> list[int] {
    import from jaclang.compiler.types.types { ClassType, TypeBase }
    import from jaclang.compiler.passes.layout_pass { class_type_native_name }
    if type_id == 0 or cause is None {
        return [];
    }
    typ = cause.type;
    if not isinstance(typ, ClassType) or typ._shared is None {
        return [];
    }
    if not isinstance(typ.shared.symbol_table, uni.Archetype) {
        return [];
    }
    ancestors: list[int] = [];
    seen: set[int] = set();
    pending: list[TypeBase] = list(typ.shared.base_classes);
    while pending {
        base = pending.pop(0);
        if not isinstance(base, ClassType) or base._shared is None {
            continue;
        }
        if id(base.shared) in seen {
            continue;
        }
        seen.add(id(base.shared));
        name = class_type_native_name(base) or base.shared.class_name;
        if name not in ("object", "Exception", "BaseException") {
            aid = self._get_or_register_exc_type(name);
            if aid not in (0, type_id) and aid not in ancestors {
                ancestors.append(aid);
            }
        }
        pending.extend(base.shared.base_classes);
    }
    return ancestors;
}
