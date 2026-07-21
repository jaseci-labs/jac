"""
Implementation of LLVM IR instructions.
"""
import from jaclang.compiler.passes.native.llvm.ir { types }
import from jaclang.compiler.passes.native.llvm.ir.values {
    Block,
    Function,
    NamedValue,
    Constant,
    MetaDataArgument,
    MetaDataString,
    AttributeSet,
    ArgumentAttributes
}
import from jaclang.compiler.passes.native.llvm.ir._utils { _HasMetadata }
class Instruction(NamedValue, _HasMetadata) {
    def init(
        self: Instruction,
        parent: Any,
        typ: Any,
        opname: Any,
        operands: Any,
        name: Any = '',
        flags: Any = ()
    ) -> object {
        super.init(parent, typ, name=name);
        assert isinstance(parent, Block);
        assert isinstance(flags, (`tuple, `list));
        self.opname = opname;
        self.operands = operands;
        self.flags = `list(flags);
        self.metadata = {};
    }

    @property
    def function(self: Instruction) -> object {
        return self.parent.function;
    }

    @property
    def module(self: Instruction) -> object {
        return self.parent.function.module;
    }

    def descr(self: Instruction, buf: Any) -> object {
        opname = self.opname;
        if self.flags {
            opname = ' '.join(([opname] + self.flags));
        }
        operands = ', '.join([op.get_reference() for op in self.operands]);
        typ = self.type;
        metadata = self._stringify_metadata(leading_comma=True);
        buf.append("{0} {1} {2}{3}\n".format(opname, typ, operands, metadata));
    }

    def replace_usage(self: Instruction, old: Any, new: Any) -> object {
        if (old in self.operands) {
            ops = [];
            for op in self.operands {
                ops.append(new if (op is old) else op);
            }
            self.operands = `tuple(ops);
            self._clear_string_cache();
        }
    }

    def __repr__(self: Instruction) -> object {
        return (
            "<ir.%s %r of type '%s', opname %r, operands %r>" % (
                self.__class__.__name__,
                self.name,
                self.type,
                self.opname,
                self.operands
            )
        );
    }
}

class CallInstrAttributes(AttributeSet) {
    with entry {
        _known = frozenset(
            [
                'convergent',
                'noreturn',
                'nounwind',
                'readonly',
                'readnone',
                'noinline',
                'alwaysinline'
            ]
        );
    }
}

with entry {
    TailMarkerOptions = frozenset(['tail', 'musttail', 'notail']);
}

class FastMathFlags(AttributeSet) {
    with entry {
        _known = frozenset(
            ['fast', 'nnan', 'ninf', 'nsz', 'arcp', 'contract', 'afn', 'reassoc']
        );
    }
}

