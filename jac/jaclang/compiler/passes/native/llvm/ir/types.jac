import struct;
import from jaclang.compiler.passes.native.llvm { ir_layer_typed_pointers_enabled }
import from jaclang.compiler.passes.native.llvm.ir._utils { _StrCaching }
def _wrapname(x: any) -> object {
    return '"{0}"'.format(x.replace('\\', '\\5c').replace('"', '\\22'));
}

class Type(_StrCaching) {
    with entry {
        is_pointer = False;
        null = 'zeroinitializer';
    }

    def __repr__(self: Type) -> object {
        return ("<%s %s>" % (`type(self), str(self)));
    }

    def _to_string(self: Type) -> object {
        raise NotImplementedError;
    }

    def as_pointer(self: Type, addrspace: any = 0) -> object {
        return PointerType(self, addrspace);
    }

    def __ne__(self: Type, other: any) -> object {
        return not (self == other);
    }

    def format_constant(self: Type, value: any) -> object {
        return str(value);
    }

    def wrap_constant_value(self: Type, value: any) -> object {
        return value;
    }

    def __call__(self: Type, value: any) -> object {
        import from jaclang.compiler.passes.native.llvm.ir { Constant }
        return Constant(self, value);
    }
}

class MetaDataType(Type) {
    def _to_string(self: MetaDataType) -> object {
        return "metadata";
    }

    def as_pointer(self: MetaDataType) -> object {
        raise TypeError;
    }

    def __eq__(self: MetaDataType, other: any) -> object {
        return isinstance(other, MetaDataType);
    }

    def __hash__(self: MetaDataType) -> object {
        return hash(MetaDataType);
    }
}

class LabelType(Type) {
    def _to_string(self: LabelType) -> object {
        return "label";
    }
}

class PointerType(Type) {
    with entry {
        is_opaque = True;
        is_pointer = True;
        null = 'null';
    }

    def __new__(cls: any, pointee: any = None, addrspace: any = 0) -> object {
        if (
            (cls is PointerType)
            and (pointee is not None)
            and (`type(pointee) is not PointerType)
        ) {
            return super.__new__(_TypedPointerType);
        }
        return super.__new__(cls);
    }

    def init(self: PointerType, pointee: any = None, addrspace: any = 0) -> object {
        assert ((pointee is None) or (`type(pointee) is PointerType));
        self.addrspace = addrspace;
    }

    def _to_string(self: PointerType) -> object {
        if (self.addrspace != 0) {
            return "ptr addrspace({0})".format(self.addrspace);
        } else {
            return "ptr";
        }
    }

    def __eq__(self: PointerType, other: any) -> object {
        return (isinstance(other, PointerType) and (self.addrspace == other.addrspace));
    }

    def __hash__(self: PointerType) -> object {
        return hash(PointerType);
    }
}

class _TypedPointerType(PointerType) {
    def init(self: _TypedPointerType, pointee: any, addrspace: any = 0) -> object {
        super.init(None, addrspace);
        assert ((pointee is not None) and (`type(pointee) is not PointerType));
        assert not isinstance(pointee, VoidType);
        self.pointee = pointee;
        self.is_opaque = False;
    }

    def _to_string(self: _TypedPointerType) -> object {
        if ir_layer_typed_pointers_enabled {
            return "{0}*".format(self.pointee)
                if (self.addrspace == 0)
                else "{0} addrspace({1})*".format(self.pointee, self.addrspace);
        }
        return super._to_string();
    }

    def __eq__(self: _TypedPointerType, other: any) -> object {
        if isinstance(other, _TypedPointerType) {
            return ((self.pointee, self.addrspace) == (other.pointee, other.addrspace));
        }
        return (isinstance(other, PointerType) and (self.addrspace == other.addrspace));
    }

    def __hash__(self: _TypedPointerType) -> object {
        return hash(_TypedPointerType);
    }

    def gep(self: _TypedPointerType, i: any) -> object {
        if not isinstance(i.type, IntType) {
            raise TypeError(i.type);
        }
        return self.pointee;
    }
}

