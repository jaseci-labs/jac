import jaclang.compiler.backends.native.llvm.ir.instructions as instructions;
import jaclang.compiler.backends.native.llvm.ir.types as types;
import jaclang.compiler.backends.native.llvm.ir.values as values;
import from jaclang.compiler.backends.native.llvm.ir.values { Value }
import type from jaclang.compiler.backends.native.llvm.ir.module { Module }

glob _CMP_MAP: dict[str, str] = {
         '>': 'gt',
         '<': 'lt',
         '==': 'eq',
         '!=': 'ne',
         '>=': 'ge',
         '<=': 'le'
     },
     MISSING_OPERAND: str = "an IR builder operand is missing (None)";

"""Builds instructions at a position in a basic block.

Value operands may be handed in as optional values (a callee or a slot held in
an optional field); a missing one raises TypeError before anything is built."""
class IRBuilder {
    has _block: values.Block | None = None,
        _anchor: int = 0,
        debug_metadata: Value | None = None;

    def init(self: IRBuilder, block: values.Block | None = None) {
        self._block = block;
        self._anchor = len(block.instructions) if block is not None else 0;
        self.debug_metadata = None;
    }

    """
        The current basic block.
        """
    has block: values.Block {
        getter {
            current = self._block;
            if current is None {
                raise ValueError("the builder is not positioned in a block");
            }
            return current;
        }
    }

    """
        The current basic block (alias of `block`).
        """
    has basic_block: values.Block {
        getter {
            return self.block;
        }
    }

    """
        The current function.
        """
    has function: values.Function {
        getter {
            return self.block.parent;
        }
    }

    """
        The current module.
        """
    has module: Module {
        getter {
            return self.block.parent.module;
        }
    }

    """The instruction a positioning call names."""
    def _positioned(self: IRBuilder, instr: Value | None) -> instructions.Instruction {
        if isinstance(instr, instructions.Instruction) {
            return instr;
        }
        raise TypeError("not an instruction");
    }

    """
        Position immediately before the given instruction.  The current block
        is also changed to the instruction's basic block.
        """
    def position_before(self: IRBuilder, instr: Value | None) {
        if instr is None {
            raise TypeError(MISSING_OPERAND);
        }
        home = self._positioned(instr).parent;
        self._block = home;
        self._anchor = home.index_of(instr);
    }

    """
        Position immediately after the given instruction.  The current block
        is also changed to the instruction's basic block.
        """
    def position_after(self: IRBuilder, instr: Value | None) {
        if instr is None {
            raise TypeError(MISSING_OPERAND);
        }
        home = self._positioned(instr).parent;
        self._block = home;
        self._anchor = home.index_of(instr) + 1;
    }

    """
        Position at the start of the basic *block*.
        """
    def position_at_start(self: IRBuilder, block: values.Block) {
        self._block = block;
        self._anchor = 0;
    }

    """
        Position at the end of the basic *block*.
        """
    def position_at_end(self: IRBuilder, block: values.Block) {
        self._block = block;
        self._anchor = len(block.instructions);
    }

    """
        Append a basic block, with the given optional *name*, to the current
        function.  The current block is not changed.  The new block is returned.
        """
    def append_basic_block(self: IRBuilder, name: str = '') -> values.Block {
        return self.function.append_basic_block(name);
    }

    """Remove the given instruction."""
    def remove(self: IRBuilder, instr: Value | None) {
        if instr is None {
            raise TypeError(MISSING_OPERAND);
        }
        home = self.block;
        idx = home.index_of(instr);
        home.instructions.pop(idx);
        if (home.terminator is instr) {
            home.terminator = None;
        }
        if (self._anchor > idx) {
            self._anchor -= 1;
        }
    }

    def _insert(self: IRBuilder, instr: values.NamedValue) {
        debug = self.debug_metadata;
        if ((debug is not None) and ('dbg' not in instr.metadata)) {
            instr.metadata['dbg'] = debug;
        }
        self.block.instructions.insert(self._anchor, instr);
        self._anchor += 1;
    }

