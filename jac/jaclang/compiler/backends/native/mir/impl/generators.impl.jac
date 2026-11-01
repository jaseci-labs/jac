impl mir_lower_generators(mir: MirModule) {
    for fn in list(mir.functions) {
        if fn.resumable {
            MirGenState(mir=mir, fn=fn).run();
        }
    }
    for fn in mir.functions {
        mir_lower_frames(mir, fn);
    }
}

impl mir_frame_bytes(t: MirType, mir: MirModule) -> int {
    if t.kind == MirKind.STR {
        return 24;
    }
    if t.kind in (MirKind.ANY, MirKind.C_VIEW) {
        return 16;
    }
    if t.kind == MirKind.OPT {
        return 8 + mir_frame_bytes(t.payload(), mir);
    }
    if t.kind == MirKind.TUPLE {
        return sum(mir_frame_bytes(member, mir) for member in t.args);
    }
    if t.kind == MirKind.C_STRUCT {
        layout = mir.structs.get(t.name);
        if layout is None {
            raise MirGenError(f"no layout for C struct {t.name}");
        }
        return max(8, sum(mir_frame_bytes(member.type, mir) for member in layout.fields));
    }
    return 8;
}

impl mir_frame_field(
    fn: MirFunction, out: list[MirInstr], base: MirValue, offset: int, t: MirType
) -> MirValue {
    address = fn.new_value(mir_int());
    out.append(MirInstr(op=MirOp.PTR_INT, result=address, operands=[base], type_arg=mir_int()));
    distance = fn.new_value(mir_int());
    out.append(MirInstr(op=MirOp.CONST_INT, result=distance, int_value=offset));
    moved = fn.new_value(mir_int());
    out.append(MirInstr(op=MirOp.BIN, result=moved, operands=[address, distance], sub="add"));
    place = fn.new_value(mir_c_ptr(t));
    out.append(
        MirInstr(op=MirOp.PTR_CAST, result=place, operands=[moved], type_arg=mir_c_ptr(t))
    );
    return place;
}

impl MirGenState.allocate(t: MirType) -> int {
    offset = self.cursor;
    self.cursor += (mir_frame_bytes(t, self.mir) + 7) // 8 * 8;
    return offset;
}

impl MirGenState.run {
    fn = self.fn;
    if len(fn.params) != 2 or not fn.blocks {
        raise MirGenError(f"resumable function {fn.symbol} is not a resume function");
    }
    frame = fn.params[0].value;
    out = fn.params[1].value;
    first = fn.blocks[0];
    prologue: list[MirInstr] = [];
    kept: list[MirInstr] = [];
    for instr in first.instrs {
        if instr.op == MirOp.SLOT and instr.result is not None {
            slot = instr.result;
            offset = self.allocate(slot.type);
            self.offsets[slot.id] = offset;
            if mir_holds_ref(slot.type) {
                self.held.append(slot);
            }
            self.addresses[slot.id] = mir_frame_field(fn, prologue, frame, offset, slot.type);
        } elif instr.op == MirOp.EXC_FRAME {
            prologue.insert(0, instr);
        } else {
            kept.append(instr);
        }
    }
    first.instrs = kept;
    for blk in fn.blocks {
        self.rewrite_returns(blk, frame);
    }
    pending: list[MirBlock] = list(fn.blocks);
    while pending {
        made = self.split(pending.pop(0), frame, out);
        if made is not None {
            pending.append(made);
        }
    }
    self.substitute_slots();
    self.spill_live_values(frame);
    self.dispatch(prologue, frame, first);
    fn.ret = mir_bool();
    drop = self.drop_function();
    self.mir.frames[fn.symbol] = MirFrame(
        size=self.cursor, drop_symbol=drop.symbol, offsets=dict(self.offsets)
    );
    self.mir.functions.append(drop);
}

impl MirGenState.rewrite_returns(blk: MirBlock, frame: MirValue) {
    fn = self.fn;
    rewritten: list[MirInstr] = [];
    for instr in blk.instrs {
        if instr.op != MirOp.RET {
            rewritten.append(instr);
            continue;
        }
        if instr.operands {
            raise MirGenError(f"resume function {fn.symbol} returns a value");
        }
        address = fn.new_value(mir_int());
        rewritten.append(
            MirInstr(op=MirOp.PTR_INT, result=address, operands=[frame], type_arg=mir_int())
        );
        mark = fn.new_value(mir_int());
        rewritten.append(MirInstr(op=MirOp.CONST_INT, result=mark, int_value=GEN_DONE));
        rewritten.append(MirInstr(op=MirOp.MEM_STORE, operands=[address, mark]));
        verdict = fn.new_value(mir_bool());
        rewritten.append(MirInstr(op=MirOp.CONST_BOOL, result=verdict, int_value=0));
        rewritten.append(MirInstr(op=MirOp.RET, operands=[verdict]));
    }
    blk.instrs = rewritten;
}

