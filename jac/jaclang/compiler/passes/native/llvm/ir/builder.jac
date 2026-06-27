import contextlib;
import functools;
import from jaclang.compiler.passes.native.llvm.ir { instructions, types, values }
with entry {
    _CMP_MAP = {'>': 'gt', '<': 'lt', '==': 'eq', '!=': 'ne', '>=': 'ge', '<=': 'le'};
}

def _unop(opname: Any, cls: Any = instructions.Instruction) -> object {
    def wrap(fn: Any) -> object {
        @functools.wraps(fn)
        def wrapped(self: Any, arg: Any, name: Any = '', flags: Any = ()) -> object {
            instr = cls(self.block, arg.type, opname, [arg], name, flags);
            self._insert(instr);
            return instr;
        }
        return wrapped;
    }
    return wrap;
}

def _binop(opname: Any, cls: Any = instructions.Instruction) -> object {
    def wrap(fn: Any) -> object {
        @functools.wraps(fn)
        def wrapped(
            self: Any, lhs: Any, rhs: Any, name: Any = '', flags: Any = ()
        ) -> object {
            if (lhs.type != rhs.type) {
                raise ValueError(
                    (
                        "Operands must be the same type, got (%s, %s)" % (
                            lhs.type,
                            rhs.type
                        )
                    )
                );
            }
            instr = cls(self.block, lhs.type, opname, (lhs, rhs), name, flags);
            self._insert(instr);
            return instr;
        }
        return wrapped;
    }
    return wrap;
}

def _binop_with_overflow(opname: Any, cls: Any = instructions.Instruction) -> object {
    def wrap(fn: Any) -> object {
        @functools.wraps(fn)
        def wrapped(self: Any, lhs: Any, rhs: Any, name: Any = '') -> object {
            if (lhs.type != rhs.type) {
                raise ValueError(
                    (
                        "Operands must be the same type, got (%s, %s)" % (
                            lhs.type,
                            rhs.type
                        )
                    )
                );
            }
            ty = lhs.type;
            if not isinstance(ty, types.IntType) {
                raise TypeError(("expected an integer type, got %s" % (ty, )));
            }
            bool_ty = types.IntType(1);
            mod = self.module;
            fnty = types.FunctionType(types.LiteralStructType([ty, bool_ty]), [ty, ty]);
            fn = mod.declare_intrinsic(
                ("llvm.%s.with.overflow" % (opname, )), [ty], fnty
            );
            ret = self.call(fn, [lhs, rhs], name=name);
            return ret;
        }
        return wrapped;
    }
    return wrap;
}

def _uniop(opname: Any, cls: Any = instructions.Instruction) -> object {
    def wrap(fn: Any) -> object {
        @functools.wraps(fn)
        def wrapped(self: Any, operand: Any, name: Any = '') -> object {
            instr = cls(self.block, operand.type, opname, [operand], name);
            self._insert(instr);
            return instr;
        }
        return wrapped;
    }
    return wrap;
}

def _uniop_intrinsic_int(opname: Any) -> object {
    def wrap(fn: Any) -> object {
        @functools.wraps(fn)
        def wrapped(self: Any, operand: Any, name: Any = '') -> object {
            if not isinstance(operand.type, types.IntType) {
                raise TypeError(("expected an integer type, got %s" % operand.type));
            }
            fn = self.module.declare_intrinsic(opname, [operand.type]);
            return self.call(fn, [operand], name);
        }
        return wrapped;
    }
    return wrap;
}

def _uniop_intrinsic_float(opname: Any) -> object {
    def wrap(fn: Any) -> object {
        @functools.wraps(fn)
        def wrapped(self: Any, operand: Any, name: Any = '') -> object {
            if not isinstance(operand.type, (types.FloatType, types.DoubleType)) {
                raise TypeError(("expected a float type, got %s" % operand.type));
            }
            fn = self.module.declare_intrinsic(opname, [operand.type]);
            return self.call(fn, [operand], name);
        }
        return wrapped;
    }
    return wrap;
}

