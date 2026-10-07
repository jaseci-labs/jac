"""
Implementation of LLVM IR instructions.
"""
import jaclang.compiler.backends.native.llvm.ir.types as types;
import from jaclang.compiler.backends.native.llvm.ir.values {
    Block,
    Function,
    NamedValue,
    Constant,
    MetaDataArgument,
    MetaDataString,
    AttributeSet,
    ArgumentAttributes,
    Value,
    _value_list,
    _str_list
}
import from jaclang.compiler.backends.native.llvm.ir.module { Module }

glob TailMarkerOptions: frozenset[str] = frozenset(['tail', 'musttail', 'notail']),
     _CALL_ATTRS: frozenset[str] = frozenset(
         [
             'convergent',
             'noreturn',
             'nounwind',
             'readonly',
             'readnone',
             'noinline',
             'alwaysinline'
         ]
     ),
     _FAST_MATH_FLAGS: frozenset[str] = frozenset(
         ['fast', 'nnan', 'ninf', 'nsz', 'arcp', 'contract', 'afn', 'reassoc']
     ),
     _ICMP_OPS: frozenset[str] = frozenset(
         ['eq', 'ne', 'ugt', 'uge', 'ult', 'ule', 'sgt', 'sge', 'slt', 'sle']
     ),
     _FCMP_OPS: frozenset[str] = frozenset(
         [
             'false',
             'oeq',
             'ogt',
             'oge',
             'olt',
             'ole',
             'one',
             'ord',
             'ueq',
             'ugt',
             'uge',
             'ult',
             'ule',
             'une',
             'uno',
             'true'
         ]
     );

"""The member type an aggregate index selects, or None when it selects none."""
def _member_type(typ: types.Type, index: int) -> types.Type | None {
    if isinstance(typ, types.ArrayType) {
        return typ.element if (0 <= index < typ.count) else None;
    }
    if isinstance(typ, types.VectorType) {
        return typ.element if (0 <= index < typ.count) else None;
    }
    if isinstance(typ, types.BaseStructType) {
        members = typ._elements;
        if members is None {
            return None;
        }
        if index < 0 {
            index += len(members);
        }
        return members[index] if (0 <= index < len(members)) else None;
    }
    return None;
}

"""The type reached by walking aggregate indices from a value's type."""
def _indexed_type(agg: Value, indices: list[int]) -> types.Type {
    typ = agg.type;
    for i in indices {
        found = _member_type(typ, i);
        if found is None {
            raise TypeError(f"Can't index at {indices!r} in {agg.type}");
        }
        typ = found;
    }
    return typ;
}

"""A copy of an index sequence handed in as one index or a list or tuple."""
def _index_list(indices: any) -> list[int] {
    out: list[int] = [];
    if isinstance(indices, int) {
        out.append(indices);
    } elif isinstance(indices, (`list, `tuple)) {
        for item in indices {
            if isinstance(item, int) {
                out.append(item);
            } else {
                raise TypeError(f"not an aggregate index: {item!r}");
            }
        }
    } else {
        raise TypeError(f"not an aggregate index: {indices!r}");
    }
    return out;
}

"""The type a load through a pointer value yields when none is given."""
def _loaded_type(ptr: Value) -> types.Type {
    if isinstance(ptr, AllocaInstr) {
        return ptr.allocated_type;
    }
    ptr_type = ptr.type;
    if isinstance(ptr_type, types.PointerType) {
        target = ptr_type.pointee;
        if target is not None {
            return target;
        }
    }
    raise ValueError("Load lacks type.");
}

class Instruction(NamedValue) {
    has parent: Block,
        opname: str = '',
        operands: list[Value],
        flags: list[str];

    def init(
        self: Instruction,
        parent: Block,
        typ: types.Type,
        opname: str,
        operands: list[Value],
        name: str = '',
        flags: any = None
    ) {
        assert isinstance(parent, Block);
        self.parent = parent;
        super.init(parent.scope, typ, name);
        self.opname = opname;
        self.operands = operands;
        self.flags = _str_list(flags);
    }

