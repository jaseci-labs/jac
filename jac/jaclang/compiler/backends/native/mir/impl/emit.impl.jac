impl emit_mir_module(mir: MirModule, triple: str = "") -> ir.Module {
    module = ir.Module(name=mir.path);
    if triple {
        module.triple = triple;
    }
    return MirEmitter(mir=mir, module=module).emit();
}

impl MirEmitter.emit -> ir.Module {
    for fn in self.mir.functions {
        self.declare(fn);
    }
    for fn in self.mir.functions {
        self.emit_function(fn);
    }
    return self.module;
}

impl MirEmitter.llvm_type(t: MirType) -> ir.Type {
    if t.kind == MirKind.BOOL {
        return ir.IntType(1);
    }
    if t.kind == MirKind.INT {
        return ir.IntType(t.width);
    }
    if t.kind == MirKind.FLOAT {
        return ir.FloatType() if t.width == 32 else ir.DoubleType();
    }
    if t.kind in (MirKind.NONE, MirKind.VOID) {
        return ir.VoidType();
    }
    raise MirEmitError(f"no LLVM form for MIR type {t.render()}");
}

impl MirEmitter.fn_type(params: list[MirType], ret: MirType) -> ir.FunctionType {
    return ir.FunctionType(self.llvm_type(ret), [self.llvm_type(p) for p in params]);
}

impl MirEmitter.declare(fn: MirFunction) -> ir.Function {
    made = ir.Function(
        self.module,
        self.fn_type([p.value.type for p in fn.params], fn.ret),
        name=fn.symbol
    );
    made.linkage = fn.linkage;
    self.functions[fn.symbol] = made;
    return made;
}

impl MirEmitter.extern(symbol: str, ret: ir.Type, args: list[ir.Type]) -> ir.Function {
    found = self.functions.get(symbol);
    if found is not None {
        return found;
    }
    existing = self.module.globals.get(symbol);
    if isinstance(existing, ir.Function) {
        self.functions[symbol] = existing;
        return existing;
    }
    made = ir.Function(self.module, ir.FunctionType(ret, args), name=symbol);
    self.functions[symbol] = made;
    return made;
}

impl MirEmitter.emit_function(fn: MirFunction) {
    func = self.functions[fn.symbol];
    self.values = {};
    self.blocks = {};
    for blk in fn.blocks {
        self.blocks[blk.label] = func.append_basic_block(name=blk.label);
    }
    for (param, arg) in zip(fn.params, func.args) {
        arg.name = param.name;
        self.values[param.value.id] = arg;
    }
    b = ir.IRBuilder();
    for blk in fn.blocks {
        b.position_at_end(self.blocks[blk.label]);
        for instr in blk.instrs {
            self.emit_instr(b, instr);
        }
    }
}

impl MirEmitter.value(v: MirValue) -> ir.Value {
    found = self.values.get(v.id);
    if found is None {
        raise MirEmitError(f"MIR value {v.render()} is used before it is defined");
    }
    return found;
}

impl MirEmitter.bind(v: (MirValue | None), made: ir.Value) {
    if v is not None {
        self.values[v.id] = made;
    }
}

impl MirEmitter.cstring(b: ir.IRBuilder, text: str) -> ir.Value {
    gv = self.strings.get(text);
    if gv is None {
        data = bytearray(text.encode("utf-8")) + bytearray([0]);
        arr = ir.ArrayType(ir.IntType(8), len(data));
        gv = ir.GlobalVariable(self.module, arr, name=f".mir.str.{len(self.strings)}");
        gv.initializer = ir.Constant(arr, data);
        gv.global_constant = True;
        gv.linkage = "private";
        self.strings[text] = gv;
    }
    return b.bitcast(gv, ir.IntType(8).as_pointer());
}