def _uniop_intrinsic_with_flag(opname: Any) -> object {
    def wrap(fn: Any) -> object {
        @functools.wraps(fn)
        def wrapped(self: Any, operand: Any, flag: Any, name: Any = '') -> object {
            if not isinstance(operand.type, types.IntType) {
                raise TypeError(("expected an integer type, got %s" % operand.type));
            }
            if not (isinstance(flag.type, types.IntType) and (flag.type.width == 1)) {
                raise TypeError(("expected an i1 type, got %s" % flag.type));
            }
            fn = self.module.declare_intrinsic(opname, [operand.type, flag.type]);
            return self.call(fn, [operand, flag], name);
        }
        return wrapped;
    }
    return wrap;
}

def _triop_intrinsic(opname: Any) -> object {
    def wrap(fn: Any) -> object {
        @functools.wraps(fn)
        def wrapped(self: Any, a: Any, b: Any, c: Any, name: Any = '') -> object {
            if ((a.type != b.type) or (b.type != c.type)) {
                raise TypeError(
                    (
                        "expected types to be the same, got %s, %s, %s" % (
                            a.type,
                            b.type,
                            c.type
                        )
                    )
                );
            } elif not isinstance(
                a.type, (types.HalfType, types.FloatType, types.DoubleType)
            ) {
                raise TypeError(("expected an floating point type, got %s" % a.type));
            }
            fn = self.module.declare_intrinsic(opname, [a.type, b.type, c.type]);
            return self.call(fn, [a, b, c], name);
        }
        return wrapped;
    }
    return wrap;
}

def _castop(opname: Any, cls: Any = instructions.CastInstr) -> object {
    def wrap(fn: Any) -> object {
        @functools.wraps(fn)
        def wrapped(self: Any, val: Any, typ: Any, name: Any = '') -> object {
            if (val.type == typ) {
                return val;
            }
            instr = cls(self.block, opname, val, typ, name);
            self._insert(instr);
            return instr;
        }
        return wrapped;
    }
    return wrap;
}

def _label_suffix(label: Any, suffix: Any) -> object {
    if (len(label) > 50) {
        nhead = 25;
        return ''.join([label[:nhead], '..', suffix]);
    } else {
        return (label + suffix);
    }
}

class IRBuilder(object) {
    def init(self: IRBuilder, block: Any = None) -> object {
        self._block = block;
        self._anchor = len(block.instructions) if block else 0;
        self.debug_metadata = None;
    }

    @property
    def block(self: IRBuilder) -> object {
        return self._block;
    }

    with entry {
        basic_block = block;
    }

    @property
    def function(self: IRBuilder) -> object {
        return self.block.parent;
    }

    @property
    def module(self: IRBuilder) -> object {
        return self.block.parent.module;
    }

    def position_before(self: IRBuilder, instr: Any) -> object {
        self._block = instr.parent;
        self._anchor = self._block.instructions.index(instr);
    }

    def position_after(self: IRBuilder, instr: Any) -> object {
        self._block = instr.parent;
        self._anchor = self._block.instructions.index(instr) + 1;
    }

    def position_at_start(self: IRBuilder, block: Any) -> object {
        self._block = block;
        self._anchor = 0;
    }

    def position_at_end(self: IRBuilder, block: Any) -> object {
        self._block = block;
        self._anchor = len(block.instructions);
    }

    def append_basic_block(self: IRBuilder, name: Any = '') -> object {
        return self.function.append_basic_block(name);
    }

    def remove(self: IRBuilder, instr: Any) -> object {
        idx = self._block.instructions.index(instr);
        del self._block.instructions[idx];
        if (self._block.terminator == instr) {
            self._block.terminator = None;
        }
        if (self._anchor > idx) {
            self._anchor -= 1;
        }
    }