impl MirGenState.split(
    blk: MirBlock, frame: MirValue, out: MirValue
) -> (MirBlock | None) {
    fn = self.fn;
    at = -1;
    for (index, instr) in enumerate(blk.instrs) {
        if instr.op == MirOp.YIELD {
            at = index;
            break;
        }
    }
    if at < 0 {
        return None;
    }
    suspended = blk.instrs[at];
    resumed = fn.new_block("resume");
    resumed.instrs = blk.instrs[at + 1:];
    self.resumes.append(resumed);
    point = len(self.resumes);
    head = blk.instrs[:at];
    cell = fn.new_value(mir_int());
    head.append(MirInstr(op=MirOp.PTR_INT, result=cell, operands=[out], type_arg=mir_int()));
    head.append(MirInstr(op=MirOp.MEM_STORE, operands=[cell, suspended.operands[0]]));
    address = fn.new_value(mir_int());
    head.append(MirInstr(op=MirOp.PTR_INT, result=address, operands=[frame], type_arg=mir_int()));
    mark = fn.new_value(mir_int());
    head.append(MirInstr(op=MirOp.CONST_INT, result=mark, int_value=point));
    head.append(MirInstr(op=MirOp.MEM_STORE, operands=[address, mark]));
    verdict = fn.new_value(mir_bool());
    head.append(MirInstr(op=MirOp.CONST_BOOL, result=verdict, int_value=1));
    head.append(MirInstr(op=MirOp.RET, operands=[verdict]));
    blk.instrs = head;
    return resumed;
}

impl MirGenState.substitute_slots {
    for blk in self.fn.blocks {
        for instr in blk.instrs {
            instr.operands = [self.addresses.get(operand.id, operand) for operand in instr.operands];
        }
    }
}

impl MirGenState.reachable_avoiding(
    home: str, successors: dict[str, list[str]]
) -> set[str] {
    seen: set[str] = set();
    pending: list[str] = [blk.label for blk in self.resumes if blk.label != home];
    while pending {
        label = pending.pop();
        if label in seen or label == home {
            continue;
        }
        seen.add(label);
        pending.extend(successors.get(label, []));
    }
    return seen;
}

impl MirGenState.spill_live_values(frame: MirValue) {
    fn = self.fn;
    homes: dict[int, str] = {};
    successors: dict[str, list[str]] = {};
    for blk in fn.blocks {
        successors[blk.label] = list(blk.instrs[-1].targets) if blk.instrs else [];
        for instr in blk.instrs {
            if instr.result is not None {
                homes[instr.result.id] = blk.label;
            }
        }
    }
    reach: dict[str, set[str]] = {};
    spilled: dict[int, int] = {};
    for blk in fn.blocks {
        for instr in blk.instrs {
            for operand in instr.operands {
                home = homes.get(operand.id);
                if home is None or home == blk.label or operand.id in spilled {
                    continue;
                }
                if home not in reach {
                    reach[home] = self.reachable_avoiding(home, successors);
                }
                if blk.label in reach[home] {
                    spilled[operand.id] = self.allocate(operand.type);
                }
            }
        }
    }
    if not spilled {
        return;
    }
    for blk in fn.blocks {
        renamed: dict[int, MirValue] = {};
        loads: list[MirInstr] = [];
        rewritten: list[MirInstr] = [];
        for instr in blk.instrs {
            for operand in instr.operands {
                if operand.id in spilled
                    and homes.get(operand.id) != blk.label
                    and operand.id not in renamed {
                    place = mir_frame_field(fn, loads, frame, spilled[operand.id], operand.type);
                    fresh = fn.new_value(operand.type);
                    loads.append(MirInstr(op=MirOp.LOAD, result=fresh, operands=[place]));
                    renamed[operand.id] = fresh;
                }
            }
            instr.operands = [renamed.get(operand.id, operand) for operand in instr.operands];
            rewritten.append(instr);
            result = instr.result;
            if result is not None and result.id in spilled {
                place = mir_frame_field(fn, rewritten, frame, spilled[result.id], result.type);
                rewritten.append(MirInstr(op=MirOp.STORE, operands=[place, result]));
            }
        }
        blk.instrs = loads + rewritten;
    }
}

impl MirGenState.dispatch(prologue: list[MirInstr], frame: MirValue, first: MirBlock) {
    fn = self.fn;
    entry = MirBlock(label="dispatch", instrs=list(prologue));
    address = fn.new_value(mir_int());
    entry.instrs.append(
        MirInstr(op=MirOp.PTR_INT, result=address, operands=[frame], type_arg=mir_int())
    );
    point = fn.new_value(mir_int());
    entry.instrs.append(
        MirInstr(op=MirOp.MEM_LOAD, result=point, operands=[address], type_arg=mir_int())
    );
    current = entry;
    for (index, target) in enumerate([first] + self.resumes) {
        following = fn.new_block("dispatch.next");
        wanted = fn.new_value(mir_int());
        current.instrs.append(MirInstr(op=MirOp.CONST_INT, result=wanted, int_value=index));
        same = fn.new_value(mir_bool());
        current.instrs.append(
            MirInstr(op=MirOp.CMP, result=same, operands=[point, wanted], sub="eq")
        );
        current.instrs.append(
            MirInstr(
                op=MirOp.COND_BR, operands=[same], targets=[target.label, following.label]
            )
        );
        current = following;
    }
    exhausted = fn.new_value(mir_bool());
    current.instrs.append(MirInstr(op=MirOp.CONST_BOOL, result=exhausted, int_value=0));
    current.instrs.append(MirInstr(op=MirOp.RET, operands=[exhausted]));
    fn.blocks.insert(0, entry);
}