class CallInstr(Instruction) {
    def init(
        self: CallInstr,
        parent: Any,
        func: Any,
        args: Any,
        name: Any = '',
        cconv: Any = None,
        tail: Any = None,
        fastmath: Any = (),
        attrs: Any = (),
        arg_attrs: Any = None
    ) -> object {
        self.cconv = func.calling_convention
            if ((cconv is None) and isinstance(func, Function))
            else cconv;
        if (isinstance(tail, str) and (tail in TailMarkerOptions)) {
            ;
        } elif tail {
            tail = "tail";
        } else {
            tail = "";
        }
        self.tail = tail;
        self.fastmath = FastMathFlags(fastmath);
        self.attributes = CallInstrAttributes(attrs);
        self.arg_attributes = {};
        if arg_attrs {
            for (idx, attrs) in arg_attrs.items() {
                if not (0 <= idx < len(args)) {
                    raise ValueError("Invalid argument index {}".format(idx));
                }
                self.arg_attributes[idx] = ArgumentAttributes(attrs);
            }
        }
        args = `list(args);
        for i in range(len(func.function_type.args)) {
            arg = args[i];
            expected_type = func.function_type.args[i];
            if (
                isinstance(expected_type, types.MetaDataType)
                and (arg.type != expected_type)
            ) {
                arg = MetaDataArgument(arg);
            }
            if (arg.type != expected_type) {
                msg = "Type of #{0} arg mismatch: {1} != {2}".format(
                    (1 + i), expected_type, arg.type
                );
                raise TypeError(msg);
            }
            args[i] = arg;
        }
        super.init(
            parent,
            func.function_type.return_type,
            "call",
            ([func] + `list(args)),
            name=name
        );
    }

    @property
    def callee(self: CallInstr) -> object {
        return self.operands[0];
    }

    @callee.setter
    def callee(self: CallInstr, newcallee: Any) -> object {
        self.operands[0] = newcallee;
    }

    @property
    def args(self: CallInstr) -> object {
        return self.operands[1:];
    }

    def replace_callee(self: CallInstr, newfunc: Any) -> object {
        if (newfunc.function_type != self.callee.function_type) {
            raise TypeError("New function has incompatible type");
        }
        self.callee = newfunc;
    }

    """The callee function"""
    @property
    def called_function(self: CallInstr) -> object {
        return self.callee;
    }

    def _descr(self: CallInstr, buf: Any, add_metadata: Any) -> object {
        def descr_arg(i: Any, a: Any) -> object {
            if (i in self.arg_attributes) {
                attrs = ' '.join(self.arg_attributes[i]._to_list(a.type)) + ' ';
            } else {
                attrs = '';
            }
            return '{0} {1}{2}'.format(a.type, attrs, a.get_reference());
        }
        args = ', '.join([descr_arg(i, a) for (i, a) in enumerate(self.args)]);
        fnty = self.callee.function_type;
        if fnty.var_arg {
            ty = fnty;
        } else {
            ty = fnty.return_type;
        }
        callee_ref = "{0} {1}".format(ty, self.callee.get_reference());
        if self.cconv {
            callee_ref = "{0} {1}".format(self.cconv, callee_ref);
        }
        tail_marker = "";
        if self.tail {
            tail_marker = "{0} ".format(self.tail);
        }
        fn_attrs = (' ' + ' '.join(self.attributes._to_list(fnty.return_type)))
            if self.attributes
            else '';
        fm_attrs = (' ' + ' '.join(self.fastmath._to_list(fnty.return_type)))
            if self.fastmath
            else '';
        buf.append(
            "{tail}{op}{fastmath} {callee}({args}){attr}{meta}\n".format(
                tail=tail_marker,
                op=self.opname,
                callee=callee_ref,
                fastmath=fm_attrs,
                args=args,
                attr=fn_attrs,
                meta=self._stringify_metadata(leading_comma=True)
                    if add_metadata
                    else ""
            )
        );
    }

    def descr(self: CallInstr, buf: Any) -> object {
        self._descr(buf, add_metadata=True);
    }
}

class Terminator(Instruction) {
    def init(self: Terminator, parent: Any, opname: Any, operands: Any) -> object {
        super.init(parent, types.VoidType(), opname, operands);
    }

    def descr(self: Terminator, buf: Any) -> object {
        opname = self.opname;
        operands = ', '.join(
            ["{0} {1}".format(op.type, op.get_reference()) for op in self.operands]
        );
        metadata = self._stringify_metadata(leading_comma=True);
        buf.append("{0} {1}{2}".format(opname, operands, metadata));
    }
}

class PredictableInstr(Instruction) {
    def set_weights(self: PredictableInstr, weights: Any) -> object {
        operands = [MetaDataString(self.module, "branch_weights")];
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
    def init(self: Ret, parent: Any, opname: Any, return_value: Any = None) -> object {
        operands = [return_value] if (return_value is not None) else [];
        super.init(parent, opname, operands);
    }

    @property
    def return_value(self: Ret) -> object {
        if self.operands {
            return self.operands[0];
        } else {
            return None;
        }
    }

    def descr(self: Ret, buf: Any) -> object {
        return_value = self.return_value;
        metadata = self._stringify_metadata(leading_comma=True);
        if (return_value is not None) {
            buf.append(
                "{0} {1} {2}{3}\n".format(
                    self.opname,
                    return_value.type,
                    return_value.get_reference(),
                    metadata
                )
            );
        } else {
            buf.append("{0}{1}\n".format(self.opname, metadata));
        }
    }
}

class Branch(Terminator) {}
class ConditionalBranch(PredictableInstr, Terminator) {}
class SwitchInstr(PredictableInstr, Terminator) {
    def init(
        self: SwitchInstr, parent: Any, opname: Any, val: Any, default_bb: Any
    ) -> object {
        super.init(parent, opname, [val]);
        self.default_bb = default_bb;
        self.cases = [];
    }

