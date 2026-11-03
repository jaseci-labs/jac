impl MirOwnState.run {
    self.carry_crossing();
    for instr in self.fn.blocks[0].instrs if self.fn.blocks else [] {
        if instr.op == MirOp.SLOT
            and instr.result is not None
            and mir_holds_ref(instr.result.type) {
            self.ref_slots.append(instr.result);
        }
    }
    self.end_temporaries();
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
    self.index_values();
    self.classify();
    self.find_movable_temps();
    for blk in self.fn.blocks {
        self.rewrite(blk);
    }
    self.initialize_slots();
    if self.fallbacks and os.environ.get("JAC_MIR_OWN_TRACE") {
        for shared in self.fallbacks {
            sys.stderr.write(f"mir-own: {self.fn.symbol}: retained {shared}\n");
        }
    }
}

impl MirOwnState.index_values {
    for param in self.fn.params {
        if param.value.owned and mir_holds_ref(param.value.type) {
            self.inputs.add(param.value.id);
        }
    }
    for blk in self.fn.blocks {
        for instr in blk.instrs {
            if instr.result is not None {
                self.defs[instr.result.id] = instr;
            }
            if instr.op == MirOp.STORE
                and instr.operands[0].is_slot
                and instr.sub == "forget" {
                self.forgets.add(instr.operands[0].id);
            } elif instr.op == MirOp.STORE
                and instr.operands[0].is_slot
                and instr.operands[0].name == "carry" {
                self.carried[instr.operands[1].id] = instr.operands[0];
            } elif instr.op == MirOp.LOAD and instr.operands[0].is_slot {
                self.final_loads[instr.operands[0].id] = id(instr);
            }
        }
    }
}

impl MirOwnState.classify {
    stores: dict[int, list[tuple[MirValue, str]]] = {};
    for blk in self.fn.blocks {
        for instr in blk.instrs {
            if instr.op == MirOp.STORE
                and instr.operands[0].is_slot
                and mir_holds_ref(instr.operands[1].type) {
                stores.setdefault(instr.operands[0].id, []).append(
                    (instr.operands[1], instr.sub)
                );
            }
        }
    }
    changed = True;
    while changed {
        changed = False;
        for slot in self.ref_slots {
            if slot.id in self.owning {
                continue;
            }
            owned = slot.hold == "own";
            for (value, sub) in stores.get(slot.id, []) {
                if owned {
                    break;
                }
                if sub == "move" or self.owned_source(value) {
                    owned = True;
                } else {
                    found = self.slot_root(value);
                    source: (MirValue | None) = found[0];
                    load: (MirInstr | None) = found[1];
                    owned = source is not None
                        and load is not None
                        and source.id in self.owning
                        and (
                            source.id in self.forgets
                                if source.hold
                                else self.final_loads.get(source.id) == id(load)
                        );
                }
            }
            if owned {
                self.owning.add(slot.id);
                changed = True;
            }
        }
    }
    for slot in self.ref_slots {
        if slot.id not in self.owning {
            slot.borrows = True;
        }
    }
}

impl MirOwnState.owned_source(value: MirValue) -> bool {
    current = value;
    for _ in range(64) {
        if current.owned {
            return True;
        }
        made = self.defs.get(current.id);
        if made is None {
            return False;
        }
        if made.op == MirOp.TUPLE_MAKE {
            return True;
        }
        if made.op
            not in (MirOp.REF_CAST, MirOp.OPT_MAKE, MirOp.ANY_BOX, MirOp.STR_MAKE)
            or not made.operands {
            return False;
        }
        current = made.operands[0];
    }
    return False;
}

impl MirOwnState.find_movable_temps {
    labels: dict[str, int] = {
        blk.label: index for (index, blk) in enumerate(self.fn.blocks)
    };
    succs: list[list[int]] = [];
    preds: list[list[int]] = [[] for _ in self.fn.blocks];
    stored: dict[int, set[int]] = {};
    loaded: dict[int, int] = {};
    for (index, blk) in enumerate(self.fn.blocks) {
        tail = blk.instrs[-1] if blk.instrs else None;
        found: list[int] = [];
        if tail is not None and tail.is_terminator() {
            for label in tail.targets {
                if label in labels {
                    found.append(labels[label]);
                    preds[labels[label]].append(index);
                }
            }
        }
        succs.append(found);
        for instr in blk.instrs {
            if instr.op == MirOp.STORE and instr.operands[0].is_slot {
                made = self.defs.get(instr.operands[1].id);
                if made is None or made.op != MirOp.CONST_NULL {
                    stored.setdefault(instr.operands[0].id, set()).add(index);
                }
            } elif instr.op == MirOp.LOAD
                and instr.operands[0].is_slot
                and self.final_loads.get(instr.operands[0].id) == id(instr) {
                loaded[instr.operands[0].id] = index;
            }
        }
    }
    loops: list[set[int]] = [];
    if self.fn.blocks {
        state: list[int] = [0 for _ in self.fn.blocks];
        stack: list[tuple[int, int]] = [(0, 0)];
        state[0] = 1;
        while stack {
            (node, at) = stack[-1];
            if at < len(succs[node]) {
                stack[-1] = (node, at + 1);
                nxt = succs[node][at];
                if state[nxt] == 1 {
                    body: set[int] = {nxt};
                    work = [node];
                    while work {
                        here = work.pop();
                        if here not in body {
                            body.add(here);
                            work.extend(preds[here]);
                        }
                    }
                    loops.append(body);
                } elif state[nxt] == 0 {
                    state[nxt] = 1;
                    stack.append((nxt, 0));
                }
            } else {
                state[node] = 2;
                stack.pop();
            }
        }
    }
    for slot in self.ref_slots {
        if slot.hold or slot.id not in self.owning or slot.id not in loaded {
            continue;
        }
        at = loaded[slot.id];
        writes = stored.get(slot.id, set());
        if all(at not in body or writes <= body for body in loops) {
            self.movable_temps.add(slot.id);
        }
    }
}