impl MirEmitter.emit_instr(b: ir.IRBuilder, instr: MirInstr) {
    op = instr.op;
    if op == MirOp.CONST_INT {
        self.bind(
            instr.result,
            ir.Constant(self.llvm_type(result_of(instr).type), instr.int_value)
        );
    } elif op == MirOp.CONST_FLOAT {
        self.bind(
            instr.result,
            ir.Constant(self.llvm_type(result_of(instr).type), instr.float_value)
        );
    } elif op == MirOp.CONST_BOOL {
        self.bind(instr.result, ir.Constant(ir.IntType(1), instr.int_value));
    } elif op == MirOp.SLOT {
        func = b.function;
        entry_builder = ir.IRBuilder(func.entry_basic_block);
        first = func.entry_basic_block.instructions;
        if first {
            entry_builder.position_before(first[0]);
        }
        self.bind(
            instr.result,
            entry_builder.alloca(
                self.llvm_type(type_arg_of(instr)), name=result_of(instr).name
            )
        );
    } elif op == MirOp.LOAD {
        self.bind(instr.result, b.load(self.value(instr.operands[0])));
    } elif op == MirOp.STORE {
        b.store(self.value(instr.operands[1]), self.value(instr.operands[0]));
    } elif op == MirOp.BIN {
        self.bind(instr.result, self.emit_bin(b, instr));
    } elif op == MirOp.OVF {
        self.bind(instr.result, self.emit_ovf(b, instr));
    } elif op == MirOp.CMP {
        self.bind(instr.result, self.emit_cmp(b, instr));
    } elif op == MirOp.NEG {
        self.bind(instr.result, b.fneg(self.value(instr.operands[0])));
    } elif op == MirOp.NOT {
        self.bind(
            instr.result,
            b.xor(self.value(instr.operands[0]), ir.Constant(ir.IntType(1), 1))
        );
    } elif op == MirOp.CONV {
        self.bind(
            instr.result,
            self.emit_conv(
                b,
                self.value(instr.operands[0]),
                instr.operands[0].type,
                type_arg_of(instr)
            )
        );
    } elif op == MirOp.CALL {
        callee = self.functions.get(instr.callee);
        if callee is None {
            raise MirEmitError(f"MIR call to undeclared function {instr.callee}");
        }
        made = b.call(callee, [self.value(v) for v in instr.operands]);
        self.bind(instr.result, made);
    } elif op == MirOp.RAISE {
        self.emit_raise(b, instr);
    } elif op == MirOp.BR {
        b.branch(self.blocks[instr.targets[0]]);
    } elif op == MirOp.COND_BR {
        b.cbranch(
            self.value(instr.operands[0]),
            self.blocks[instr.targets[0]],
            self.blocks[instr.targets[1]]
        );
    } elif op == MirOp.RET {
        if instr.operands {
            b.ret(self.value(instr.operands[0]));
        } else {
            b.ret_void();
        }
    } elif op == MirOp.UNREACHABLE {
        b.unreachable();
    } else {
        raise MirEmitError(f"no emitter for MIR instruction {op.value}");
    }
}

impl MirEmitter.emit_bin(b: ir.IRBuilder, instr: MirInstr) -> ir.Value {
    l = self.value(instr.operands[0]);
    r = self.value(instr.operands[1]);
    t = instr.operands[0].type;
    op = instr.sub;
    if t.kind == MirKind.FLOAT {
        if op == "add" {
            return b.fadd(l, r);
        }
        if op == "sub" {
            return b.fsub(l, r);
        }
        if op == "mul" {
            return b.fmul(l, r);
        }
        if op == "div" {
            return b.fdiv(l, r);
        }
        if op == "floordiv" {
            floor_fn = self.extern(f"llvm.floor.f{t.width}", l.type, [l.type]);
            return b.call(floor_fn, [b.fdiv(l, r)]);
        }
        if op == "mod" {
            return self.emit_float_mod(b, l, r);
        }
    } else {
        if op == "add" {
            return b.add(l, r);
        }
        if op == "sub" {
            return b.sub(l, r);
        }
        if op == "mul" {
            return b.mul(l, r);
        }
        if op == "and" {
            return b.and_(l, r);
        }
        if op == "or" {
            return b.or_(l, r);
        }
        if op == "xor" {
            return b.xor(l, r);
        }
        if op == "floordiv" {
            return self.emit_floordiv(b, l, r, t.signed);
        }
        if op == "mod" {
            return self.emit_mod(b, l, r, t.signed);
        }
    }
    raise MirEmitError(f"no emitter for MIR {op} on {t.render()}");
}

impl MirEmitter.emit_floordiv(
    b: ir.IRBuilder, l: ir.Value, r: ir.Value, signed: bool
) -> ir.Value {
    if not signed {
        return b.udiv(l, r);
    }
    zero = ir.Constant(l.type, 0);
    q = b.sdiv(l, r);
    rem = b.srem(l, r);
    adjust = b.and_(
        b.icmp_signed("!=", rem, zero),
        b.icmp_unsigned(
            "!=", b.icmp_signed("<", rem, zero), b.icmp_signed("<", r, zero)
        )
    );
    return b.select(adjust, b.sub(q, ir.Constant(l.type, 1)), q);
}

impl MirEmitter.emit_mod(
    b: ir.IRBuilder, l: ir.Value, r: ir.Value, signed: bool
) -> ir.Value {
    if not signed {
        return b.urem(l, r);
    }
    zero = ir.Constant(l.type, 0);
    rem = b.srem(l, r);
    adjust = b.and_(
        b.icmp_signed("!=", rem, zero),
        b.icmp_unsigned(
            "!=", b.icmp_signed("<", rem, zero), b.icmp_signed("<", r, zero)
        )
    );
    return b.select(adjust, b.add(rem, r), rem);
}