    def _set_terminator(self: IRBuilder, term: values.NamedValue) -> Value {
        assert not self.block.is_terminated;
        self._insert(term);
        self.block.terminator = term;
        return term;
    }

    def _binop(
        self: IRBuilder,
        opname: str,
        lhs: Value | None,
        rhs: Value | None,
        name: str,
        flags: any
    ) -> Value {
        if lhs is None {
            raise TypeError(MISSING_OPERAND);
        }
        if rhs is None {
            raise TypeError(MISSING_OPERAND);
        }
        if (lhs.type != rhs.type) {
            raise ValueError(
                f"Operands must be the same type, got ({lhs.type}, {rhs.type})"
            );
        }
        instr = instructions.Instruction(
            self.block, lhs.type, opname, [lhs, rhs], name, flags
        );
        self._insert(instr);
        return instr;
    }

    def _castop(
        self: IRBuilder, opname: str, val: Value | None, typ: types.Type, name: str
    ) -> Value {
        if val is None {
            raise TypeError(MISSING_OPERAND);
        }
        if (val.type == typ) {
            return val;
        }
        instr = instructions.CastInstr(self.block, opname, val, typ, name);
        self._insert(instr);
        return instr;
    }

    """
        Left integer shift:
            name = lhs << rhs
        """
    def shl(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('shl', lhs, rhs, name, flags);
    }

    """
        Logical (unsigned) right integer shift:
            name = lhs >> rhs
        """
    def lshr(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('lshr', lhs, rhs, name, flags);
    }

    """
        Arithmetic (signed) right integer shift:
            name = lhs >> rhs
        """
    def ashr(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('ashr', lhs, rhs, name, flags);
    }

    """
        Integer addition:
            name = lhs + rhs
        """
    def add(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('add', lhs, rhs, name, flags);
    }

    """
        Floating-point addition:
            name = lhs + rhs
        """
    def fadd(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('fadd', lhs, rhs, name, flags);
    }

    """
        Integer subtraction:
            name = lhs - rhs
        """
    def sub(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('sub', lhs, rhs, name, flags);
    }

    """
        Floating-point subtraction:
            name = lhs - rhs
        """
    def fsub(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('fsub', lhs, rhs, name, flags);
    }

    """
        Integer multiplication:
            name = lhs * rhs
        """
    def mul(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('mul', lhs, rhs, name, flags);
    }

    """
        Floating-point multiplication:
            name = lhs * rhs
        """
    def fmul(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('fmul', lhs, rhs, name, flags);
    }

    """
        Unsigned integer division:
            name = lhs / rhs
        """
    def udiv(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('udiv', lhs, rhs, name, flags);
    }

    """
        Signed integer division:
            name = lhs / rhs
        """
    def sdiv(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('sdiv', lhs, rhs, name, flags);
    }

    """
        Floating-point division:
            name = lhs / rhs
        """
    def fdiv(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('fdiv', lhs, rhs, name, flags);
    }

    """
        Unsigned integer remainder:
            name = lhs % rhs
        """
    def urem(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('urem', lhs, rhs, name, flags);
    }

    """
        Signed integer remainder:
            name = lhs % rhs
        """
    def srem(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('srem', lhs, rhs, name, flags);
    }

    """
        Floating-point remainder:
            name = lhs % rhs
        """
    def frem(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('frem', lhs, rhs, name, flags);
    }

    """
        Bitwise integer OR:
            name = lhs | rhs
        """
    def or_(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('or', lhs, rhs, name, flags);
    }

    """
        Bitwise integer AND:
            name = lhs & rhs
        """
    def and_(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('and', lhs, rhs, name, flags);
    }

    """
        Bitwise integer XOR:
            name = lhs ^ rhs
        """
    def xor(
        self: IRBuilder,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._binop('xor', lhs, rhs, name, flags);
    }