    has function: Function {
        getter {
            return self.parent.function;
        }
    }

    has module: Module {
        getter {
            return self.parent.function.module;
        }
    }

    def descr(self: Instruction, buf: list[str]) {
        opname = self.opname;
        if self.flags {
            opname = ' '.join(([opname] + self.flags));
        }
        operands = ', '.join([op.get_reference() for op in self.operands]);
        metadata = self._stringify_metadata(leading_comma=True);
        buf.append(f"{opname} {self.type} {operands}{metadata}\n");
    }

    def replace_usage(self: Instruction, old: Value, new: Value) {
        used = False;
        for op in self.operands {
            if op is old or op == old {
                used = True;
                break;
            }
        }
        if used {
            ops: list[Value] = [];
            for op in self.operands {
                ops.append(new if (op is old) else op);
            }
            self.operands = ops;
            self._clear_string_cache();
        }
    }

    def __repr__(self: Instruction) -> str {
        shown = ', '.join([op.__repr__() for op in self.operands]);
        return f"<ir.{self.__class__.__name__} {self._name!r} of type '{self.type}', "
        f"opname {self.opname!r}, operands [{shown}]>";
    }
}

class CallInstrAttributes(AttributeSet) {
    def _is_known(self: CallInstrAttributes, name: str) -> bool {
        return name in _CALL_ATTRS;
    }
}

class FastMathFlags(AttributeSet) {
    def _is_known(self: FastMathFlags, name: str) -> bool {
        return name in _FAST_MATH_FLAGS;
    }
}

class CallInstr(Instruction) {
    has cconv: str | None = None,
        tail: str = '',
        fastmath: FastMathFlags,
        attributes: CallInstrAttributes,
        arg_attributes: dict[int, ArgumentAttributes];

    def init(
        self: CallInstr,
        parent: Block,
        func: Value,
        args: any,
        name: str = '',
        cconv: str | None = None,
        tail: any = None,
        fastmath: any = None,
        attrs: any = None,
        arg_attrs: dict[int, any] | None = None
    ) {
        if (cconv is None) and isinstance(func, Function) {
            self.cconv = func.calling_convention;
        } else {
            self.cconv = cconv;
        }
        marker = '';
        if isinstance(tail, str) {
            if tail in TailMarkerOptions {
                marker = tail;
            } elif tail {
                marker = "tail";
            }
        } elif isinstance(tail, bool) {
            if tail {
                marker = "tail";
            }
        } elif isinstance(tail, int) {
            if tail != 0 {
                marker = "tail";
            }
        } elif tail is not None {
            marker = "tail";
        }
        self.tail = marker;
        self.fastmath = FastMathFlags(fastmath);
        self.attributes = CallInstrAttributes(attrs);
        self.arg_attributes = {};
        call_args = _value_list(args);
        if arg_attrs is not None {
            for (idx, one_attrs) in arg_attrs.items() {
                if not (0 <= idx < len(call_args)) {
                    raise ValueError(f"Invalid argument index {idx}");
                }
                self.arg_attributes[idx] = ArgumentAttributes(one_attrs);
            }
        }
        fnty = func.function_type;
        for i in range(len(fnty.args)) {
            arg = call_args[i];
            expected_type = fnty.args[i];
            if (
                isinstance(expected_type, types.MetaDataType)
                and (arg.type != expected_type)
            ) {
                arg = MetaDataArgument(arg);
            }
            if (arg.type != expected_type) {
                raise TypeError(
                    f"Type of #{1 + i} arg mismatch: {expected_type} != {arg.type}"
                );
            }
            call_args[i] = arg;
        }
        operands: list[Value] = [func];
        operands += call_args;
        super.init(parent, fnty.return_type, "call", operands, name);
    }

    has callee: Value {
        getter {
            return self.operands[0];
        }
        setter(self: CallInstr, newcallee: Value) {
            self.operands[0] = newcallee;
        }
    }