impl MirEmitter.emit_float_mod(b: ir.IRBuilder, l: ir.Value, r: ir.Value) -> ir.Value {
    zero = ir.Constant(l.type, 0.0);
    rem = b.frem(l, r);
    adjust = b.and_(
        b.fcmp_ordered("!=", rem, zero),
        b.icmp_unsigned(
            "!=", b.fcmp_ordered("<", rem, zero), b.fcmp_ordered("<", r, zero)
        )
    );
    return b.select(adjust, b.fadd(rem, r), rem);
}

impl MirEmitter.emit_ovf(b: ir.IRBuilder, instr: MirInstr) -> ir.Value {
    l = self.value(instr.operands[0]);
    r = self.value(instr.operands[1]);
    t = instr.operands[0].type;
    if instr.sub == "floordiv" {
        if not t.signed {
            return ir.Constant(ir.IntType(1), 0);
        }
        lowest = ir.Constant(l.type, -(1 << (t.width - 1)));
        return b.and_(
            b.icmp_signed("==", l, lowest),
            b.icmp_signed("==", r, ir.Constant(l.type, -1))
        );
    }
    prefix = "s" if t.signed else "u";
    pair = ir.LiteralStructType([l.type, ir.IntType(1)]);
    intrinsic = self.extern(
        f"llvm.{prefix}{instr.sub}.with.overflow.i{t.width}", pair, [l.type, l.type]
    );
    return b.extract_value(b.call(intrinsic, [l, r]), 1);
}

impl MirEmitter.emit_cmp(b: ir.IRBuilder, instr: MirInstr) -> ir.Value {
    l = self.value(instr.operands[0]);
    r = self.value(instr.operands[1]);
    t = instr.operands[0].type;
    symbol = CMP_SYMBOLS[instr.sub];
    if t.kind == MirKind.FLOAT {
        if instr.sub == "ne" {
            return b.fcmp_unordered("!=", l, r);
        }
        return b.fcmp_ordered(symbol, l, r);
    }
    if t.kind == MirKind.INT and t.signed {
        return b.icmp_signed(symbol, l, r);
    }
    return b.icmp_unsigned(symbol, l, r);
}

impl MirEmitter.emit_conv(
    b: ir.IRBuilder, value: ir.Value, src: MirType, dst: MirType
) -> ir.Value {
    to = self.llvm_type(dst);
    if dst.kind == MirKind.BOOL {
        if src.kind == MirKind.FLOAT {
            return b.fcmp_unordered("!=", value, ir.Constant(value.type, 0.0));
        }
        return b.icmp_unsigned("!=", value, ir.Constant(value.type, 0));
    }
    if dst.kind == MirKind.FLOAT {
        if src.kind == MirKind.FLOAT {
            if src.width < dst.width {
                return b.fpext(value, to);
            }
            return b.fptrunc(value, to) if src.width > dst.width else value;
        }
        if src.kind == MirKind.INT and src.signed {
            return b.sitofp(value, to);
        }
        return b.uitofp(value, to);
    }
    if dst.kind == MirKind.INT {
        if src.kind == MirKind.FLOAT {
            return b.fptosi(value, to) if dst.signed else b.fptoui(value, to);
        }
        if src.width < dst.width {
            if src.kind == MirKind.INT and src.signed {
                return b.sext(value, to);
            }
            return b.zext(value, to);
        }
        return b.trunc(value, to) if src.width > dst.width else value;
    }
    raise MirEmitError(f"no conversion from {src.render()} to {dst.render()}");
}

impl MirEmitter.emit_raise(b: ir.IRBuilder, instr: MirInstr) {
    i8p = ir.IntType(8).as_pointer();
    raiser = self.extern(RAISE_BUILTIN_SYMBOL, ir.VoidType(), [ir.IntType(32), i8p]);
    type_id = JAC_TYPE_REGISTRY.exception_type_id(instr.callee);
    b.call(
        raiser, [ir.Constant(ir.IntType(32), type_id), self.cstring(b, instr.str_value)]
    );
    b.unreachable();
}

impl result_of(instr: MirInstr) -> MirValue {
    found = instr.result;
    if found is None {
        raise MirEmitError(f"MIR {instr.op.value} has no result");
    }
    return found;
}

impl type_arg_of(instr: MirInstr) -> MirType {
    found = instr.type_arg;
    if found is None {
        raise MirEmitError(f"MIR {instr.op.value} has no type argument");
    }
    return found;
}
