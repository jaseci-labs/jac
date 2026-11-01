impl emit_mir_module(
    mir: MirModule, triple: str = "", native_tls: bool = False
) -> ir.Module {
    module = ir.Module(name=mir.path);
    if triple {
        module.triple = triple;
    }
    return MirEmitter(mir=mir, module=module, native_tls=native_tls).emit();
}

impl MirEmitter.emit -> ir.Module {
    for ext in self.mir.externs.values() {
        self.extern(
            ext.symbol,
            self.llvm_type(ext.ret),
            [self.llvm_type(param) for param in ext.params]
        );
    }
    if self.native_tls {
        for (label, size) in self.mir.tls_blocks.items() {
            self.tls_block(label, size);
        }
    }
    for glob_def in self.mir.globals.values() {
        self.global_variable(glob_def);
    }
    for (label, size) in self.mir.global_blocks.items() {
        self.global_block(label, size);
    }
    for fn in self.mir.functions {
        self.declare(fn);
    }
    for fn in self.mir.functions {
        self.emit_function(fn);
    }
    for obj_def in self.mir.objects.values() {
        if obj_def.local and obj_def.vtable_symbol {
            self.vtable_global(obj_def);
        }
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
    if t.kind == MirKind.STR {
        return self.str_type();
    }
    if t.kind == MirKind.OBJ and t.name != "*" {
        return self.object_struct(t.name).as_pointer();
    }
    if t.kind == MirKind.STR_REF or t.kind == MirKind.OBJ or mir_is_container(t) {
        return ir.IntType(8).as_pointer();
    }
    if t.kind == MirKind.C_PTR {
        elem = t.payload();
        if elem.kind in (MirKind.NONE, MirKind.VOID) {
            return ir.IntType(8).as_pointer();
        }
        return self.llvm_type(elem).as_pointer();
    }
    if t.kind == MirKind.C_STRUCT {
        return self.c_struct(t.name);
    }
    if t.kind == MirKind.C_VIEW {
        return ir.LiteralStructType(
            [self.llvm_type(mir_c_ptr(t.payload())), ir.IntType(64)]
        );
    }
    if t.kind == MirKind.C_FN {
        return ir.FunctionType(
            self.llvm_type(t.args[0]), [self.llvm_type(arg) for arg in t.args[1:]]
        ).as_pointer();
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
        self.bind(
            instr.result,
            b.alloca(self.llvm_type(type_arg_of(instr)), name=result_of(instr).name)
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
    } elif op == MirOp.CONST_NULL {
        self.bind(instr.result, ir.Constant(self.llvm_type(type_arg_of(instr)), None));
    } elif op == MirOp.CONST_STR {
        data = self.str_literal(b, instr.str_value);
        if type_arg_of(instr).kind == MirKind.STR {
            size = len(instr.str_value.encode("utf-8"));
            made = b.insert_value(ir.Constant(self.str_type(), None), data, 0);
            made = b.insert_value(made, data, 1);
            made = b.insert_value(made, ir.Constant(ir.IntType(64), size), 2);
            self.bind(instr.result, made);
        } else {
            self.bind(instr.result, data);
        }
    } elif op == MirOp.STR_PART {
        index = ["root", "data", "len"].index(instr.sub);
        self.bind(instr.result, b.extract_value(self.value(instr.operands[0]), index));
    } elif op == MirOp.STR_MAKE {
        made = ir.Constant(self.str_type(), None);
        for (index, part) in enumerate(instr.operands) {
            made = b.insert_value(made, self.value(part), index);
        }
        self.bind(instr.result, made);
    } elif op == MirOp.REF_CAST {
        source = self.value(instr.operands[0]);
        to = self.llvm_type(type_arg_of(instr));
        if isinstance(source.type, ir.IntType) {
            self.bind(instr.result, b.inttoptr(source, to));
        } elif source.type == to {
            self.bind(instr.result, source);
        } else {
            self.bind(instr.result, b.bitcast(source, to));
        }
    } elif op in (MirOp.RETAIN, MirOp.RELEASE) {
        self.emit_rc(b, instr);
    } elif op == MirOp.CALL_RUNTIME {
        callee = self.functions.get(instr.callee);
        if callee is None {
            raise MirEmitError(f"MIR runtime call to undeclared {instr.callee}");
        }
        made = b.call(callee, [self.value(v) for v in instr.operands]);
        self.bind(instr.result, made);
    } elif op == MirOp.SELECT {
        self.bind(
            instr.result,
            b.select(
                self.value(instr.operands[0]),
                self.value(instr.operands[1]),
                self.value(instr.operands[2])
            )
        );
    } elif op == MirOp.BITCAST {
        self.bind(
            instr.result,
            b.bitcast(
                self.value(instr.operands[0]), self.llvm_type(type_arg_of(instr))
            )
        );
    } elif op in MEMORY_OPS {
        self.emit_memory(b, instr);
    } elif op == MirOp.CALL {
        callee = self.functions.get(instr.callee);
        if callee is None {
            raise MirEmitError(f"MIR call to undeclared function {instr.callee}");
        }
        made = b.call(callee, [self.value(v) for v in instr.operands]);
        self.bind(instr.result, made);
    } elif op == MirOp.RAISE {
        self.emit_raise(b, instr);
    } elif op in C_OPS {
        self.emit_c(b, instr);
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
        if op == "shl" {
            return b.shl(l, r);
        }
        if op == "shr" {
            return b.ashr(l, r) if t.signed else b.lshr(l, r);
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

impl MirEmitter.c_struct(name: str) -> ir.Type {
    made = self.module.context.get_identified_type(f"jac.c.{name}");
    if made.is_opaque and name not in self.building {
        layout = self.mir.structs.get(name);
        if layout is None {
            raise MirEmitError(f"no layout for C struct {name}");
        }
        self.building.add(name);
        members = [self.llvm_type(member.type) for member in layout.fields];
        self.building.discard(name);
        made.set_body(*members);
    }
    return made;
}

impl MirEmitter.tls_block(label: str, size: int) -> ir.GlobalVariable {
    found = self.module.globals.get(label);
    if isinstance(found, ir.GlobalVariable) {
        return found;
    }
    cell = ir.ArrayType(ir.IntType(64), (size + 7) // 8);
    made = ir.GlobalVariable(self.module, cell, name=label);
    made.linkage = "weak";
    made.initializer = ir.Constant(cell, None);
    made.thread_local = True;
    made.tls_model = "initialexec";
    return made;
}

impl MirEmitter.emit_c(b: ir.IRBuilder, instr: MirInstr) {
    op = instr.op;
    i32 = ir.IntType(32);
    if op == MirOp.PTR_NULL {
        self.bind(instr.result, ir.Constant(self.llvm_type(type_arg_of(instr)), None));
    } elif op == MirOp.PTR_CAST {
        source = self.value(instr.operands[0]);
        to = self.llvm_type(type_arg_of(instr));
        if isinstance(source.type, ir.IntType) {
            self.bind(instr.result, b.inttoptr(source, to));
        } else {
            self.bind(instr.result, b.bitcast(source, to));
        }
    } elif op == MirOp.PTR_INT {
        self.bind(
            instr.result,
            b.ptrtoint(
                self.value(instr.operands[0]), self.llvm_type(type_arg_of(instr))
            )
        );
    } elif op == MirOp.PTR_OFFSET {
        self.bind(
            instr.result,
            b.gep(self.value(instr.operands[0]), [self.value(instr.operands[1])])
        );
    } elif op == MirOp.CSTR {
        self.bind(
            instr.result,
            b.bitcast(
                self.cstring(b, instr.str_value), self.llvm_type(type_arg_of(instr))
            )
        );
    } elif op == MirOp.VIEW {
        shape = self.llvm_type(type_arg_of(instr));
        made = b.insert_value(
            ir.Constant(shape, None), self.value(instr.operands[0]), 0
        );
        self.bind(instr.result, b.insert_value(made, self.value(instr.operands[1]), 1));
    } elif op == MirOp.VIEW_LEN {
        self.bind(instr.result, b.extract_value(self.value(instr.operands[0]), 1));
    } elif op == MirOp.ELEM_ADDR {
        base = b.extract_value(self.value(instr.operands[0]), 0);
        self.bind(instr.result, b.gep(base, [self.value(instr.operands[1])]));
    } elif op == MirOp.FIELD_ADDR {
        self.bind(
            instr.result,
            b.gep(
                self.value(instr.operands[0]),
                [ir.Constant(i32, 0), ir.Constant(i32, instr.int_value)]
            )
        );
    } elif op == MirOp.GLOBAL_ADDR {
        self.bind(instr.result, self.module.globals[instr.str_value]);
    } elif op == MirOp.TLS_BLOCK {
        if self.native_tls {
            block = self.tls_block(instr.str_value, instr.int_value);
            self.bind(instr.result, b.ptrtoint(block, ir.IntType(64)));
        } else {
            self.bind(
                instr.result,
                b.call(self.keyed_block_fn(instr.str_value, instr.int_value), [])
            );
        }
    } elif op == MirOp.EXC_FRAME {
        frame = b.alloca(ir.ArrayType(ir.IntType(64), EXC_FRAME_BYTES // 8));
        self.bind(instr.result, b.bitcast(frame, ir.IntType(8).as_pointer()));
    } elif op == MirOp.SETJMP {
        i8p = ir.IntType(8).as_pointer();
        jump = self.extern(SETJMP_SYMBOL, ir.IntType(32), [i8p]);
        jump.attributes.add("returns_twice");
        self.bind(instr.result, b.call(jump, [self.value(instr.operands[0])]));
    } elif op == MirOp.SIZEOF {
        shape = self.llvm_type(type_arg_of(instr));
        pointee: ir.Type = shape;
        if isinstance(shape, ir.PointerType) and shape.pointee is not None {
            pointee = shape.pointee;
        }
        past = b.gep(ir.Constant(pointee.as_pointer(), None), [ir.Constant(ir.IntType(32), 1)]);
        self.bind(instr.result, b.ptrtoint(past, ir.IntType(64)));
    } elif op == MirOp.VTABLE_ADDR {
        obj_def = self.mir.objects[instr.str_value];
        self.bind(
            instr.result,
            b.bitcast(self.vtable_global(obj_def), ir.IntType(8).as_pointer().as_pointer())
        );
    } elif op == MirOp.GLOBAL_BLOCK {
        block = self.global_block(instr.str_value, instr.int_value);
        self.bind(instr.result, b.ptrtoint(block, ir.IntType(64)));
    } elif op == MirOp.FN_ADDR {
        target = self.functions.get(instr.callee);
        if target is None {
            raise MirEmitError(f"MIR address of undeclared function {instr.callee}");
        }
        self.bind(instr.result, target);
    } elif op == MirOp.CALL_DTOR {
        i8p = ir.IntType(8).as_pointer();
        dtor_type = ir.FunctionType(ir.VoidType(), [i8p]).as_pointer();
        b.call(
            b.inttoptr(self.value(instr.operands[0]), dtor_type),
            [b.inttoptr(self.value(instr.operands[1]), i8p)]
        );
    } elif op == MirOp.CALL_C {
        callee = self.functions.get(instr.callee);
        if callee is None {
            raise MirEmitError(f"MIR C call to undeclared function {instr.callee}");
        }
        made = b.call(callee, [self.value(v) for v in instr.operands]);
        if type_arg_of(instr).kind != MirKind.NONE {
            self.bind(instr.result, made);
        }
    } elif op == MirOp.CALL_FNPTR {
        made = b.call(
            self.value(instr.operands[0]), [self.value(v) for v in instr.operands[1:]]
        );
        if type_arg_of(instr).kind != MirKind.NONE {
            self.bind(instr.result, made);
        }
    } else {
        raise MirEmitError(f"no emitter for MIR instruction {op.value}");
    }
}

impl MirEmitter.global_block(label: str, size: int) -> ir.GlobalVariable {
    found = self.module.globals.get(label);
    if isinstance(found, ir.GlobalVariable) {
        return found;
    }
    shape = ir.ArrayType(ir.IntType(64), (max(size, 1) + 7) // 8);
    made = ir.GlobalVariable(self.module, shape, name=label);
    made.linkage = "weak";
    made.initializer = ir.Constant(shape, None);
    made.align = 16;
    return made;
}

impl MirEmitter.global_variable(glob_def: MirGlobal) -> ir.GlobalVariable {
    found = self.module.globals.get(glob_def.symbol);
    if isinstance(found, ir.GlobalVariable) {
        return found;
    }
    shape = self.llvm_type(glob_def.type);
    made = ir.GlobalVariable(self.module, shape, name=glob_def.symbol);
    made.linkage = glob_def.linkage;
    if glob_def.type.kind == MirKind.FLOAT {
        made.initializer = ir.Constant(shape, glob_def.float_value);
    } elif glob_def.type.kind in (MirKind.INT, MirKind.BOOL) {
        made.initializer = ir.Constant(shape, glob_def.int_value);
    } else {
        made.initializer = ir.Constant(shape, None);
    }
    return made;
}

impl MirEmitter.keyed_block_fn(label: str, size: int) -> ir.Function {
    name = f"__jac_tls_block.{label}";
    found = self.module.globals.get(name);
    if isinstance(found, ir.Function) {
        return found;
    }
    i8p = ir.IntType(8).as_pointer();
    i32 = ir.IntType(32);
    i64 = ir.IntType(64);
    key_gv = ir.GlobalVariable(self.module, i64, name=f"{label}.key");
    key_gv.linkage = "weak";
    key_gv.initializer = ir.Constant(i64, 0);
    ready_gv = ir.GlobalVariable(self.module, i32, name=f"{label}.ready");
    ready_gv.linkage = "weak";
    ready_gv.initializer = ir.Constant(i32, 0);
    key_create = self.extern("pthread_key_create", i32, [i8p, i8p]);
    get_specific = self.extern("pthread_getspecific", i8p, [i64]);
    set_specific = self.extern("pthread_setspecific", i32, [i64, i8p]);
    zalloc = self.extern("calloc", i8p, [i64, i64]);
    func = ir.Function(self.module, ir.FunctionType(i64, []), name=name);
    func.linkage = "linkonce_odr";
    first = func.append_basic_block("entry");
    claim = func.append_basic_block("claim");
    make_key = func.append_basic_block("make_key");
    spin = func.append_basic_block("spin");
    keyed = func.append_basic_block("keyed");
    create = func.append_basic_block("create");
    done = func.append_basic_block("done");
    b = ir.IRBuilder(first);
    ready = b.load_atomic(ready_gv, "acquire", 4);
    b.cbranch(b.icmp_unsigned("==", ready, ir.Constant(i32, 2)), keyed, claim);
    b.position_at_end(claim);
    pair = b.cmpxchg(
        ready_gv, ir.Constant(i32, 0), ir.Constant(i32, 1), "acq_rel", "acquire"
    );
    b.cbranch(b.extract_value(pair, 1), make_key, spin);
    b.position_at_end(make_key);
    b.call(key_create, [b.bitcast(key_gv, i8p), ir.Constant(i8p, None)]);
    b.store_atomic(ir.Constant(i32, 2), ready_gv, "release", 4);
    b.branch(keyed);
    b.position_at_end(spin);
    again = b.load_atomic(ready_gv, "acquire", 4);
    b.cbranch(b.icmp_unsigned("==", again, ir.Constant(i32, 2)), keyed, spin);
    b.position_at_end(keyed);
    key = b.load(key_gv);
    held = b.call(get_specific, [key]);
    b.cbranch(b.icmp_unsigned("==", held, ir.Constant(i8p, None)), create, done);
    b.position_at_end(create);
    made = b.call(zalloc, [ir.Constant(i64, 1), ir.Constant(i64, size)]);
    b.call(set_specific, [key, made]);
    b.branch(done);
    b.position_at_end(done);
    block = b.phi(i8p);
    block.add_incoming(held, keyed);
    block.add_incoming(made, create);
    b.ret(b.ptrtoint(block, i64));
    return func;
}

impl MirEmitter.emit_memory(b: ir.IRBuilder, instr: MirInstr) {
    op = instr.op;
    if op == MirOp.FENCE {
        if instr.str_value != "monotonic" {
            b.fence(instr.str_value);
        }
        return;
    }
    cell = self.llvm_type(
        instr.operands[1].type
            if op in (MirOp.MEM_STORE, MirOp.ATOMIC_STORE)
            else type_arg_of(instr)
    );
    address = b.inttoptr(self.value(instr.operands[0]), cell.as_pointer());
    width = cell.width if isinstance(cell, ir.IntType) else 64;
    align = max(width // 8, 1);
    if op == MirOp.MEM_LOAD {
        self.bind(instr.result, b.load(address));
    } elif op == MirOp.MEM_STORE {
        b.store(self.value(instr.operands[1]), address);
    } elif op == MirOp.ATOMIC_LOAD {
        self.bind(instr.result, b.load_atomic(address, instr.str_value, align));
    } elif op == MirOp.ATOMIC_STORE {
        b.store_atomic(
            self.value(instr.operands[1]), address, instr.str_value, align
        );
    } elif op == MirOp.ATOMIC_RMW {
        self.bind(
            instr.result,
            b.atomic_rmw(
                instr.sub,
                address,
                self.value(instr.operands[1]),
                ordering=instr.str_value
            )
        );
    } elif op == MirOp.ATOMIC_CAS {
        order = instr.str_value;
        failure = "acquire"
            if order == "acq_rel"
            else ("monotonic" if order == "release" else order);
        pair = b.cmpxchg(
            address,
            self.value(instr.operands[1]),
            self.value(instr.operands[2]),
            order,
            failure
        );
        self.bind(instr.result, b.extract_value(pair, 0));
    }
}

impl MirEmitter.str_type -> ir.Type {
    shape = self.module.context.get_identified_type("JacStr");
    if shape.is_opaque {
        i8p = ir.IntType(8).as_pointer();
        shape.set_body(i8p, i8p, ir.IntType(64));
    }
    return shape;
}

impl MirEmitter.str_literal(b: ir.IRBuilder, text: str) -> ir.Value {
    found = self.literals.get(text);
    if found is None {
        data = (text + "\0").encode("utf-8");
        i64 = ir.IntType(64);
        chars = ir.ArrayType(ir.IntType(8), len(data));
        shape = ir.LiteralStructType([i64, i64, chars]);
        found = ir.GlobalVariable(
            self.module, shape, name=f".jac.str.{len(self.literals)}"
        );
        found.linkage = "private";
        found.global_constant = True;
        found.initializer = ir.Constant(
            shape,
            [
                ir.Constant(i64, RC_SENTINEL),
                ir.Constant(
                    i64, str_len_tag(len(data) - 1, all(byte < 0x80 for byte in data))
                ),
                ir.Constant(chars, bytearray(data))
            ]
        );
        self.literals[text] = found;
    }
    i32 = ir.IntType(32);
    return b.gep(found, [ir.Constant(i32, 0), ir.Constant(i32, 2), ir.Constant(i32, 0)]);
}

impl MirEmitter.emit_rc(b: ir.IRBuilder, instr: MirInstr) {
    subject = instr.operands[0];
    i8p = ir.IntType(8).as_pointer();
    target = self.value(subject);
    if subject.type.kind == MirKind.STR {
        target = b.extract_value(target, 0);
    } elif target.type != i8p {
        target = b.bitcast(target, i8p);
    }
    if instr.op == MirOp.RETAIN {
        b.call(self.extern(RETAIN_SYMBOL, ir.VoidType(), [i8p]), [target]);
        self.bind(instr.result, self.value(subject));
        return;
    }
    symbol = RELEASE_ACYCLIC_SYMBOL
        if subject.type.kind in (MirKind.STR, MirKind.STR_REF)
        else RELEASE_SYMBOL;
    b.call(self.extern(symbol, ir.VoidType(), [i8p]), [target]);
}

impl MirEmitter.object_struct(name: str) -> ir.Type {
    shape = self.module.context.get_identified_type(name);
    if not shape.is_opaque or name in self.building {
        return shape;
    }
    obj_def = self.mir.objects.get(name);
    if obj_def is None {
        raise MirEmitError(f"MIR object {name} has no layout");
    }
    self.building.add(name);
    i8p = ir.IntType(8).as_pointer();
    slots: list[ir.Type] = [];
    for _ in range(obj_def.slot_count) {
        slots.append(ir.IntType(64));
    }
    if obj_def.vtable_slot >= 0 {
        slots[obj_def.vtable_slot] = i8p.as_pointer();
    }
    if obj_def.reports_slot >= 0 {
        slots[obj_def.reports_slot] = i8p;
    }
    for member in obj_def.fields {
        slots[member.index] = self.llvm_type(member.type);
    }
    shape.set_body(*slots);
    self.building.discard(name);
    return shape;
}

impl MirEmitter.vtable_global(obj_def: MirObjectDef) -> ir.GlobalVariable {
    found = self.module.globals.get(obj_def.vtable_symbol);
    i8p = ir.IntType(8).as_pointer();
    if isinstance(found, ir.GlobalVariable) and (found.initializer is not None or not obj_def.local) {
        return found;
    }
    shape = ir.ArrayType(i8p, len(obj_def.vtable_methods) + VTABLE_HEADER_SLOTS);
    made = found
        if isinstance(found, ir.GlobalVariable)
        else ir.GlobalVariable(self.module, shape, name=obj_def.vtable_symbol);
    if not obj_def.local {
        return made;
    }
    lineage = [
        b_sym
        for b_sym in obj_def.ancestry
    ];
    lineage_shape = ir.ArrayType(i8p, len(lineage) + 1);
    lineage_global = ir.GlobalVariable(
        self.module, lineage_shape, name=f"{obj_def.vtable_symbol}.ancestry"
    );
    lineage_global.linkage = "private";
    lineage_global.global_constant = True;
    members: list[ir.Value] = [];
    for symbol in lineage {
        holder = self.module.globals.get(symbol);
        if holder is None {
            holder = ir.GlobalVariable(self.module, ir.ArrayType(i8p, VTABLE_HEADER_SLOTS), name=symbol);
        }
        members.append(holder.bitcast(i8p));
    }
    members.append(ir.Constant(i8p, None));
    lineage_global.initializer = ir.Constant(lineage_shape, members);
    name_text = (obj_def.name + "\0").encode("utf-8");
    name_global = ir.GlobalVariable(
        self.module,
        ir.ArrayType(ir.IntType(8), len(name_text)),
        name=f"{obj_def.vtable_symbol}.name"
    );
    name_global.linkage = "private";
    name_global.global_constant = True;
    name_global.initializer = ir.Constant(
        ir.ArrayType(ir.IntType(8), len(name_text)), bytearray(name_text)
    );
    entries: list[ir.Value] = [
        name_global.bitcast(i8p), lineage_global.bitcast(i8p), ir.Constant(i8p, None)
    ];
    for symbol in obj_def.vtable_methods {
        target = self.functions.get(symbol);
        entries.append(target.bitcast(i8p) if target is not None else ir.Constant(i8p, None));
    }
    made.initializer = ir.Constant(shape, entries);
    made.global_constant = True;
    return made;
}