impl MirGenState.drop_function -> MirFunction {
    i8p = mir_c_ptr(mir_int(8, False));
    made = MirFunction(
        name=f"{self.fn.name}.__drop",
        symbol=f"{self.fn.symbol}.__drop",
        ret=mir_none(),
        manual_rc=True,
        linkage="internal"
    );
    frame = made.new_value(i8p, "frame");
    made.params.append(MirParam(name="frame", value=frame));
    blk = made.new_block("entry");
    for slot in self.held {
        place = mir_frame_field(made, blk.instrs, frame, self.offsets[slot.id], slot.type);
        value = made.new_value(slot.type);
        blk.instrs.append(MirInstr(op=MirOp.LOAD, result=value, operands=[place]));
        blk.instrs.append(MirInstr(op=MirOp.RELEASE, operands=[value]));
    }
    address = made.new_value(mir_int());
    blk.instrs.append(
        MirInstr(op=MirOp.PTR_INT, result=address, operands=[frame], type_arg=mir_int())
    );
    header = made.new_value(mir_int());
    blk.instrs.append(MirInstr(op=MirOp.CONST_INT, result=header, int_value=32));
    raw = made.new_value(mir_int());
    blk.instrs.append(MirInstr(op=MirOp.BIN, result=raw, operands=[address, header], sub="sub"));
    (params, ret) = mir_runtime_signature("__jac_rt_free_block");
    self.mir.externs["__jac_rt_free_block"] = MirExtern(
        symbol="__jac_rt_free_block", ret=ret, params=params
    );
    blk.instrs.append(
        MirInstr(op=MirOp.CALL_RUNTIME, operands=[raw], callee="__jac_rt_free_block")
    );
    blk.instrs.append(MirInstr(op=MirOp.RET));
    return made;
}

impl mir_lower_frames(mir: MirModule, fn: MirFunction) {
    i8p = mir_c_ptr(mir_int(8, False));
    for blk in fn.blocks {
        rewritten: list[MirInstr] = [];
        for instr in blk.instrs {
            if instr.op not in (MirOp.FRAME_NEW, MirOp.FRAME_FIELD) {
                rewritten.append(instr);
                continue;
            }
            frame_info = mir.frames.get(instr.callee);
            if frame_info is None {
                raise MirGenError(f"{fn.symbol} names the frame of {instr.callee}, which has none");
            }
            if instr.op == MirOp.FRAME_FIELD {
                offset = frame_info.offsets.get(instr.int_value);
                if offset is None or instr.result is None {
                    raise MirGenError(f"{fn.symbol} names a slot the frame of {instr.callee} lacks");
                }
                address = fn.new_value(mir_int());
                rewritten.append(
                    MirInstr(
                        op=MirOp.PTR_INT,
                        result=address,
                        operands=[instr.operands[0]],
                        type_arg=mir_int()
                    )
                );
                distance = fn.new_value(mir_int());
                rewritten.append(MirInstr(op=MirOp.CONST_INT, result=distance, int_value=offset));
                moved = fn.new_value(mir_int());
                rewritten.append(
                    MirInstr(op=MirOp.BIN, result=moved, operands=[address, distance], sub="add")
                );
                rewritten.append(
                    MirInstr(
                        op=MirOp.PTR_CAST,
                        result=instr.result,
                        operands=[moved],
                        type_arg=instr.type_arg
                    )
                );
                continue;
            }
            size = fn.new_value(mir_int());
            rewritten.append(MirInstr(op=MirOp.CONST_INT, result=size, int_value=frame_info.size));
            drop = fn.new_value(mir_c_fn([i8p], mir_none()));
            rewritten.append(
                MirInstr(
                    op=MirOp.FN_ADDR,
                    result=drop,
                    callee=frame_info.drop_symbol,
                    type_arg=mir_c_fn([i8p], mir_none())
                )
            );
            drop_code = fn.new_value(mir_int());
            rewritten.append(
                MirInstr(op=MirOp.PTR_INT, result=drop_code, operands=[drop], type_arg=mir_int())
            );
            (params, ret) = mir_runtime_signature("__jac_rt_gen_frame");
            mir.externs["__jac_rt_gen_frame"] = MirExtern(
                symbol="__jac_rt_gen_frame", ret=ret, params=params
            );
            rewritten.append(
                MirInstr(
                    op=MirOp.CALL_RUNTIME,
                    result=instr.result,
                    operands=[size, drop_code],
                    callee="__jac_rt_gen_frame"
                )
            );
        }
        blk.instrs = rewritten;
    }
}