class VoidType(Type) {
    def _to_string(self: VoidType) -> object {
        return 'void';
    }

    def __eq__(self: VoidType, other: any) -> object {
        return isinstance(other, VoidType);
    }

    def __hash__(self: VoidType) -> object {
        return hash(VoidType);
    }
}

class FunctionType(Type) {
    def init(
        self: FunctionType, return_type: any, args: any, var_arg: any = False
    ) -> object {
        self.return_type = return_type;
        self.args = `tuple(args);
        self.var_arg = var_arg;
    }

    def _to_string(self: FunctionType) -> object {
        if self.args {
            strargs = ', '.join([str(a) for a in self.args]);
            if self.var_arg {
                return '{0} ({1}, ...)'.format(self.return_type, strargs);
            } else {
                return '{0} ({1})'.format(self.return_type, strargs);
            }
        } elif self.var_arg {
            return '{0} (...)'.format(self.return_type);
        } else {
            return '{0} ()'.format(self.return_type);
        }
    }

    def __eq__(self: FunctionType, other: any) -> object {
        if isinstance(other, FunctionType) {
            return (
                (self.return_type == other.return_type)
                and (self.args == other.args)
                and (self.var_arg == other.var_arg)
            );
        } else {
            return False;
        }
    }

    def __hash__(self: FunctionType) -> object {
        return hash(FunctionType);
    }
}

class IntType(Type) {
    with entry {
        null = '0';
        _instance_cache = {};
        width: int;
    }

    def __new__(cls: any, bits: any) -> object {
        if (0 <= bits <= 128) {
            try {
                return cls._instance_cache[bits];
            } except KeyError {
                inst = cls._instance_cache[bits]=cls.__new(bits);
                return inst;
            }
        }
        return cls.__new(bits);
    }

    @classmethod
    def __new(cls: any, bits: any) -> object {
        assert (isinstance(bits, int) and (bits >= 0));
        self = super.__new__(cls);
        self.width = bits;
        return self;
    }

    def __getnewargs__(self: IntType) -> object {
        return (self.width, );
    }

    def __copy__(self: IntType) -> object {
        return self;
    }

    def _to_string(self: IntType) -> object {
        return ('i%u' % (self.width, ));
    }

    def __eq__(self: IntType, other: any) -> object {
        if isinstance(other, IntType) {
            return (self.width == other.width);
        } else {
            return False;
        }
    }

    def __hash__(self: IntType) -> object {
        return hash(IntType);
    }

    def format_constant(self: IntType, val: any) -> object {
        if isinstance(val, bool) {
            return str(val).lower();
        } else {
            return str(val);
        }
    }

    def wrap_constant_value(self: IntType, val: any) -> object {
        if (val is None) {
            return 0;
        }
        return val;
    }
}

def _as_float(value: any) -> object {
    return struct.unpack('f', struct.pack('f', value))[0];
}

def _as_half(value: any) -> object {
    try {
        return struct.unpack('e', struct.pack('e', value))[0];
    } except struct.error {
        return _as_float(value);
    }
}

def _format_float_as_hex(
    value: any, packfmt: any, unpackfmt: any, numdigits: any
) -> object {
    raw = struct.pack(packfmt, float(value));
    intrep = struct.unpack(unpackfmt, raw)[0];
    out = '{{0:#{0}x}}'.format(numdigits).format(intrep);
    return out;
}

def _format_double(value: any) -> object {
    return _format_float_as_hex(value, 'd', 'Q', 16);
}

class _BaseFloatType(Type) {
    def __new__(cls: any) -> object {
        return cls._instance_cache;
    }

    def __eq__(self: _BaseFloatType, other: any) -> object {
        return isinstance(other, `type(self));
    }

    def __hash__(self: _BaseFloatType) -> object {
        return hash(`type(self));
    }

    @classmethod
    def _create_instance(cls: any) -> object {
        cls._instance_cache = super.__new__(cls);
    }
}

class HalfType(_BaseFloatType) {
    with entry {
        null = '0.0';
    }

    def __str__(self: HalfType) -> object {
        return 'half';
    }

    def format_constant(self: HalfType, value: any) -> object {
        return _format_double(_as_half(value));
    }
}

class FloatType(_BaseFloatType) {
    with entry {
        null = '0.0';
    }

    def __str__(self: FloatType) -> object {
        return 'float';
    }

    def format_constant(self: FloatType, value: any) -> object {
        return _format_double(_as_float(value));
    }
}

class DoubleType(_BaseFloatType) {
    with entry {
        null = '0.0';
    }

    def __str__(self: DoubleType) -> object {
        return 'double';
    }

    def format_constant(self: DoubleType, value: any) -> object {
        return _format_double(value);
    }
}

with entry {
    for _cls in (HalfType, FloatType, DoubleType) {
        _cls._create_instance();
    }
}

class _Repeat(object) {
    def init(self: _Repeat, value: any, size: any) -> object {
        self.value = value;
        self.size = size;
    }

    def __len__(self: _Repeat) -> object {
        return self.size;
    }

    def __getitem__(self: _Repeat, item: any) -> object {
        if (0 <= item < self.size) {
            return self.value;
        } else {
            raise IndexError(item);
        }
    }
}

class VectorType(Type) {
    def init(self: VectorType, element: any, count: any) -> object {
        self.element = element;
        self.count = count;
    }

    has elements: object {
        getter {
            return _Repeat(self.element, self.count);
        }
    }

    def __len__(self: VectorType) -> object {
        return self.count;
    }

    def _to_string(self: VectorType) -> object {
        return ("<%d x %s>" % (self.count, self.element));
    }

    def __eq__(self: VectorType, other: any) -> object {
        if isinstance(other, VectorType) {
            return ((self.element == other.element) and (self.count == other.count));
        }
        return False;
    }

    def __hash__(self: VectorType) -> object {
        return hash(VectorType);
    }

    def __copy__(self: VectorType) -> object {
        return self;
    }

    def format_constant(self: VectorType, value: any) -> object {
        itemstring = ", ".join(
            ["{0} {1}".format(x.type, x.get_reference()) for x in value]
        );
        return "<{0}>".format(itemstring);
    }

    def wrap_constant_value(self: VectorType, values: any) -> object {
        import from jaclang.compiler.passes.native.llvm.ir { Value, Constant }
        if not isinstance(values, (`list, `tuple)) {
            if isinstance(values, Constant) {
                if (values.type != self.element) {
                    raise TypeError(
                        "expected {} for {}".format(self.element, values.type)
                    );
                }
                return ((values, ) * self.count);
            }
            return ((Constant(self.element, values), ) * self.count);
        }
        if (len(values) != len(self)) {
            raise ValueError(
                ("wrong constant size for %s: got %d elements" % (self, len(values)))
            );
        }
        return [
            Constant(ty, val) if not isinstance(val, Value) else val
            for (ty, val) in zip(self.elements, values)
        ];
    }
}

class Aggregate(Type) {
    def wrap_constant_value(self: Aggregate, values: any) -> object {
        import from jaclang.compiler.passes.native.llvm.ir { Value, Constant }
        if not isinstance(values, (`list, `tuple)) {
            return values;
        }
        if (len(values) != len(self)) {
            raise ValueError(
                ("wrong constant size for %s: got %d elements" % (self, len(values)))
            );
        }
        return [
            Constant(ty, val) if not isinstance(val, Value) else val
            for (ty, val) in zip(self.elements, values)
        ];
    }
}

class ArrayType(Aggregate) {
    def init(self: ArrayType, element: any, count: any) -> object {
        self.element = element;
        self.count = count;
    }

    has elements: object {
        getter {
            return _Repeat(self.element, self.count);
        }
    }

    def __len__(self: ArrayType) -> object {
        return self.count;
    }

    def _to_string(self: ArrayType) -> object {
        return ("[%d x %s]" % (self.count, self.element));
    }

    def __eq__(self: ArrayType, other: any) -> object {
        if isinstance(other, ArrayType) {
            return ((self.element == other.element) and (self.count == other.count));
        }
        return False;
    }

    def __hash__(self: ArrayType) -> object {
        return hash(ArrayType);
    }

    def gep(self: ArrayType, i: any) -> object {
        if not isinstance(i.type, IntType) {
            raise TypeError(i.type);
        }
        return self.element;
    }

    def format_constant(self: ArrayType, value: any) -> object {
        itemstring = ", ".join(
            ["{0} {1}".format(x.type, x.get_reference()) for x in value]
        );
        return "[{0}]".format(itemstring);
    }
}

class BaseStructType(Aggregate) {
    with entry {
        _packed = False;
    }

    has packed: object {
        getter {
            return self._packed;
        }
        setter(self: BaseStructType, val: any) -> object {
            self._packed = bool(val);
        }
    }

    def __len__(self: BaseStructType) -> object {
        assert (self.elements is not None);
        return len(self.elements);
    }

    def __iter__(self: BaseStructType) -> object {
        assert (self.elements is not None);
        return iter(self.elements);
    }

    has is_opaque: object {
        getter {
            return (self.elements is None);
        }
    }

    def structure_repr(self: BaseStructType) -> object {
        ret = '{%s}' % ', '.join([str(x) for x in self.elements]);
        return self._wrap_packed(ret);
    }

    def format_constant(self: BaseStructType, value: any) -> object {
        itemstring = ", ".join(
            ["{0} {1}".format(x.type, x.get_reference()) for x in value]
        );
        ret = "{{{0}}}".format(itemstring);
        return self._wrap_packed(ret);
    }

    def gep(self: BaseStructType, i: any) -> object {
        if not isinstance(i.type, IntType) {
            raise TypeError(i.type);
        }
        return self.elements[i.constant];
    }

    def _wrap_packed(self: BaseStructType, textrepr: any) -> object {
        if self.packed {
            return '<{}>'.format(textrepr);
        } else {
            return textrepr;
        }
    }
}

class LiteralStructType(BaseStructType) {
    with entry {
        null = 'zeroinitializer';
    }

    def init(self: LiteralStructType, elems: any, packed: any = False) -> object {
        self.elements = `tuple(elems);
        self.packed = packed;
    }

    def _to_string(self: LiteralStructType) -> object {
        return self.structure_repr();
    }

    def __eq__(self: LiteralStructType, other: any) -> object {
        if isinstance(other, LiteralStructType) {
            return (
                (self.elements == other.elements) and (self.packed == other.packed)
            );
        }
        return False;
    }

    def __hash__(self: LiteralStructType) -> object {
        return hash(LiteralStructType);
    }
}

