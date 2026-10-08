"""
Classes that are LLVM values: Value, Constant...
Instructions are in the instructions module.
"""
import jaclang.compiler.backends.native.llvm.ir.types as types;
import jaclang.compiler.backends.native.llvm.ir._utils as _utils;
import type from jaclang.compiler.backends.native.llvm.ir.module { Module }

glob _CMP_MAP: dict[str, str] = {
         '>': 'gt',
         '<': 'lt',
         '==': 'eq',
         '!=': 'ne',
         '>=': 'ge',
         '<=': 'le'
     },
     _VALID_CHAR_TEXT: str = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
     "0123456789 !#$%&'()*+,-./:;<=>?@[]^_`{|}~",
     _IDENT_START_TEXT: str = "-abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ$._",
     _DIGIT_TEXT: str = "0123456789",
     _ESCAPE_MAP: list[str] = [],
     _FUNCTION_ATTRS: frozenset[str] = frozenset(
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
     ),
     _ARGUMENT_ATTRS: dict[str, bool] = {
         'byref': True,
         'byval': True,
         'captures(none)': False,
         'elementtype': True,
         'immarg': False,
         'inalloca': True,
         'inreg': False,
         'nest': False,
         'noalias': False,
         'nofree': False,
         'nonnull': False,
         'noundef': False,
         'preallocated': True,
         'readonly': False,
         'returned': False,
         'signext': False,
         'sret': True,
         'swiftasync': False,
         'swifterror': False,
         'swiftself': False,
         'zeroext': False
     };

"""The text each byte takes inside an LLVM string constant."""
def _escape_table -> list[str] {
    if not _ESCAPE_MAP {
        for ch in range(256) {
            if chr(ch) in _VALID_CHAR_TEXT {
                _ESCAPE_MAP.append(chr(ch));
            } else {
                _ESCAPE_MAP.append(f"\\{ch:02x}");
            }
        }
    }
    return _ESCAPE_MAP;
}

"""
    Escape the given bytestring for safe use as a LLVM array constant.
    Any unicode string input is first encoded with utf8 into bytes.
    """
