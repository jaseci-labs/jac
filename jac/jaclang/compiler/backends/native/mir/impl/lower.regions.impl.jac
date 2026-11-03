impl MirLowering.region_extern(
    name: str, args: list[MirValue], ret: MirType
) -> MirValue {
    unit = os.path.realpath(kernel_unit_path(REGION_KERNEL_REL));
    if unit != os.path.realpath(self.module.loc.mod_path)
        and unit not in self.mir.deps {
        self.mir.deps.append(unit);
    }
    if name not in self.mir.externs {
        self.mir.externs[name] = MirExtern(
            symbol=name, ret=ret, params=[arg.type for arg in args], c_abi=True
        );
    }
    made = self.emit_value(MirOp.CALL_C, ret, args, callee=name);
    if name == "__jac_region_new" and self.state is not None {
        self.st().region_news.add(made.id);
    }
    return made;
}

impl MirLowering.lower_open(nd: uni.OpenStmt) {
    region_type = nd.target.type
        or self.prog.get_type_evaluator().get_type_of_expression(nd.target);
    if not is_builtin_region_type(region_type) {
        raise MirRefused(
            mir_refusal(
                "statement",
                "in-block over a value that is not a Region",
                nd,
                "`in <handle> { ... }` opens a Region handle."
            )
        );
    }
    held = self.spill(self.coerce(self.lower_expr(nd.target), mir_int(), nd.target));
    self.region_extern("__jac_region_enter", [held], mir_none());
    self.with_guarded(
        [],
        0,
        list(nd.body),
        MirWithExit(
            site=nd,
            region=True,
            region_drop=held if isinstance(nd.target, uni.FuncCall) else None
        )
    );
}

impl MirLowering.region_slot(name: str, args: list[uni.Expr]) -> MirValue {
    if name == "__jac_region_gbl_get" {
        label = "__jac_region_tls_gbl";
        self.mir.global_blocks[label] = max(self.mir.global_blocks.get(label, 0), 64);
        return self.emit_value(
            MirOp.GLOBAL_BLOCK, mir_int(64), [], str_value=label, int_value=64
        );
    }
    label = "__jac_region_tls";
    self.mir.tls_blocks[label] = max(self.mir.tls_blocks.get(label, 0), 8);
    slot = self.emit_value(
        MirOp.TLS_BLOCK, mir_int(64), [], str_value=label, int_value=8
    );
    if name == "__jac_region_tls_get" {
        return self.emit_value(MirOp.MEM_LOAD, mir_int(64), [slot]);
    }
    value = self.intrinsic_operand(args[0], "i64");
    return self.emit_value(MirOp.MEM_STORE, mir_none(), [slot, value]);
}

impl MirLowering.own_region_handle(slot: MirValue) {
    if not any(held is slot for held in self.st().region_slots) {
        self.st().region_slots.append(slot);
    }
    self.region_extern(
        "__jac_region_drop", [self.builder().load(slot, mir_int())], mir_none()
    );
}

impl MirLowering.drop_region_handles(fn: MirFunction) {
    slots = list(self.st().region_slots);
    if not slots {
        return;
    }
    saved = self.st().b;
    opening = MirBlock(label="region.init");
    self.st().b = MirBuilder(fn=fn, block=opening);
    for slot in slots {
        self.builder().store(slot, self.builder().const_int(0, mir_int()));
    }
    opening_block = fn.blocks[0];
    at = 0;
    while at < len(opening_block.instrs)
        and opening_block.instrs[at].op in (MirOp.SLOT, MirOp.EXC_FRAME) {
        at += 1;
    }
    opening_block.instrs[at:at] = opening.instrs;
    for blk in fn.blocks {
        if not blk.instrs or blk.instrs[-1].op != MirOp.RET {
            continue;
        }
        term = blk.instrs.pop();
        returned = term.operands[0] if term.operands else None;
        tail = MirBlock(label="region.drop");
        self.st().b = MirBuilder(fn=fn, block=tail);
        for slot in slots {
            moved = returned is not None
                and any(
                    instr.op == MirOp.LOAD
                        and instr.result is returned
                        and instr.operands
                        and instr.operands[0] is slot for instr in blk.instrs
                );
            if not moved {
                self.region_extern(
                    "__jac_region_drop",
                    [self.builder().load(slot, mir_int())],
                    mir_none()
                );
            }
        }
        blk.instrs.extend(tail.instrs);
        blk.instrs.append(term);
    }
    self.st().b = saved;
}