    @property
    def value(self: SwitchInstr) -> object {
        return self.operands[0];
    }

    def add_case(self: SwitchInstr, val: Any, block: Any) -> object {
        assert isinstance(block, Block);
        if not isinstance(val, Constant) {
            val = Constant(self.value.type, val);
        }
        self.cases.append((val, block));
    }

    def descr(self: SwitchInstr, buf: Any) -> object {
        cases = [
            "{0} {1}, label {2}".format(
                case.type, case.get_reference(), blk.get_reference()
            ) for (case, blk) in self.cases
        ];
        buf.append(
            "switch {0} {1}, label {2} [{3}]  {4}\n".format(
                self.value.type,
                self.value.get_reference(),
                self.default_bb.get_reference(),
                ' '.join(cases),
                self._stringify_metadata(leading_comma=True)
            )
        );
    }
}

class SwitchInstr(PredictableInstr, Terminator) {
    def init(
        self: SwitchInstr, parent: Any, opname: Any, val: Any, default_bb: Any
    ) -> object {
        super.init(parent, opname, [val]);
        self.default_bb = default_bb;
        self.cases = [];
    }

    @property
    def value(self: SwitchInstr) -> object {
        return self.operands[0];
    }

    def add_case(self: SwitchInstr, val: Any, block: Any) -> object {
        assert isinstance(block, Block);
        if not isinstance(val, Constant) {
            val = Constant(self.value.type, val);
        }
        self.cases.append((val, block));
    }

    def descr(self: SwitchInstr, buf: Any) -> object {
        cases = [];
        for cs in self.cases {
            cases.append(
                "{0} {1}, label {2}".format(
                    cs[0].type, cs[0].get_reference(), cs[1].get_reference()
                )
            );
        }
        buf.append(
            "switch {0} {1}, label {2} [{3}]  {4}\n".format(
                self.value.type,
                self.value.get_reference(),
                self.default_bb.get_reference(),
                ' '.join(cases),
                self._stringify_metadata(leading_comma=True)
            )
        );
    }
}

class SelectInstr(Instruction) {
    def init(
        self: SelectInstr,
        parent: Any,
        cond: Any,
        lhs: Any,
        rhs: Any,
        name: Any = '',
        flags: Any = ()
    ) -> object {
        assert (lhs.type == rhs.type);
        super.init(
            parent, lhs.type, "select", [cond, lhs, rhs], name=name, flags=flags
        );
    }

    @property
    def cond(self: SelectInstr) -> object {
        return self.operands[0];
    }

    @property
    def lhs(self: SelectInstr) -> object {
        return self.operands[1];
    }

    @property
    def rhs(self: SelectInstr) -> object {
        return self.operands[2];
    }

    def descr(self: SelectInstr, buf: Any) -> object {
        buf.append(
            "select {0} {1} {2}, {3} {4}, {5} {6} {7}\n".format(
                ' '.join(self.flags),
                self.cond.type,
                self.cond.get_reference(),
                self.lhs.type,
                self.lhs.get_reference(),
                self.rhs.type,
                self.rhs.get_reference(),
                self._stringify_metadata(leading_comma=True)
            )
        );
    }
}

class CompareInstr(Instruction) {
    with entry {
        OPNAME = 'invalid-compare';
        VALID_OP = {};
    }

    def init(
        self: CompareInstr,
        parent: Any,
        op: Any,
        lhs: Any,
        rhs: Any,
        name: Any = '',
        flags: Any = []
    ) -> object {
        if (op not in self.VALID_OP) {
            raise ValueError(("invalid comparison %r for %s" % (op, self.OPNAME)));
        }
        for flag in flags {
            if (flag not in self.VALID_FLAG) {
                raise ValueError(("invalid flag %r for %s" % (flag, self.OPNAME)));
            }
        }
        opname = self.OPNAME;
        if isinstance(lhs.type, types.VectorType) {
            typ = types.VectorType(types.IntType(1), lhs.type.count);
        } else {
            typ = types.IntType(1);
        }
        super.init(parent, typ, opname, [lhs, rhs], flags=flags, name=name);
        self.op = op;
    }

