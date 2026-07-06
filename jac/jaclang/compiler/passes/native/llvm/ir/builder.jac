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

class IRBuilder(object) {
    def init(self: IRBuilder, block: Any = None) -> object {
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
    def position_before(self: IRBuilder, instr: Any) -> object {
        self._block = instr.parent;
        self._anchor = self._block.instructions.index(instr);
    }

    """
        Position immediately after the given instruction.  The current block
        is also changed to the instruction's basic block.
        """
    def position_after(self: IRBuilder, instr: Any) -> object {
        self._block = instr.parent;
        self._anchor = self._block.instructions.index(instr) + 1;
    }

    """
        Position at the start of the basic *block*.
        """
    def position_at_start(self: IRBuilder, block: Any) -> object {
        self._block = block;
        self._anchor = 0;
    }

    """
        Position at the end of the basic *block*.
        """
    def position_at_end(self: IRBuilder, block: Any) -> object {
        self._block = block;
        self._anchor = len(block.instructions);
    }

    """
        Append a basic block, with the given optional *name*, to the current
        function.  The current block is not changed.  The new block is returned.
        """
    def append_basic_block(self: IRBuilder, name: Any = '') -> object {
        return self.function.append_basic_block(name);
    }

    """Remove the given instruction."""
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
    """
        Left integer shift:
            name = lhs << rhs
        """
    @_binop('shl')
    def shl(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    """
        Logical (unsigned) right integer shift:
            name = lhs >> rhs
        """
    @_binop('lshr')
    def lshr(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    """
        Arithmetic (signed) right integer shift:
            name = lhs >> rhs
        """
    @_binop('ashr')
    def ashr(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    """
        Integer addition:
            name = lhs + rhs
        """
    @_binop('add')
    def add(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    """
        Floating-point addition:
            name = lhs + rhs
        """
    @_binop('fadd')
    def fadd(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    """
        Integer subtraction:
            name = lhs - rhs
        """
    @_binop('sub')
    def sub(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    """
        Floating-point subtraction:
            name = lhs - rhs
        """
    @_binop('fsub')
    def fsub(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    """
        Integer multiplication:
            name = lhs * rhs
        """
    @_binop('mul')
    def mul(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    """
        Floating-point multiplication:
            name = lhs * rhs
        """
    @_binop('fmul')
    def fmul(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    """
        Unsigned integer division:
            name = lhs / rhs
        """
    @_binop('udiv')
    def udiv(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    """
        Signed integer division:
            name = lhs / rhs
        """
    @_binop('sdiv')
    def sdiv(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    """
        Floating-point division:
            name = lhs / rhs
        """
    @_binop('fdiv')
    def fdiv(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    """
        Unsigned integer remainder:
            name = lhs % rhs
        """
    @_binop('urem')
    def urem(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    """
        Signed integer remainder:
            name = lhs % rhs
        """
    @_binop('srem')
    def srem(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    """
        Floating-point remainder:
            name = lhs % rhs
        """
    @_binop('frem')
    def frem(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    """
        Bitwise integer OR:
            name = lhs | rhs
        """
    @_binop('or')
    def or_(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    """
        Bitwise integer AND:
            name = lhs & rhs
        """
    @_binop('and')
    def and_(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }

    """
        Bitwise integer XOR:
            name = lhs ^ rhs
        """
    @_binop('xor')
    def xor(self: IRBuilder, lhs: Any, rhs: Any, name: Any = '') -> object { }


    """
        Bitwise integer complement:
            name = ~value
        """
    def not_(self: IRBuilder, value: Any, name: Any = '') -> object {
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
    def neg(self: IRBuilder, value: Any, name: Any = '') -> object {
        return self.sub(values.Constant(value.type, 0), value, name=name);
    }

    """
        Floating-point negative:
            name = -arg
        """
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
    """
        Signed integer comparison:
            name = lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>='
        """
    def icmp_signed(
        self: IRBuilder, cmpop: Any, lhs: Any, rhs: Any, name: Any = ''
    ) -> object {
        return self._icmp('s', cmpop, lhs, rhs, name);
    }

    """
        Unsigned integer (or pointer) comparison:
            name = lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>='
        """
    def icmp_unsigned(
        self: IRBuilder, cmpop: Any, lhs: Any, rhs: Any, name: Any = ''
    ) -> object {
        return self._icmp('u', cmpop, lhs, rhs, name);
    }

    """
        Floating-point ordered comparison:
            name = lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>=', 'ord', 'uno'
        """
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

    """
        Floating-point unordered comparison:
            name = lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>=', 'ord', 'uno'
        """
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

    """
        Ternary select operator:
            name = cond ? lhs : rhs
        """
    def select(
        self: IRBuilder, cond: Any, lhs: Any, rhs: Any, name: Any = '', flags: Any = ()
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
    def trunc(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    """
        Zero-extending integer upcast to a larger type:
            name = (typ) value
        """
    @_castop('zext')
    def zext(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    """
        Sign-extending integer upcast to a larger type:
            name = (typ) value
        """
    @_castop('sext')
    def sext(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    """
        Floating-point downcast to a less precise type:
            name = (typ) value
        """
    @_castop('fptrunc')
    def fptrunc(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    """
        Floating-point upcast to a more precise type:
            name = (typ) value
        """
    @_castop('fpext')
    def fpext(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    """
        Pointer cast to a different pointer type:
            name = (typ) value
        """
    @_castop('bitcast')
    def bitcast(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    """
        Pointer cast to a different address space:
            name = (typ) value
        """
    @_castop('addrspacecast')
    def addrspacecast(
        self: IRBuilder, value: Any, typ: Any, name: Any = ''
    ) -> object { }

    """
        Convert floating-point to unsigned integer:
            name = (typ) value
        """
    @_castop('fptoui')
    def fptoui(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    """
        Convert unsigned integer to floating-point:
            name = (typ) value
        """
    @_castop('uitofp')
    def uitofp(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    """
        Convert floating-point to signed integer:
            name = (typ) value
        """
    @_castop('fptosi')
    def fptosi(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    """
        Convert signed integer to floating-point:
            name = (typ) value
        """
    @_castop('sitofp')
    def sitofp(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    """
        Cast pointer to integer:
            name = (typ) value
        """
    @_castop('ptrtoint')
    def ptrtoint(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    """
        Cast integer to pointer:
            name = (typ) value
        """
    @_castop('inttoptr')
    def inttoptr(self: IRBuilder, value: Any, typ: Any, name: Any = '') -> object { }

    """
        Stack-allocate a slot for *size* elements of the given type.
        (default one element)
        """
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

    """
        Load value from pointer, with optional guaranteed alignment:
            name = *ptr
        """
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

    """
        Store value to pointer, with optional guaranteed alignment:
            *ptr = name
        """
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


    """
        Unconditional branch to *target*.
        """
    def branch(self: IRBuilder, target: Any) -> object {
        br = instructions.Branch(self.block, "br", [target]);
        self._set_terminator(br);
        return br;
    }

    """
        Conditional branch to *truebr* if *cond* is true, else to *falsebr*.
        """
    def cbranch(self: IRBuilder, cond: Any, truebr: Any, falsebr: Any) -> object {
        br = instructions.ConditionalBranch(self.block, "br", [cond, truebr, falsebr]);
        self._set_terminator(br);
        return br;
    }

    """
        Indirect branch to target *addr*.
        """
    def branch_indirect(self: IRBuilder, addr: Any) -> object {
        br = instructions.IndirectBranch(self.block, "indirectbr", addr);
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
    def ret(self: IRBuilder, value: Any) -> object {
        return self._set_terminator(instructions.Ret(self.block, "ret", value));
    }


    """
        Call function *fn* with *args*:
            name = fn(args...)
        """
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

    """
        Inline assembler.
        """
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

    """
        Compute effective address (getelementptr):
            name = getelementptr ptr, <indices...>
        """
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


    """
        Returns vector with vector[idx] replaced by value.
        The result is undefined if the idx is larger or equal the vector length.
        """
    def insert_element(
        self: IRBuilder, vector: Any, value: Any, idx: Any, name: Any = ''
    ) -> object {
        instr = instructions.InsertElement(self.block, vector, value, idx, name=name);
        self._insert(instr);
        return instr;
    }


    """
        Extract member number *idx* from aggregate.
        """
    def extract_value(self: IRBuilder, agg: Any, idx: Any, name: Any = '') -> object {
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
}