    has args: list[Value] {
        getter {
            return self.operands[1:];
        }
    }

    def replace_callee(self: CallInstr, newfunc: Value) {
        if (newfunc.function_type != self.callee.function_type) {
            raise TypeError("New function has incompatible type");
        }
        self.callee = newfunc;
    }

    """The callee function"""
    has called_function: Value {
        getter {
            return self.operands[0];
        }
    }

    def _descr(self: CallInstr, buf: list[str], add_metadata: bool) {
        shown: list[str] = [];
        for i in range(1, len(self.operands)) {
            a = self.operands[i];
            one_attrs = self.arg_attributes.get(i - 1);
            if one_attrs is not None {
                attrs = ' '.join(one_attrs._to_list(a.type)) + ' ';
            } else {
                attrs = '';
            }
            shown.append(f"{a.type} {attrs}{a.get_reference()}");
        }
        args = ', '.join(shown);
        target = self.operands[0];
        fnty = target.function_type;
        if fnty.var_arg {
            callee_ref = f"{fnty} {target.get_reference()}";
        } else {
            callee_ref = f"{fnty.return_type} {target.get_reference()}";
        }
        convention = self.cconv;
        if convention is not None and convention != '' {
            callee_ref = f"{convention} {callee_ref}";
        }
        tail_marker = "";
        if self.tail {
            tail_marker = self.tail + " ";
        }
        fn_attrs = '';
        if not self.attributes.is_empty() {
            fn_attrs = ' ' + ' '.join(self.attributes._to_list(fnty.return_type));
        }
        fm_attrs = '';
        if not self.fastmath.is_empty() {
            fm_attrs = ' ' + ' '.join(self.fastmath._to_list(fnty.return_type));
        }
        meta = self._stringify_metadata(leading_comma=True) if add_metadata else "";
        buf.append(
            f"{tail_marker}{self.opname}{fm_attrs} {callee_ref}({args}){fn_attrs}{meta}\n"
        );
    }

    def descr(self: CallInstr, buf: list[str]) {
        self._descr(buf, add_metadata=True);
    }
}

class Terminator(Instruction) {
    def init(self: Terminator, parent: Block, opname: str, operands: list[Value]) {
        super.init(parent, types.VoidType(), opname, operands);
    }

    def descr(self: Terminator, buf: list[str]) {
        operands = ', '.join(
            [f"{op.type} {op.get_reference()}" for op in self.operands]
        );
        metadata = self._stringify_metadata(leading_comma=True);
        buf.append(f"{self.opname} {operands}{metadata}");
    }
}

class PredictableInstr(Terminator) {
    def set_weights(self: PredictableInstr, weights: list[int]) {
        operands: list[Value] = [MetaDataString(self.module, "branch_weights")];
        for w in weights {
            if (w < 0) {
                raise ValueError("branch weight must be a positive integer");
            }
            operands.append(Constant(types.IntType(32), w));
        }
        md = self.module.add_metadata(operands);
        self.set_metadata("prof", md);
    }
}

class Ret(Terminator) {
    def init(self: Ret, parent: Block, opname: str, return_value: Value | None = None) {
        operands: list[Value] = [];
        if return_value is not None {
            operands.append(return_value);
        }
        super.init(parent, opname, operands);
    }

    has return_value: Value | None {
        getter {
            if self.operands {
                return self.operands[0];
            } else {
                return None;
            }
        }
    }

    def descr(self: Ret, buf: list[str]) {
        metadata = self._stringify_metadata(leading_comma=True);
        if self.operands {
            returned = self.operands[0];
            buf.append(
                f"{self.opname} {returned.type} {returned.get_reference()}{metadata}\n"
            );
        } else {
            buf.append(f"{self.opname}{metadata}\n");
        }
    }
}

class Branch(Terminator) {}

class ConditionalBranch(PredictableInstr) {}

class SwitchInstr(PredictableInstr) {
    has default_bb: Block,
        cases: list[tuple[Value, Block]];