    def descr(self: CompareInstr, buf: Any) -> object {
        buf.append(
            "{opname}{flags} {op} {ty} {lhs}, {rhs} {meta}\n".format(
                opname=self.opname,
                flags=''.join((' ' + it) for it in self.flags),
                op=self.op,
                ty=self.operands[0].type,
                lhs=self.operands[0].get_reference(),
                rhs=self.operands[1].get_reference(),
                meta=self._stringify_metadata(leading_comma=True)
            )
        );
    }
}

class ICMPInstr(CompareInstr) {
    with entry {
        OPNAME = 'icmp';
        VALID_OP = {
            'eq': 'equal',
            'ne': 'not equal',
            'ugt': 'unsigned greater than',
            'uge': 'unsigned greater or equal',
            'ult': 'unsigned less than',
            'ule': 'unsigned less or equal',
            'sgt': 'signed greater than',
            'sge': 'signed greater or equal',
            'slt': 'signed less than',
            'sle': 'signed less or equal'
        };
        VALID_FLAG = `set();
    }
}

class FCMPInstr(CompareInstr) {
    with entry {
        OPNAME = 'fcmp';
        VALID_OP = {
            'false': 'no comparison, always returns false',
            'oeq': 'ordered and equal',
            'ogt': 'ordered and greater than',
            'oge': 'ordered and greater than or equal',
            'olt': 'ordered and less than',
            'ole': 'ordered and less than or equal',
            'one': 'ordered and not equal',
            'ord': 'ordered (no nans)',
            'ueq': 'unordered or equal',
            'ugt': 'unordered or greater than',
            'uge': 'unordered or greater than or equal',
            'ult': 'unordered or less than',
            'ule': 'unordered or less than or equal',
            'une': 'unordered or not equal',
            'uno': 'unordered (either nans)',
            'true': 'no comparison, always returns true'
        };
        VALID_FLAG = {
            'nnan',
            'ninf',
            'nsz',
            'arcp',
            'contract',
            'afn',
            'reassoc',
            'fast'
        };
    }
}

class CastInstr(Instruction) {
    def init(
        self: CastInstr, parent: Any, op: Any, val: Any, typ: Any, name: Any = ''
    ) -> object {
        super.init(parent, typ, op, [val], name=name);
    }

    def descr(self: CastInstr, buf: Any) -> object {
        buf.append(
            "{0} {1} {2} to {3} {4}\n".format(
                self.opname,
                self.operands[0].type,
                self.operands[0].get_reference(),
                self.type,
                self._stringify_metadata(leading_comma=True)
            )
        );
    }
}

class LoadInstr(Instruction) {
    def init(
        self: LoadInstr, parent: Any, ptr: Any, name: Any = '', typ: Any = None
    ) -> object {
        if (typ is None) {
            if isinstance(ptr, AllocaInstr) {
                typ = ptr.allocated_type;
            } elif not ptr.type.is_opaque {
                typ = ptr.type.pointee;
            } else {
                raise ValueError("Load lacks type.");
            }
        }
        super.init(parent, typ, "load", [ptr], name=name);
        self.align = None;
    }

    def descr(self: LoadInstr, buf: Any) -> object {
        [val] = self.operands;
        if (self.align is not None) {
            align = ', align %d' % self.align;
        } else {
            align = '';
        }
        buf.append(
            "load {0}, {1} {2}{3}{4}\n".format(
                self.type,
                val.type,
                val.get_reference(),
                align,
                self._stringify_metadata(leading_comma=True)
            )
        );
    }
}

class StoreInstr(Instruction) {
    def init(self: StoreInstr, parent: Any, val: Any, ptr: Any) -> object {
        super.init(parent, types.VoidType(), "store", [val, ptr]);
    }

    def descr(self: StoreInstr, buf: Any) -> object {
        (val, ptr) = self.operands;
        if (self.align is not None) {
            align = ', align %d' % self.align;
        } else {
            align = '';
        }
        buf.append(
            "store {0} {1}, {2} {3}{4}{5}\n".format(
                val.type,
                val.get_reference(),
                ptr.type,
                ptr.get_reference(),
                align,
                self._stringify_metadata(leading_comma=True)
            )
        );
    }
}

class AllocaInstr(Instruction) {
    def init(
        self: AllocaInstr, parent: Any, typ: Any, count: Any, name: Any
    ) -> object {
        operands = [count] if count else ();
        super.init(parent, typ.as_pointer(), "alloca", operands, name);
        self.allocated_type = typ;
        self.align = None;
    }

    def descr(self: AllocaInstr, buf: Any) -> object {
        buf.append("{0} {1}".format(self.opname, self.allocated_type));
        if self.operands {
            (op, ) = self.operands;
            buf.append(", {0} {1}".format(op.type, op.get_reference()));
        }
        if (self.align is not None) {
            buf.append(", align {0}".format(self.align));
        }
        if self.metadata {
            buf.append(self._stringify_metadata(leading_comma=True));
        }
    }
}

class GEPInstr(Instruction) {
    def init(
        self: GEPInstr,
        parent: Any,
        ptr: Any,
        indices: Any,
        inbounds: Any,
        name: Any,
        source_etype: Any = None
    ) -> object {
        if (source_etype is not None) {
            typ = ptr.type;
            self.source_etype = source_etype;
        } elif not ptr.type.is_opaque {
            typ = ptr.type;
            lasttyp = None;
            lastaddrspace = 0;
            for i in indices {
                (lasttyp, typ) = (typ, typ.gep(i));
                if isinstance(lasttyp, types.PointerType) {
                    lastaddrspace = lasttyp.addrspace;
                }
            }
            if (
                not isinstance(typ, types.PointerType)
                and isinstance(lasttyp, types.PointerType)
            ) {
                typ = lasttyp;
            } else {
                typ = typ.as_pointer(lastaddrspace);
            }
            self.source_etype = ptr.type.pointee;
        } else {
            raise ValueError("GEP lacks type.");
        }
        super.init(parent, typ, "getelementptr", ([ptr] + `list(indices)), name=name);
        self.pointer = ptr;
        self.indices = indices;
        self.inbounds = inbounds;
    }

    def descr(self: GEPInstr, buf: Any) -> object {
        indices = ['{0} {1}'.format(i.type, i.get_reference()) for i in self.indices];
        op = "getelementptr inbounds" if self.inbounds else "getelementptr";
        buf.append(
            "{0} {1}, {2} {3}, {4} {5}\n".format(
                op,
                self.source_etype,
                self.pointer.type,
                self.pointer.get_reference(),
                ', '.join(indices),
                self._stringify_metadata(leading_comma=True)
            )
        );
    }
}

