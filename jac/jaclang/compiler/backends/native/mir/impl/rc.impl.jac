impl mir_insert_rc(fn: MirFunction) {
    if not fn.manual_rc {
        MirRcState(fn=fn).run();
    }
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
            if instr.op
                in (
                    MirOp.STR_PART,
                    MirOp.PTR_CAST,
                    MirOp.PTR_INT,
                    MirOp.OPT_GET,
                    MirOp.TUPLE_GET,
                    MirOp.ANY_TAG,
                    MirOp.ANY_PAYLOAD,
                    MirOp.FRAME_FIELD,
                    MirOp.FIELD_ADDR,
                    MirOp.PTR_OFFSET
                )
                and instr.result is not None {
                self.parents[instr.result.id] = instr.operands[0].id;
            }
            if instr.op in (MirOp.CONST_STR, MirOp.CONST_BYTES, MirOp.CONST_NULL)
                and instr.result is not None {
                self.immortal.add(instr.result.id);
            }
        }
    }
    self.carry_across_blocks();
    for blk in self.fn.blocks {
        self.rewrite(blk);
    }
    self.initialize_slots();
}

impl MirRcState.carry_across_blocks {
    if self.fn.resumable {
        return;
    }
    owned: set[int] = set();
    home: dict[int, MirBlock] = {};
    for blk in self.fn.blocks {
        for instr in blk.instrs {
            made = instr.result;
            if made is None or made.is_slot or not mir_holds_ref(made.type) {
                continue;
            }
            home[made.id] = blk;
            if made.owned
                or (instr.op == MirOp.LOAD and not instr.operands[0].is_slot)
                or (
                    instr.op
                        in (MirOp.REF_CAST, MirOp.STR_MAKE, MirOp.OPT_MAKE, MirOp.ANY_BOX)
                    and instr.operands
                    and instr.operands[0].id in owned
                ) {
                owned.add(made.id);
            }
        }
    }
    crossing: list[int] = [];
    for blk in self.fn.blocks {
        for instr in blk.instrs {
            for operand in instr.operands {
                for used in (operand.id, self.base_of(operand.id)) {
                    if used in owned
                        and used not in self.immortal
                        and home[used] is not blk
                        and used not in crossing {
                        crossing.append(used);
                    }
                }
            }
        }
    }
    for value_id in crossing {
        blk = home[value_id];
        for (index, instr) in enumerate(blk.instrs) {
            if instr.result is not None and instr.result.id == value_id {
                value = instr.result;
                held = self.fn.new_value(value.type, "carried");
                held.is_slot = True;
                self.fn.blocks[0].instrs.insert(
                    0, MirInstr(op=MirOp.SLOT, result=held, type_arg=value.type)
                );
                self.ref_slots.append(held);
                at = blk.instrs.index(instr) + 1;
                blk.instrs.insert(at, MirInstr(op=MirOp.STORE, operands=[held, value]));
                break;
            }
        }
    }
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
        } elif instr.op == MirOp.STORE and mir_holds_ref(instr.operands[1].type) {
            place = instr.operands[0];
            previous = self.fn.new_value(instr.operands[1].type);
            self.out.append(MirInstr(op=MirOp.LOAD, result=previous, operands=[place]));
            held = self.consume(instr.operands[1]);
            self.out.append(MirInstr(op=MirOp.STORE, operands=[place, held]));
            self.release(previous);
        } elif instr.op == MirOp.LOAD
            and not instr.operands[0].is_slot
            and instr.result is not None
            and mir_holds_ref(instr.result.type) {
            self.out.append(instr);
            self.out.append(MirInstr(op=MirOp.RETAIN, operands=[instr.result]));
            instr.result.owned = True;
        } elif instr.op == MirOp.RET {
            if instr.operands and mir_holds_ref(instr.operands[0].type) {
                returned = self.consume(instr.operands[0]);
                self.release_slots();
                self.out.append(MirInstr(op=MirOp.RET, operands=[returned]));
            } else {
                if not self.fn.resumable {
                    self.release_slots();
                }
                self.out.append(instr);
            }
        } elif instr.op == MirOp.TUPLE_MAKE {
            members = [
                self.consume(member) if mir_holds_ref(member.type) else member
                for member in instr.operands
            ];
            made = MirInstr(
                op=MirOp.TUPLE_MAKE,
                result=instr.result,
                operands=members,
                type_arg=instr.type_arg
            );
            if instr.result is not None {
                instr.result.owned = mir_holds_ref(instr.result.type);
            }
            self.out.append(made);
        } elif instr.op
            in (MirOp.STR_MAKE, MirOp.REF_CAST, MirOp.OPT_MAKE, MirOp.ANY_BOX) {
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
        mark = len(self.out);
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
        if instr.is_terminator() and len(self.out) > mark and mark > 0 {
            closing = self.out.pop(mark - 1);
            self.out.append(closing);
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
    if not self.ref_slots or self.fn.resumable {
        return;
    }
    first = self.fn.blocks[0];
    at = 0;
    while at < len(first.instrs)
        and first.instrs[at].op in (MirOp.SLOT, MirOp.EXC_FRAME) {
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