    def init(
        self: SwitchInstr, parent: Block, opname: str, val: Value, default_bb: Block
    ) {
        super.init(parent, opname, [val]);
        self.default_bb = default_bb;
        self.cases = [];
    }

    has value: Value {
        getter {
            return self.operands[0];
        }
    }

    def add_case(self: SwitchInstr, val: any, block: Block) {
        assert isinstance(block, Block);
        if isinstance(val, Constant) {
            self.cases.append((val, block));
        } else {
            self.cases.append((Constant(self.operands[0].type, val), block));
        }
    }

    def descr(self: SwitchInstr, buf: list[str]) {
        cases: list[str] = [];
        for (case_val, case_bb) in self.cases {
            cases.append(
                f"{case_val.type} {case_val.get_reference()}, "
                f"label {case_bb.get_reference()}"
            );
        }
        switched = self.operands[0];
        joined = ' '.join(cases);
        buf.append(
            f"switch {switched.type} {switched.get_reference()}, "
            f"label {self.default_bb.get_reference()} [{joined}]  "
            f"{self._stringify_metadata(leading_comma=True)}\n"
        );
    }
}

class SelectInstr(Instruction) {
    def init(
        self: SelectInstr,
        parent: Block,
        cond: Value,
        lhs: Value,
        rhs: Value,
        name: str = '',
        flags: any = None
    ) {
        assert (lhs.type == rhs.type);
        super.init(parent, lhs.type, "select", [cond, lhs, rhs], name, flags);
    }

    has cond: Value {
        getter {
            return self.operands[0];
        }
    }

    has lhs: Value {
        getter {
            return self.operands[1];
        }
    }

    has rhs: Value {
        getter {
            return self.operands[2];
        }
    }

    def descr(self: SelectInstr, buf: list[str]) {
        cond = self.operands[0];
        lhs = self.operands[1];
        rhs = self.operands[2];
        flags = ' '.join(self.flags);
        buf.append(
            f"select {flags} {cond.type} {cond.get_reference()}, "
            f"{lhs.type} {lhs.get_reference()}, {rhs.type} {rhs.get_reference()} "
            f"{self._stringify_metadata(leading_comma=True)}\n"
        );
    }
}

class CompareInstr(Instruction) {
    with entry {
        OPNAME = 'invalid-compare';
    }

    has op: str = '';

    def _valid_op(self: CompareInstr, op: str) -> bool {
        return False;
    }

    def _valid_flag(self: CompareInstr, flag: str) -> bool {
        return False;
    }

    def init(
        self: CompareInstr,
        parent: Block,
        op: str,
        lhs: Value,
        rhs: Value,
        name: str = '',
        flags: any = None
    ) {
        if not self._valid_op(op) {
            raise ValueError(f"invalid comparison {op!r} for {self.OPNAME}");
        }
        checked = _str_list(flags);
        for flag in checked {
            if not self._valid_flag(flag) {
                raise ValueError(f"invalid flag {flag!r} for {self.OPNAME}");
            }
        }
        opname = self.OPNAME;
        lhs_type = lhs.type;
        typ: types.Type = types.IntType(1);
        if isinstance(lhs_type, types.VectorType) {
            typ = types.VectorType(types.IntType(1), lhs_type.count);
        }
        super.init(parent, typ, opname, [lhs, rhs], name, checked);
        self.op = op;
    }

    def descr(self: CompareInstr, buf: list[str]) {
        flags = ''.join([(' ' + it) for it in self.flags]);
        lhs = self.operands[0];
        rhs = self.operands[1];
        buf.append(
            f"{self.opname}{flags} {self.op} {lhs.type} {lhs.get_reference()}, "
            f"{rhs.get_reference()} {self._stringify_metadata(leading_comma=True)}\n"
        );
    }
}

class ICMPInstr(CompareInstr) {
    with entry {
        OPNAME = 'icmp';
    }

    def _valid_op(self: ICMPInstr, op: str) -> bool {
        return op in _ICMP_OPS;
    }
}

