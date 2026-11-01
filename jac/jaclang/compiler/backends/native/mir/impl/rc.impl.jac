impl mir_insert_rc(fn: MirFunction) {
    MirRcState(fn=fn).run();
}

impl MirRcState.run {
    for instr in self.fn.blocks[0].instrs if self.fn.blocks else [] {
        if instr.op == MirOp.SLOT
            and instr.result is not None
            and mir_holds_ref(instr.result.type) {
            self.ref_slots.append(instr.result);
        }
    }
    for blk in self.fn.blocks {
        for instr in blk.instrs {
            if instr.op in (MirOp.STR_PART, MirOp.PTR_CAST, MirOp.PTR_INT)
                and instr.result is not None {
                self.parents[instr.result.id] = instr.operands[0].id;
            }
            if instr.op in (MirOp.CONST_STR, MirOp.CONST_NULL)
                and instr.result is not None {
                self.immortal.add(instr.result.id);
            }
        }
    }
    for blk in self.fn.blocks {
        self.rewrite(blk);
    }
    self.initialize_slots();
}

impl MirRcState.last_uses(blk: MirBlock) -> dict[int, int] {
    found: dict[int, int] = {};
    for (index, instr) in enumerate(blk.instrs) {
        for operand in instr.operands {
            found[operand.id] = index;
            found[self.base_of(operand.id)] = index;
        }
    }
    return found;
}

impl MirRcState.base_of(value_id: int) -> int {
    current = value_id;
    while current in self.parents {
        current = self.parents[current];
    }
    return current;
}

impl MirRcState.rewrite(blk: MirBlock) {
    last = self.last_uses(blk);
    self.pending = {};
    self.out = [];
    for (index, instr) in enumerate(blk.instrs) {
        if instr.op == MirOp.STORE
            and instr.operands[0].is_slot
            and mir_holds_ref(instr.operands[1].type) {
            slot = instr.operands[0];
            previous = self.fn.new_value(slot.type);
            self.out.append(MirInstr(op=MirOp.LOAD, result=previous, operands=[slot]));
            held = self.consume(instr.operands[1]);
            self.out.append(MirInstr(op=MirOp.STORE, operands=[slot, held]));
            self.release(previous);
        } elif instr.op == MirOp.RET {
            if instr.operands and mir_holds_ref(instr.operands[0].type) {
                returned = self.consume(instr.operands[0]);
                self.release_slots();
                self.out.append(MirInstr(op=MirOp.RET, operands=[returned]));
            } else {
                self.release_slots();
                self.out.append(instr);
            }
        } elif instr.op in (MirOp.STR_MAKE, MirOp.REF_CAST) {
            owner = instr.operands[0];
            result = instr.result;
            if result is not None and owner.id in self.pending {
                self.pending.pop(owner.id);
                result.owned = True;
            } elif result is not None and instr.sub != "owned" {
                result.owned = False;
            }
            self.out.append(instr);
        } else {
            self.out.append(instr);
        }
        seen: set[int] = set();
        for operand in instr.operands {
            for used in (operand.id, self.base_of(operand.id)) {
                if used in seen {
                    continue;
                }
                seen.add(used);
                if used in self.pending and last.get(used) == index {
                    self.release(self.pending.pop(used));
                }
            }
        }
        result = instr.result;
        if result is not None
            and result.owned
            and mir_holds_ref(result.type)
            and not result.is_slot {
            if result.id in last {
                self.pending[result.id] = result;
            } else {
                self.release(result);
            }
        }
    }
    if self.pending {
        names = ", ".join(v.render() for v in self.pending.values());
        raise MirRcError(
            f"owned values {names} outlive block {blk.label} of {self.fn.symbol}"
        );
    }
    blk.instrs = self.out;
}

impl MirRcState.consume(value: MirValue) -> MirValue {
    if value.id in self.immortal {
        return value;
    }
    if value.owned and value.id in self.pending {
        self.pending.pop(value.id);
        return value;
    }
    copy = self.fn.new_value(value.type);
    copy.owned = True;
    self.out.append(MirInstr(op=MirOp.RETAIN, result=copy, operands=[value]));
    return copy;
}

impl MirRcState.release(value: MirValue) {
    if value.id in self.immortal {
        return;
    }
    self.out.append(MirInstr(op=MirOp.RELEASE, operands=[value]));
}

impl MirRcState.release_slots {
    for slot in self.ref_slots {
        held = self.fn.new_value(slot.type);
        self.out.append(MirInstr(op=MirOp.LOAD, result=held, operands=[slot]));
        self.out.append(MirInstr(op=MirOp.RELEASE, operands=[held]));
    }
}

impl MirRcState.initialize_slots {
    if not self.ref_slots {
        return;
    }
    first = self.fn.blocks[0];
    at = 0;
    while at < len(first.instrs) and first.instrs[at].op == MirOp.SLOT {
        at += 1;
    }
    made: list[MirInstr] = [];
    for slot in self.ref_slots {
        empty = self.fn.new_value(slot.type);
        made.append(MirInstr(op=MirOp.CONST_NULL, result=empty, type_arg=slot.type));
        made.append(MirInstr(op=MirOp.STORE, operands=[slot, empty]));
    }
    first.instrs[at:at] = made;
}