impl MirOwnState.owned_here(instr: MirInstr) -> bool {
    result = instr.result;
    if result is None or result.is_slot or not mir_holds_ref(result.type) {
        return False;
    }
    if instr.op == MirOp.LOAD {
        return False;
    }
    if instr.op in (MirOp.STR_MAKE, MirOp.REF_CAST, MirOp.OPT_MAKE, MirOp.ANY_BOX) {
        return result.owned and instr.sub == "owned";
    }
    return result.owned or instr.op == MirOp.TUPLE_MAKE;
}

impl MirOwnState.rewrite(blk: MirBlock) {
    last = self.last_uses(blk);
    self.pending = {};
    self.out = [];
    self.moved = set();
    for (index, instr) in enumerate(blk.instrs) {
        if instr.op == MirOp.STORE and mir_holds_ref(instr.operands[1].type) {
            self.store(instr);
        } elif instr.op == MirOp.LOAD
            and not instr.operands[0].is_slot
            and instr.result is not None
            and mir_holds_ref(instr.result.type) {
            instr.result.owned = False;
            self.out.append(instr);
        } elif instr.op == MirOp.RET {
            if instr.operands and mir_holds_ref(instr.operands[0].type) {
                returned = instr.operands[0];
                if not self.fn.borrow_return {
                    source: (MirValue | None) = self.slot_root(returned)[0];
                    if source is not None
                        and source.id in self.owning
                        and source.id not in self.moved
                        and not (returned.owned and returned.id in self.pending) {
                        self.moved.add(source.id);
                    } else {
                        returned = self.consume(returned);
                    }
                }
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
        } elif instr.op == MirOp.REF_CAST and instr.sub == "escape" {
            self.escape(instr);
        } elif instr.op
            in (MirOp.STR_MAKE, MirOp.REF_CAST, MirOp.OPT_MAKE, MirOp.ANY_BOX) {
            owner = instr.operands[0];
            result = instr.result;
            if result is not None and owner.id in self.pending {
                self.pending.pop(owner.id);
                result.owned = True;
            } elif result is not None
                and (
                    instr.sub != "owned"
                    or (owner.owned and mir_holds_ref(owner.type) and not owner.is_slot)
                ) {
                result.owned = False;
            }
            self.out.append(instr);
        } elif instr.op in (MirOp.CALL, MirOp.CALL_FNPTR) {
            self.call(instr);
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
    self.settle_moved();
    blk.instrs = self.out;
}

impl MirOwnState.store(instr: MirInstr) {
    place = instr.operands[0];
    value = instr.operands[1];
    sub = instr.sub;
    if place.is_slot and place.id not in self.owning {
        self.out.append(MirInstr(op=MirOp.STORE, operands=[place, value]));
        return;
    }
    if not place.is_slot and self.place_borrowed(place) {
        self.out.append(MirInstr(op=MirOp.STORE, operands=[place, value]));
        return;
    }
    if sub == "move" {
        held = value;
        if value.owned and value.id in self.pending {
            self.pending.pop(value.id);
        } elif value.id in self.inputs {
            self.inputs.discard(value.id);
        }
        self.out.append(MirInstr(op=MirOp.STORE, operands=[place, held]));
        self.moved.discard(place.id);
        return;
    }
    if sub == "forget" and place.id in self.moved {
        self.moved.discard(place.id);
        self.out.append(MirInstr(op=MirOp.STORE, operands=[place, value]));
        return;
    }
    previous = self.fn.new_value(place.type if place.is_slot else value.type);
    self.out.append(MirInstr(op=MirOp.LOAD, result=previous, operands=[place]));
    held = self.consume(value);
    self.out.append(MirInstr(op=MirOp.STORE, operands=[place, held]));
    if place.is_slot and place.id in self.moved {
        self.moved.discard(place.id);
    } else {
        self.release(previous);
    }
}

impl MirOwnState.escape(instr: MirInstr) {
    value = instr.operands[0];
    source: (MirValue | None) = self.slot_root(value)[0];
    if source is not None
        and source.id in self.owning
        and source.id not in self.moved
        and not (value.owned and value.id in self.pending) {
        held = value;
        self.moved.add(source.id);
    } else {
        held = self.consume(value);
    }
    if instr.result is not None {
        instr.result.owned = False;
    }
    self.out.append(
        MirInstr(
            op=MirOp.REF_CAST,
            result=instr.result,
            operands=[held],
            sub="escape",
            type_arg=instr.type_arg
        )
    );
    for slot in self.ref_slots {
        if slot.id in self.moved {
            empty = self.fn.new_value(slot.type);
            self.out.append(
                MirInstr(op=MirOp.CONST_NULL, result=empty, type_arg=slot.type)
            );
            self.out.append(MirInstr(op=MirOp.STORE, operands=[slot, empty]));
        }
    }
    self.moved = set();
}

impl MirOwnState.call(instr: MirInstr) {
    result = instr.result;
    if instr.sub == "borrow" and result is not None {
        at = 1 if instr.op == MirOp.CALL_FNPTR else 0;
        receiver = instr.operands[at] if len(instr.operands) > at else None;
        if receiver is not None
            and receiver.id in self.pending
            and receiver.type.render() == result.type.render() {
            self.pending.pop(receiver.id);
            result.owned = True;
        } else {
            result.owned = False;
        }
    }
    if instr.consumes {
        operands = list(instr.operands);
        for index in instr.consumes {
            if index < len(operands) and mir_holds_ref(operands[index].type) {
                operands[index] = self.consume(operands[index]);
            }
        }
        instr.operands = operands;
    }
    self.out.append(instr);
}

impl MirOwnState.consume(value: MirValue) -> MirValue {
    if value.id in self.immortal {
        return value;
    }
    if value.owned and value.id in self.pending {
        self.pending.pop(value.id);
        return value;
    }
    if value.id in self.inputs {
        self.inputs.discard(value.id);
        return value;
    }
    carry = self.carried.get(value.id);
    if carry is not None and value.owned and carry.id not in self.moved {
        self.moved.add(carry.id);
        return value;
    }
    found = self.slot_root(value);
    source: (MirValue | None) = found[0];
    load: (MirInstr | None) = found[1];
    if source is not None
        and source.id not in self.moved
        and self.movable(source, load) {
        self.moved.add(source.id);
        return value;
    }
    if value.type.kind in (MirKind.STR, MirKind.STR_REF) {
        return self.copy_text(value);
    }
    if value.type.kind == MirKind.BYTES {
        return self.copy_bytes(value);
    }
    return self.share(value);
}

impl MirOwnState.slot_root(
    value: MirValue
) -> tuple[(MirValue | None), (MirInstr | None)] {
    current = value;
    for _ in range(64) {
        made = self.defs.get(current.id);
        if made is None or not made.operands {
            return (None, None);
        }
        if made.op == MirOp.LOAD {
            source = made.operands[0];
            return (source, made) if source.is_slot else (None, None);
        }
        if made.op
            not in (
                MirOp.REF_CAST,
                MirOp.OPT_MAKE,
                MirOp.OPT_GET,
                MirOp.ANY_BOX,
                MirOp.STR_MAKE
            ) {
            return (None, None);
        }
        current = made.operands[0];
    }
    return (None, None);
}

impl MirOwnState.movable(slot: MirValue, load: (MirInstr | None)) -> bool {
    if slot.id not in self.owning {
        return False;
    }
    if slot.hold {
        return slot.id in self.forgets;
    }
    return load is not None
        and self.final_loads.get(slot.id) == id(load)
        and slot.id in self.movable_temps;
}

impl MirOwnState.place_borrowed(place: MirValue) -> bool {
    made = self.defs.get(place.id);
    if made is None
        or made.op != MirOp.FIELD_ADDR
        or not made.operands
        or self.mir is None {
        return False;
    }
    holder = made.operands[0].type;
    if holder.kind != MirKind.OBJ {
        return False;
    }
    obj_def = self.mir.objects.get(holder.name);
    if obj_def is None {
        return False;
    }
    for member in obj_def.fields {
        if member.index == made.int_value {
            return member.borrowed;
        }
    }
    return False;
}

impl MirOwnState.copy_text(value: MirValue) -> MirValue {
    name = "__jac_rt_str_new";
    (params, ret) = self.runtime_extern(name);
    if value.type.kind == MirKind.STR_REF {
        self.runtime_extern("__jac_rt_str_size");
        size = self.fn.new_value(mir_int());
        self.out.append(
            MirInstr(
                op=MirOp.CALL_RUNTIME,
                result=size,
                operands=[value],
                callee="__jac_rt_str_size"
            )
        );
        text = self.fn.new_value(mir_c_ptr(mir_int(8, False)));
        self.out.append(
            MirInstr(
                op=MirOp.PTR_CAST, result=text, operands=[value], type_arg=text.type
            )
        );
        fresh = self.fn.new_value(ret);
        fresh.owned = True;
        self.out.append(
            MirInstr(
                op=MirOp.CALL_RUNTIME, result=fresh, operands=[text, size], callee=name
            )
        );
        return fresh;
    }
    data = self.fn.new_value(mir_c_ptr(mir_int(8, False)));
    self.out.append(
        MirInstr(op=MirOp.STR_PART, result=data, operands=[value], sub="data")
    );
    length = self.fn.new_value(mir_int());
    self.out.append(
        MirInstr(op=MirOp.STR_PART, result=length, operands=[value], sub="len")
    );
    handle = self.fn.new_value(ret);
    self.out.append(
        MirInstr(
            op=MirOp.CALL_RUNTIME, result=handle, operands=[data, length], callee=name
        )
    );
    made = self.fn.new_value(value.type);
    made.owned = True;
    self.out.append(
        MirInstr(op=MirOp.STR_MAKE, result=made, operands=[handle, handle, length])
    );
    return made;
}

impl MirOwnState.copy_bytes(value: MirValue) -> MirValue {
    name = "__jac_rt_bytes_new";
    (params, ret) = self.runtime_extern(name);
    fn = self.fn;
    address = fn.new_value(mir_int());
    self.out.append(
        MirInstr(op=MirOp.PTR_INT, result=address, operands=[value], type_arg=mir_int())
    );
    size = fn.new_value(mir_int());
    self.out.append(
        MirInstr(op=MirOp.MEM_LOAD, result=size, operands=[address], type_arg=mir_int())
    );
    eight = fn.new_value(mir_int());
    self.out.append(MirInstr(op=MirOp.CONST_INT, result=eight, int_value=8));
    start = fn.new_value(mir_int());
    self.out.append(
        MirInstr(op=MirOp.BIN, result=start, operands=[address, eight], sub="add")
    );
    data = fn.new_value(mir_c_ptr(mir_int(8, False)));
    self.out.append(
        MirInstr(op=MirOp.PTR_CAST, result=data, operands=[start], type_arg=data.type)
    );
    handle = fn.new_value(ret);
    handle.owned = True;
    self.out.append(
        MirInstr(
            op=MirOp.CALL_RUNTIME, result=handle, operands=[data, size], callee=name
        )
    );
    made = fn.new_value(value.type);
    made.owned = True;
    self.out.append(
        MirInstr(
            op=MirOp.REF_CAST,
            result=made,
            operands=[handle],
            sub="owned",
            type_arg=value.type
        )
    );
    return made;
}

impl MirOwnState.runtime_extern(name: str) -> tuple[list[MirType], MirType] {
    (params, ret) = mir_runtime_signature(name);
    if self.mir is not None {
        self.mir.externs[name] = MirExtern(symbol=name, ret=ret, params=params);
    }
    return (params, ret);
}

impl MirOwnState.share(value: MirValue) -> MirValue {
    self.fallbacks.append(value.type.render());
    copy = self.fn.new_value(value.type);
    copy.owned = True;
    self.out.append(MirInstr(op=MirOp.RETAIN, result=copy, operands=[value]));
    return copy;
}

impl MirOwnState.release_slots {
    for param in self.fn.params {
        if param.value.id in self.inputs {
            self.release(param.value);
        }
    }
    for slot in self.ref_slots {
        if slot.id not in self.owning or slot.id in self.moved {
            continue;
        }
        held = self.fn.new_value(slot.type);
        self.out.append(MirInstr(op=MirOp.LOAD, result=held, operands=[slot]));
        self.out.append(MirInstr(op=MirOp.RELEASE, operands=[held]));
    }
}

impl MirOwnState.settle_moved {
    if not self.moved or not self.out {
        return;
    }
    tail = self.out[-1];
    if not tail.is_terminator() or tail.op == MirOp.RET {
        return;
    }
    made: list[MirInstr] = [];
    for slot in self.ref_slots {
        if slot.id not in self.moved {
            continue;
        }
        empty = self.fn.new_value(slot.type);
        made.append(MirInstr(op=MirOp.CONST_NULL, result=empty, type_arg=slot.type));
        made.append(MirInstr(op=MirOp.STORE, operands=[slot, empty]));
    }
    self.out[-1:-1] = made;
    self.moved = set();
}