    """
        Bitwise integer complement:
            name = ~value
        """
    def not_(self: IRBuilder, value: Value | None, name: str = '') -> Value {
        if value is None {
            raise TypeError(MISSING_OPERAND);
        }
        value_type = value.type;
        if isinstance(value_type, types.VectorType) {
            rhs = values.Constant(value_type, [-1] * value_type.count);
        } else {
            rhs = values.Constant(value_type, -1);
        }
        return self.xor(value, rhs, name=name);
    }

    """
        Integer negative:
            name = -value
        """
    def neg(self: IRBuilder, value: Value | None, name: str = '') -> Value {
        if value is None {
            raise TypeError(MISSING_OPERAND);
        }
        return self.sub(values.Constant(value.type, 0), value, name=name);
    }

    """
        Floating-point negative:
            name = -arg
        """
    def fneg(
        self: IRBuilder, arg: Value | None, name: str = '', flags: any = None
    ) -> Value {
        if arg is None {
            raise TypeError(MISSING_OPERAND);
        }
        instr = instructions.Instruction(
            self.block, arg.type, 'fneg', [arg], name, flags
        );
        self._insert(instr);
        return instr;
    }

    def _icmp(
        self: IRBuilder,
        prefix: str,
        cmpop: str,
        lhs: Value | None,
        rhs: Value | None,
        name: str
    ) -> Value {
        if lhs is None {
            raise TypeError(MISSING_OPERAND);
        }
        if rhs is None {
            raise TypeError(MISSING_OPERAND);
        }
        found = _CMP_MAP.get(cmpop);
        if found is None {
            raise ValueError(f"invalid comparison {cmpop!r} for icmp");
        }
        op = found;
        if (cmpop not in ('==', '!=')) {
            op = prefix + op;
        }
        instr = instructions.ICMPInstr(self.block, op, lhs, rhs, name);
        self._insert(instr);
        return instr;
    }

    """
        Signed integer comparison:
            name = lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>='
        """
    def icmp_signed(
        self: IRBuilder,
        cmpop: str,
        lhs: Value | None,
        rhs: Value | None,
        name: str = ''
    ) -> Value {
        return self._icmp('s', cmpop, lhs, rhs, name);
    }

    """
        Unsigned integer (or pointer) comparison:
            name = lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>='
        """
    def icmp_unsigned(
        self: IRBuilder,
        cmpop: str,
        lhs: Value | None,
        rhs: Value | None,
        name: str = ''
    ) -> Value {
        return self._icmp('u', cmpop, lhs, rhs, name);
    }

    def _fcmp(
        self: IRBuilder,
        prefix: str,
        cmpop: str,
        lhs: Value | None,
        rhs: Value | None,
        name: str,
        flags: any
    ) -> Value {
        if lhs is None {
            raise TypeError(MISSING_OPERAND);
        }
        if rhs is None {
            raise TypeError(MISSING_OPERAND);
        }
        found = _CMP_MAP.get(cmpop);
        op = (prefix + found) if found is not None else cmpop;
        instr = instructions.FCMPInstr(self.block, op, lhs, rhs, name, flags);
        self._insert(instr);
        return instr;
    }

    """
        Floating-point ordered comparison:
            name = lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>=', 'ord', 'uno'
        """
    def fcmp_ordered(
        self: IRBuilder,
        cmpop: str,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._fcmp('o', cmpop, lhs, rhs, name, flags);
    }

    """
        Floating-point unordered comparison:
            name = lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>=', 'ord', 'uno'
        """
    def fcmp_unordered(
        self: IRBuilder,
        cmpop: str,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        return self._fcmp('u', cmpop, lhs, rhs, name, flags);
    }

    """
        Ternary select operator:
            name = cond ? lhs : rhs
        """
    def select(
        self: IRBuilder,
        cond: Value | None,
        lhs: Value | None,
        rhs: Value | None,
        name: str = '',
        flags: any = None
    ) -> Value {
        if cond is None {
            raise TypeError(MISSING_OPERAND);
        }
        if lhs is None {
            raise TypeError(MISSING_OPERAND);
        }
        if rhs is None {
            raise TypeError(MISSING_OPERAND);
        }
        instr = instructions.SelectInstr(self.block, cond, lhs, rhs, name, flags);
        self._insert(instr);
        return instr;
    }

