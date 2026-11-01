impl MirValue.render -> str {
    return f"%{self.name or self.id}";
}

impl MirInstr.is_terminator -> bool {
    return self.op
        in (MirOp.BR, MirOp.COND_BR, MirOp.RET, MirOp.UNREACHABLE, MirOp.RAISE);
}

impl MirInstr.render -> str {
    parts: list[str] = [self.op.value];
    if self.sub {
        parts.append(self.sub);
    }
    if self.callee {
        parts.append(f"@{self.callee}");
    }
    if self.op == MirOp.CONST_INT {
        parts.append(str(self.int_value));
    } elif self.op == MirOp.CONST_FLOAT {
        parts.append(repr(self.float_value));
    } elif self.op == MirOp.CONST_BOOL {
        parts.append("true" if self.int_value else "false");
    } elif self.op in (MirOp.CONST_STR, MirOp.CONST_BYTES) {
        parts.append(repr(self.str_value));
    }
    if self.operands {
        parts.append(", ".join(v.render() for v in self.operands));
    }
    if self.type_arg is not None {
        parts.append(f"to {self.type_arg.render()}");
    }
    if self.targets {
        parts.append(" ".join(f"^{t}" for t in self.targets));
    }
    text = " ".join(parts);
    if self.result is not None {
        return f"{self.result.render()}: {self.result.type.render()} = {text}";
    }
    return text;
}

impl MirBlock.terminated -> bool {
    return bool(self.instrs) and self.instrs[-1].is_terminator();
}

impl MirFunction.new_value(type: MirType, name: str = "") -> MirValue {
    self.next_id += 1;
    return MirValue(id=self.next_id, type=type, name=name);
}

impl MirFunction.new_block(hint: str = "bb") -> MirBlock {
    self.next_label += 1;
    made = MirBlock(label=f"{hint}{self.next_label}");
    self.blocks.append(made);
    return made;
}

impl MirFunction.block(label: str) -> MirBlock {
    for blk in self.blocks {
        if blk.label == label {
            return blk;
        }
    }
    raise KeyError(f"MIR function {self.symbol} has no block {label}");
}

impl MirFunction.render -> str {
    params = ", ".join(
        f"{p.value.render()}: {p.value.type.render()}" for p in self.params
    );
    lines: list[str] = [f"fn @{self.symbol}({params}) -> {self.ret.render()} {{"];
    for blk in self.blocks {
        lines.append(f"^{blk.label}:");
        for instr in blk.instrs {
            lines.append(f"    {instr.render()}");
        }
    }
    lines.append("}");
    return "\n".join(lines);
}

impl MirModule.function(symbol: str) -> (MirFunction | None) {
    for fn in self.functions {
        if fn.symbol == symbol {
            return fn;
        }
    }
    return None;
}

impl MirModule.render -> str {
    return "\n\n".join(fn.render() for fn in self.functions);
}

impl MirBuilder.position(block: MirBlock) {
    self.block = block;
}

impl MirBuilder.emit(instr: MirInstr) -> (MirValue | None) {
    if self.block.terminated() {
        raise RuntimeError(
            f"MIR block {self.block.label} of {self.fn.symbol} is already terminated"
        );
    }
    self.block.instrs.append(instr);
    return instr.result;
}

impl MirBuilder.const_int(value: int, type: MirType) -> MirValue {
    result = self.fn.new_value(type);
    self.emit(MirInstr(op=MirOp.CONST_INT, result=result, int_value=value));
    return result;
}

impl MirBuilder.const_float(value: float, type: MirType) -> MirValue {
    result = self.fn.new_value(type);
    self.emit(MirInstr(op=MirOp.CONST_FLOAT, result=result, float_value=value));
    return result;
}

impl MirBuilder.const_bool(value: bool) -> MirValue {
    result = self.fn.new_value(mir_bool());
    self.emit(
        MirInstr(op=MirOp.CONST_BOOL, result=result, int_value=1 if value else 0)
    );
    return result;
}

impl MirBuilder.slot(type: MirType, name: str = "") -> MirValue {
    result = self.fn.new_value(type, name);
    self.emit(MirInstr(op=MirOp.SLOT, result=result, type_arg=type));
    return result;
}

impl MirBuilder.load(slot: MirValue, type: MirType) -> MirValue {
    result = self.fn.new_value(type);
    self.emit(MirInstr(op=MirOp.LOAD, result=result, operands=[slot]));
    return result;
}

impl MirBuilder.store(slot: MirValue, value: MirValue) {
    self.emit(MirInstr(op=MirOp.STORE, operands=[slot, value]));
}

impl MirBuilder.binary(op: str, left: MirValue, right: MirValue) -> MirValue {
    result = self.fn.new_value(left.type);
    self.emit(MirInstr(op=MirOp.BIN, result=result, operands=[left, right], sub=op));
    return result;
}

impl MirBuilder.overflows(op: str, left: MirValue, right: MirValue) -> MirValue {
    result = self.fn.new_value(mir_bool());
    self.emit(MirInstr(op=MirOp.OVF, result=result, operands=[left, right], sub=op));
    return result;
}

