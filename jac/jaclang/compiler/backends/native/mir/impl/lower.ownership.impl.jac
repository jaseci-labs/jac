impl MirLowering.tag_ownership(tag: (uni.UniNode | None)) -> (OwnershipKind | None) {
    for _ in range(8) {
        if isinstance(tag, (uni.SubTag, uni.UnaryExpr))
            and tag.ownership is not None
            and tag.ownership != OwnershipKind.NONE {
            return tag.ownership;
        }
        if isinstance(tag, uni.SubTag) {
            tag = tag.tag;
        } elif isinstance(tag, uni.AtomUnit) {
            tag = tag.value;
        } else {
            return None;
        }
    }
    return None;
}

impl MirLowering.tag_borrows(tag: (uni.UniNode | None)) -> bool {
    found = self.tag_ownership(tag);
    return found is not None and is_borrow_kind(found);
}

impl MirLowering.returns_borrow(ab: uni.Ability) -> bool {
    sig = ab.signature;
    if not isinstance(sig, uni.FuncSignature) {
        return False;
    }
    if self.tag_borrows(sig.return_type) {
        return True;
    }
    if not ab.is_method or ab.is_static {
        return False;
    }
    found = False;
    for ret in ab.element_sub_nodes(uni.ReturnStmt) {
        if ret.enclosing_frame is not ab {
            continue;
        }
        if not (isinstance(ret.expr, uni.Name) and ret.expr.value == "self") {
            return False;
        }
        found = True;
    }
    return found;
}

impl MirLowering.param_owns(pv: uni.ParamVar) -> bool {
    if pv.name.sym is not None and pv.name.sym.ownership == OwnershipKind.OWN {
        return True;
    }
    return self.tag_ownership(pv.type_tag) == OwnershipKind.OWN;
}

impl MirLowering.field_consumes(arch: uni.Archetype, name: str) -> bool {
    init = self.find_method(arch, "init") or self.find_method(arch, "__init__");
    if init is not None {
        if not isinstance(init.signature, uni.FuncSignature) {
            return False;
        }
        for pv in self.param_nodes(init.signature, True) {
            if pv.name.value == name {
                return self.param_owns(pv);
            }
        }
        return False;
    }
    obj_def = self.object_def(arch);
    member = obj_def.field(name);
    return member is not None and not member.borrowed;
}

impl MirLowering.stamp_ownership {
    known: dict[str, MirDecl] = {};
    for decl in list(self.decls.values()) + list(self.instances.values()) {
        known.setdefault(decl.symbol, decl);
    }
    consumes: dict[str, list[int]] = dict(self.ctor_consumes);
    borrowing: set[str] = set();
    for (symbol, decl) in known.items() {
        sig = decl.ability.signature;
        if decl.c_variadic or not isinstance(sig, uni.FuncSignature) {
            continue;
        }
        if self.returns_borrow(decl.ability) {
            borrowing.add(symbol);
        }
        shift = 1 if decl.self_type is not None else 0;
        nodes = self.param_nodes(sig, decl.self_type is not None);
        owned = [
            index + shift
            for (index, pv) in enumerate(nodes)
            if index < len(decl.params)
                and mir_holds_ref(decl.params[index])
                and self.param_owns(pv)
        ];
        if owned {
            consumes.setdefault(symbol, owned);
        }
    }
    for fn in self.mir.functions {
        fn.ownership = not fn.manual_rc;
        for blk in fn.blocks {
            for instr in blk.instrs {
                if instr.op == MirOp.CALL {
                    callee = instr.callee;
                    shift = 0;
                } elif instr.op == MirOp.CALL_FNPTR and instr.str_value {
                    callee = instr.str_value;
                    shift = 1;
                } else {
                    continue;
                }
                taken = consumes.get(callee);
                if taken {
                    instr.consumes = [
                        index + shift
                        for index in taken
                        if index + shift < len(instr.operands)
                    ];
                }
                if callee in borrowing and instr.result is not None {
                    instr.sub = "borrow";
                    instr.result.owned = False;
                }
            }
        }
    }
}