    """
        Truncating integer downcast to a smaller type:
            name = (typ) value
        """
    def trunc(
        self: IRBuilder, value: Value | None, typ: types.Type, name: str = ''
    ) -> Value {
        return self._castop('trunc', value, typ, name);
    }

    """
        Zero-extending integer upcast to a larger type:
            name = (typ) value
        """
    def zext(
        self: IRBuilder, value: Value | None, typ: types.Type, name: str = ''
    ) -> Value {
        return self._castop('zext', value, typ, name);
    }

    """
        Sign-extending integer upcast to a larger type:
            name = (typ) value
        """
    def sext(
        self: IRBuilder, value: Value | None, typ: types.Type, name: str = ''
    ) -> Value {
        return self._castop('sext', value, typ, name);
    }

    """
        Floating-point downcast to a less precise type:
            name = (typ) value
        """
    def fptrunc(
        self: IRBuilder, value: Value | None, typ: types.Type, name: str = ''
    ) -> Value {
        return self._castop('fptrunc', value, typ, name);
    }

    """
        Floating-point upcast to a more precise type:
            name = (typ) value
        """
    def fpext(
        self: IRBuilder, value: Value | None, typ: types.Type, name: str = ''
    ) -> Value {
        return self._castop('fpext', value, typ, name);
    }

    """
        Pointer cast to a different pointer type:
            name = (typ) value
        """
    def bitcast(
        self: IRBuilder, value: Value | None, typ: types.Type, name: str = ''
    ) -> Value {
        return self._castop('bitcast', value, typ, name);
    }

    """
        Convert unsigned integer to floating-point:
            name = (typ) value
        """
    def uitofp(
        self: IRBuilder, value: Value | None, typ: types.Type, name: str = ''
    ) -> Value {
        return self._castop('uitofp', value, typ, name);
    }

    """
        Convert floating-point to signed integer:
            name = (typ) value
        """
    def fptosi(
        self: IRBuilder, value: Value | None, typ: types.Type, name: str = ''
    ) -> Value {
        return self._castop('fptosi', value, typ, name);
    }

    """
        Convert floating-point to unsigned integer:
            name = (typ) value
        """
    def fptoui(
        self: IRBuilder, value: Value | None, typ: types.Type, name: str = ''
    ) -> Value {
        return self._castop('fptoui', value, typ, name);
    }

    """
        Convert signed integer to floating-point:
            name = (typ) value
        """
    def sitofp(
        self: IRBuilder, value: Value | None, typ: types.Type, name: str = ''
    ) -> Value {
        return self._castop('sitofp', value, typ, name);
    }

    """
        Cast pointer to integer:
            name = (typ) value
        """
    def ptrtoint(
        self: IRBuilder, value: Value | None, typ: types.Type, name: str = ''
    ) -> Value {
        return self._castop('ptrtoint', value, typ, name);
    }

    """
        Cast integer to pointer:
            name = (typ) value
        """
    def inttoptr(
        self: IRBuilder, value: Value | None, typ: types.Type, name: str = ''
    ) -> Value {
        return self._castop('inttoptr', value, typ, name);
    }

    """
        Stack-allocate a slot for *size* elements of the given type.
        (default one element)
        """
    def alloca(
        self: IRBuilder, typ: types.Type, size: any = None, name: str = ''
    ) -> Value {
        count: Value | None = None;
        if (size is None) {
            count = None;
        } elif isinstance(size, Value) {
            assert isinstance(size.type, types.IntType);
            count = size;
        } else {
            count = values.Constant(types.IntType(32), size);
        }
        al = instructions.AllocaInstr(self.block, typ, count, name);
        self._insert(al);
        return al;
    }