class IdentifiedStructType(BaseStructType) {
    with entry {
        null = 'zeroinitializer';
    }

    def init(
        self: IdentifiedStructType, context: any, name: any, packed: any = False
    ) -> object {
        assert name;
        self.context = context;
        self.name = name;
        self.elements = None;
        self.packed = packed;
    }

    def _to_string(self: IdentifiedStructType) -> object {
        return "%{name}".format(name=_wrapname(self.name));
    }

    def get_declaration(self: IdentifiedStructType) -> object {
        if self.is_opaque {
            out = "{strrep} = type opaque".format(strrep=str(self));
        } else {
            out = "{strrep} = type {struct}".format(
                strrep=str(self), struct=self.structure_repr()
            );
        }
        return out;
    }

    def __eq__(self: IdentifiedStructType, other: any) -> object {
        if isinstance(other, IdentifiedStructType) {
            return ((self.name == other.name) and (self.packed == other.packed));
        }
        return False;
    }

    def __hash__(self: IdentifiedStructType) -> object {
        return hash(IdentifiedStructType);
    }

    def set_body(self: IdentifiedStructType, *elems: any) -> object {
        if not self.is_opaque {
            raise RuntimeError("{name} is already defined".format(name=self.name));
        }
        self.elements = `tuple(elems);
    }
}