impl MirBuilder.raise_builtin(exception: str, message: str) {
    self.emit(MirInstr(op=MirOp.RAISE, callee=exception, str_value=message));
}

impl MirBuilder.compare(op: str, left: MirValue, right: MirValue) -> MirValue {
    result = self.fn.new_value(mir_bool());
    self.emit(MirInstr(op=MirOp.CMP, result=result, operands=[left, right], sub=op));
    return result;
}

impl MirBuilder.negate(value: MirValue) -> MirValue {
    result = self.fn.new_value(value.type);
    self.emit(MirInstr(op=MirOp.NEG, result=result, operands=[value]));
    return result;
}

impl MirBuilder.logical_not(value: MirValue) -> MirValue {
    result = self.fn.new_value(mir_bool());
    self.emit(MirInstr(op=MirOp.NOT, result=result, operands=[value]));
    return result;
}

impl MirBuilder.convert(value: MirValue, to: MirType) -> MirValue {
    if value.type is to {
        return value;
    }
    result = self.fn.new_value(to);
    self.emit(MirInstr(op=MirOp.CONV, result=result, operands=[value], type_arg=to));
    return result;
}

impl MirBuilder.select(
    cond: MirValue, then: MirValue, otherwise: MirValue
) -> MirValue {
    result = self.fn.new_value(then.type);
    self.emit(
        MirInstr(op=MirOp.SELECT, result=result, operands=[cond, then, otherwise])
    );
    return result;
}

impl MirBuilder.call(
    callee: str, args: list[MirValue], ret: MirType
) -> (MirValue | None) {
    result = None if ret.kind == MirKind.VOID else self.fn.new_value(ret);
    if result is not None and mir_holds_ref(ret) {
        result.owned = True;
    }
    self.emit(MirInstr(op=MirOp.CALL, result=result, operands=args, callee=callee));
    return result;
}

impl MirBuilder.call_runtime(
    callee: str, args: list[MirValue], ret: MirType
) -> (MirValue | None) {
    result = None if ret.kind in (MirKind.VOID, MirKind.NONE) else self.fn.new_value(ret);
    if result is not None and mir_holds_ref(ret) {
        result.owned = True;
    }
    self.emit(
        MirInstr(op=MirOp.CALL_RUNTIME, result=result, operands=args, callee=callee)
    );
    return result;
}

impl MirBuilder.const_str(text: str, type: MirType) -> MirValue {
    result = self.fn.new_value(type);
    self.emit(
        MirInstr(op=MirOp.CONST_STR, result=result, str_value=text, type_arg=type)
    );
    return result;
}

impl MirBuilder.const_null(type: MirType) -> MirValue {
    result = self.fn.new_value(type);
    self.emit(MirInstr(op=MirOp.CONST_NULL, result=result, type_arg=type));
    return result;
}

impl MirBuilder.str_part(value: MirValue, part: str) -> MirValue {
    part_type = mir_int() if part == "len" else mir_c_ptr(mir_int(8, False));
    result = self.fn.new_value(part_type);
    self.emit(
        MirInstr(op=MirOp.STR_PART, result=result, operands=[value], sub=part)
    );
    return result;
}

impl MirBuilder.str_make(
    owner: MirValue, data: MirValue, length: MirValue
) -> MirValue {
    result = self.fn.new_value(mir_str());
    result.owned = owner.owned;
    self.emit(
        MirInstr(op=MirOp.STR_MAKE, result=result, operands=[owner, data, length])
    );
    return result;
}

impl MirBuilder.ref_cast(value: MirValue, to: MirType, owned: bool) -> MirValue {
    result = self.fn.new_value(to);
    result.owned = owned;
    self.emit(
        MirInstr(
            op=MirOp.REF_CAST,
            result=result,
            operands=[value],
            type_arg=to,
            sub="owned" if owned else ""
        )
    );
    return result;
}

impl MirBuilder.branch(target: MirBlock) {
    self.emit(MirInstr(op=MirOp.BR, targets=[target.label]));
}

impl MirBuilder.cond_branch(cond: MirValue, then: MirBlock, otherwise: MirBlock) {
    self.emit(
        MirInstr(
            op=MirOp.COND_BR, operands=[cond], targets=[then.label, otherwise.label]
        )
    );
}

impl MirBuilder.ret(value: (MirValue | None)) {
    self.emit(MirInstr(op=MirOp.RET, operands=[value] if value is not None else []));
}

impl MirBuilder.unreachable {
    self.emit(MirInstr(op=MirOp.UNREACHABLE));
}

impl MirStructDef.index_of(field: str) -> int {
    for (index, member) in enumerate(self.fields) {
        if member.name == field {
            return index;
        }
    }
    raise KeyError(f"C struct {self.name} has no field {field}");
}

impl MirObjectDef.field(name: str) -> (MirObjectField | None) {
    for found in self.fields {
        if found.name == name {
            return found;
        }
    }
    return None;
}