class PhiInstr(Instruction) {
    def init(
        self: PhiInstr, parent: Any, typ: Any, name: Any, flags: Any = ()
    ) -> object {
        super.init(parent, typ, "phi", (), name=name, flags=flags);
        self.incomings = [];
    }

    def descr(self: PhiInstr, buf: Any) -> object {
        incs = ', '.join(
            '[{0}, {1}]'.format(v.get_reference(), b.get_reference())
            for (v, b) in self.incomings
        );
        buf.append(
            "phi {0} {1} {2} {3}\n".format(
                ' '.join(self.flags),
                self.type,
                incs,
                self._stringify_metadata(leading_comma=True)
            )
        );
    }

    def add_incoming(self: PhiInstr, value: Any, block: Any) -> object {
        assert isinstance(block, Block);
        self.incomings.append((value, block));
    }

    def replace_usage(self: PhiInstr, old: Any, new: Any) -> object {
        self.incomings = [
            (new if (val is old) else val, blk) for (val, blk) in self.incomings
        ];
    }
}

class ExtractValue(Instruction) {
    def init(
        self: ExtractValue, parent: Any, agg: Any, indices: Any, name: Any = ''
    ) -> object {
        typ = agg.type;
        try {
            for i in indices {
                typ = typ.elements[i];
            }
        } except (AttributeError, IndexError) {
            raise TypeError(("Can't index at %r in %s" % (`list(indices), agg.type)));
        }
        super.init(parent, typ, "extractvalue", [agg], name=name);
        self.aggregate = agg;
        self.indices = indices;
    }

    def descr(self: ExtractValue, buf: Any) -> object {
        indices = [str(i) for i in self.indices];
        buf.append(
            "extractvalue {0} {1}, {2} {3}\n".format(
                self.aggregate.type,
                self.aggregate.get_reference(),
                ', '.join(indices),
                self._stringify_metadata(leading_comma=True)
            )
        );
    }
}

class InsertValue(Instruction) {
    def init(
        self: InsertValue,
        parent: Any,
        agg: Any,
        elem: Any,
        indices: Any,
        name: Any = ''
    ) -> object {
        typ = agg.type;
        try {
            for i in indices {
                typ = typ.elements[i];
            }
        } except (AttributeError, IndexError) {
            raise TypeError(("Can't index at %r in %s" % (`list(indices), agg.type)));
        }
        if (elem.type != typ) {
            raise TypeError(
                (
                    "Can only insert %s at %r in %s: got %s" % (
                        typ,
                        `list(indices),
                        agg.type,
                        elem.type
                    )
                )
            );
        }
        super.init(parent, agg.type, "insertvalue", [agg, elem], name=name);
        self.aggregate = agg;
        self.value = elem;
        self.indices = indices;
    }

    def descr(self: InsertValue, buf: Any) -> object {
        indices = [str(i) for i in self.indices];
        buf.append(
            "insertvalue {0} {1}, {2} {3}, {4} {5}\n".format(
                self.aggregate.type,
                self.aggregate.get_reference(),
                self.value.type,
                self.value.get_reference(),
                ', '.join(indices),
                self._stringify_metadata(leading_comma=True)
            )
        );
    }
}

class Unreachable(Instruction) {
    def init(self: Unreachable, parent: Any) -> object {
        super.init(parent, types.VoidType(), "unreachable", (), name='');
    }

    def descr(self: Unreachable, buf: Any) -> object {
        buf += (self.opname, "\n");
    }
}

class InlineAsm(object) {
    def init(
        self: InlineAsm, ftype: Any, asm: Any, constraint: Any, side_effect: Any = False
    ) -> object {
        self.type = ftype.return_type;
        self.function_type = ftype;
        self.asm = asm;
        self.constraint = constraint;
        self.side_effect = side_effect;
    }

    def descr(self: InlineAsm, buf: Any) -> object {
        sideeffect = 'sideeffect' if self.side_effect else '';
        fmt = 'asm {sideeffect} "{asm}", "{constraint}"';
        buf.append(
            fmt.format(sideeffect=sideeffect, asm=self.asm, constraint=self.constraint)
        );
    }

    def get_reference(self: InlineAsm) -> object {
        buf = [];
        self.descr(buf);
        return "".join(buf);
    }

    def __str__(self: InlineAsm) -> object {
        return "{0} {1}".format(self.type, self.get_reference());
    }
}

class AtomicRMW(Instruction) {
    def init(
        self: AtomicRMW,
        parent: Any,
        op: Any,
        ptr: Any,
        val: Any,
        ordering: Any,
        name: Any
    ) -> object {
        super.init(parent, val.type, "atomicrmw", (ptr, val), name=name);
        self.operation = op;
        self.ordering = ordering;
    }

    def descr(self: AtomicRMW, buf: Any) -> object {
        (ptr, val) = self.operands;
        fmt = "atomicrmw {op} {ptrty} {ptr}, {valty} {val} {ordering} " "{metadata}\n";
        buf.append(
            fmt.format(
                op=self.operation,
                ptrty=ptr.type,
                ptr=ptr.get_reference(),
                valty=val.type,
                val=val.get_reference(),
                ordering=self.ordering,
                metadata=self._stringify_metadata(leading_comma=True)
            )
        );
    }
}
