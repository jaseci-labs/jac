impl mir_insert_rc(fn: MirFunction, mir: (MirModule | None) = None) {
    if fn.manual_rc {
        return;
    }
    if fn.ownership {
        MirOwnState(fn=fn, mir=mir).run();
    } else {
        MirRcState(fn=fn).run();
    }
}

impl MirRcState.run {
    self.carry_crossing();
    for instr in self.fn.blocks[0].instrs if self.fn.blocks else [] {
        if instr.op == MirOp.SLOT
            and instr.result is not None
            and instr.result.hold != "raw"
            and mir_holds_ref(instr.result.type) {
            self.ref_slots.append(instr.result);
        }
    }
    self.end_temporaries();
    for blk in self.fn.blocks {
        self.move_temps(blk);
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
            if instr.op == MirOp.SELECT and instr.result is not None {
                self.joins[instr.result.id] = [
                    operand.id for operand in instr.operands[1:]
                ];
            }
            if instr.op in (MirOp.CONST_STR, MirOp.CONST_BYTES, MirOp.CONST_NULL)
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
            for base in self.bases_of(operand.id) {
                found[base] = index;
            }
        }
    }
    return found;
}

impl MirRcState.bases_of(value_id: int) -> list[int] {
    found: list[int] = [];
    pending = [value_id];
    while pending {
        current = self.base_of(pending.pop());
        if current in found {
            continue;
        }
        found.append(current);
        pending.extend(self.joins.get(current, []));
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
    self.released_early = False;
    tail = blk.instrs[-1] if blk.instrs else None;
    exits = tail is not None
        and tail.op == MirOp.RET
        and not (tail.operands and mir_holds_ref(tail.operands[0].type))
        and not self.fn.resumable;
    for (index, instr) in enumerate(blk.instrs) {
        if exits
            and not self.released_early
            and instr.op == MirOp.CALL_RUNTIME
            and instr.callee == "__jac_region_drop" {
            self.release_slots();
            self.released_early = True;
        }
        if instr.op == MirOp.STORE and instr.sub == "vacated" {
            self.out.append(instr);
        } elif instr.op == MirOp.STORE
            and instr.operands[0].is_slot
            and instr.operands[0].hold == "raw" {
            stored = instr.operands[1];
            if stored.owned and stored.id in self.pending {
                self.pending.pop(stored.id);
            }
            self.out.append(instr);
        } elif instr.op == MirOp.STORE
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
            and instr.sub != "raw"
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
                if not self.fn.resumable and not self.released_early {
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
            } elif result is not None
                and (
                    instr.sub != "owned"
                    or (owner.owned and mir_holds_ref(owner.type) and not owner.is_slot)
                ) {
                result.owned = False;
            }
            self.out.append(instr);
        } else {
            self.out.append(instr);
        }
        seen: set[int] = set();
        mark = len(self.out);
        for operand in instr.operands {
            for used in [operand.id] + self.bases_of(operand.id) {
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
        and (
            first.instrs[at].op in (MirOp.SLOT, MirOp.EXC_FRAME)
            or (first.instrs[at].op == MirOp.ALLOCA and not first.instrs[at].operands)
        ) {
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

impl MirRcState.end_temporaries {
    temps = [
        slot
        for slot in self.ref_slots
        if slot.is_temp
    ];
    if not temps or not self.fn.blocks {
        return;
    }
    start = 0;
    while start < len(temps) {
        self.end_temporary_batch(temps[start:start + TEMP_BATCH_BITS]);
        start += TEMP_BATCH_BITS;
    }
}

impl MirRcState.end_temporary_batch(temps: list[MirValue]) {
    bits: dict[int, int] = {};
    for (index, slot) in enumerate(temps) {
        bits[slot.id] = 1 << index;
    }
    every = (1 << len(temps)) - 1;
    keeps = self.temp_keeps(bits);
    labels: dict[str, MirBlock] = {blk.label: blk for blk in self.fn.blocks};
    succs: dict[str, list[str]] = {};
    preds: dict[str, list[str]] = {blk.label: [] for blk in self.fn.blocks};
    dispatch: set[str] = set();
    uses: dict[str, list[int]] = {};
    defs: dict[str, list[int]] = {};
    for blk in self.fn.blocks {
        tail = blk.instrs[-1] if blk.instrs else None;
        found = list(tail.targets) if tail is not None and tail.is_terminator() else [];
        succs[blk.label] = [
            label
            for label in found
            if label in labels
        ];
        for label in succs[blk.label] {
            preds[label].append(blk.label);
        }
        if tail is not None
            and tail.op == MirOp.COND_BR
            and len(found) == 2
            and any(instr.op == MirOp.SETJMP for instr in blk.instrs) {
            dispatch.add(found[1]);
        }
        uses[blk.label] = [self.temp_uses(instr, keeps) for instr in blk.instrs];
        defs[blk.label] = [self.temp_defs(instr, bits) for instr in blk.instrs];
    }
    for (body, handler, guard) in self.protected_regions(labels, succs) {
        pending = [body];
        seen: set[str] = set();
        while pending {
            label = pending.pop();
            if label in seen or label == handler {
                continue;
            }
            seen.add(label);
            if handler not in succs[label] {
                succs[label].append(handler);
                preds[handler].append(label);
            }
            if any(
                instr.op == MirOp.CALL_RUNTIME
                    and instr.callee == "__jac_rt_exc_pop"
                    and instr.operands
                    and instr.operands[0] is guard for instr in labels[label].instrs
            ) {
                continue;
            }
            pending.extend(succs[label]);
        }
    }
    live_in: dict[str, int] = {blk.label: 0 for blk in self.fn.blocks};
    live_out: dict[str, int] = {blk.label: 0 for blk in self.fn.blocks};
    changed = True;
    while changed {
        changed = False;
        for blk in reversed(self.fn.blocks) {
            out = 0;
            for label in succs[blk.label] {
                out |= live_in[label];
            }
            live = out;
            block_uses = uses[blk.label];
            block_defs = defs[blk.label];
            for index in range(len(blk.instrs) - 1, -1, -1) {
                live = (live & ~block_defs[index]) | block_uses[index];
            }
            if out != live_out[blk.label] or live != live_in[blk.label] {
                live_out[blk.label] = out;
                live_in[blk.label] = live;
                changed = True;
            }
        }
    }
    held_out: dict[str, int] = {};
    for blk in self.fn.blocks {
        held = live_out[blk.label];
        if blk.terminated() {
            held |= uses[blk.label][-1];
        }
        held_out[blk.label] = held;
    }
    for blk in self.fn.blocks {
        label = blk.label;
        ending: dict[int, list[MirValue]] = {};
        touched = 0;
        for index in range(len(blk.instrs)) {
            touched |= uses[label][index] | defs[label][index];
        }
        for slot in temps {
            bit = bits[slot.id];
            if not touched & bit or held_out[label] & bit {
                continue;
            }
            last = -1;
            for index in range(len(blk.instrs)) {
                if blk.instrs[index].is_terminator() {
                    break;
                }
                if (uses[label][index] | defs[label][index]) & bit {
                    last = index;
                }
            }
            if last >= 0 {
                ending.setdefault(last, []).append(slot);
            }
        }
        for index in sorted(ending.keys(), reverse=True) {
            made: list[MirInstr] = [];
            for slot in ending[index] {
                made.extend(self.temp_end(slot));
            }
            blk.instrs[index + 1:index + 1] = made;
        }
        entering = 0;
        for pred in preds[label] {
            entering |= held_out[pred];
        }
        if label in dispatch and not self.fn.resumable {
            entering |= every;
        }
        entering &= ~live_in[label];
        if not entering {
            continue;
        }
        at = 0;
        while at < len(blk.instrs)
            and (
                blk.instrs[at].op in (MirOp.SLOT, MirOp.EXC_FRAME)
                or (blk.instrs[at].op == MirOp.ALLOCA and not blk.instrs[at].operands)
            ) {
            at += 1;
        }
        made: list[MirInstr] = [];
        for slot in temps {
            if entering & bits[slot.id] {
                made.extend(self.temp_end(slot));
            }
        }
        blk.instrs[at:at] = made;
    }
}

impl MirRcState.move_temps(blk: MirBlock) {
    loaded: dict[int, MirValue] = {};
    instrs = blk.instrs;
    index = 0;
    while index < len(instrs) {
        instr = instrs[index];
        if instr.op == MirOp.LOAD
            and instr.result is not None
            and instr.operands[0].is_slot
            and instr.operands[0].is_temp
            and mir_holds_ref(instr.result.type) {
            loaded[instr.result.id] = instr.operands[0];
        } elif instr.op == MirOp.STORE and instr.operands[0].is_temp {
            target = instr.operands[0];
            for stale in [
                key
                for (key, slot) in loaded.items()
                if slot is target
            ] {
                loaded.pop(stale);
            }
        } elif instr.op == MirOp.STORE
            and instr.operands[0].is_slot
            and not instr.operands[0].is_temp
            and instr.operands[1].id in loaded
            and not instr.operands[1].owned {
            temp = loaded[instr.operands[1].id];
            ending = self.temp_ending(instrs, index + 1, temp);
            if ending > index + 1 {
                cleared = instrs.pop(ending);
                empty = instrs.pop(ending - 1);
                cleared.sub = "vacated";
                instrs.insert(index + 1, cleared);
                instrs.insert(index + 1, empty);
                instr.operands[1].owned = True;
                loaded.pop(instr.operands[1].id);
            }
        }
        index += 1;
    }
}

impl MirRcState.temp_ending(instrs: list[MirInstr], start: int, temp: MirValue) -> int {
    at = start;
    while at < len(instrs) {
        instr = instrs[at];
        if instr.is_terminator() {
            return -1;
        }
        if instr.op == MirOp.STORE and instr.operands[0] is temp {
            empty = instrs[at - 1];
            if empty.op == MirOp.CONST_NULL and empty.result is instr.operands[1] {
                return at;
            }
            return -1;
        }
        if any(operand is temp for operand in instr.operands) {
            return -1;
        }
        at += 1;
    }
    return -1;
}

impl MirRcState.temp_keeps(bits: dict[int, int]) -> dict[int, int] {
    keeps: dict[int, int] = dict(bits);
    changed = True;
    while changed {
        changed = False;
        for blk in self.fn.blocks {
            for instr in blk.instrs {
                mask = 0;
                target: (MirValue | None) = None;
                if instr.op == MirOp.STORE and instr.operands[0].is_slot {
                    slot = instr.operands[0];
                    if slot.id in bits {
                        target = instr.operands[1];
                        mask = bits[slot.id];
                    } elif slot.is_temp and not mir_holds_ref(slot.type) {
                        target = slot;
                        mask = keeps.get(instr.operands[1].id, 0);
                    }
                } elif instr.result is not None {
                    target = instr.result;
                    if instr.op == MirOp.LOAD {
                        source = instr.operands[0];
                        if source.is_slot or not mir_holds_ref(target.type) {
                            mask = keeps.get(source.id, 0);
                        }
                    } elif instr.op
                        in (
                            MirOp.STR_MAKE,
                            MirOp.REF_CAST,
                            MirOp.OPT_MAKE,
                            MirOp.ANY_BOX
                        )
                        and instr.operands {
                        mask = keeps.get(instr.operands[0].id, 0);
                    } elif instr.op != MirOp.TUPLE_MAKE
                        and not (target.owned and mir_holds_ref(target.type)) {
                        for operand in instr.operands {
                            mask |= keeps.get(operand.id, 0);
                        }
                    }
                }
                if target is None or not mask {
                    continue;
                }
                had = keeps.get(target.id, 0);
                if mask & ~had {
                    keeps[target.id] = had | mask;
                    changed = True;
                }
            }
        }
    }
    return keeps;
}

impl MirRcState.temp_uses(instr: MirInstr, keeps: dict[int, int]) -> int {
    mask = 0;
    for (index, operand) in enumerate(instr.operands) {
        if index == 0 and instr.op == MirOp.STORE and operand.is_slot {
            continue;
        }
        mask |= keeps.get(operand.id, 0);
    }
    return mask;
}

impl MirRcState.temp_defs(instr: MirInstr, bits: dict[int, int]) -> int {
    if instr.op == MirOp.STORE and instr.operands and instr.operands[0].is_slot {
        return bits.get(instr.operands[0].id, 0);
    }
    return 0;
}

impl MirRcState.temp_end(slot: MirValue) -> list[MirInstr] {
    empty = self.fn.new_value(slot.type);
    return [
        MirInstr(op=MirOp.CONST_NULL, result=empty, type_arg=slot.type),
        MirInstr(op=MirOp.STORE, operands=[slot, empty])
    ];
}

impl MirRcState.owned_here(instr: MirInstr) -> bool {
    result = instr.result;
    if result is None or result.is_slot or not mir_holds_ref(result.type) {
        return False;
    }
    if instr.op == MirOp.LOAD {
        return not instr.operands[0].is_slot and instr.sub != "raw";
    }
    if instr.op in (MirOp.STR_MAKE, MirOp.REF_CAST, MirOp.OPT_MAKE, MirOp.ANY_BOX) {
        return result.owned and instr.sub == "owned";
    }
    return result.owned or instr.op == MirOp.TUPLE_MAKE;
}

impl MirRcState.carry_crossing {
    if not self.fn.blocks {
        return;
    }
    home: dict[int, str] = {};
    roots: dict[int, set[int]] = {};
    for blk in self.fn.blocks {
        for instr in blk.instrs {
            if instr.result is not None and self.owned_here(instr) {
                home[instr.result.id] = blk.label;
                roots[instr.result.id] = {instr.result.id};
            }
        }
    }
    if not home {
        return;
    }
    changed = True;
    while changed {
        changed = False;
        for blk in self.fn.blocks {
            for instr in blk.instrs {
                result = instr.result;
                if result is None or result.id in home or result.is_slot {
                    continue;
                }
                if instr.op == MirOp.LOAD
                    and (instr.operands[0].is_slot or mir_holds_ref(result.type)) {
                    continue;
                }
                found: set[int] = set();
                for operand in instr.operands {
                    found |= roots.get(operand.id, set());
                }
                if found - roots.get(result.id, set()) {
                    roots[result.id] = roots.get(result.id, set()) | found;
                    changed = True;
                }
            }
        }
    }
    taken: dict[int, int] = {};
    for blk in self.fn.blocks {
        for instr in blk.instrs {
            if instr.op
                in (MirOp.STR_MAKE, MirOp.REF_CAST, MirOp.OPT_MAKE, MirOp.ANY_BOX)
                and instr.result is not None
                and instr.operands
                and instr.result.id in home {
                taken[instr.operands[0].id] = instr.result.id;
            }
        }
    }
    crossing: set[int] = set();
    for blk in self.fn.blocks {
        for instr in blk.instrs {
            for operand in instr.operands {
                for origin in roots.get(operand.id, set()) {
                    while origin in taken and home[origin] == home[taken[origin]] {
                        origin = taken[origin];
                    }
                    if home[origin] != blk.label {
                        crossing.add(origin);
                    }
                }
            }
        }
    }
    if not crossing {
        return;
    }
    made: list[MirInstr] = [];
    for blk in self.fn.blocks {
        index = 0;
        while index < len(blk.instrs) {
            result = blk.instrs[index].result;
            index += 1;
            if result is None or result.id not in crossing {
                continue;
            }
            slot = self.fn.new_value(result.type, "carry");
            slot.is_slot = True;
            slot.is_temp = True;
            made.append(MirInstr(op=MirOp.SLOT, result=slot, type_arg=result.type));
            blk.instrs.insert(index, MirInstr(op=MirOp.STORE, operands=[slot, result]));
            index += 1;
        }
    }
    self.fn.blocks[0].instrs[0:0] = made;
}

impl MirRcState.protected_regions(
    labels: dict[str, MirBlock], succs: dict[str, list[str]]
) -> list[tuple[str, str, MirValue]] {
    found: list[tuple[str, str, MirValue]] = [];
    for blk in self.fn.blocks {
        tail = blk.instrs[-1] if blk.instrs else None;
        if tail is None or tail.op != MirOp.COND_BR or len(tail.targets) != 2 {
            continue;
        }
        buffers: dict[int, MirValue] = {};
        guard: (MirValue | None) = None;
        for instr in blk.instrs {
            if instr.op == MirOp.CALL_RUNTIME
                and instr.callee == "__jac_rt_exc_jmp_buf"
                and instr.result is not None
                and instr.operands {
                buffers[instr.result.id] = instr.operands[0];
            } elif instr.op == MirOp.SETJMP and instr.operands {
                guard = buffers.get(instr.operands[0].id);
            }
        }
        if guard is None
            or tail.targets[0] not in labels
            or tail.targets[1] not in labels {
            continue;
        }
        found.append((tail.targets[0], tail.targets[1], guard));
    }
    return found;
}

impl mir_insert_unwind(mir: MirModule) {
    made: list[MirFunction] = [];
    for fn in mir.functions {
        if fn.manual_rc or fn.resumable or not fn.blocks {
            continue;
        }
        slots = [
            instr.result
            for instr in fn.blocks[0].instrs
            if instr.op == MirOp.SLOT
                and instr.result is not None
                and mir_holds_ref(instr.result.type)
                and not instr.result.borrows
        ];
        if not slots {
            continue;
        }
        cleanup = mir_unwind_cleanup(fn, slots);
        made.append(cleanup);
        mir_register_unwind(fn, slots, cleanup.symbol);
    }
    if not made {
        return;
    }
    for name in ("__jac_rt_unwind_push", "__jac_rt_unwind_pop") {
        (params, ret) = mir_runtime_signature(name);
        mir.externs[name] = MirExtern(symbol=name, ret=ret, params=params);
    }
    mir.functions.extend(made);
}

impl mir_unwind_cleanup(fn: MirFunction, slots: list[MirValue]) -> MirFunction {
    i8p = mir_c_ptr(mir_int(8, False));
    made = MirFunction(
        name=f"{fn.name}.__unwind",
        symbol=f"{fn.symbol}.__unwind",
        ret=mir_none(),
        manual_rc=True,
        linkage="internal"
    );
    record = made.new_value(i8p, "record");
    made.params.append(MirParam(name="record", value=record));
    blk = made.new_block("entry");
    base = made.new_value(mir_int());
    blk.instrs.append(
        MirInstr(op=MirOp.PTR_INT, result=base, operands=[record], type_arg=mir_int())
    );
    for (index, slot) in enumerate(slots) {
        distance = made.new_value(mir_int());
        blk.instrs.append(
            MirInstr(
                op=MirOp.CONST_INT,
                result=distance,
                int_value=(UNWIND_RECORD_WORDS + index) * 8
            )
        );
        cell = made.new_value(mir_int());
        blk.instrs.append(
            MirInstr(op=MirOp.BIN, result=cell, operands=[base, distance], sub="add")
        );
        address = made.new_value(mir_int());
        blk.instrs.append(
            MirInstr(
                op=MirOp.MEM_LOAD, result=address, operands=[cell], type_arg=mir_int()
            )
        );
        place = made.new_value(mir_c_ptr(slot.type));
        blk.instrs.append(
            MirInstr(
                op=MirOp.PTR_CAST,
                result=place,
                operands=[address],
                type_arg=mir_c_ptr(slot.type)
            )
        );
        held = made.new_value(slot.type);
        blk.instrs.append(MirInstr(op=MirOp.LOAD, result=held, operands=[place]));
        blk.instrs.append(MirInstr(op=MirOp.RELEASE, operands=[held]));
    }
    blk.instrs.append(MirInstr(op=MirOp.RET));
    return made;
}

impl mir_register_unwind(fn: MirFunction, slots: list[MirValue], cleanup: str) {
    i8p = mir_c_ptr(mir_int(8, False));
    first = fn.blocks[0];
    at = 0;
    while at < len(first.instrs)
        and (
            first.instrs[at].op in (MirOp.SLOT, MirOp.EXC_FRAME)
            or (first.instrs[at].op == MirOp.ALLOCA and not first.instrs[at].operands)
        ) {
        at += 1;
    }
    record = fn.new_value(mir_c_ptr(mir_int()), "unwind");
    setup: list[MirInstr] = [
        MirInstr(
            op=MirOp.ALLOCA, result=record, int_value=UNWIND_RECORD_WORDS + len(slots)
        )
    ];
    base = fn.new_value(mir_int());
    setup.append(
        MirInstr(op=MirOp.PTR_INT, result=base, operands=[record], type_arg=mir_int())
    );
    def store_word(offset: int, value: MirValue) {
        distance = fn.new_value(mir_int());
        setup.append(MirInstr(op=MirOp.CONST_INT, result=distance, int_value=offset));
        cell = fn.new_value(mir_int());
        setup.append(
            MirInstr(op=MirOp.BIN, result=cell, operands=[base, distance], sub="add")
        );
        setup.append(MirInstr(op=MirOp.MEM_STORE, operands=[cell, value]));
    }
    for (index, slot) in enumerate(slots) {
        address = fn.new_value(mir_int());
        setup.append(
            MirInstr(
                op=MirOp.PTR_INT, result=address, operands=[slot], type_arg=mir_int()
            )
        );
        store_word((UNWIND_RECORD_WORDS + index) * 8, address);
    }
    store_word(8, base);
    code = fn.new_value(mir_c_fn([i8p], mir_none()));
    setup.append(
        MirInstr(
            op=MirOp.FN_ADDR,
            result=code,
            callee=cleanup,
            type_arg=mir_c_fn([i8p], mir_none())
        )
    );
    code_word = fn.new_value(mir_int());
    setup.append(
        MirInstr(
            op=MirOp.PTR_INT, result=code_word, operands=[code], type_arg=mir_int()
        )
    );
    store_word(16, code_word);
    handle = fn.new_value(i8p);
    setup.append(
        MirInstr(op=MirOp.PTR_CAST, result=handle, operands=[record], type_arg=i8p)
    );
    setup.append(
        MirInstr(
            op=MirOp.CALL_RUNTIME, operands=[handle], callee="__jac_rt_unwind_push"
        )
    );
    allocas = [setup[0]];
    first.instrs[at:at] = allocas + setup[1:];
    for blk in fn.blocks {
        rewritten: list[MirInstr] = [];
        for instr in blk.instrs {
            if instr.op == MirOp.RET {
                rewritten.append(
                    MirInstr(
                        op=MirOp.CALL_RUNTIME,
                        operands=[handle],
                        callee="__jac_rt_unwind_pop"
                    )
                );
            }
            rewritten.append(instr);
        }
        blk.instrs = rewritten;
    }
}