    """The pointer type of a load or store address, or a TypeError."""
    def _pointer_type(self: IRBuilder, ptr: Value, action: str) -> types.PointerType {
        ptr_type = ptr.type;
        if isinstance(ptr_type, types.PointerType) {
            return ptr_type;
        }
        text = str(ptr);
        raise TypeError(
            f"cannot {action} value of type {ptr.type} ({text!r}): not a pointer"
        );
    }

    """
        Load value from pointer, with optional guaranteed alignment:
            name = *ptr
        """
    def load(
        self: IRBuilder,
        ptr: Value | None,
        name: str = '',
        align: int | None = None,
        typ: types.Type | None = None
    ) -> Value {
        if ptr is None {
            raise TypeError(MISSING_OPERAND);
        }
        self._pointer_type(ptr, "load from");
        ld = instructions.LoadInstr(self.block, ptr, name, typ);
        ld.align = align;
        self._insert(ld);
        return ld;
    }

    """
        Store value to pointer, with optional guaranteed alignment:
            *ptr = name
        """
    def store(
        self: IRBuilder,
        value: Value | None,
        ptr: Value | None,
        align: int | None = None
    ) -> Value {
        if value is None {
            raise TypeError(MISSING_OPERAND);
        }
        if ptr is None {
            raise TypeError(MISSING_OPERAND);
        }
        ptr_type = self._pointer_type(ptr, "store to");
        target = ptr_type.pointee;
        if (target is not None and (target != value.type)) {
            raise TypeError(
                f"cannot store {value.type} to {ptr.type}: mismatching types"
            );
        }
        st = instructions.StoreInstr(self.block, value, ptr);
        st.align = align;
        self._insert(st);
        return st;
    }

    """
        Atomically load from pointer with the given memory ordering:
            name = load atomic *ptr
        LLVM requires an explicit alignment on atomic accesses.
        """
    def load_atomic(
        self: IRBuilder,
        ptr: Value | None,
        ordering: str,
        align: int,
        name: str = '',
        typ: types.Type | None = None
    ) -> Value {
        if ptr is None {
            raise TypeError(MISSING_OPERAND);
        }
        self._pointer_type(ptr, "load from");
        ld = instructions.LoadAtomicInstr(self.block, ptr, ordering, align, name, typ);
        self._insert(ld);
        return ld;
    }

    """
        Atomically store value to pointer with the given memory ordering:
            store atomic value, *ptr
        """
    def store_atomic(
        self: IRBuilder,
        value: Value | None,
        ptr: Value | None,
        ordering: str,
        align: int
    ) -> Value {
        if value is None {
            raise TypeError(MISSING_OPERAND);
        }
        if ptr is None {
            raise TypeError(MISSING_OPERAND);
        }
        ptr_type = self._pointer_type(ptr, "store to");
        target = ptr_type.pointee;
        if (target is not None and (target != value.type)) {
            raise TypeError(
                f"cannot store {value.type} to {ptr.type}: mismatching types"
            );
        }
        st = instructions.StoreAtomicInstr(self.block, value, ptr, ordering, align);
        self._insert(st);
        return st;
    }

    """
        Unconditional branch to *target*.
        """
    def branch(self: IRBuilder, target: values.Block) -> Value {
        br = instructions.Branch(self.block, "br", [target]);
        self._set_terminator(br);
        return br;
    }