def _escape_string(text: any) -> str {
    table = _escape_table();
    buf: list[str] = [];
    if isinstance(text, str) {
        for ch in text.encode() {
            buf.append(table[ch]);
        }
    } elif isinstance(text, bytearray) {
        for ch in text {
            buf.append(table[ch]);
        }
    } elif isinstance(text, `bytes) {
        for ch in text {
            buf.append(table[ch]);
        }
    } else {
        raise AssertionError;
    }
    return ''.join(buf);
}

"""Whether a block name prints bare: `[-a-zA-Z$._][-a-zA-Z$._0-9]*`, with one
trailing newline allowed as the pattern's `$` allows it."""
def _is_simple_identifier(name: str) -> bool {
    body = name[:-1] if name.endswith("\n") else name;
    if not body {
        return False;
    }
    if body[0] not in _IDENT_START_TEXT {
        return False;
    }
    for ch in body {
        if ch not in _IDENT_START_TEXT and ch not in _DIGIT_TEXT {
            return False;
        }
    }
    return True;
}

"""A copy of a value sequence handed in as a list or tuple of values."""
def _value_list(items: any) -> list[Value] {
    out: list[Value] = [];
    if items is None {
        return out;
    }
    if isinstance(items, (`list, `tuple)) {
        for item in items {
            if isinstance(item, Value) {
                out.append(item);
            } else {
                raise TypeError(f"not an IR value: {item!r}");
            }
        }
    } else {
        for item in items {
            if isinstance(item, Value) {
                out.append(item);
            } else {
                raise TypeError(f"not an IR value: {item!r}");
            }
        }
    }
    return out;
}

"""A copy of a string sequence handed in as one string or a list or tuple."""
def _str_list(items: any) -> list[str] {
    out: list[str] = [];
    if items is None {
        return out;
    }
    if isinstance(items, str) {
        out.append(items);
    } elif isinstance(items, (`list, `tuple)) {
        for item in items {
            if isinstance(item, str) {
                out.append(item);
            } else {
                raise TypeError(f"not a string: {item!r}");
            }
        }
    } else {
        for item in items {
            if isinstance(item, str) {
                out.append(item);
            } else {
                raise TypeError(f"not a string: {item!r}");
            }
        }
    }
    return out;
}

"""Whether two value sequences hold pairwise equal values."""
def _same_values(left: list[Value], right: list[Value]) -> bool {
    if len(left) != len(right) {
        return False;
    }
    for i in range(len(left)) {
        if left[i] is not right[i] and left[i] != right[i] {
            return False;
        }
    }
    return True;
}

"""
    The base class for all values.

    A value prints through `_to_string` and names itself through
    `_get_reference`; both texts are computed once. The constant operations
    (`add`, `bitcast`, `gep`, ...) build constant expressions over the value
    and apply to constants and global values.
    """
class Value {
    has type: types.Type,
        is_owned: bool = False,
        jac_loc: str = "",
        jac_signed: bool = False,
        jac_env_struct: str | None = None,
        na_tuple_owned: list[bool] | None = None,
        _cached_str: str | None = None,
        _cached_refstr: str | None = None,
        _callee_type: types.FunctionType | None = None;

    has pointee_type: types.Type {
        getter {
            ty = self.type;
            if isinstance(ty, types.PointerType) {
                target = ty.pointee;
                if target is not None {
                    return target;
                }
            }
            raise TypeError(f"Value has no typed pointee: {ty}");
        }
    }

    has function_type: types.FunctionType {
        getter {
            return self._function_type();
        }
    }

    """The function type a call through this value uses: the one a callee that
    is not a function pointer (inline assembly) carries, else the pointee of
    the value's own type."""
    def _function_type(self: Value) -> types.FunctionType {
        carried = self._callee_type;
        if carried is not None {
            return carried;
        }
        ty = self.type;
        if isinstance(ty, types.PointerType) {
            target = ty.pointee;
            if target is not None {
                ty = target;
            }
        }
        if isinstance(ty, types.FunctionType) {
            return ty;
        } else {
            raise TypeError(f"Not a function: {self.type}");
        }
    }

    def _to_string(self: Value) -> str {
        raise NotImplementedError;
    }

    def _clear_string_cache(self: Value) {
        self._cached_str = None;
    }

    def __str__(self: Value) -> str {
        cached = self._cached_str;
        if cached is None {
            cached = self._to_string();
            self._cached_str = cached;
        }
        return cached;
    }

    def _get_reference(self: Value) -> str {
        raise NotImplementedError;
    }

    def get_reference(self: Value) -> str {
        cached = self._cached_refstr;
        if cached is None {
            cached = self._get_reference();
            self._cached_refstr = cached;
        }
        return cached;
    }

    def __eq__(self: Value, other: object) -> bool {
        return self is other;
    }

    def __hash__(self: Value) -> int {
        return id(self);
    }

    def __repr__(self: Value) -> str {
        return f"<ir.{self.__class__.__name__} type='{self.type}' ...>";
    }

    def _const_binop(self: Value, opname: str, other: Value) -> FormattedConstant {
        if (self.type != other.type) {
            raise ValueError(
                f"Operands must be the same type, got ({self.type}, {other.type})"
            );
        }
        fmt = f"{opname} ({self.type} {self.get_reference()}, "
        f"{other.type} {other.get_reference()})";
        return FormattedConstant(self.type, fmt);
    }

    def _const_castop(self: Value, opname: str, typ: types.Type) -> Value {
        if (typ == self.type) {
            return self;
        }
        op = f"{opname} ({self.type} {self.get_reference()} to {typ})";
        return FormattedConstant(typ, op);
    }

    """
        Left integer shift:
            lhs << rhs
        """
    def shl(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('shl', other);
    }

    """
        Logical (unsigned) right integer shift:
            lhs >> rhs
        """
    def lshr(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('lshr', other);
    }

    """
        Arithmetic (signed) right integer shift:
            lhs >> rhs
        """
    def ashr(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('ashr', other);
    }

    """
        Integer addition:
            lhs + rhs
        """
    def add(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('add', other);
    }

    """
        Floating-point addition:
            lhs + rhs
        """
    def fadd(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('fadd', other);
    }

    """
        Integer subtraction:
            lhs - rhs
        """
    def sub(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('sub', other);
    }

    """
        Floating-point subtraction:
            lhs - rhs
        """
    def fsub(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('fsub', other);
    }

    """
        Integer multiplication:
            lhs * rhs
        """
    def mul(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('mul', other);
    }

    """
        Floating-point multiplication:
            lhs * rhs
        """
    def fmul(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('fmul', other);
    }

    """
        Unsigned integer division:
            lhs / rhs
        """
    def udiv(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('udiv', other);
    }

    """
        Signed integer division:
            lhs / rhs
        """
    def sdiv(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('sdiv', other);
    }

    """
        Floating-point division:
            lhs / rhs
        """
    def fdiv(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('fdiv', other);
    }

    """
        Unsigned integer remainder:
            lhs % rhs
        """
    def urem(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('urem', other);
    }

    """
        Signed integer remainder:
            lhs % rhs
        """
    def srem(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('srem', other);
    }

    """
        Floating-point remainder:
            lhs % rhs
        """
    def frem(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('frem', other);
    }

    """
        Bitwise integer OR:
            lhs | rhs
        """
    def or_(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('or', other);
    }

    """
        Bitwise integer AND:
            lhs & rhs
        """
    def and_(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('and', other);
    }

    """
        Bitwise integer XOR:
            lhs ^ rhs
        """
    def xor(self: Value, other: Value) -> FormattedConstant {
        return self._const_binop('xor', other);
    }

    def _cmp(
        self: Value, prefix: str, sign: str, cmpop: str, other: Value
    ) -> FormattedConstant {
        ins = prefix + 'cmp';
        found = _CMP_MAP.get(cmpop);
        if found is None {
            raise ValueError(f"invalid comparison {cmpop!r} for {ins}");
        }
        op = found;
        if not ((prefix == 'i') and (cmpop in ('==', '!='))) {
            op = sign + op;
        }
        if (self.type != other.type) {
            raise ValueError(
                f"Operands must be the same type, got ({self.type}, {other.type})"
            );
        }
        fmt = f"{ins} {op} ({self.type} {self.get_reference()}, "
        f"{other.type} {other.get_reference()})";
        return FormattedConstant(types.IntType(1), fmt);
    }

    """
        Signed integer comparison:
            lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>='
        """
    def icmp_signed(self: Value, cmpop: str, other: Value) -> FormattedConstant {
        return self._cmp('i', 's', cmpop, other);
    }

    """
        Unsigned integer (or pointer) comparison:
            lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>='
        """
    def icmp_unsigned(self: Value, cmpop: str, other: Value) -> FormattedConstant {
        return self._cmp('i', 'u', cmpop, other);
    }

    """
        Floating-point ordered comparison:
            lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>=', 'ord', 'uno'
        """
    def fcmp_ordered(self: Value, cmpop: str, other: Value) -> FormattedConstant {
        return self._cmp('f', 'o', cmpop, other);
    }

    """
        Floating-point unordered comparison:
            lhs <cmpop> rhs

        where cmpop can be '==', '!=', '<', '<=', '>', '>=', 'ord', 'uno'
        """
    def fcmp_unordered(self: Value, cmpop: str, other: Value) -> FormattedConstant {
        return self._cmp('f', 'u', cmpop, other);
    }

    """
        Bitwise integer complement:
            ~value
        """
    def not_(self: Value) -> FormattedConstant {
        ty = self.type;
        if isinstance(ty, types.VectorType) {
            rhs = Constant(ty, [-1] * ty.count);
        } else {
            rhs = Constant(ty, -1);
        }
        return self.xor(rhs);
    }

    """
        Integer negative:
            -value
        """
    def neg(self: Value) -> FormattedConstant {
        zero = Constant(self.type, 0);
        return zero.sub(self);
    }

    """
        Floating-point negative:
            -value
        """
    def fneg(self: Value) -> FormattedConstant {
        fmt = f"fneg ({self.type} {self.get_reference()})";
        return FormattedConstant(self.type, fmt);
    }

    """
        Truncating integer downcast to a smaller type.
        """
    def trunc(self: Value, typ: types.Type) -> Value {
        return self._const_castop('trunc', typ);
    }

    """
        Zero-extending integer upcast to a larger type
        """
    def zext(self: Value, typ: types.Type) -> Value {
        return self._const_castop('zext', typ);
    }

    """
        Sign-extending integer upcast to a larger type.
        """
    def sext(self: Value, typ: types.Type) -> Value {
        return self._const_castop('sext', typ);
    }

    """
        Floating-point downcast to a less precise type.
        """
    def fptrunc(self: Value, typ: types.Type) -> Value {
        return self._const_castop('fptrunc', typ);
    }

    """
        Floating-point upcast to a more precise type.
        """
    def fpext(self: Value, typ: types.Type) -> Value {
        return self._const_castop('fpext', typ);
    }

    """
        Pointer cast to a different pointer type.
        """
    def bitcast(self: Value, typ: types.Type) -> Value {
        return self._const_castop('bitcast', typ);
    }

    """
        Convert unsigned integer to floating-point.
        """
    def uitofp(self: Value, typ: types.Type) -> Value {
        return self._const_castop('uitofp', typ);
    }

    """
        Convert floating-point to signed integer.
        """
    def fptosi(self: Value, typ: types.Type) -> Value {
        return self._const_castop('fptosi', typ);
    }

    """
        Convert signed integer to floating-point.
        """
    def sitofp(self: Value, typ: types.Type) -> Value {
        return self._const_castop('sitofp', typ);
    }

    """
        Cast pointer to integer.
        """
    def ptrtoint(self: Value, typ: types.Type) -> Value {
        if not isinstance(self.type, types.PointerType) {
            raise TypeError(
                f"can only call ptrtoint() on pointer type, not '{self.type}'"
            );
        }
        if not isinstance(typ, types.IntType) {
            raise TypeError(f"can only ptrtoint() to integer type, not '{typ}'");
        }
        return self._const_castop('ptrtoint', typ);
    }

    """
        Cast integer to pointer.
        """
    def inttoptr(self: Value, typ: types.Type) -> Value {
        if not isinstance(self.type, types.IntType) {
            raise TypeError(
                f"can only call inttoptr() on integer constants, not '{self.type}'"
            );
        }
        if not isinstance(typ, types.PointerType) {
            raise TypeError(f"can only inttoptr() to pointer type, not '{typ}'");
        }
        return self._const_castop('inttoptr', typ);
    }

    """
        Call getelementptr on this pointer constant.
        """
    def gep(self: Value, indices: any) -> FormattedConstant {
        ptr_type = self.type;
        if not isinstance(ptr_type, types.PointerType) {
            raise TypeError(
                f"can only call gep() on pointer constants, not '{self.type}'"
            );
        }
        steps = _value_list(indices);
        outtype: types.Type = ptr_type;
        for i in steps {
            outtype = outtype.gep(i);
        }
        strindices = [f"{idx.type} {idx.get_reference()}" for idx in steps];
        op = f"getelementptr ({ptr_type.pointee}, {ptr_type} {self.get_reference()}, "
            + ', '.join(strindices)
            + ")";
        return FormattedConstant(outtype.as_pointer(ptr_type.addrspace), op);
    }
}

"""
    'undef': a value for undefined values.
    """
class _Undefined {}

glob Undefined: _Undefined = _Undefined();

"""
    A constant LLVM value.
    """
class Constant(Value) {
    has constant: any = None;

    def init(self: Constant, typ: types.Type, constant: any) {
        assert isinstance(typ, types.Type);
        assert not isinstance(typ, types.VoidType);
        self.type = typ;
        self.constant = typ.wrap_constant_value(constant);
    }

    def _to_string(self: Constant) -> str {
        return f"{self.type} {self.get_reference()}";
    }

    def _get_reference(self: Constant) -> str {
        held = self.constant;
        if (held is None) {
            val = self.type.null;
        } elif (held is Undefined) {
            val = "undef";
        } elif isinstance(held, bytearray) {
            val = 'c"' + _escape_string(held) + '"';
        } else {
            val = self.type.format_constant(held);
        }
        return val;
    }

    """
        Construct a literal array constant made of the given members.
        """
    static def literal_array(elems: any) -> Constant {
        members = _value_list(elems);
        if (len(members) == 0) {
            raise ValueError("need at least one element");
        }
        ty = members[0].type;
        for el in members {
            if (ty != el.type) {
                raise TypeError("all elements must have the same type");
            }
        }
        return Constant(types.ArrayType(ty, len(members)), members);
    }

    """
        Construct a literal structure constant made of the given members.
        """
    static def literal_struct(elems: any, packed: bool = False) -> Constant {
        members = _value_list(elems);
        tys = [el.type for el in members];
        return Constant(types.LiteralStructType(tys, packed), members);
    }

    has addrspace: int {
        getter {
            ty = self.type;
            if not isinstance(ty, types.PointerType) {
                raise TypeError("Only pointer constant have address spaces");
            }
            return ty.addrspace;
        }
    }

    def __eq__(self: Constant, other: object) -> bool {
        if isinstance(other, Constant) {
            return (str(self) == str(other));
        } else {
            return False;
        }
    }

    def __ne__(self: Constant, other: object) -> bool {
        return not self.__eq__(other);
    }

    def __hash__(self: Constant) -> int {
        return hash(str(self));
    }

    def __repr__(self: Constant) -> str {
        return f"<ir.Constant type='{self.type}' value={self.constant!r}>";
    }
}

"""
    A constant with an already formatted IR representation.
    """
class FormattedConstant(Constant) {
    has _text: str = "";

    def init(self: FormattedConstant, typ: types.Type, constant: str) {
        assert isinstance(constant, str);
        super.init(typ, constant);
        self._text = constant;
    }

    def _to_string(self: FormattedConstant) -> str {
        return self._text;
    }

    def _get_reference(self: FormattedConstant) -> str {
        return self._text;
    }
}

"""
    The base class for named values.

    A named value registers its name in the scope it is created in and may
    carry metadata attachments.
    """
class NamedValue(Value) {
    with entry {
        name_prefix = '%';
        deduplicate_name = True;
    }

    has _name: str = "",
        _scope: _utils.NameScope,
        metadata: dict[str, Value];

    def init(self: NamedValue, scope: _utils.NameScope, `type: types.Type, name: str) {
        assert isinstance(`type, types.Type);
        self._scope = scope;
        self.type = `type;
        self.metadata = {};
        self._set_name(name);
    }

    def _to_string(self: NamedValue) -> str {
        buf: list[str] = [];
        if not isinstance(self.type, types.VoidType) {
            buf.append(self.get_reference() + " = ");
        }
        self.descr(buf);
        return "".join(buf).rstrip();
    }

    def descr(self: NamedValue, buf: list[str]) {
        raise NotImplementedError;
    }

    def _get_name(self: NamedValue) -> str {
        return self._name;
    }

    def _set_name(self: NamedValue, name: str) {
        self._name = self._scope.register(name, deduplicate=self.deduplicate_name);
    }

    has name: str {
        getter {
            return self._name;
        }
        setter(self: NamedValue, value: str) {
            self._set_name(value);
        }
    }

    def _get_reference(self: NamedValue) -> str {
        name = self._name;
        if (('\\' in name) or ('"' in name)) {
            name = name.replace('\\', '\\5c').replace('"', '\\22');
        }
        return self.name_prefix + '"' + name + '"';
    }

    def __repr__(self: NamedValue) -> str {
        return f"<ir.{self.__class__.__name__} {self._name!r} of type '{self.type}'>";
    }

    """
        Attach unnamed metadata *node* to the metadata slot *name* of this
        value.
        """
    def set_metadata(self: NamedValue, name: str, `node: Value) {
        self.metadata[name] = `node;
    }

    def _stringify_metadata(self: NamedValue, leading_comma: bool = False) -> str {
        if self.metadata {
            buf: list[str] = [];
            if leading_comma {
                buf.append("");
            }
            for (k, v) in self.metadata.items() {
                buf.append(f"!{k} {v.get_reference()}");
            }
            return ', '.join(buf);
        } else {
            return '';
        }
    }
}

"""
    A metadata string, i.e. a constant string used as a value in a metadata
    node.
    """
class MetaDataString(NamedValue) {
    has parent: Module,
        string: str = "";

    def init(self: MetaDataString, parent: Module, string: str) {
        self.parent = parent;
        super.init(parent.scope, types.MetaDataType(), "");
        self.string = string;
    }

    def descr(self: MetaDataString, buf: list[str]) {
        buf.append(self.get_reference());
        buf.append("\n");
    }

    def _get_reference(self: MetaDataString) -> str {
        return '!"' + _escape_string(self.string) + '"';
    }

    def _to_string(self: MetaDataString) -> str {
        return self._get_reference();
    }

    def __eq__(self: MetaDataString, other: object) -> bool {
        if isinstance(other, MetaDataString) {
            return (self.string == other.string);
        } else {
            return False;
        }
    }

    def __ne__(self: MetaDataString, other: object) -> bool {
        return not self.__eq__(other);
    }

    def __hash__(self: MetaDataString) -> int {
        return hash(self.string);
    }
}

"""
    An argument value to a function taking metadata arguments.
    This can wrap any other kind of LLVM value.

    Do not instantiate directly, Builder.call() will create these
    automatically.
    """
class MetaDataArgument(Value) {
    has wrapped_value: Value;

    def init(self: MetaDataArgument, value: Value) {
        assert isinstance(value, Value);
        assert not isinstance(value.type, types.MetaDataType);
        self.type = types.MetaDataType();
        self.wrapped_value = value;
    }

    def _get_reference(self: MetaDataArgument) -> str {
        return f"{self.wrapped_value.type} {self.wrapped_value.get_reference()}";
    }

    def _to_string(self: MetaDataArgument) -> str {
        return self._get_reference();
    }
}

"""
    A named metadata node.

    Do not instantiate directly, use Module.add_named_metadata() instead.
    """
class NamedMetaData {
    has parent: Module,
        operands: list[Value];

    def init(self: NamedMetaData, parent: Module) {
        self.parent = parent;
        self.operands = [];
    }

    def add(self: NamedMetaData, md: Value) {
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

    has parent: Module,
        operands: list[Value];

    def init(self: MDValue, parent: Module, values: any, name: str) {
        self.parent = parent;
        super.init(parent.scope, types.MetaDataType(), name);
        self.operands = _value_list(values);
        parent.metadata.append(self);
    }

    def descr(self: MDValue, buf: list[str]) {
        operands: list[str] = [];
        for op in self.operands {
            if isinstance(op.type, types.MetaDataType) {
                if (isinstance(op, Constant) and (op.constant is None)) {
                    operands.append("null");
                } else {
                    operands.append(op.get_reference());
                }
            } else {
                operands.append(f"{op.type} {op.get_reference()}");
            }
        }
        buf.append("!{ " + ', '.join(operands) + " }");
        buf.append("\n");
    }

    def _get_reference(self: MDValue) -> str {
        return (self.name_prefix + str(self._name));
    }

    def __eq__(self: MDValue, other: object) -> bool {
        if isinstance(other, MDValue) {
            return _same_values(self.operands, other.operands);
        } else {
            return False;
        }
    }

    def __ne__(self: MDValue, other: object) -> bool {
        return not self.__eq__(other);
    }

    def __hash__(self: MDValue) -> int {
        mixed = len(self.operands);
        for op in self.operands {
            mixed = ((mixed * 31) + (op.__hash__() & 0xffffffff)) & 0xffffffffffff;
        }
        return mixed;
    }
}

"""
    A debug information enumeration value that should appear bare in
    the emitted metadata.

    Use this to wrap known constants, e.g. the DW_* enumerations.
    """
class DIToken {
    has value: str = "";

    def init(self: DIToken, value: str) {
        self.value = value;
    }
}

"""One `key: value` operand of a debug information descriptor."""
class DIOperand {
    has key: str = "",
        value: any = None;

    def init(self: DIOperand, key: str, value: any) {
        self.key = key;
        self.value = value;
    }

    def same_as(self: DIOperand, other: DIOperand) -> bool {
        if self.key != other.key {
            return False;
        }
        mine = self.value;
        theirs = other.value;
        if mine is None or theirs is None {
            return mine is None and theirs is None;
        }
        if isinstance(mine, bool) or isinstance(mine, int) {
            if isinstance(theirs, bool) or isinstance(theirs, int) {
                return int(mine) == int(theirs);
            }
            return False;
        }
        if isinstance(mine, str) {
            if isinstance(theirs, str) {
                return mine == theirs;
            }
            return False;
        }
        if isinstance(mine, Value) {
            if isinstance(theirs, Value) {
                return mine is theirs or mine == theirs;
            }
            return False;
        }
        return mine is theirs;
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

    has parent: Module,
        is_distinct: bool = False,
        kind: str = "",
        operands: list[DIOperand];

    def init(
        self: DIValue,
        parent: Module,
        is_distinct: bool,
        kind: str,
        operands: list[DIOperand],
        name: str
    ) {
        self.parent = parent;
        super.init(parent.scope, types.MetaDataType(), name);
        self.is_distinct = is_distinct;
        self.kind = kind;
        self.operands = `list(operands);
        parent.metadata.append(self);
    }

    def descr(self: DIValue, buf: list[str]) {
        if self.is_distinct {
            buf.append("distinct ");
        }
        operands: list[str] = [];
        for operand in self.operands {
            value = operand.value;
            strvalue = "";
            if (value is None) {
                strvalue = "null";
            } elif isinstance(value, bool) {
                strvalue = "true" if value else "false";
            } elif isinstance(value, DIToken) {
                strvalue = value.value;
            } elif isinstance(value, str) {
                strvalue = '"' + _escape_string(value) + '"';
            } elif isinstance(value, int) {
                strvalue = str(value);
            } elif isinstance(value, Constant) {
                strvalue = str(value);
            } elif isinstance(value, NamedValue) {
                strvalue = value.get_reference();
            } else {
                raise TypeError(f"invalid operand type for debug info: {value!r}");
            }
            operands.append(f"{operand.key}: {strvalue}");
        }
        buf.append("!");
        buf.append(self.kind);
        buf.append("(");
        buf.append(', '.join(operands));
        buf.append(")\n");
    }

    def _get_reference(self: DIValue) -> str {
        return (self.name_prefix + str(self._name));
    }

    def __eq__(self: DIValue, other: object) -> bool {
        if isinstance(other, DIValue) {
            if self.is_distinct != other.is_distinct or self.kind != other.kind {
                return False;
            }
            if len(self.operands) != len(other.operands) {
                return False;
            }
            for i in range(len(self.operands)) {
                if not self.operands[i].same_as(other.operands[i]) {
                    return False;
                }
            }
            return True;
        } else {
            return False;
        }
    }

    def __ne__(self: DIValue, other: object) -> bool {
        return not self.__eq__(other);
    }

    def __hash__(self: DIValue) -> int {
        return hash(self.kind) + len(self.operands) + (1 if self.is_distinct else 0);
    }
}

"""
    A global value.
    """
class GlobalValue(NamedValue) {
    with entry {
        name_prefix = '@';
        deduplicate_name = False;
    }

    has parent: Module,
        linkage: str = '',
        storage_class: str = '',
        section: str = '';

    def init(self: GlobalValue, parent: Module, `type: types.Type, name: str) {
        assert (parent is not None);
        self.parent = parent;
        super.init(parent.scope, `type, name);
        self.linkage = '';
        self.storage_class = '';
        self.section = '';
    }
}

"""
    A global variable.
    """
class GlobalVariable(GlobalValue) {
    has value_type: types.Type,
        initializer: Value | None = None,
        unnamed_addr: bool = False,
        global_constant: bool = False,
        thread_local: bool = False,
        addrspace: int = 0,
        align: int | None = None;

    def init(
        self: GlobalVariable,
        module: Module,
        typ: types.Type,
        name: str,
        addrspace: int = 0
    ) {
        assert isinstance(typ, types.Type);
        super.init(module, typ.as_pointer(addrspace), name);
        self.value_type = typ;
        self.initializer = None;
        self.unnamed_addr = False;
        self.global_constant = False;
        self.thread_local = False;
        self.addrspace = addrspace;
        self.align = None;
        self.parent.add_global(self);
    }

    def descr(self: GlobalVariable, buf: list[str]) {
        if self.global_constant {
            kind = 'constant';
        } else {
            kind = 'global';
        }
        initial = self.initializer;
        if not self.linkage {
            linkage = 'external' if (initial is None) else '';
        } else {
            linkage = self.linkage;
        }
        if linkage {
            buf.append((linkage + " "));
        }
        if self.storage_class {
            buf.append((self.storage_class + " "));
        }
        # LLVM grammar puts the thread-local model between the storage class
        # and unnamed_addr; a bare `thread_local` selects the general-dynamic
        # model, which every target we emit for accepts (the wasm backend
        # strips it to a plain global when the module has no atomics).
        if self.thread_local {
            buf.append("thread_local ");
        }
        if self.unnamed_addr {
            buf.append("unnamed_addr ");
        }
        if (self.addrspace != 0) {
            buf.append(f"addrspace({self.addrspace}) ");
        }
        buf.append(f"{kind} {self.value_type}");
        if (initial is not None) {
            if (initial.type != self.value_type) {
                raise TypeError(
                    f"got initializer of type {initial.type} "
                    f"for global value type {self.value_type}"
                );
            }
            buf.append((" " + initial.get_reference()));
        } elif (linkage not in ('external', 'extern_weak')) {
            buf.append((" " + Constant(self.value_type, Undefined).get_reference()));
        }
        if self.section {
            buf.append(', section "' + self.section + '"');
        }
        alignment = self.align;
        if (alignment is not None) {
            buf.append(f", align {alignment}");
        }
        if self.metadata {
            buf.append(self._stringify_metadata(leading_comma=True));
        }
        buf.append("\n");
    }
}

"""A set of string attribute.
    Only accept items listed as known by the subclass.

    Properties:
    * Iterate in sorted order
    """
class AttributeSet {
    has _items: set[str];

    def init(self: AttributeSet, args: any = None) {
        self._items = set();
        for name in _str_list(args) {
            self.add(name);
        }
    }

    """Whether the subclass accepts the attribute name."""
    def _is_known(self: AttributeSet, name: str) -> bool {
        return False;
    }

    def _expand(self: AttributeSet, name: str, typ: types.Type) -> str {
        return name;
    }

    def _refuse(self: AttributeSet, name: str) {
        listed = ', '.join([repr(item) for item in sorted(self._items)]);
        shown = ('{' + listed + '}') if listed else '';
        raise ValueError(
            f"unknown attr {name!r} for {self.__class__.__name__}({shown})"
        );
    }

    def add(self: AttributeSet, name: str) {
        if not self._is_known(name) {
            self._refuse(name);
        }
        self._items.add(name);
    }

    def discard(self: AttributeSet, name: str) {
        self._items.discard(name);
    }

    def contains(self: AttributeSet, name: str) -> bool {
        return name in self._items;
    }

    def is_empty(self: AttributeSet) -> bool {
        return len(self._items) == 0;
    }

    def __contains__(self: AttributeSet, name: str) -> bool {
        return name in self._items;
    }

    def __len__(self: AttributeSet) -> int {
        return len(self._items);
    }

    def __bool__(self: AttributeSet) -> bool {
        return len(self._items) > 0;
    }

    def __iter__(self: AttributeSet) -> Iterator[str] {
        return iter(sorted(self._items));
    }

    def _to_list(self: AttributeSet, typ: types.Type) -> list[str] {
        return [self._expand(i, typ) for i in sorted(self._items)];
    }
}

class FunctionAttributes(AttributeSet) {
    has _alignstack: int = 0,
        _personality: GlobalValue | None = None;

    def init(self: FunctionAttributes, args: any = None) {
        self._alignstack = 0;
        self._personality = None;
        super.init(args);
    }

    def _is_known(self: FunctionAttributes, name: str) -> bool {
        return name in _FUNCTION_ATTRS;
    }

    def add(self: FunctionAttributes, name: str) {
        if (
            ((name == 'alwaysinline') and self.contains('noinline'))
            or ((name == 'noinline') and self.contains('alwaysinline'))
        ) {
            raise ValueError("Can't have alwaysinline and noinline");
        }
        super.add(name);
    }

    has alignstack: int {
        getter {
            return self._alignstack;
        }
        setter(self: FunctionAttributes, val: int) {
            assert (val >= 0);
            self._alignstack = val;
        }
    }

    has personality: GlobalValue | None {
        getter {
            return self._personality;
        }
        setter(self: FunctionAttributes, val: GlobalValue | None) {
            assert ((val is None) or isinstance(val, GlobalValue));
            self._personality = val;
        }
    }

    def _to_list(self: FunctionAttributes, typ: types.Type) -> list[str] {
        attrs = super._to_list(typ);
        if self._alignstack {
            attrs.append(f"alignstack({self._alignstack})");
        }
        handler = self._personality;
        if handler is not None {
            attrs.append(f"personality {handler.type} {handler.get_reference()}");
        }
        return attrs;
    }
}

"""Represent a LLVM Function but does uses a Module as parent.
    Global Values are stored as a set of dependencies (attribute `depends`).
    """
class Function(GlobalValue) {
    has ftype: types.FunctionType,
        scope: _utils.NameScope,
        blocks: list[Block],
        attributes: FunctionAttributes,
        args: list[Argument],
        return_value: ReturnValue,
        calling_convention: str = '';

    def init(self: Function, module: Module, ftype: types.FunctionType, name: str) {
        assert isinstance(ftype, types.FunctionType);
        super.init(module, ftype.as_pointer(), name);
        self.ftype = ftype;
        self.scope = _utils.NameScope();
        self.blocks = [];
        self.attributes = FunctionAttributes();
        self.args = [Argument(self, t) for t in ftype.args];
        self.return_value = ReturnValue(self, ftype.return_type);
        self.parent.add_global(self);
        self.calling_convention = '';
    }

    has module: Module {
        getter {
            return self.parent;
        }
    }

    has entry_basic_block: Block {
        getter {
            return self.blocks[0];
        }
    }

    has basic_blocks: list[Block] {
        getter {
            return self.blocks;
        }
    }

    def append_basic_block(self: Function, name: str = '') -> Block {
        blk = Block(parent=self, name=name);
        self.blocks.append(blk);
        return blk;
    }

    """Insert block before
        """
    def insert_basic_block(self: Function, before: int, name: str = '') -> Block {
        blk = Block(parent=self, name=name);
        self.blocks.insert(before, blk);
        return blk;
    }

    """
        Describe the prototype ("head") of the function.
        """
    def descr_prototype(self: Function, buf: list[str]) {
        state = "define" if self.blocks else "declare";
        args = ", ".join([str(a) for a in self.args]);
        name = self.get_reference();
        attrs = '';
        if not self.attributes.is_empty() {
            attrs = ' ' + ' '.join(self.attributes._to_list(self.ftype.return_type));
        }
        if self.args {
            vararg = ', ...' if self.ftype.var_arg else '';
        } else {
            vararg = '...' if self.ftype.var_arg else '';
        }
        lead: list[str] = [state];
        if self.linkage {
            lead.append(self.linkage);
        }
        if self.calling_convention {
            lead.append(self.calling_convention);
        }
        lead.append(str(self.return_value));
        prefix = " ".join(lead);
        metadata = self._stringify_metadata();
        if metadata {
            metadata = ' ' + metadata;
        }
        section = '';
        if self.section {
            section = ' section "' + self.section + '"';
        }
        buf.append(f"{prefix} {name}({args}{vararg}){attrs}{section}{metadata}\n");
    }

    """
        Describe of the body of the function.
        """
    def descr_body(self: Function, buf: list[str]) {
        for blk in self.blocks {
            blk.descr(buf);
        }
    }

    def descr(self: Function, buf: list[str]) {
        self.descr_prototype(buf);
        if self.blocks {
            buf.append("{\n");
            self.descr_body(buf);
            buf.append("}\n");
        }
    }

    def __str__(self: Function) -> str {
        buf: list[str] = [];
        self.descr(buf);
        return "".join(buf);
    }

    has is_declaration: bool {
        getter {
            return (len(self.blocks) == 0);
        }
    }
}

class ArgumentAttributes(AttributeSet) {
    has type: types.Type | None = None,
        _align: int = 0,
        _dereferenceable: int = 0,
        _dereferenceable_or_null: int = 0;

    def init(self: ArgumentAttributes, args: any = None) {
        self._align = 0;
        self._dereferenceable = 0;
        self._dereferenceable_or_null = 0;
        super.init(args);
    }

    def _is_known(self: ArgumentAttributes, name: str) -> bool {
        return name in _ARGUMENT_ATTRS;
    }

    def _expand(self: ArgumentAttributes, name: str, typ: types.Type) -> str {
        if _ARGUMENT_ATTRS.get(name, False) {
            target: types.Type | None = None;
            if isinstance(typ, types.PointerType) {
                target = typ.pointee;
            }
            if target is None {
                raise TypeError(f"attribute {name} needs a typed pointer, not {typ}");
            }
            return f"{name}({target})";
        } else {
            return name;
        }
    }

    has align: int {
        getter {
            return self._align;
        }
        setter(self: ArgumentAttributes, val: int) {
            assert (isinstance(val, int) and (val >= 0));
            self._align = val;
        }
    }

    has dereferenceable: int {
        getter {
            return self._dereferenceable;
        }
        setter(self: ArgumentAttributes, val: int) {
            assert (isinstance(val, int) and (val >= 0));
            self._dereferenceable = val;
        }
    }

    has dereferenceable_or_null: int {
        getter {
            return self._dereferenceable_or_null;
        }
        setter(self: ArgumentAttributes, val: int) {
            assert (isinstance(val, int) and (val >= 0));
            self._dereferenceable_or_null = val;
        }
    }

    def _to_list(self: ArgumentAttributes, typ: types.Type) -> list[str] {
        attrs = super._to_list(typ);
        if self._align {
            attrs.append(f"align {self._align}");
        }
        if self._dereferenceable {
            attrs.append(f"dereferenceable({self._dereferenceable})");
        }
        if self._dereferenceable_or_null {
            attrs.append(f"dereferenceable_or_null({self._dereferenceable_or_null})");
        }
        return attrs;
    }
}

class _BaseArgument(NamedValue) {
    has parent: Function,
        attributes: ArgumentAttributes;

    def init(self: _BaseArgument, parent: Function, typ: types.Type, name: str = '') {
        assert isinstance(typ, types.Type);
        self.parent = parent;
        super.init(parent.scope, typ, name);
        self.attributes = ArgumentAttributes();
    }

    def __repr__(self: _BaseArgument) -> str {
        return f"<ir.{self.__class__.__name__} {self._name!r} of type {self.type}>";
    }

    def add_attribute(self: _BaseArgument, attr: str) {
        self.attributes.add(attr);
    }
}

"""
    The specification of a function argument.
    """
class Argument(_BaseArgument) {
    def __str__(self: Argument) -> str {
        attrs = self.attributes._to_list(self.type);
        if attrs {
            joined = ' '.join(attrs);
            return f"{self.type} {joined} {self.get_reference()}";
        } else {
            return f"{self.type} {self.get_reference()}";
        }
    }
}

"""
    The specification of a function's return value.
    """
class ReturnValue(_BaseArgument) {
    def __str__(self: ReturnValue) -> str {
        attrs = self.attributes._to_list(self.type);
        if attrs {
            joined = ' '.join(attrs);
            return f"{joined} {self.type}";
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
    has parent: Function,
        scope: _utils.NameScope,
        instructions: list[NamedValue],
        terminator: NamedValue | None = None;

    def init(self: Block, parent: Function, name: str = '') {
        self.parent = parent;
        super.init(parent.scope, types.LabelType(), name);
        self.scope = parent.scope;
        self.instructions = [];
        self.terminator = None;
    }

    has is_terminated: bool {
        getter {
            return (self.terminator is not None);
        }
    }

    has function: Function {
        getter {
            return self.parent;
        }
    }

    has module: Module {
        getter {
            return self.parent.module;
        }
    }

    def descr(self: Block, buf: list[str]) {
        buf.append(self._format_name() + ":\n");
        for instr in self.instructions {
            buf.append(f"  {instr}\n");
        }
    }

    """The position of an instruction in the block, by identity."""
    def index_of(self: Block, instr: Value) -> int {
        for i in range(len(self.instructions)) {
            if self.instructions[i] is instr {
                return i;
            }
        }
        raise ValueError("instruction is not in the block");
    }

    """Replace an instruction"""
    def replace(self: Block, old: NamedValue, new: NamedValue) {
        if (old.type != new.type) {
            raise TypeError("new instruction has a different type");
        }
        import from jaclang.compiler.backends.native.llvm.ir.instructions {
            Instruction
        }
        pos = self.index_of(old);
        self.instructions.pop(pos);
        self.instructions.insert(pos, new);
        for bb in self.parent.basic_blocks {
            for instr in bb.instructions {
                if isinstance(instr, Instruction) {
                    instr.replace_usage(old, new);
                }
            }
        }
    }

    def _format_name(self: Block) -> str {
        name = self._name;
        if not _is_simple_identifier(name) {
            name = name.replace('\\', '\\5c').replace('"', '\\22');
            name = '"' + name + '"';
        }
        return name;
    }
}
