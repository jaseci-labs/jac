import functools;
import from jaclang.compiler.passes.native.llvm.ir { instructions, types, values }

glob _CMP_MAP = {
         '>': 'gt',
         '<': 'lt',
         '==': 'eq',
         '!=': 'ne',
         '>=': 'ge',
         '<=': 'le'
     };

def _unop(opname: any, cls: any = instructions.Instruction) -> object {
    def wrap(fn: any) -> object {
        @functools.wraps(fn)
        def wrapped(self: any, arg: any, name: any = '', flags: any = ()) -> object {
            instr = cls(self.block, arg.type, opname, [arg], name, flags);
            self._insert(instr);
            return instr;
        }
        return wrapped;
    }
    return wrap;
}

def _binop(opname: any, cls: any = instructions.Instruction) -> object {
    def wrap(fn: any) -> object {
        @functools.wraps(fn)
        def wrapped(
            self: any, lhs: any, rhs: any, name: any = '', flags: any = ()
        ) -> object {
            if (lhs.type != rhs.type) {
                raise ValueError(
                    (
                        "Operands must be the same type, got (%s, %s)"
                        % (lhs.type, rhs.type)
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

def _castop(opname: any, cls: any = instructions.CastInstr) -> object {
    def wrap(fn: any) -> object {
        @functools.wraps(fn)
        def wrapped(self: any, val: any, typ: any, name: any = '') -> object {
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

class IRBuilder(object) {
    def init(self: IRBuilder, block: any = None) -> object {
        self._block = block;
        self._anchor = len(block.instructions) if block else 0;
        self.debug_metadata = None;
    }

    """
        The current basic block.
        """
    @property
    def block(self: IRBuilder) -> object {
        return self._block;
    }

    with entry {
        basic_block = block;
    }

    """
        The current function.
        """
    @property
    def function(self: IRBuilder) -> object {
        return self.block.parent;
    }

    """
        The current module.
        """
    @property
    def module(self: IRBuilder) -> object {
        return self.block.parent.module;
    }

    """
        Position immediately before the given instruction.  The current block
        is also changed to the instruction's basic block.
        """
    def position_before(self: IRBuilder, instr: any) -> object {
        self._block = instr.parent;
        self._anchor = self._block.instructions.index(instr);
    }

    """
        Position immediately after the given instruction.  The current block
        is also changed to the instruction's basic block.
        """
    def position_after(self: IRBuilder, instr: any) -> object {
        self._block = instr.parent;
        self._anchor = self._block.instructions.index(instr) + 1;
    }

    """
        Position at the start of the basic *block*.
        """
    def position_at_start(self: IRBuilder, block: any) -> object {
        self._block = block;
        self._anchor = 0;
    }

    """
        Position at the end of the basic *block*.
        """
    def position_at_end(self: IRBuilder, block: any) -> object {
        self._block = block;
        self._anchor = len(block.instructions);
    }

    """
        Append a basic block, with the given optional *name*, to the current
        function.  The current block is not changed.  The new block is returned.
        """
    def append_basic_block(self: IRBuilder, name: any = '') -> object {
        return self.function.append_basic_block(name);
    }

    """Remove the given instruction."""
    def remove(self: IRBuilder, instr: any) -> object {
        idx = self._block.instructions.index(instr);
        del self._block.instructions[idx];
        if (self._block.terminator == instr) {
            self._block.terminator = None;
        }
        if (self._anchor > idx) {
            self._anchor -= 1;
        }
    }

    def _insert(self: IRBuilder, instr: any) -> object {
        if ((self.debug_metadata is not None) and ('dbg' not in instr.metadata)) {
            instr.metadata['dbg'] = self.debug_metadata;
        }
        self._block.instructions.insert(self._anchor, instr);
        self._anchor += 1;
    }

    def _set_terminator(self: IRBuilder, term: any) -> object {
        assert not self.block.is_terminated;
        self._insert(term);
        self.block.terminator = term;
        return term;
    }

    """
        Left integer shift:
            name = lhs << rhs
        """
    @_binop('shl')
    def shl(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Logical (unsigned) right integer shift:
            name = lhs >> rhs
        """
    @_binop('lshr')
    def lshr(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Arithmetic (signed) right integer shift:
            name = lhs >> rhs
        """
    @_binop('ashr')
    def ashr(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Integer addition:
            name = lhs + rhs
        """
    @_binop('add')
    def add(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Floating-point addition:
            name = lhs + rhs
        """
    @_binop('fadd')
    def fadd(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Integer subtraction:
            name = lhs - rhs
        """
    @_binop('sub')
    def sub(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Floating-point subtraction:
            name = lhs - rhs
        """
    @_binop('fsub')
    def fsub(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Integer multiplication:
            name = lhs * rhs
        """
    @_binop('mul')
    def mul(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Floating-point multiplication:
            name = lhs * rhs
        """
    @_binop('fmul')
    def fmul(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Unsigned integer division:
            name = lhs / rhs
        """
    @_binop('udiv')
    def udiv(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Signed integer division:
            name = lhs / rhs
        """
    @_binop('sdiv')
    def sdiv(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Floating-point division:
            name = lhs / rhs
        """
    @_binop('fdiv')
    def fdiv(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Unsigned integer remainder:
            name = lhs % rhs
        """
    @_binop('urem')
    def urem(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Signed integer remainder:
            name = lhs % rhs
        """
    @_binop('srem')
    def srem(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Floating-point remainder:
            name = lhs % rhs
        """
    @_binop('frem')
    def frem(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Bitwise integer OR:
            name = lhs | rhs
        """
    @_binop('or')
    def or_(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Bitwise integer AND:
            name = lhs & rhs
        """
    @_binop('and')
    def and_(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Bitwise integer XOR:
            name = lhs ^ rhs
        """
    @_binop('xor')
    def xor(self: IRBuilder, lhs: any, rhs: any, name: any = '') -> object { }

    """
        Bitwise integer complement:
            name = ~value
        """
    def not_(self: IRBuilder, value: any, name: any = '') -> object {
        if isinstance(value.type, types.VectorType) {
            rhs = values.Constant(value.type, ((-1, ) * value.type.count));
        } else {
            rhs = values.Constant(value.type, -1);
        }
        return self.xor(value, rhs, name=name);
    }

    """
        Integer negative:
            name = -value
        """
    def neg(self: IRBuilder, value: any, name: any = '') -> object {
        return self.sub(values.Constant(value.type, 0), value, name=name);
    }

    """
        Floating-point negative:
            name = -arg
        """
    @_unop('fneg')
    def fneg(self: IRBuilder, arg: any, name: any = '', flags: any = ()) -> object { }

    def _icmp(
        self: IRBuilder, prefix: any, cmpop: any, lhs: any, rhs: any, name: any
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

    """
        Signed integer comparison:
            name = lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>='
        """
    def icmp_signed(
        self: IRBuilder, cmpop: any, lhs: any, rhs: any, name: any = ''
    ) -> object {
        return self._icmp('s', cmpop, lhs, rhs, name);
    }

    """
        Unsigned integer (or pointer) comparison:
            name = lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>='
        """
    def icmp_unsigned(
        self: IRBuilder, cmpop: any, lhs: any, rhs: any, name: any = ''
    ) -> object {
        return self._icmp('u', cmpop, lhs, rhs, name);
    }

    """
        Floating-point ordered comparison:
            name = lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>=', 'ord', 'uno'
        """
    def fcmp_ordered(
        self: IRBuilder, cmpop: any, lhs: any, rhs: any, name: any = '', flags: any = ()
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

    """
        Floating-point unordered comparison:
            name = lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>=', 'ord', 'uno'
        """
    def fcmp_unordered(
        self: IRBuilder, cmpop: any, lhs: any, rhs: any, name: any = '', flags: any = ()
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

    """
        Ternary select operator:
            name = cond ? lhs : rhs
        """
    def select(
        self: IRBuilder, cond: any, lhs: any, rhs: any, name: any = '', flags: any = ()
    ) -> object {
        instr = instructions.SelectInstr(
            self.block, cond, lhs, rhs, name=name, flags=flags
        );
        self._insert(instr);
        return instr;
    }

    """
        Truncating integer downcast to a smaller type:
            name = (typ) value
        """
    @_castop('trunc')
    def trunc(self: IRBuilder, value: any, typ: any, name: any = '') -> object { }

    """
        Zero-extending integer upcast to a larger type:
            name = (typ) value
        """
    @_castop('zext')
    def zext(self: IRBuilder, value: any, typ: any, name: any = '') -> object { }

    """
        Sign-extending integer upcast to a larger type:
            name = (typ) value
        """
    @_castop('sext')
    def sext(self: IRBuilder, value: any, typ: any, name: any = '') -> object { }

    """
        Floating-point downcast to a less precise type:
            name = (typ) value
        """
    @_castop('fptrunc')
    def fptrunc(self: IRBuilder, value: any, typ: any, name: any = '') -> object { }

    """
        Floating-point upcast to a more precise type:
            name = (typ) value
        """
    @_castop('fpext')
    def fpext(self: IRBuilder, value: any, typ: any, name: any = '') -> object { }

    """
        Pointer cast to a different pointer type:
            name = (typ) value
        """
    @_castop('bitcast')
    def bitcast(self: IRBuilder, value: any, typ: any, name: any = '') -> object { }

    """
        Convert unsigned integer to floating-point:
            name = (typ) value
        """
    @_castop('uitofp')
    def uitofp(self: IRBuilder, value: any, typ: any, name: any = '') -> object { }

    """
        Convert floating-point to signed integer:
            name = (typ) value
        """
    @_castop('fptosi')
    def fptosi(self: IRBuilder, value: any, typ: any, name: any = '') -> object { }

    """
        Convert signed integer to floating-point:
            name = (typ) value
        """
    @_castop('sitofp')
    def sitofp(self: IRBuilder, value: any, typ: any, name: any = '') -> object { }

    """
        Cast pointer to integer:
            name = (typ) value
        """
    @_castop('ptrtoint')
    def ptrtoint(self: IRBuilder, value: any, typ: any, name: any = '') -> object { }

    """
        Cast integer to pointer:
            name = (typ) value
        """
    @_castop('inttoptr')
    def inttoptr(self: IRBuilder, value: any, typ: any, name: any = '') -> object { }

    """
        Stack-allocate a slot for *size* elements of the given type.
        (default one element)
        """
    def alloca(self: IRBuilder, typ: any, size: any = None, name: any = '') -> object {
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

    """
        Load value from pointer, with optional guaranteed alignment:
            name = *ptr
        """
    def load(
        self: IRBuilder, ptr: any, name: any = '', align: any = None, typ: any = None
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

    """
        Store value to pointer, with optional guaranteed alignment:
            *ptr = name
        """
    def store(self: IRBuilder, value: any, ptr: any, align: any = None) -> object {
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

    """
        Unconditional branch to *target*.
        """
    def branch(self: IRBuilder, target: any) -> object {
        br = instructions.Branch(self.block, "br", [target]);
        self._set_terminator(br);
        return br;
    }

    """
        Switch on *value*, jumping to *default_bb* unless a case added via
        `add_case` matches.
        """
    def `switch(self: IRBuilder, value: any, default_bb: any) -> object {
        swt = instructions.SwitchInstr(self.block, "switch", value, default_bb);
        self._set_terminator(swt);
        return swt;
    }

    """
        Switch on *value*, jumping to *default_bb* unless a case added via
        `add_case` matches.
        """
    def `switch(self: IRBuilder, value: any, default_bb: any) -> object {
        swt = instructions.SwitchInstr(self.block, "switch", value, default_bb);
        self._set_terminator(swt);
        return swt;
    }

    """
        Conditional branch to *truebr* if *cond* is true, else to *falsebr*.
        """
    def cbranch(self: IRBuilder, cond: any, truebr: any, falsebr: any) -> object {
        br = instructions.ConditionalBranch(self.block, "br", [cond, truebr, falsebr]);
        self._set_terminator(br);
        return br;
    }

    """
        Return from function without a value.
        """
    def ret_void(self: IRBuilder) -> object {
        return self._set_terminator(instructions.Ret(self.block, "ret void"));
    }

    """
        Return from function with the given *value*.
        """
    def ret(self: IRBuilder, value: any) -> object {
        return self._set_terminator(instructions.Ret(self.block, "ret", value));
    }

    """
        Call function *fn* with *args*:
            name = fn(args...)
        """
    def call(
        self: IRBuilder,
        fn: any,
        args: any,
        name: any = '',
        cconv: any = None,
        tail: any = False,
        fastmath: any = (),
        attrs: any = (),
        arg_attrs: any = None
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

    """
        Inline assembler.
        """
    def asm(
        self: IRBuilder,
        ftype: any,
        asm: any,
        constraint: any,
        args: any,
        side_effect: any,
        name: any = ''
    ) -> object {
        asm = instructions.InlineAsm(ftype, asm, constraint, side_effect);
        return self.call(asm, args, name);
    }

    """
        Compute effective address (getelementptr):
            name = getelementptr ptr, <indices...>
        """
    def gep(
        self: IRBuilder,
        ptr: any,
        indices: any,
        inbounds: any = False,
        name: any = '',
        source_etype: any = None
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

    """
        Extract member number *idx* from aggregate.
        """
    def extract_value(self: IRBuilder, agg: any, idx: any, name: any = '') -> object {
        if not isinstance(idx, (`tuple, `list)) {
            idx = [idx];
        }
        instr = instructions.ExtractValue(self.block, agg, idx, name=name);
        self._insert(instr);
        return instr;
    }

    """
        Insert *value* into member number *idx* from aggregate.
        """
    def insert_value(
        self: IRBuilder, agg: any, value: any, idx: any, name: any = ''
    ) -> object {
        if not isinstance(idx, (`tuple, `list)) {
            idx = [idx];
        }
        instr = instructions.InsertValue(self.block, agg, value, idx, name=name);
        self._insert(instr);
        return instr;
    }

    def phi(self: IRBuilder, typ: any, name: any = '', flags: any = ()) -> object {
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
        self: IRBuilder, op: any, ptr: any, val: any, ordering: any, name: any = ''
    ) -> object {
        inst = instructions.AtomicRMW(self.block, op, ptr, val, ordering, name=name);
        self._insert(inst);
        return inst;
    }
}