    @contextlib.contextmanager
    def goto_block(self: IRBuilder, block: Any) -> object {
        old_block = self.basic_block;
        term = block.terminator;
        if (term is not None) {
            self.position_before(term);
        } else {
            self.position_at_end(block);
        }
        try {
            yield ;
        } finally {
            self.position_at_end(old_block);
        }
    }

    @contextlib.contextmanager
    def goto_entry_block(self: IRBuilder) -> object {
        with self.goto_block(self.function.entry_basic_block) {
            yield ;
        }
    }

    @contextlib.contextmanager
    def _branch_helper(self: IRBuilder, bbenter: Any, bbexit: Any) -> object {
        self.position_at_end(bbenter);
        yield bbexit;
        if (self.basic_block.terminator is None) {
            self.branch(bbexit);
        }
    }

    @contextlib.contextmanager
    def if_then(self: IRBuilder, pred: Any, likely: Any = None) -> object {
        bb = self.basic_block;
        bbif = self.append_basic_block(name=_label_suffix(bb.name, '.if'));
        bbend = self.append_basic_block(name=_label_suffix(bb.name, '.endif'));
        br = self.cbranch(pred, bbif, bbend);
        if (likely is not None) {
            br.set_weights([99, 1] if likely else [1, 99]);
        }
        with self._branch_helper(bbif, bbend) {
            yield bbend;
        }
        self.position_at_end(bbend);
    }

    @contextlib.contextmanager
    def if_else(self: IRBuilder, pred: Any, likely: Any = None) -> object {
        bb = self.basic_block;
        bbif = self.append_basic_block(name=_label_suffix(bb.name, '.if'));
        bbelse = self.append_basic_block(name=_label_suffix(bb.name, '.else'));
        bbend = self.append_basic_block(name=_label_suffix(bb.name, '.endif'));
        br = self.cbranch(pred, bbif, bbelse);
        if (likely is not None) {
            br.set_weights([99, 1] if likely else [1, 99]);
        }
        then = self._branch_helper(bbif, bbend);
        otherwise = self._branch_helper(bbelse, bbend);
        yield (then, otherwise);
        self.position_at_end(bbend);
    }

    def _insert(self: IRBuilder, instr: Any) -> object {
        if ((self.debug_metadata is not None) and ('dbg' not in instr.metadata)) {
            instr.metadata['dbg'] = self.debug_metadata;
        }
        self._block.instructions.insert(self._anchor, instr);
        self._anchor += 1;
    }

    def _set_terminator(self: IRBuilder, term: Any) -> object {
        assert not self.block.is_terminated;
        self._insert(term);
        self.block.terminator = term;
        return term;
    }