class FCMPInstr(CompareInstr) {
    with entry {
        OPNAME = 'fcmp';
    }

    def _valid_op(self: FCMPInstr, op: str) -> bool {
        return op in _FCMP_OPS;
    }

    def _valid_flag(self: FCMPInstr, flag: str) -> bool {
        return flag in _FAST_MATH_FLAGS;
    }
}

class CastInstr(Instruction) {
    def init(
        self: CastInstr,
        parent: Block,
        op: str,
        val: Value,
        typ: types.Type,
        name: str = ''
    ) {
        super.init(parent, typ, op, [val], name);
    }

    def descr(self: CastInstr, buf: list[str]) {
        val = self.operands[0];
        buf.append(
            f"{self.opname} {val.type} {val.get_reference()} to {self.type} "
            f"{self._stringify_metadata(leading_comma=True)}\n"
        );
    }
}

class LoadInstr(Instruction) {
    has align: int | None = None;

    def init(
        self: LoadInstr,
        parent: Block,
        ptr: Value,
        name: str = '',
        typ: types.Type | None = None
    ) {
        loaded = typ if typ is not None else _loaded_type(ptr);
        super.init(parent, loaded, "load", [ptr], name);
        self.align = None;
    }

    def descr(self: LoadInstr, buf: list[str]) {
        val = self.operands[0];
        alignment = self.align;
        if (alignment is not None) {
            align = f", align {alignment}";
        } else {
            align = '';
        }
        buf.append(
            f"load {self.type}, {val.type} {val.get_reference()}{align}"
            f"{self._stringify_metadata(leading_comma=True)}\n"
        );
    }
}

class StoreInstr(Instruction) {
    has align: int | None = None;

    def init(self: StoreInstr, parent: Block, val: Value, ptr: Value) {
        super.init(parent, types.VoidType(), "store", [val, ptr]);
        self.align = None;
    }

    def descr(self: StoreInstr, buf: list[str]) {
        val = self.operands[0];
        ptr = self.operands[1];
        alignment = self.align;
        if (alignment is not None) {
            align = f", align {alignment}";
        } else {
            align = '';
        }
        buf.append(
            f"store {val.type} {val.get_reference()}, {ptr.type} {ptr.get_reference()}"
            f"{align}{self._stringify_metadata(leading_comma=True)}\n"
        );
    }
}

class LoadAtomicInstr(Instruction) {
    has ordering: str = '',
        align: int = 0;

    def init(
        self: LoadAtomicInstr,
        parent: Block,
        ptr: Value,
        ordering: str,
        align: int,
        name: str = '',
        typ: types.Type | None = None
    ) {
        loaded = typ if typ is not None else _loaded_type(ptr);
        super.init(parent, loaded, "load atomic", [ptr], name);
        self.ordering = ordering;
        self.align = align;
    }

    def descr(self: LoadAtomicInstr, buf: list[str]) {
        val = self.operands[0];
        buf.append(
            f"load atomic {self.type}, {val.type} {val.get_reference()} "
            f"{self.ordering}, align {self.align}"
            f"{self._stringify_metadata(leading_comma=True)}\n"
        );
    }
}

class StoreAtomicInstr(Instruction) {
    has ordering: str = '',
        align: int = 0;

    def init(
        self: StoreAtomicInstr,
        parent: Block,
        val: Value,
        ptr: Value,
        ordering: str,
        align: int
    ) {
        super.init(parent, types.VoidType(), "store atomic", [val, ptr]);
        self.ordering = ordering;
        self.align = align;
    }

    def descr(self: StoreAtomicInstr, buf: list[str]) {
        val = self.operands[0];
        ptr = self.operands[1];
        buf.append(
            f"store atomic {val.type} {val.get_reference()}, "
            f"{ptr.type} {ptr.get_reference()} {self.ordering}, align {self.align}"
            f"{self._stringify_metadata(leading_comma=True)}\n"
        );
    }
}

class AllocaInstr(Instruction) {
    has allocated_type: types.Type,
        align: int | None = None;

