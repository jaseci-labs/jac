"""
Classes that are LLVM values: Value, Constant...
Instructions are in the instructions module.
"""
import functools;
import string;
import re;
import from types { MappingProxyType }
import from jaclang.compiler.passes.native.llvm.ir { values, types, _utils }
import from jaclang.compiler.passes.native.llvm.ir._utils { _StrCaching, _StringReferenceCaching, _HasMetadata }
with entry {
    _VALID_CHARS = (
        frozenset(map(ord, string.ascii_letters)) | frozenset(
            map(ord, string.digits)
        ) | frozenset(map(ord, ' !#$%&\'()*+,-./:;<=>?@[]^_`{|}~'))
    );
    _SIMPLE_IDENTIFIER_RE = re.compile(r"[-a-zA-Z$._][-a-zA-Z$._0-9]*$");
    _CMP_MAP = {'>': 'gt', '<': 'lt', '==': 'eq', '!=': 'ne', '>=': 'ge', '<=': 'le'};
}
"""
    Escape the given bytestring for safe use as a LLVM array constant.
    Any unicode string input is first encoded with utf8 into bytes.
    """
def _escape_string(text: Any, _map: Any = {}) -> object {
    if isinstance(text, str) {
        text = text.encode();
    }
    assert isinstance(text, (`bytes, bytearray));
    if not _map {
        for ch in range(256) {
            if (ch in _VALID_CHARS) {
                _map[ch] = chr(ch);
            } else {
                _map[ch] = '\\%02x' % ch;
            }
        }
    }
    buf = [_map[ch] for ch in text];
    return ''.join(buf);
}

def _binop(opname: Any) -> object {
    def wrap(fn: Any) -> object {
        @functools.wraps(fn)
        def wrapped(lhs: Any, rhs: Any) -> object {
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
            fmt = "{0} ({1} {2}, {3} {4})".format(
                opname, lhs.type, lhs.get_reference(), rhs.type, rhs.get_reference()
            );
            return FormattedConstant(lhs.type, fmt);
        }
        return wrapped;
    }
    return wrap;
}
def _castop(opname: Any) -> object {
    def wrap(fn: Any) -> object {
        @functools.wraps(fn)
        def wrapped(self: Any, typ: Any) -> object {
            fn(self, typ);
            if (typ == self.type) {
                return self;
            }
            op = "{0} ({1} {2} to {3})".format(
                opname, self.type, self.get_reference(), typ
            );
            return FormattedConstant(typ, op);
        }
        return wrapped;
    }
    return wrap;
}
"""
    A mixin defining constant operations, for use in constant-like classes.
    """
class _ConstOpMixin(object) {
    """
        Left integer shift:
            lhs << rhs
        """
    @_binop('shl')
    def shl(self: _ConstOpMixin, other: Any) -> object { }

    """
        Logical (unsigned) right integer shift:
            lhs >> rhs
        """
    @_binop('lshr')
    def lshr(self: _ConstOpMixin, other: Any) -> object { }

    """
        Arithmetic (signed) right integer shift:
            lhs >> rhs
        """
    @_binop('ashr')
    def ashr(self: _ConstOpMixin, other: Any) -> object { }

    """
        Integer addition:
            lhs + rhs
        """
    @_binop('add')
    def add(self: _ConstOpMixin, other: Any) -> object { }

    """
        Floating-point addition:
            lhs + rhs
        """
    @_binop('fadd')
    def fadd(self: _ConstOpMixin, other: Any) -> object { }

    """
        Integer subtraction:
            lhs - rhs
        """
    @_binop('sub')
    def sub(self: _ConstOpMixin, other: Any) -> object { }

    """
        Floating-point subtraction:
            lhs - rhs
        """
    @_binop('fsub')
    def fsub(self: _ConstOpMixin, other: Any) -> object { }

    """
        Integer multiplication:
            lhs * rhs
        """
    @_binop('mul')
    def mul(self: _ConstOpMixin, other: Any) -> object { }

    """
        Floating-point multiplication:
            lhs * rhs
        """
    @_binop('fmul')
    def fmul(self: _ConstOpMixin, other: Any) -> object { }

    """
        Unsigned integer division:
            lhs / rhs
        """
    @_binop('udiv')
    def udiv(self: _ConstOpMixin, other: Any) -> object { }

    """
        Signed integer division:
            lhs / rhs
        """
    @_binop('sdiv')
    def sdiv(self: _ConstOpMixin, other: Any) -> object { }

    """
        Floating-point division:
            lhs / rhs
        """
    @_binop('fdiv')
    def fdiv(self: _ConstOpMixin, other: Any) -> object { }

    """
        Unsigned integer remainder:
            lhs % rhs
        """
    @_binop('urem')
    def urem(self: _ConstOpMixin, other: Any) -> object { }

    """
        Signed integer remainder:
            lhs % rhs
        """
    @_binop('srem')
    def srem(self: _ConstOpMixin, other: Any) -> object { }

    """
        Floating-point remainder:
            lhs % rhs
        """
    @_binop('frem')
    def frem(self: _ConstOpMixin, other: Any) -> object { }

    """
        Bitwise integer OR:
            lhs | rhs
        """
    @_binop('or')
    def or_(self: _ConstOpMixin, other: Any) -> object { }

    """
        Bitwise integer AND:
            lhs & rhs
        """
    @_binop('and')
    def and_(self: _ConstOpMixin, other: Any) -> object { }

    """
        Bitwise integer XOR:
            lhs ^ rhs
        """
    @_binop('xor')
    def xor(self: _ConstOpMixin, other: Any) -> object { }

    def _cmp(
        self: _ConstOpMixin, prefix: Any, sign: Any, cmpop: Any, other: Any
    ) -> object {
        ins = prefix + 'cmp';
        try {
            op = _CMP_MAP[cmpop];
        } except KeyError {
            raise ValueError(("invalid comparison %r for %s" % (cmpop, ins)));
        }
        if not ((prefix == 'i') and (cmpop in ('==', '!='))) {
            op = sign + op;
        }
        if (self.type != other.type) {
            raise ValueError(
                (
                    "Operands must be the same type, got (%s, %s)" % (
                        self.type,
                        other.type
                    )
                )
            );
        }
        fmt = "{0} {1} ({2} {3}, {4} {5})".format(
            ins, op, self.type, self.get_reference(), other.type, other.get_reference()
        );
        return FormattedConstant(types.IntType(1), fmt);
    }
    """
        Signed integer comparison:
            lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>='
        """
    def icmp_signed(self: _ConstOpMixin, cmpop: Any, other: Any) -> object {
        return self._cmp('i', 's', cmpop, other);
    }

    """
        Unsigned integer (or pointer) comparison:
            lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>='
        """
    def icmp_unsigned(self: _ConstOpMixin, cmpop: Any, other: Any) -> object {
        return self._cmp('i', 'u', cmpop, other);
    }

    """
        Floating-point ordered comparison:
            lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>=', 'ord', 'uno'
        """
    def fcmp_ordered(self: _ConstOpMixin, cmpop: Any, other: Any) -> object {
        return self._cmp('f', 'o', cmpop, other);
    }

    """
        Floating-point unordered comparison:
            lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>=', 'ord', 'uno'
        """
    def fcmp_unordered(self: _ConstOpMixin, cmpop: Any, other: Any) -> object {
        return self._cmp('f', 'u', cmpop, other);
    }

    """
        Bitwise integer complement:
            ~value
        """
    def not_(self: _ConstOpMixin) -> object {
        if isinstance(self.type, types.VectorType) {
            rhs = values.Constant(self.type, ((-1, ) * self.type.count));
        } else {
            rhs = values.Constant(self.type, -1);
        }
        return self.xor(rhs);
    }

    """
        Integer negative:
            -value
        """
    def neg(self: _ConstOpMixin) -> object {
        zero = values.Constant(self.type, 0);
        return zero.sub(self);
    }

    """
        Floating-point negative:
            -value
        """
    def fneg(self: _ConstOpMixin) -> object {
        fmt = "fneg ({0} {1})".format(self.type, self.get_reference());
        return FormattedConstant(self.type, fmt);
    }

    """
        Truncating integer downcast to a smaller type.
        """
    @_castop('trunc')
    def trunc(self: _ConstOpMixin, typ: Any) -> object { }

    """
        Zero-extending integer upcast to a larger type
        """
    @_castop('zext')
    def zext(self: _ConstOpMixin, typ: Any) -> object { }

    """
        Sign-extending integer upcast to a larger type.
        """
    @_castop('sext')
    def sext(self: _ConstOpMixin, typ: Any) -> object { }

    """
        Floating-point downcast to a less precise type.
        """
    @_castop('fptrunc')
    def fptrunc(self: _ConstOpMixin, typ: Any) -> object { }

    """
        Floating-point upcast to a more precise type.
        """
    @_castop('fpext')
    def fpext(self: _ConstOpMixin, typ: Any) -> object { }

    """
        Pointer cast to a different pointer type.
        """
    @_castop('bitcast')
    def bitcast(self: _ConstOpMixin, typ: Any) -> object { }

    """
        Convert floating-point to unsigned integer.
        """
    @_castop('fptoui')
    def fptoui(self: _ConstOpMixin, typ: Any) -> object { }

    """
        Convert unsigned integer to floating-point.
        """
    @_castop('uitofp')
    def uitofp(self: _ConstOpMixin, typ: Any) -> object { }

    """
        Convert floating-point to signed integer.
        """
    @_castop('fptosi')
    def fptosi(self: _ConstOpMixin, typ: Any) -> object { }

    """
        Convert signed integer to floating-point.
        """
    @_castop('sitofp')
    def sitofp(self: _ConstOpMixin, typ: Any) -> object { }

    """
        Cast pointer to integer.
        """
    @_castop('ptrtoint')
    def ptrtoint(self: _ConstOpMixin, typ: Any) -> object {
        if not isinstance(self.type, types.PointerType) {
            msg = "can only call ptrtoint() on pointer type, not '%s'";
            raise TypeError((msg % (self.type, )));
        }
        if not isinstance(typ, types.IntType) {
            raise TypeError(
                ("can only ptrtoint() to integer type, not '%s'" % (typ, ))
            );
        }
    }

    """
        Cast integer to pointer.
        """
    @_castop('inttoptr')
    def inttoptr(self: _ConstOpMixin, typ: Any) -> object {
        if not isinstance(self.type, types.IntType) {
            msg = "can only call inttoptr() on integer constants, not '%s'";
            raise TypeError((msg % (self.type, )));
        }
        if not isinstance(typ, types.PointerType) {
            raise TypeError(
                ("can only inttoptr() to pointer type, not '%s'" % (typ, ))
            );
        }
    }

    """
        Call getelementptr on this pointer constant.
        """
    def gep(self: _ConstOpMixin, indices: Any) -> object {
        if not isinstance(self.type, types.PointerType) {
            raise TypeError(
                ("can only call gep() on pointer constants, not '%s'" % (self.type, ))
            );
        }
        outtype = self.type;
        for i in indices {
            outtype = outtype.gep(i);
        }
        strindices = [
            "{0} {1}".format(idx.type, idx.get_reference()) for idx in indices
        ];
        op = "getelementptr ({0}, {1} {2}, {3})".format(
            self.type.pointee, self.type, self.get_reference(), ', '.join(strindices)
        );
        return FormattedConstant(outtype.as_pointer(self.addrspace), op);
    }
}

"""
    The base class for all values.
    """
class Value(object) {
    def __repr__(self: Value) -> object {
        return ("<ir.%s type='%s' ...>" % (self.__class__.__name__, self.type));
    }
}

"""
    'undef': a value for undefined values.
    """
class _Undefined(object) {
    def __new__(cls: Any) -> object {
        try {
            return Undefined;
        } except NameError {
            return object.__new__(_Undefined);
        }
    }
}

with entry {
    Undefined = _Undefined();
}
"""
    A constant LLVM value.
    """
class Constant(_StrCaching, _StringReferenceCaching, _ConstOpMixin, Value) {
    def init(self: Constant, typ: Any, constant: Any) -> object {
        assert isinstance(typ, types.Type);
        assert not isinstance(typ, types.VoidType);
        self.type = typ;
        constant = typ.wrap_constant_value(constant);
        self.constant = constant;
    }
    def _to_string(self: Constant) -> object {
        return '{0} {1}'.format(self.type, self.get_reference());
    }
    def _get_reference(self: Constant) -> object {
        if (self.constant is None) {
            val = self.type.null;
        } elif (self.constant is Undefined) {
            val = "undef";
        } elif isinstance(self.constant, bytearray) {
            val = 'c"{0}"'.format(_escape_string(self.constant));
        } else {
            val = self.type.format_constant(self.constant);
        }
        return val;
    }
    """
        Construct a literal array constant made of the given members.
        """
    @classmethod
    def literal_array(cls: Any, elems: Any) -> object {
        tys = [el.type for el in elems];
        if (len(tys) == 0) {
            raise ValueError("need at least one element");
        }
        ty = tys[0];
        for other in tys {
            if (ty != other) {
                raise TypeError("all elements must have the same type");
            }
        }
        return cls(types.ArrayType(ty, len(elems)), elems);
    }

    """
        Construct a literal structure constant made of the given members.
        """
    @classmethod
    def literal_struct(cls: Any, elems: Any, packed: Any = False) -> object {
        tys = [el.type for el in elems];
        return cls(types.LiteralStructType(tys, packed), elems);
    }

    @property
    def addrspace(self: Constant) -> object {
        if not isinstance(self.type, types.PointerType) {
            raise TypeError("Only pointer constant have address spaces");
        }
        return self.type.addrspace;
    }
    def __eq__(self: Constant, other: Any) -> object {
        if isinstance(other, Constant) {
            return (str(self) == str(other));
        } else {
            return False;
        }
    }
    def __ne__(self: Constant, other: Any) -> object {
        return not self.__eq__(other);
    }
    def __hash__(self: Constant) -> object {
        return hash(str(self));
    }
    def __repr__(self: Constant) -> object {
        return ("<ir.Constant type='%s' value=%r>" % (self.type, self.constant));
    }
}

"""
    A constant with an already formatted IR representation.
    """
class FormattedConstant(Constant) {
    def init(self: FormattedConstant, typ: Any, constant: Any) -> object {
        assert isinstance(constant, str);
        Constant.init(self, typ, constant);
    }
    def _to_string(self: FormattedConstant) -> object {
        return self.constant;
    }
    def _get_reference(self: FormattedConstant) -> object {
        return self.constant;
    }
}

"""
    The base class for named values.
    """
class NamedValue(_StrCaching, _StringReferenceCaching, Value) {
    with entry {
        name_prefix = '%';
        deduplicate_name = True;
    }

    def init(self: NamedValue, parent: Any, `type: Any, name: Any) -> object {
        assert (parent is not None);
        assert isinstance(`type, types.Type);
        self.parent = parent;
        self.type = `type;
        self._set_name(name);
    }
    def _to_string(self: NamedValue) -> object {
        buf = [];
        if not isinstance(self.type, types.VoidType) {
            buf.append("{0} = ".format(self.get_reference()));
        }
        self.descr(buf);
        return "".join(buf).rstrip();
    }
    def descr(self: NamedValue, buf: Any) -> object {
        raise NotImplementedError;
    }
    def _get_name(self: NamedValue) -> object {
        return self._name;
    }
    def _set_name(self: NamedValue, name: Any) -> object {
        name = self.parent.scope.register(name, deduplicate=self.deduplicate_name);
        self._name = name;
    }

    with entry {
        name = property(_get_name, _set_name);
    }

    def _get_reference(self: NamedValue) -> object {
        name = self.name;
        if (('\\' in name) or ('"' in name)) {
            name = name.replace('\\', '\\5c').replace('"', '\\22');
        }
        return '{0}"{1}"'.format(self.name_prefix, name);
    }
    def __repr__(self: NamedValue) -> object {
        return (
            "<ir.%s %r of type '%s'>" % (self.__class__.__name__, self.name, self.type)
        );
    }
    @property
    def function_type(self: NamedValue) -> object {
        ty = self.type;
        if isinstance(ty, types.PointerType) {
            ty = self.type.pointee;
        }
        if isinstance(ty, types.FunctionType) {
            return ty;
        } else {
            raise TypeError("Not a function: {0}".format(self.type));
        }
    }
}

"""
    A metadata string, i.e. a constant string used as a value in a metadata
    node.
    """
class MetaDataString(NamedValue) {
    def init(self: MetaDataString, parent: Any, string: Any) -> object {
        super.init(parent, types.MetaDataType(), name="");
        self.string = string;
    }
    def descr(self: MetaDataString, buf: Any) -> object {
        buf += (self.get_reference(), "\n");
    }
    def _get_reference(self: MetaDataString) -> object {
        return '!"{0}"'.format(_escape_string(self.string));
    }

    with entry {
        _to_string = _get_reference;
    }

    def __eq__(self: MetaDataString, other: Any) -> object {
        if isinstance(other, MetaDataString) {
            return (self.string == other.string);
        } else {
            return False;
        }
    }
    def __ne__(self: MetaDataString, other: Any) -> object {
        return not self.__eq__(other);
    }
    def __hash__(self: MetaDataString) -> object {
        return hash(self.string);
    }
}

"""
    An argument value to a function taking metadata arguments.
    This can wrap any other kind of LLVM value.

    Do not instantiate directly, Builder.call() will create these
    automatically.
    """
class MetaDataArgument(_StrCaching, _StringReferenceCaching, Value) {
    def init(self: MetaDataArgument, value: Any) -> object {
        assert isinstance(value, Value);
        assert not isinstance(value.type, types.MetaDataType);
        self.type = types.MetaDataType();
        self.wrapped_value = value;
    }
    def _get_reference(self: MetaDataArgument) -> object {
        return "{0} {1}".format(
            self.wrapped_value.type, self.wrapped_value.get_reference()
        );
    }

    with entry {
        _to_string = _get_reference;
    }
}

"""
    A named metadata node.

    Do not instantiate directly, use Module.add_named_metadata() instead.
    """
class NamedMetaData(object) {
    def init(self: NamedMetaData, parent: Any) -> object {
        self.parent = parent;
        self.operands = [];
    }
    def add(self: NamedMetaData, md: Any) -> object {
        self.operands.append(md);
    }
}

"""
    A metadata node's value, consisting of a sequence of elements ("operands").

    Do not instantiate directly, use Module.add_metadata() instead.
    """
class MDValue(NamedValue) {
    with entry {
        name_prefix = '!';
    }

    def init(self: MDValue, parent: Any, values: Any, name: Any) -> object {
        super.init(parent, types.MetaDataType(), name=name);
        self.operands = `tuple(values);
        parent.metadata.append(self);
    }
    def descr(self: MDValue, buf: Any) -> object {
        operands = [];
        for op in self.operands {
            if isinstance(op.type, types.MetaDataType) {
                if (isinstance(op, Constant) and (op.constant is None)) {
                    operands.append("null");
                } else {
                    operands.append(op.get_reference());
                }
            } else {
                operands.append("{0} {1}".format(op.type, op.get_reference()));
            }
        }
        operands = ', '.join(operands);
        buf += ("!{{ {0} }}".format(operands), "\n");
    }
    def _get_reference(self: MDValue) -> object {
        return (self.name_prefix + str(self.name));
    }
    def __eq__(self: MDValue, other: Any) -> object {
        if isinstance(other, MDValue) {
            return (self.operands == other.operands);
        } else {
            return False;
        }
    }
    def __ne__(self: MDValue, other: Any) -> object {
        return not self.__eq__(other);
    }
    def __hash__(self: MDValue) -> object {
        return hash(self.operands);
    }
}

"""
    A debug information enumeration value that should appear bare in
    the emitted metadata.

    Use this to wrap known constants, e.g. the DW_* enumerations.
    """
class DIToken {
    def init(self: DIToken, value: Any) -> object {
        self.value = value;
    }
}

"""
    A debug information descriptor, containing key-value pairs.

    Do not instantiate directly, use Module.add_debug_info() instead.
    """
class DIValue(NamedValue) {
    with entry {
        name_prefix = '!';
    }

    def init(
        self: DIValue,
        parent: Any,
        is_distinct: Any,
        kind: Any,
        operands: Any,
        name: Any
    ) -> object {
        super.init(parent, types.MetaDataType(), name=name);
        self.is_distinct = is_distinct;
        self.kind = kind;
        self.operands = `tuple(operands);
        parent.metadata.append(self);
    }
    def descr(self: DIValue, buf: Any) -> object {
        if self.is_distinct {
            buf += ("distinct ", );
        }
        operands = [];
        for (key, value) in self.operands {
            if (value is None) {
                strvalue = "null";
            } elif (value is True) {
                strvalue = "true";
            } elif (value is False) {
                strvalue = "false";
            } elif isinstance(value, DIToken) {
                strvalue = value.value;
            } elif isinstance(value, str) {
                strvalue = '"{}"'.format(_escape_string(value));
            } elif isinstance(value, int) {
                strvalue = str(value);
            } elif isinstance(value, Constant) {
                strvalue = str(value);
            } elif isinstance(value, NamedValue) {
                strvalue = value.get_reference();
            } else {
                raise TypeError(
                    ("invalid operand type for debug info: %r" % (value, ))
                );
            }
            operands.append("{0}: {1}".format(key, strvalue));
        }
        operands = ', '.join(operands);
        buf += ("!", self.kind, "(", operands, ")\n");
    }
    def _get_reference(self: DIValue) -> object {
        return (self.name_prefix + str(self.name));
    }
    def __eq__(self: DIValue, other: Any) -> object {
        if isinstance(other, DIValue) {
            return (
                (self.is_distinct == other.is_distinct)
                and (self.kind == other.kind)
                and (self.operands == other.operands)
            );
        } else {
            return False;
        }
    }
    def __ne__(self: DIValue, other: Any) -> object {
        return not self.__eq__(other);
    }
    def __hash__(self: DIValue) -> object {
        return hash((self.is_distinct, self.kind, self.operands));
    }
}

"""
    A global value.
    """
class GlobalValue(NamedValue, _ConstOpMixin, _HasMetadata) {
    with entry {
        name_prefix = '@';
        deduplicate_name = False;
    }

    def init(self: GlobalValue, *args: Any, **kwargs: Any) -> object {
        super.init(*args, **kwargs);
        self.linkage = '';
        self.storage_class = '';
        self.section = '';
        self.metadata = {};
    }
}

"""
    A global variable.
    """
class GlobalVariable(GlobalValue) {
    def init(
        self: GlobalVariable, module: Any, typ: Any, name: Any, addrspace: Any = 0
    ) -> object {
        assert isinstance(typ, types.Type);
        super.init(module, typ.as_pointer(addrspace), name=name);
        self.value_type = typ;
        self.initializer = None;
        self.unnamed_addr = False;
        self.global_constant = False;
        self.addrspace = addrspace;
        self.align = None;
        self.parent.add_global(self);
    }
    def descr(self: GlobalVariable, buf: Any) -> object {
        if self.global_constant {
            kind = 'constant';
        } else {
            kind = 'global';
        }
        if not self.linkage {
            linkage = 'external' if (self.initializer is None) else '';
        } else {
            linkage = self.linkage;
        }
        if linkage {
            buf.append((linkage + " "));
        }
        if self.storage_class {
            buf.append((self.storage_class + " "));
        }
        if self.unnamed_addr {
            buf.append("unnamed_addr ");
        }
        if (self.addrspace != 0) {
            buf.append('addrspace({0:d}) '.format(self.addrspace));
        }
        buf.append("{kind} {type}".format(kind=kind, `type=self.value_type));
        if (self.initializer is not None) {
            if (self.initializer.type != self.value_type) {
                raise TypeError(
                    (
                        "got initializer of type %s " "for global value type %s" % (
                            self.initializer.type,
                            self.value_type
                        )
                    )
                );
            }
            buf.append((" " + self.initializer.get_reference()));
        } elif (linkage not in ('external', 'extern_weak')) {
            buf.append((" " + self.value_type(Undefined).get_reference()));
        }
        if self.section {
            buf.append((", section \"%s\"" % (self.section, )));
        }
        if (self.align is not None) {
            buf.append((", align %d" % (self.align, )));
        }
        if self.metadata {
            buf.append(self._stringify_metadata(leading_comma=True));
        }
        buf.append("\n");
    }
}

"""A set of string attribute.
    Only accept items listed in *_known*.

    Properties:
    * Iterate in sorted order
    """
class AttributeSet(`set) {
    with entry {
        _known = ();
    }

    def init(self: AttributeSet, args: Any = ()) -> object {
        super.init();
        if isinstance(args, str) {
            args = [args];
        }
        for name in args {
            self.add(name);
        }
    }
    def _expand(self: AttributeSet, name: Any, typ: Any) -> object {
        return name;
    }
    def add(self: AttributeSet, name: Any) -> object {
        if (name not in self._known) {
            raise ValueError('unknown attr {!r} for {}'.format(name, self));
        }
        return super.add(name);
    }
    def _to_list(self: AttributeSet, typ: Any) -> object {
        return [self._expand(i, typ) for i in sorted(self)];
    }
}

class FunctionAttributes(AttributeSet) {
    with entry {
        _known = frozenset(
            [
                'argmemonly',
                'alwaysinline',
                'builtin',
                'cold',
                'convergent',
                'inaccessiblememonly',
                'inaccessiblemem_or_argmemonly',
                'inlinehint',
                'jumptable',
                'minsize',
                'naked',
                'nobuiltin',
                'noduplicate',
                'noimplicitfloat',
                'noinline',
                'nonlazybind',
                'norecurse',
                'noredzone',
                'noreturn',
                'nounwind',
                'optnone',
                'optsize',
                'readnone',
                'readonly',
                'returns_twice',
                'sanitize_address',
                'sanitize_memory',
                'sanitize_thread',
                'ssp',
                'sspreg',
                'sspstrong',
                'uwtable'
            ]
        );
    }

    def init(self: FunctionAttributes, args: Any = ()) -> object {
        self._alignstack = 0;
        self._personality = None;
        super.init(args);
    }
    def add(self: FunctionAttributes, name: Any) -> object {
        if (
            ((name == 'alwaysinline') and ('noinline' in self))
            or ((name == 'noinline') and ('alwaysinline' in self))
        ) {
            raise ValueError("Can't have alwaysinline and noinline");
        }
        super.add(name);
    }
    @property
    def alignstack(self: FunctionAttributes) -> object {
        return self._alignstack;
    }
    @alignstack.setter
    def alignstack(self: FunctionAttributes, val: Any) -> object {
        assert (val >= 0);
        self._alignstack = val;
    }
    @property
    def personality(self: FunctionAttributes) -> object {
        return self._personality;
    }
    @personality.setter
    def personality(self: FunctionAttributes, val: Any) -> object {
        assert ((val is None) or isinstance(val, GlobalValue));
        self._personality = val;
    }
    def _to_list(self: FunctionAttributes, ret_type: Any) -> object {
        attrs = super._to_list(ret_type);
        if self.alignstack {
            attrs.append('alignstack({0:d})'.format(self.alignstack));
        }
        if self.personality {
            attrs.append(
                'personality {persty} {persfn}'.format(
                    persty=self.personality.type,
                    persfn=self.personality.get_reference()
                )
            );
        }
        return attrs;
    }
}
"""Represent a LLVM Function but does uses a Module as parent.
    Global Values are stored as a set of dependencies (attribute `depends`).
    """
class Function(GlobalValue) {
    def init(self: Function, module: Any, ftype: Any, name: Any) -> object {
        assert isinstance(ftype, types.Type);
        super.init(module, ftype.as_pointer(), name=name);
        self.ftype = ftype;
        self.scope = _utils.NameScope();
        self.blocks = [];
        self.attributes = FunctionAttributes();
        self.args = `tuple([Argument(self, t) for t in ftype.args]);
        self.return_value = ReturnValue(self, ftype.return_type);
        self.parent.add_global(self);
        self.calling_convention = '';
    }
    @property
    def module(self: Function) -> object {
        return self.parent;
    }
    @property
    def entry_basic_block(self: Function) -> object {
        return self.blocks[0];
    }
    @property
    def basic_blocks(self: Function) -> object {
        return self.blocks;
    }
    def append_basic_block(self: Function, name: Any = '') -> object {
        blk = Block(parent=self, name=name);
        self.blocks.append(blk);
        return blk;
    }
    """Insert block before
        """
    def insert_basic_block(self: Function, before: Any, name: Any = '') -> object {
        blk = Block(parent=self, name=name);
        self.blocks.insert(before, blk);
        return blk;
    }

    """
        Describe the prototype ("head") of the function.
        """
    def descr_prototype(self: Function, buf: Any) -> object {
        state = "define" if self.blocks else "declare";
        ret = self.return_value;
        args = ", ".join(str(a) for a in self.args);
        name = self.get_reference();
        attrs = (' ' + ' '.join(self.attributes._to_list(self.ftype.return_type)))
            if self.attributes
            else '';
        if `any(self.args) {
            vararg = ', ...' if self.ftype.var_arg else '';
        } else {
            vararg = '...' if self.ftype.var_arg else '';
        }
        linkage = self.linkage;
        cconv = self.calling_convention;
        prefix = " ".join(
            str(x)
            for x in [state, linkage, cconv, ret]
            if x
        );
        metadata = self._stringify_metadata();
        metadata = ' {}'.format(metadata) if metadata else '';
        section = ' section "{}"'.format(self.section) if self.section else '';
        pt_str = "{prefix} {name}({args}{vararg}){attrs}{section}{metadata}\n";
        prototype = pt_str.format(
            prefix=prefix,
            name=name,
            args=args,
            vararg=vararg,
            attrs=attrs,
            section=section,
            metadata=metadata
        );
        buf.append(prototype);
    }

    """
        Describe of the body of the function.
        """
    def descr_body(self: Function, buf: Any) -> object {
        for blk in self.blocks {
            blk.descr(buf);
        }
    }

    def descr(self: Function, buf: Any) -> object {
        self.descr_prototype(buf);
        if self.blocks {
            buf.append("{\n");
            self.descr_body(buf);
            buf.append("}\n");
        }
    }
    def __str__(self: Function) -> object {
        buf = [];
        self.descr(buf);
        return "".join(buf);
    }
    @property
    def is_declaration(self: Function) -> object {
        return (len(self.blocks) == 0);
    }
}

class ArgumentAttributes(AttributeSet) {
    with entry {
        _known = MappingProxyType(
            {
                'byref': True,
                'byval': True,
                'elementtype': True,
                'immarg': False,
                'inalloca': True,
                'inreg': False,
                'nest': False,
                'noalias': False,
                'nocapture': False,
                'nofree': False,
                'nonnull': False,
                'noundef': False,
                'preallocated': True,
                'returned': False,
                'signext': False,
                'sret': True,
                'swiftasync': False,
                'swifterror': False,
                'swiftself': False,
                'zeroext': False
            }
        );
    }

    def init(self: ArgumentAttributes, args: Any = ()) -> object {
        self._align = 0;
        self._dereferenceable = 0;
        self._dereferenceable_or_null = 0;
        super.init(args);
    }
    def _expand(self: ArgumentAttributes, name: Any, typ: Any) -> object {
        requires_type = self._known.get(name);
        if requires_type {
            return f"{name}({typ.pointee})";
        } else {
            return name;
        }
    }
    @property
    def align(self: ArgumentAttributes) -> object {
        return self._align;
    }
    @align.setter
    def align(self: ArgumentAttributes, val: Any) -> object {
        assert (isinstance(val, int) and (val >= 0));
        self._align = val;
    }
    @property
    def dereferenceable(self: ArgumentAttributes) -> object {
        return self._dereferenceable;
    }
    @dereferenceable.setter
    def dereferenceable(self: ArgumentAttributes, val: Any) -> object {
        assert (isinstance(val, int) and (val >= 0));
        self._dereferenceable = val;
    }
    @property
    def dereferenceable_or_null(self: ArgumentAttributes) -> object {
        return self._dereferenceable_or_null;
    }
    @dereferenceable_or_null.setter
    def dereferenceable_or_null(self: ArgumentAttributes, val: Any) -> object {
        assert (isinstance(val, int) and (val >= 0));
        self._dereferenceable_or_null = val;
    }
    def _to_list(self: ArgumentAttributes, typ: Any) -> object {
        attrs = super._to_list(typ);
        if self.align {
            attrs.append('align {0:d}'.format(self.align));
        }
        if self.dereferenceable {
            attrs.append('dereferenceable({0:d})'.format(self.dereferenceable));
        }
        if self.dereferenceable_or_null {
            dref = 'dereferenceable_or_null({0:d})';
            attrs.append(dref.format(self.dereferenceable_or_null));
        }
        return attrs;
    }
}
class _BaseArgument(NamedValue) {
    def init(self: _BaseArgument, parent: Any, typ: Any, name: Any = '') -> object {
        assert isinstance(typ, types.Type);
        super.init(parent, typ, name=name);
        self.parent = parent;
        self.attributes = ArgumentAttributes();
    }
    def __repr__(self: _BaseArgument) -> object {
        return (
            "<ir.%s %r of type %s>" % (self.__class__.__name__, self.name, self.type)
        );
    }
    def add_attribute(self: _BaseArgument, attr: Any) -> object {
        self.attributes.add(attr);
    }
}
"""
    The specification of a function argument.
    """
class Argument(_BaseArgument) {
    def __str__(self: Argument) -> object {
        attrs = self.attributes._to_list(self.type);
        if attrs {
            return "{0} {1} {2}".format(
                self.type, ' '.join(attrs), self.get_reference()
            );
        } else {
            return "{0} {1}".format(self.type, self.get_reference());
        }
    }
}

"""
    The specification of a function's return value.
    """
class ReturnValue(_BaseArgument) {
    def __str__(self: ReturnValue) -> object {
        attrs = self.attributes._to_list(self.type);
        if attrs {
            return "{0} {1}".format(' '.join(attrs), self.type);
        } else {
            return str(self.type);
        }
    }
}

"""
    A LLVM IR basic block. A basic block is a sequence of
    instructions whose execution always goes from start to end.  That
    is, a control flow instruction (branch) can only appear as the
    last instruction, and incoming branches can only jump to the first
    instruction.
    """
class Block(NamedValue) {
    def init(self: Block, parent: Any, name: Any = '') -> object {
        super.init(parent, types.LabelType(), name=name);
        self.scope = parent.scope;
        self.instructions = [];
        self.terminator = None;
    }
    @property
    def is_terminated(self: Block) -> object {
        return (self.terminator is not None);
    }
    @property
    def function(self: Block) -> object {
        return self.parent;
    }
    @property
    def module(self: Block) -> object {
        return self.parent.module;
    }
    def descr(self: Block, buf: Any) -> object {
        buf.append("{0}:\n".format(self._format_name()));
        buf += ["  {0}\n".format(instr) for instr in self.instructions];
    }
    """Replace an instruction"""
    def replace(self: Block, old: Any, new: Any) -> object {
        if (old.type != new.type) {
            raise TypeError("new instruction has a different type");
        }
        pos = self.instructions.index(old);
        self.instructions.remove(old);
        self.instructions.insert(pos, new);
        for bb in self.parent.basic_blocks {
            for instr in bb.instructions {
                instr.replace_usage(old, new);
            }
        }
    }
    def _format_name(self: Block) -> object {
        name = self.name;
        if not _SIMPLE_IDENTIFIER_RE.match(name) {
            name = name.replace('\\', '\\5c').replace('"', '\\22');
            name = '"{0}"'.format(name);
        }
        return name;
    }
}

"""
    The address of a basic block.
    """
class BlockAddress(Value) {
    def init(self: BlockAddress, function: Any, basic_block: Any) -> object {
        assert isinstance(function, Function);
        assert isinstance(basic_block, Block);
        self.type = types.IntType(8).as_pointer();
        self.function = function;
        self.basic_block = basic_block;
    }
    def __str__(self: BlockAddress) -> object {
        return '{0} {1}'.format(self.type, self.get_reference());
    }
    def get_reference(self: BlockAddress) -> object {
        return "blockaddress({0}, {1})".format(
            self.function.get_reference(), self.basic_block.get_reference()
        );
    }
}