    @_binop('shl')
    def shl(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop('lshr')
    def lshr(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop('ashr')
    def ashr(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop('add')
    def add(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop('fadd')
    def fadd(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop('sub')
    def sub(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop('fsub')
    def fsub(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop('mul')
    def mul(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop('fmul')
    def fmul(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop('udiv')
    def udiv(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop('sdiv')
    def sdiv(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop('fdiv')
    def fdiv(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop('urem')
    def urem(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop('srem')
    def srem(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop('frem')
    def frem(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop('or')
    def or_(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop('and')
    def and_(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop('xor')
    def xor(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    @_binop_with_overflow('sadd')
    def sadd_with_overflow(
        self: IRBuilder, lhs: Any, rhs: Any, name: Any = ''
    ) -> object { }

    @_binop_with_overflow('smul')
    def smul_with_overflow(
        self: IRBuilder, lhs: Any, rhs: Any, name: Any = ''
    ) -> object { }

    @_binop_with_overflow('ssub')
    def ssub_with_overflow(
        self: IRBuilder, lhs: Any, rhs: Any, name: Any = ''
    ) -> object { }

    @_binop_with_overflow('uadd')
    def uadd_with_overflow(
        self: IRBuilder, lhs: Any, rhs: Any, name: Any = ''
    ) -> object { }

    @_binop_with_overflow('umul')
    def umul_with_overflow(
        self: IRBuilder, lhs: Any, rhs: Any, name: Any = ''
    ) -> object { }

    @_binop_with_overflow('usub')
    def usub_with_overflow(
        self: IRBuilder, lhs: Any, rhs: Any, name: Any = ''
    ) -> object { }

    def not_(self: IRBuilder, value: Any, name: Any = '') -> object {
        if isinstance(value.type, types.VectorType) {
            rhs = values.Constant(value.type, ((-1, ) * value.type.count));
        } else {
            rhs = values.Constant(value.type, -1);
        }
        return self.xor(value, rhs, name=name);
    }

    def neg(self: IRBuilder, value: Any, name: Any = '') -> object {
        return self.sub(values.Constant(value.type, 0), value, name=name);
    }

    @_unop('fneg')
    def fneg(self: IRBuilder, arg: Any, name: Any = '', flags: Any = ()) -> object { }

    def _icmp(
        self: IRBuilder, prefix: Any, cmpop: Any, lhs: Any, rhs: Any, name: Any
    ) -> object {
        try {
            op = _CMP_MAP[cmpop];
        } except KeyError {
            raise ValueError(("invalid comparison %r for icmp" % (cmpop, )));
        }
        if (cmpop not in ('==', '!=')) {
            op = prefix + op;
        }
        instr = instructions.ICMPInstr(self.block, op, lhs, rhs, name=name);
        self._insert(instr);
        return instr;
    }

    def icmp_signed(
        self: IRBuilder, cmpop: Any, lhs: Any, rhs: Any, name: Any = ''
    ) -> object {
        return self._icmp('s', cmpop, lhs, rhs, name);
    }

    def icmp_unsigned(
        self: IRBuilder, cmpop: Any, lhs: Any, rhs: Any, name: Any = ''
    ) -> object {
        return self._icmp('u', cmpop, lhs, rhs, name);
    }

    def fcmp_ordered(
        self: IRBuilder, cmpop: Any, lhs: Any, rhs: Any, name: Any = '', flags: Any = ()
    ) -> object {
        if (cmpop in _CMP_MAP) {
            op = 'o' + _CMP_MAP[cmpop];
        } else {
            op = cmpop;
        }
        instr = instructions.FCMPInstr(
            self.block, op, lhs, rhs, name=name, flags=flags
        );
        self._insert(instr);
        return instr;
    }

    def fcmp_unordered(
        self: IRBuilder, cmpop: Any, lhs: Any, rhs: Any, name: Any = '', flags: Any = ()
    ) -> object {
        if (cmpop in _CMP_MAP) {
            op = 'u' + _CMP_MAP[cmpop];
        } else {
            op = cmpop;
        }
        instr = instructions.FCMPInstr(
            self.block, op, lhs, rhs, name=name, flags=flags
        );
        self._insert(instr);
        return instr;
    }

    def select(
        self: IRBuilder, cond: Any, lhs: Any, rhs: Any, name: Any = '', flags: Any = ()
    ) -> object {
        instr = instructions.SelectInstr(
            self.block, cond, lhs, rhs, name=name, flags=flags
        );
        self._insert(instr);
        return instr;
    }

    @_castop('trunc')
    def trunc(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    @_castop('zext')
    def zext(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    @_castop('sext')
    def sext(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    @_castop('fptrunc')
    def fptrunc(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    @_castop('fpext')
    def fpext(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    @_castop('bitcast')
    def bitcast(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    @_castop('addrspacecast')
    def addrspacecast(
        self: IRBuilder, value: Any, typ: Any, name: Any = ''
    ) -> object { }

    @_castop('fptoui')
    def fptoui(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    @_castop('uitofp')
    def uitofp(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    @_castop('fptosi')
    def fptosi(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    @_castop('sitofp')
    def sitofp(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    @_castop('ptrtoint')
    def ptrtoint(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    @_castop('inttoptr')
    def inttoptr(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    def alloca(self: IRBuilder, typ: Any, size: Any = None, name: Any = '') -> object {
        if (size is None) {
            ;
        } elif isinstance(size, (values.Value, values.Constant)) {
            assert isinstance(size.type, types.IntType);
        } else {
            size = values.Constant(types.IntType(32), size);
        }
        al = instructions.AllocaInstr(self.block, typ, size, name);
        self._insert(al);
        return al;
    }

    def load(
        self: IRBuilder, ptr: Any, name: Any = '', align: Any = None, typ: Any = None
    ) -> object {
        if not isinstance(ptr.type, types.PointerType) {
            msg = "cannot load from value of type %s (%r): not a pointer";
            raise TypeError((msg % (ptr.type, str(ptr))));
        }
        ld = instructions.LoadInstr(self.block, ptr, name, typ=typ);
        ld.align = align;
        self._insert(ld);
        return ld;
    }

    def store(self: IRBuilder, value: Any, ptr: Any, align: Any = None) -> object {
        if not isinstance(ptr.type, types.PointerType) {
            msg = "cannot store to value of type %s (%r): not a pointer";
            raise TypeError((msg % (ptr.type, str(ptr))));
        }
        if (not ptr.type.is_opaque and (ptr.type.pointee != value.type)) {
            raise TypeError(
                ("cannot store %s to %s: mismatching types" % (value.type, ptr.type))
            );
        }
        st = instructions.StoreInstr(self.block, value, ptr);
        st.align = align;
        self._insert(st);
        return st;
    }

    def load_atomic(
        self: IRBuilder,
        ptr: Any,
        ordering: Any,
        align: Any,
        name: Any = '',
        typ: Any = None
    ) -> object {
        if not isinstance(ptr.type, types.PointerType) {
            msg = "cannot load from value of type %s (%r): not a pointer";
            raise TypeError((msg % (ptr.type, str(ptr))));
        }
        ld = instructions.LoadAtomicInstr(
            self.block, ptr, ordering, align, name, typ=typ
        );
        self._insert(ld);
        return ld;
    }

    def store_atomic(
        self: IRBuilder, value: Any, ptr: Any, ordering: Any, align: Any
    ) -> object {
        if not isinstance(ptr.type, types.PointerType) {
            msg = "cannot store to value of type %s (%r): not a pointer";
            raise TypeError((msg % (ptr.type, str(ptr))));
        }
        if (ptr.type.pointee != value.type) {
            raise TypeError(
                ("cannot store %s to %s: mismatching types" % (value.type, ptr.type))
            );
        }
        st = instructions.StoreAtomicInstr(self.block, value, ptr, ordering, align);
        self._insert(st);
        return st;
    }

    def `switch(self: IRBuilder, value: Any, `default: Any) -> object {
        swt = instructions.SwitchInstr(self.block, 'switch', value, `default);
        self._set_terminator(swt);
        return swt;
    }

    def branch(self: IRBuilder, target: Any) -> object {
        br = instructions.Branch(self.block, "br", [target]);
        self._set_terminator(br);
        return br;
    }

    def cbranch(self: IRBuilder, cond: Any, truebr: Any, falsebr: Any) -> object {
        br = instructions.ConditionalBranch(self.block, "br", [cond, truebr, falsebr]);
        self._set_terminator(br);
        return br;
    }

    def branch_indirect(self: IRBuilder, addr: Any) -> object {
        br = instructions.IndirectBranch(self.block, "indirectbr", addr);
        self._set_terminator(br);
        return br;
    }

    def ret_void(self: IRBuilder) -> object {
        return self._set_terminator(instructions.Ret(self.block, "ret void"));
    }

    def ret(self: IRBuilder, value: Any) -> object {
        return self._set_terminator(instructions.Ret(self.block, "ret", value));
    }

    def resume(self: IRBuilder, landingpad: Any) -> object {
        br = instructions.Branch(self.block, "resume", [landingpad]);
        self._set_terminator(br);
        return br;
    }

    def call(
        self: IRBuilder,
        fn: Any,
        args: Any,
        name: Any = '',
        cconv: Any = None,
        tail: Any = False,
        fastmath: Any = (),
        attrs: Any = (),
        arg_attrs: Any = None
    ) -> object {
        inst = instructions.CallInstr(
            self.block,
            fn,
            args,
            name=name,
            cconv=cconv,
            tail=tail,
            fastmath=fastmath,
            attrs=attrs,
            arg_attrs=arg_attrs
        );
        self._insert(inst);
        return inst;
    }

    def asm(
        self: IRBuilder,
        ftype: Any,
        asm: Any,
        constraint: Any,
        args: Any,
        side_effect: Any,
        name: Any = ''
    ) -> object {
        asm = instructions.InlineAsm(ftype, asm, constraint, side_effect);
        return self.call(asm, args, name);
    }

    def load_reg(
        self: IRBuilder, reg_type: Any, reg_name: Any, name: Any = ''
    ) -> object {
        ftype = types.FunctionType(reg_type, []);
        return self.asm(ftype, "", ("={%s}" % reg_name), [], False, name);
    }

    def store_reg(
        self: IRBuilder, value: Any, reg_type: Any, reg_name: Any, name: Any = ''
    ) -> object {
        ftype = types.FunctionType(types.VoidType(), [reg_type]);
        return self.asm(ftype, "", ("{%s}" % reg_name), [value], True, name);
    }

    def invoke(
        self: IRBuilder,
        fn: Any,
        args: Any,
        normal_to: Any,
        unwind_to: Any,
        name: Any = '',
        cconv: Any = None,
        fastmath: Any = (),
        attrs: Any = (),
        arg_attrs: Any = None
    ) -> object {
        inst = instructions.InvokeInstr(
            self.block,
            fn,
            args,
            normal_to,
            unwind_to,
            name=name,
            cconv=cconv,
            fastmath=fastmath,
            attrs=attrs,
            arg_attrs=arg_attrs
        );
        self._set_terminator(inst);
        return inst;
    }

    def gep(
        self: IRBuilder,
        ptr: Any,
        indices: Any,
        inbounds: Any = False,
        name: Any = '',
        source_etype: Any = None
    ) -> object {
        instr = instructions.GEPInstr(
            self.block,
            ptr,
            indices,
            inbounds=inbounds,
            name=name,
            source_etype=source_etype
        );
        self._insert(instr);
        return instr;
    }

    def extract_element(
        self: IRBuilder, vector: Any, idx: Any, name: Any = ''
    ) -> object {
        instr = instructions.ExtractElement(self.block, vector, idx, name=name);
        self._insert(instr);
        return instr;
    }

    def insert_element(
        self: IRBuilder, vector: Any, value: Any, idx: Any, name: Any = ''
    ) -> object {
        instr = instructions.InsertElement(self.block, vector, value, idx, name=name);
        self._insert(instr);
        return instr;
    }

    def shuffle_vector(
        self: IRBuilder, vector1: Any, vector2: Any, mask: Any, name: Any = ''
    ) -> object {
        instr = instructions.ShuffleVector(
            self.block, vector1, vector2, mask, name=name
        );
        self._insert(instr);
        return instr;
    }

    def extract_value(self: IRBuilder, agg: Any, idx: Any, name: Any = '') -> object {
        if not isinstance(idx, (`tuple, `list)) {
            idx = [idx];
        }
        instr = instructions.ExtractValue(self.block, agg, idx, name=name);
        self._insert(instr);
        return instr;
    }

    def insert_value(
        self: IRBuilder, agg: Any, value: Any, idx: Any, name: Any = ''
    ) -> object {
        if not isinstance(idx, (`tuple, `list)) {
            idx = [idx];
        }
        instr = instructions.InsertValue(self.block, agg, value, idx, name=name);
        self._insert(instr);
        return instr;
    }

    def phi(self: IRBuilder, typ: Any, name: Any = '', flags: Any = ()) -> object {
        inst = instructions.PhiInstr(self.block, typ, name=name, flags=flags);
        self._insert(inst);
        return inst;
    }

    def unreachable(self: IRBuilder) -> object {
        inst = instructions.Unreachable(self.block);
        self._set_terminator(inst);
        return inst;
    }

    def atomic_rmw(
        self: IRBuilder, op: Any, ptr: Any, val: Any, ordering: Any, name: Any = ''
    ) -> object {
        inst = instructions.AtomicRMW(self.block, op, ptr, val, ordering, name=name);
        self._insert(inst);
        return inst;
    }

    def cmpxchg(
        self: IRBuilder,
        ptr: Any,
        cmp: Any,
        val: Any,
        ordering: Any,
        failordering: Any = None,
        name: Any = ''
    ) -> object {
        failordering = ordering if (failordering is None) else failordering;
        inst = instructions.CmpXchg(
            self.block, ptr, cmp, val, ordering, failordering, name=name
        );
        self._insert(inst);
        return inst;
    }

    def landingpad(
        self: IRBuilder, typ: Any, name: Any = '', cleanup: Any = False
    ) -> object {
        inst = instructions.LandingPadInstr(self.block, typ, name, cleanup);
        self._insert(inst);
        return inst;
    }

    def assume(self: IRBuilder, cond: Any) -> object {
        fn = self.module.declare_intrinsic("llvm.assume");
        return self.call(fn, [cond]);
    }

    def fence(
        self: IRBuilder, ordering: Any, targetscope: Any = None, name: Any = ''
    ) -> object {
        inst = instructions.Fence(self.block, ordering, targetscope, name=name);
        self._insert(inst);
        return inst;
    }

    def comment(self: IRBuilder, text: Any) -> object {
        inst = instructions.Comment(self.block, text);
        self._insert(inst);
        return inst;
    }

    @_uniop_intrinsic_int("llvm.bswap")
    def bswap(self: IRBuilder, cond: Any) -> object { }

    @_uniop_intrinsic_int("llvm.bitreverse")
    def bitreverse(self: IRBuilder, cond: Any) -> object { }

    @_uniop_intrinsic_int("llvm.ctpop")
    def ctpop(self: IRBuilder, cond: Any) -> object { }

    @_uniop_intrinsic_with_flag("llvm.ctlz")
    def ctlz(self: IRBuilder, cond: Any, flag: Any) -> object { }

    @_uniop_intrinsic_with_flag("llvm.cttz")
    def cttz(self: IRBuilder, cond: Any, flag: Any) -> object { }

    @_triop_intrinsic("llvm.fma")
    def fma(self: IRBuilder, a: Any, b: Any, c: Any) -> object { }

    def convert_from_fp16(
        self: IRBuilder, a: Any, `to: Any = None, name: Any = ''
    ) -> object {
        if not `to {
            raise TypeError("expected a float return type");
        }
        if not isinstance(`to, (types.FloatType, types.DoubleType)) {
            raise TypeError(("expected a float type, got %s" % `to));
        }
        if not (isinstance(a.type, types.IntType) and (a.type.width == 16)) {
            raise TypeError(("expected an i16 type, got %s" % a.type));
        }
        opname = 'llvm.convert.from.fp16';
        fn = self.module.declare_intrinsic(opname, [`to]);
        return self.call(fn, [a], name);
    }

    @_uniop_intrinsic_float("llvm.convert.to.fp16")
    def convert_to_fp16(self: IRBuilder, a: Any) -> object { }
}