    def init(
        self: AllocaInstr,
        parent: Block,
        typ: types.Type,
        count: Value | None,
        name: str
    ) {
        operands: list[Value] = [];
        if count is not None {
            operands.append(count);
        }
        super.init(parent, typ.as_pointer(), "alloca", operands, name);
        self.allocated_type = typ;
        self.align = None;
    }

    def descr(self: AllocaInstr, buf: list[str]) {
        buf.append(f"{self.opname} {self.allocated_type}");
        if self.operands {
            op = self.operands[0];
            buf.append(f", {op.type} {op.get_reference()}");
        }
        alignment = self.align;
        if (alignment is not None) {
            buf.append(f", align {alignment}");
        }
        if self.metadata {
            buf.append(self._stringify_metadata(leading_comma=True));
        }
    }
}

class GEPInstr(Instruction) {
    has source_etype: types.Type | None = None,
        pointer: Value,
        indices: list[Value],
        inbounds: bool = False;

    def init(
        self: GEPInstr,
        parent: Block,
        ptr: Value,
        indices: any,
        inbounds: bool,
        name: str,
        source_etype: types.Type | None = None
    ) {
        steps = _value_list(indices);
        typ: types.Type = ptr.type;
        ptr_type = ptr.type;
        if (source_etype is not None) {
            self.source_etype = source_etype;
        } elif isinstance(ptr_type, types.PointerType)
            and ptr_type.pointee is not None {
            lasttyp: types.Type | None = None;
            lastaddrspace = 0;
            for i in steps {
                lasttyp = typ;
                typ = typ.gep(i);
                if isinstance(lasttyp, types.PointerType) {
                    lastaddrspace = lasttyp.addrspace;
                }
            }
            if (
                not isinstance(typ, types.PointerType)
                and lasttyp is not None
                and isinstance(lasttyp, types.PointerType)
            ) {
                typ = lasttyp;
            } else {
                typ = typ.as_pointer(lastaddrspace);
            }
            self.source_etype = ptr_type.pointee;
        } else {
            raise ValueError("GEP lacks type.");
        }
        operands: list[Value] = [ptr];
        operands += steps;
        super.init(parent, typ, "getelementptr", operands, name);
        self.pointer = ptr;
        self.indices = steps;
        self.inbounds = bool(inbounds);
    }

    def descr(self: GEPInstr, buf: list[str]) {
        indices = ', '.join([f"{i.type} {i.get_reference()}" for i in self.indices]);
        op = "getelementptr inbounds" if self.inbounds else "getelementptr";
        buf.append(
            f"{op} {self.source_etype}, {self.pointer.type} "
            f"{self.pointer.get_reference()}, {indices} "
            f"{self._stringify_metadata(leading_comma=True)}\n"
        );
    }
}

class PhiInstr(Instruction) {
    has incomings: list[tuple[Value, Block]];

    def init(
        self: PhiInstr, parent: Block, typ: types.Type, name: str, flags: any = None
    ) {
        super.init(parent, typ, "phi", [], name, flags);
        self.incomings = [];
    }

    def descr(self: PhiInstr, buf: list[str]) {
        shown: list[str] = [];
        for (v, b) in self.incomings {
            shown.append(f"[{v.get_reference()}, {b.get_reference()}]");
        }
        flags = ' '.join(self.flags);
        incs = ', '.join(shown);
        buf.append(
            f"phi {flags} {self.type} {incs} "
            f"{self._stringify_metadata(leading_comma=True)}\n"
        );
    }

    def add_incoming(self: PhiInstr, value: Value | None, block: Block) {
        assert isinstance(block, Block);
        if value is None {
            raise TypeError("a phi incoming value is missing (None)");
        }
        self.incomings.append((value, block));
    }

    def replace_usage(self: PhiInstr, old: Value, new: Value) {
        swapped: list[tuple[Value, Block]] = [];
        for (val, blk) in self.incomings {
            if val is old {
                swapped.append((new, blk));
            } else {
                swapped.append((val, blk));
            }
        }
        self.incomings = swapped;
    }
}