    """
        Switch on *value*, jumping to *default_bb* unless a case added via
        `add_case` matches.
        """
    def `switch(
        self: IRBuilder, value: Value | None, default_bb: values.Block
    ) -> instructions.SwitchInstr {
        if value is None {
            raise TypeError(MISSING_OPERAND);
        }
        swt = instructions.SwitchInstr(self.block, "switch", value, default_bb);
        self._set_terminator(swt);
        return swt;
    }

    """
        Conditional branch to *truebr* if *cond* is true, else to *falsebr*.
        """
    def cbranch(
        self: IRBuilder, cond: Value | None, truebr: values.Block, falsebr: values.Block
    ) -> instructions.ConditionalBranch {
        if cond is None {
            raise TypeError(MISSING_OPERAND);
        }
        br = instructions.ConditionalBranch(self.block, "br", [cond, truebr, falsebr]);
        self._set_terminator(br);
        return br;
    }

    """
        Return from function without a value.
        """
    def ret_void(self: IRBuilder) -> Value {
        return self._set_terminator(instructions.Ret(self.block, "ret void"));
    }

    """
        Return from function with the given *value*.
        """
    def ret(self: IRBuilder, value: Value | None) -> Value {
        if value is None {
            raise TypeError(MISSING_OPERAND);
        }
        return self._set_terminator(instructions.Ret(self.block, "ret", value));
    }

    """
        Call function *fn* with *args*:
            name = fn(args...)
        """
    def call(
        self: IRBuilder,
        fn: Value | None,
        args: any,
        name: str = '',
        cconv: str | None = None,
        tail: any = False,
        fastmath: any = None,
        attrs: any = None,
        arg_attrs: dict[int, any] | None = None
    ) -> instructions.CallInstr {
        if fn is None {
            raise TypeError(MISSING_OPERAND);
        }
        inst = instructions.CallInstr(
            self.block, fn, args, name, cconv, tail, fastmath, attrs, arg_attrs
        );
        self._insert(inst);
        return inst;
    }

    """
        Inline assembler.
        """
    def asm(
        self: IRBuilder,
        ftype: types.FunctionType,
        asm: str,
        constraint: str,
        args: any,
        side_effect: bool,
        name: str = ''
    ) -> Value {
        callee = instructions.InlineAsm(ftype, asm, constraint, side_effect);
        return self.call(callee, args, name);
    }

    """
        Compute effective address (getelementptr):
            name = getelementptr ptr, <indices...>
        """
    def gep(
        self: IRBuilder,
        ptr: Value | None,
        indices: any,
        inbounds: bool = False,
        name: str = '',
        source_etype: types.Type | None = None
    ) -> Value {
        if ptr is None {
            raise TypeError(MISSING_OPERAND);
        }
        instr = instructions.GEPInstr(
            self.block, ptr, indices, inbounds, name, source_etype
        );
        self._insert(instr);
        return instr;
    }

    """
        Extract member number *idx* from aggregate.
        """
    def extract_value(
        self: IRBuilder, agg: Value | None, idx: any, name: str = ''
    ) -> Value {
        if agg is None {
            raise TypeError(MISSING_OPERAND);
        }
        instr = instructions.ExtractValue(self.block, agg, idx, name);
        self._insert(instr);
        return instr;
    }

    """
        Insert *value* into member number *idx* from aggregate.
        """
    def insert_value(
        self: IRBuilder,
        agg: Value | None,
        value: Value | None,
        idx: any,
        name: str = ''
    ) -> Value {
        if agg is None {
            raise TypeError(MISSING_OPERAND);
        }
        if value is None {
            raise TypeError(MISSING_OPERAND);
        }
        instr = instructions.InsertValue(self.block, agg, value, idx, name);
        self._insert(instr);
        return instr;
    }

    def phi(
        self: IRBuilder, typ: types.Type, name: str = '', flags: any = None
    ) -> instructions.PhiInstr {
        inst = instructions.PhiInstr(self.block, typ, name, flags);
        self._insert(inst);
        return inst;
    }

    def unreachable(self: IRBuilder) -> Value {
        inst = instructions.Unreachable(self.block);
        self._set_terminator(inst);
        return inst;
    }

    def atomic_rmw(
        self: IRBuilder,
        op: str,
        ptr: Value | None,
        val: Value | None,
        ordering: str,
        name: str = ''
    ) -> Value {
        if ptr is None {
            raise TypeError(MISSING_OPERAND);
        }
        if val is None {
            raise TypeError(MISSING_OPERAND);
        }
        inst = instructions.AtomicRMW(self.block, op, ptr, val, ordering, name);
        self._insert(inst);
        return inst;
    }
}