class ExtractValue(Instruction) {
    has aggregate: Value,
        indices: list[int];

    def init(
        self: ExtractValue, parent: Block, agg: Value, indices: any, name: str = ''
    ) {
        path = _index_list(indices);
        typ = _indexed_type(agg, path);
        super.init(parent, typ, "extractvalue", [agg], name);
        self.aggregate = agg;
        self.indices = path;
    }

    def descr(self: ExtractValue, buf: list[str]) {
        indices = ', '.join([str(i) for i in self.indices]);
        buf.append(
            f"extractvalue {self.aggregate.type} {self.aggregate.get_reference()}, "
            f"{indices} {self._stringify_metadata(leading_comma=True)}\n"
        );
    }
}

class InsertValue(Instruction) {
    has aggregate: Value,
        value: Value,
        indices: list[int];

    def init(
        self: InsertValue,
        parent: Block,
        agg: Value,
        elem: Value,
        indices: any,
        name: str = ''
    ) {
        path = _index_list(indices);
        typ = _indexed_type(agg, path);
        if (elem.type != typ) {
            raise TypeError(
                f"Can only insert {typ} at {path!r} in {agg.type}: got {elem.type}"
            );
        }
        super.init(parent, agg.type, "insertvalue", [agg, elem], name);
        self.aggregate = agg;
        self.value = elem;
        self.indices = path;
    }

    def descr(self: InsertValue, buf: list[str]) {
        indices = ', '.join([str(i) for i in self.indices]);
        buf.append(
            f"insertvalue {self.aggregate.type} {self.aggregate.get_reference()}, "
            f"{self.value.type} {self.value.get_reference()}, {indices} "
            f"{self._stringify_metadata(leading_comma=True)}\n"
        );
    }
}

class Unreachable(Instruction) {
    def init(self: Unreachable, parent: Block) {
        super.init(parent, types.VoidType(), "unreachable", [], '');
    }

    def descr(self: Unreachable, buf: list[str]) {
        buf.append(self.opname);
        buf.append("\n");
    }
}

"""An inline assembly callee. It stands where a function value stands in a
call, so it is a value whose type is the assembly's return type."""
class InlineAsm(Value) {
    has asm: str = '',
        constraint: str = '',
        side_effect: bool = False;

    def init(
        self: InlineAsm,
        ftype: types.FunctionType,
        asm: str,
        constraint: str,
        side_effect: bool = False
    ) {
        self.type = ftype.return_type;
        self._callee_type = ftype;
        self.asm = asm;
        self.constraint = constraint;
        self.side_effect = side_effect;
    }

    def descr(self: InlineAsm, buf: list[str]) {
        sideeffect = 'sideeffect' if self.side_effect else '';
        buf.append(
            'asm ' + sideeffect + ' "' + self.asm + '", "' + self.constraint + '"'
        );
    }

    def _get_reference(self: InlineAsm) -> str {
        buf: list[str] = [];
        self.descr(buf);
        return "".join(buf);
    }

    def __str__(self: InlineAsm) -> str {
        return f"{self.type} {self.get_reference()}";
    }
}

class AtomicRMW(Instruction) {
    has operation: str = '',
        ordering: str = '';

    def init(
        self: AtomicRMW,
        parent: Block,
        op: str,
        ptr: Value,
        val: Value,
        ordering: str,
        name: str
    ) {
        super.init(parent, val.type, "atomicrmw", [ptr, val], name);
        self.operation = op;
        self.ordering = ordering;
    }

    def descr(self: AtomicRMW, buf: list[str]) {
        ptr = self.operands[0];
        val = self.operands[1];
        buf.append(
            f"atomicrmw {self.operation} {ptr.type} {ptr.get_reference()}, "
            f"{val.type} {val.get_reference()} {self.ordering} "
            f"{self._stringify_metadata(leading_comma=True)}\n"
        );
    }
}
