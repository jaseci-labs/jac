import struct;
import from jaclang.compiler.driver.compile_options { env_typed_pointers_enabled }
import type from jaclang.compiler.backends.native.llvm.ir.values { Value, Constant }
import type from jaclang.compiler.backends.native.llvm.ir.context { Context }

glob ir_layer_typed_pointers_enabled: bool = env_typed_pointers_enabled(),
     _TYPES_MODULE: str = "jaclang.compiler.backends.native.llvm.ir.types";

def _wrapname(x: str) -> str {
    return '"' + x.replace('\\', '\\5c').replace('"', '\\22') + '"';
}

"""Whether two type sequences hold pairwise equal types."""
def _same_types(left: list[Type], right: list[Type]) -> bool {
    if len(left) != len(right) {
        return False;
    }
    for i in range(len(left)) {
        if left[i] != right[i] {
            return False;
        }
    }
    return True;
}

"""A copy of a type sequence handed in as any iterable of types."""
def _type_list(items: any) -> list[Type] {
    out: list[Type] = [];
    if isinstance(items, (`list, `tuple)) {
        for item in items {
            if isinstance(item, Type) {
                out.append(item);
            } else {
                raise TypeError(f"not an IR type: {item!r}");
            }
        }
    } else {
        for item in items {
            if isinstance(item, Type) {
                out.append(item);
            } else {
                raise TypeError(f"not an IR type: {item!r}");
            }
        }
    }
    return out;
}

"""The `<type> <reference>` list an aggregate constant prints."""
def _format_members(value: any) -> str {
    import from jaclang.compiler.backends.native.llvm.ir.values { Value }
    parts: list[str] = [];
    if isinstance(value, (`list, `tuple)) {
        for x in value {
            if isinstance(x, Value) {
                parts.append(f"{x.type} {x.get_reference()}");
            } else {
                raise TypeError(f"not an IR value: {x!r}");
            }
        }
    } else {
        raise TypeError(f"not a sequence of IR values: {value!r}");
    }
    return ", ".join(parts);
}

"""Constants for the members of an aggregate, wrapping raw member values."""
def _wrap_members(elements: list[Type], values: any) -> list[Value] {
    import from jaclang.compiler.backends.native.llvm.ir.values { Value, Constant }
    out: list[Value] = [];
    index = 0;
    if isinstance(values, (`list, `tuple)) {
        for val in values {
            if index >= len(elements) {
                break;
            }
            if isinstance(val, Value) {
                out.append(val);
            } else {
                out.append(Constant(elements[index], val));
            }
            index += 1;
        }
    }
    return out;
}

"""An LLVM type. Its text form is computed once and kept: every subclass that
prints through `_to_string` lives in this module, so the call dispatches."""
class Type {
    has _pointer_types: dict[int, PointerType] | None = None,
        _cached_str: str | None = None;

    with entry {
        is_pointer = False;
        null = 'zeroinitializer';
    }

    def __repr__(self: Type) -> str {
        return f"<<class '{_TYPES_MODULE}.{self.__class__.__name__}'> {self}>";
    }

    def _to_string(self: Type) -> str {
        raise NotImplementedError;
    }

    def _clear_string_cache(self: Type) {
        self._cached_str = None;
    }

    def __str__(self: Type) -> str {
        cached = self._cached_str;
        if cached is None {
            cached = self._to_string();
            self._cached_str = cached;
        }
        return cached;
    }

    def as_pointer(self: Type, addrspace: int = 0) -> PointerType {
        pointers = self._pointer_types;
        if pointers is None {
            pointers = {};
            self._pointer_types = pointers;
        }
        pointer = pointers.get(addrspace);
        if pointer is None {
            pointer = PointerType(self, addrspace);
            pointers[addrspace] = pointer;
        }
        return pointer;
    }

    def __eq__(self: Type, other: object) -> bool {
        return self is other;
    }

    def __hash__(self: Type) -> int {
        return id(self);
    }

    def format_constant(self: Type, value: any) -> str {
        return str(value);
    }

    def wrap_constant_value(self: Type, value: any) -> any {
        return value;
    }

    def __call__(self: Type, value: any) -> Constant {
        import from jaclang.compiler.backends.native.llvm.ir.values { Constant }
        return Constant(self, value);
    }

    def gep(self: Type, i: Value) -> Type {
        raise TypeError(f"{self} does not support gep");
    }
}

class MetaDataType(Type) {
    def _to_string(self: MetaDataType) -> str {
        return "metadata";
    }

    def as_pointer(self: MetaDataType, addrspace: int = 0) -> PointerType {
        raise TypeError;
    }

    def __eq__(self: MetaDataType, other: object) -> bool {
        return isinstance(other, MetaDataType);
    }

    def __hash__(self: MetaDataType) -> int {
        return hash("MetaDataType");
    }
}

class LabelType(Type) {
    def _to_string(self: LabelType) -> str {
        return "label";
    }
}

"""A pointer type. One built over a pointee that is not itself an opaque
pointer is typed: it remembers the pointee, and `is_opaque` is false."""
class PointerType(Type) {
    with entry {
        is_pointer = True;
        null = 'null';
    }

    has pointee: Type | None = None,
        addrspace: int = 0;

    def init(self: PointerType, pointee: Type | None = None, addrspace: int = 0) {
        self.addrspace = addrspace;
        if pointee is not None {
            if isinstance(pointee, PointerType) and pointee.pointee is None {
                self.pointee = None;
            } else {
                assert not isinstance(pointee, VoidType);
                self.pointee = pointee;
            }
        } else {
            self.pointee = None;
        }
    }

    has is_opaque: bool {
        getter {
            return self.pointee is None;
        }
    }

    """The pointee of a typed pointer; an opaque pointer has none."""
    has pointee_type: Type {
        getter {
            target = self.pointee;
            if target is None {
                raise TypeError(f"{self} is an opaque pointer");
            }
            return target;
        }
    }

    def _to_string(self: PointerType) -> str {
        target = self.pointee;
        if target is not None and ir_layer_typed_pointers_enabled {
            if self.addrspace == 0 {
                return f"{target}*";
            }
            return f"{target} addrspace({self.addrspace})*";
        }
        if (self.addrspace != 0) {
            return f"ptr addrspace({self.addrspace})";
        } else {
            return "ptr";
        }
    }

    def __eq__(self: PointerType, other: object) -> bool {
        if isinstance(other, PointerType) {
            mine = self.pointee;
            theirs = other.pointee;
            if mine is not None and theirs is not None {
                return mine == theirs and self.addrspace == other.addrspace;
            }
            return self.addrspace == other.addrspace;
        }
        return False;
    }

    def __hash__(self: PointerType) -> int {
        return hash("PointerType") + self.addrspace;
    }

    def gep(self: PointerType, i: Value) -> Type {
        target = self.pointee;
        if target is None {
            raise TypeError(f"{self} does not support gep");
        }
        if not isinstance(i.type, IntType) {
            raise TypeError(i.type);
        }
        return target;
    }
}

class VoidType(Type) {
    def _to_string(self: VoidType) -> str {
        return 'void';
    }

    def __eq__(self: VoidType, other: object) -> bool {
        return isinstance(other, VoidType);
    }

    def __hash__(self: VoidType) -> int {
        return hash("VoidType");
    }
}

class FunctionType(Type) {
    has return_type: Type,
        args: list[Type],
        var_arg: bool = False;

    def init(self: FunctionType, return_type: Type, args: any, var_arg: bool = False) {
        self.return_type = return_type;
        self.args = _type_list(args);
        self.var_arg = var_arg;
    }

    def _to_string(self: FunctionType) -> str {
        if self.args {
            strargs = ', '.join([str(a) for a in self.args]);
            if self.var_arg {
                return f"{self.return_type} ({strargs}, ...)";
            } else {
                return f"{self.return_type} ({strargs})";
            }
        } elif self.var_arg {
            return f"{self.return_type} (...)";
        } else {
            return f"{self.return_type} ()";
        }
    }

    def __eq__(self: FunctionType, other: object) -> bool {
        if isinstance(other, FunctionType) {
            return (
                (self.return_type == other.return_type)
                and _same_types(self.args, other.args)
                and (self.var_arg == other.var_arg)
            );
        } else {
            return False;
        }
    }

    def __hash__(self: FunctionType) -> int {
        return hash("FunctionType");
    }
}

class IntType(Type) {
    with entry {
        null = '0';
    }

    has width: int = 0;

    def init(self: IntType, bits: int) {
        assert (isinstance(bits, int) and (bits >= 0));
        self.width = bits;
    }

    def __getnewargs__(self: IntType) -> tuple[int] {
        return (self.width, );
    }

    def __copy__(self: IntType) -> IntType {
        return self;
    }

    def _to_string(self: IntType) -> str {
        return f"i{self.width}";
    }

    def __eq__(self: IntType, other: object) -> bool {
        if isinstance(other, IntType) {
            return (self.width == other.width);
        } else {
            return False;
        }
    }

    def __hash__(self: IntType) -> int {
        return hash("IntType");
    }

    def format_constant(self: IntType, value: any) -> str {
        if isinstance(value, bool) {
            return 'true' if value else 'false';
        } else {
            return str(value);
        }
    }

    def wrap_constant_value(self: IntType, value: any) -> any {
        if (value is None) {
            return 0;
        }
        return value;
    }
}

"""The 64 bits of a double, as the integer `struct` reads them."""
def _double_bits(value: float) -> int {
    return struct.unpack('Q', struct.pack('d', value))[0];
}

"""The double a constant's raw value stands for."""
def _as_double(value: any) -> float {
    if isinstance(value, float) {
        return value;
    }
    if isinstance(value, bool) {
        return 1.0 if value else 0.0;
    }
    if isinstance(value, int) {
        return float(value);
    }
    if isinstance(value, str) {
        return float(value);
    }
    raise TypeError(f"not a floating-point constant: {value!r}");
}

def _as_float(value: float) -> float {
    return struct.unpack('f', struct.pack('f', value))[0];
}

"""Round a double to the nearest IEEE half (ties to even) and widen it back,
the round trip `struct`'s 'e' format performs."""
def _as_half(value: float) -> float {
    bits = _double_bits(value);
    negative = (bits >> 63) != 0;
    exponent = (bits >> 52) & 0x7ff;
    mantissa = bits & 0xfffffffffffff;
    if exponent == 0x7ff {
        if mantissa == 0 {
            return value;
        }
        quiet = float("nan");
        return -quiet if negative else quiet;
    }
    magnitude = 0.0;
    if exponent != 0 {
        scale = exponent - 1023;
        full = (1 << 52) | mantissa;
        if scale >= -14 {
            kept = full >> 42;
            rest = full & ((1 << 42) - 1);
            if rest > (1 << 41) or (rest == (1 << 41) and (kept & 1) == 1) {
                kept += 1;
            }
            if kept == (1 << 11) {
                kept = 1 << 10;
                scale += 1;
            }
            if scale > 15 {
                raise OverflowError("float too large to pack with e format");
            }
            shift = scale - 10;
            if shift >= 0 {
                magnitude = float(kept * (1 << shift));
            } else {
                magnitude = float(kept) / float(1 << (0 - shift));
            }
        } else {
            drop = 28 - scale;
            kept = 0;
            if drop <= 53 {
                kept = full >> drop;
                rest = full & ((1 << drop) - 1);
                middle = 1 << (drop - 1);
                if rest > middle or (rest == middle and (kept & 1) == 1) {
                    kept += 1;
                }
            }
            magnitude = float(kept) / 16777216.0;
        }
    }
    return -magnitude if negative else magnitude;
}

"""A double as the hexadecimal literal LLVM reads, right-aligned to 16."""
def _format_double(value: float) -> str {
    intrep = _double_bits(value);
    high = (intrep >> 32) & 0xffffffff;
    low = intrep & 0xffffffff;
    if high != 0 {
        text = f"0x{high:x}{low:08x}";
    } else {
        text = f"0x{low:x}";
    }
    return text.rjust(16);
}

class _BaseFloatType(Type) {}

class HalfType(_BaseFloatType) {
    with entry {
        null = '0.0';
    }

    def __str__(self: HalfType) -> str {
        return 'half';
    }

    def __eq__(self: HalfType, other: object) -> bool {
        return isinstance(other, HalfType);
    }

    def __hash__(self: HalfType) -> int {
        return hash("HalfType");
    }

    def format_constant(self: HalfType, value: any) -> str {
        return _format_double(_as_half(_as_double(value)));
    }
}

class FloatType(_BaseFloatType) {
    with entry {
        null = '0.0';
    }

    def __str__(self: FloatType) -> str {
        return 'float';
    }

    def __eq__(self: FloatType, other: object) -> bool {
        return isinstance(other, FloatType);
    }

    def __hash__(self: FloatType) -> int {
        return hash("FloatType");
    }

    def format_constant(self: FloatType, value: any) -> str {
        return _format_double(_as_float(_as_double(value)));
    }
}

class DoubleType(_BaseFloatType) {
    with entry {
        null = '0.0';
    }

    def __str__(self: DoubleType) -> str {
        return 'double';
    }

    def __eq__(self: DoubleType, other: object) -> bool {
        return isinstance(other, DoubleType);
    }

    def __hash__(self: DoubleType) -> int {
        return hash("DoubleType");
    }

    def format_constant(self: DoubleType, value: any) -> str {
        return _format_double(_as_double(value));
    }
}

class VectorType(Type) {
    has element: Type,
        count: int = 0;

    def init(self: VectorType, element: Type, count: int) {
        self.element = element;
        self.count = count;
    }

    has elements: list[Type] {
        getter {
            return [self.element] * self.count;
        }
    }

    def __len__(self: VectorType) -> int {
        return self.count;
    }

    def _to_string(self: VectorType) -> str {
        return f"<{self.count} x {self.element}>";
    }

    def __eq__(self: VectorType, other: object) -> bool {
        if isinstance(other, VectorType) {
            return ((self.element == other.element) and (self.count == other.count));
        }
        return False;
    }

    def __hash__(self: VectorType) -> int {
        return hash("VectorType");
    }

    def __copy__(self: VectorType) -> VectorType {
        return self;
    }

    def format_constant(self: VectorType, value: any) -> str {
        return "<" + _format_members(value) + ">";
    }

    def wrap_constant_value(self: VectorType, value: any) -> any {
        import from jaclang.compiler.backends.native.llvm.ir.values { Constant }
        if isinstance(value, bytearray) {
            return [Constant(self.element, value)] * self.count;
        }
        if not isinstance(value, (`list, `tuple)) {
            if isinstance(value, Constant) {
                if (value.type != self.element) {
                    raise TypeError(f"expected {self.element} for {value.type}");
                }
                return [value] * self.count;
            }
            return [Constant(self.element, value)] * self.count;
        }
        if (len(value) != self.count) {
            raise ValueError(
                f"wrong constant size for {self}: got {len(value)} elements"
            );
        }
        return _wrap_members(self.elements, value);
    }
}

class Aggregate(Type) {
    """The member types, or None while a struct is still opaque."""
    def _element_types(self: Aggregate) -> list[Type] | None {
        raise NotImplementedError;
    }

    has elements: list[Type] | None {
        getter {
            return self._element_types();
        }
    }

    """The member types of a defined aggregate; an opaque struct has none yet."""
    def members(self: Aggregate) -> list[Type] {
        found = self._element_types();
        if found is None {
            raise TypeError(f"{self} is opaque");
        }
        return found;
    }

    def __len__(self: Aggregate) -> int {
        raise NotImplementedError;
    }

    def wrap_constant_value(self: Aggregate, value: any) -> any {
        if isinstance(value, bytearray) or not isinstance(value, (`list, `tuple)) {
            return value;
        }
        members = self._element_types();
        assert (members is not None);
        if (len(value) != len(members)) {
            raise ValueError(
                f"wrong constant size for {self}: got {len(value)} elements"
            );
        }
        return _wrap_members(members, value);
    }
}

class ArrayType(Aggregate) {
    has element: Type,
        count: int = 0;

    def init(self: ArrayType, element: Type, count: int) {
        self.element = element;
        self.count = count;
    }

    def _element_types(self: ArrayType) -> list[Type] | None {
        return [self.element] * self.count;
    }

    def __len__(self: ArrayType) -> int {
        return self.count;
    }

    def _to_string(self: ArrayType) -> str {
        return f"[{self.count} x {self.element}]";
    }

    def __eq__(self: ArrayType, other: object) -> bool {
        if isinstance(other, ArrayType) {
            return ((self.element == other.element) and (self.count == other.count));
        }
        return False;
    }

    def __hash__(self: ArrayType) -> int {
        return hash("ArrayType");
    }

    def gep(self: ArrayType, i: Value) -> Type {
        if not isinstance(i.type, IntType) {
            raise TypeError(i.type);
        }
        return self.element;
    }

    def format_constant(self: ArrayType, value: any) -> str {
        return "[" + _format_members(value) + "]";
    }

    def wrap_constant_value(self: ArrayType, value: any) -> any {
        if isinstance(value, bytearray) or not isinstance(value, (`list, `tuple)) {
            return value;
        }
        if (len(value) != self.count) {
            raise ValueError(
                f"wrong constant size for {self}: got {len(value)} elements"
            );
        }
        import from jaclang.compiler.backends.native.llvm.ir.values { Value, Constant }
        out: list[Value] = [];
        for val in value {
            if isinstance(val, Value) {
                out.append(val);
            } else {
                out.append(Constant(self.element, val));
            }
        }
        return out;
    }
}

class BaseStructType(Aggregate) {
    has _elements: list[Type] | None = None,
        packed: bool = False;

    def _element_types(self: BaseStructType) -> list[Type] | None {
        return self._elements;
    }

    def __len__(self: BaseStructType) -> int {
        members = self._elements;
        assert (members is not None);
        return len(members);
    }

    def __iter__(self: BaseStructType) -> Iterator[Type] {
        members = self._elements;
        assert (members is not None);
        return iter(members);
    }

    has is_opaque: bool {
        getter {
            return (self._elements is None);
        }
    }

    def structure_repr(self: BaseStructType) -> str {
        members = self._elements;
        assert (members is not None);
        ret = '{' + ', '.join([str(x) for x in members]) + '}';
        return self._wrap_packed(ret);
    }

    def format_constant(self: BaseStructType, value: any) -> str {
        ret = "{" + _format_members(value) + "}";
        return self._wrap_packed(ret);
    }

    def gep(self: BaseStructType, i: Value) -> Type {
        import from jaclang.compiler.backends.native.llvm.ir.values { Constant }
        if not isinstance(i.type, IntType) {
            raise TypeError(i.type);
        }
        members = self._elements;
        if members is None {
            raise TypeError(f"{self} has no indexable elements");
        }
        if not isinstance(i, Constant) {
            raise TypeError(f"{self} is indexed by constants only");
        }
        index = i.constant;
        if not isinstance(index, int) {
            raise TypeError(f"{self} is indexed by integer constants only");
        }
        return members[index];
    }

    def _wrap_packed(self: BaseStructType, textrepr: str) -> str {
        if self.packed {
            return '<' + textrepr + '>';
        } else {
            return textrepr;
        }
    }
}

class LiteralStructType(BaseStructType) {
    with entry {
        null = 'zeroinitializer';
    }

    def init(self: LiteralStructType, elems: any, packed: bool = False) {
        self._elements = _type_list(elems);
        self.packed = bool(packed);
    }

    def _to_string(self: LiteralStructType) -> str {
        return self.structure_repr();
    }

    def __eq__(self: LiteralStructType, other: object) -> bool {
        if isinstance(other, LiteralStructType) {
            mine = self._elements;
            theirs = other._elements;
            if mine is None or theirs is None {
                return False;
            }
            return _same_types(mine, theirs) and (self.packed == other.packed);
        }
        return False;
    }

    def __hash__(self: LiteralStructType) -> int {
        members = self._elements;
        count = len(members) if members is not None else 0;
        return hash("LiteralStructType") + count + (1 if self.packed else 0);
    }
}

class IdentifiedStructType(BaseStructType) {
    with entry {
        null = 'zeroinitializer';
    }

    has context: Context | None = None,
        name: str = "";

    def init(
        self: IdentifiedStructType, context: Context, name: str, packed: bool = False
    ) {
        assert name;
        self.context = context;
        self.name = name;
        self.packed = bool(packed);
    }

    def _to_string(self: IdentifiedStructType) -> str {
        return "%" + _wrapname(self.name);
    }

    def get_declaration(self: IdentifiedStructType) -> str {
        if self.is_opaque {
            out = f"{self} = type opaque";
        } else {
            out = f"{self} = type {self.structure_repr()}";
        }
        return out;
    }

    def __eq__(self: IdentifiedStructType, other: object) -> bool {
        if isinstance(other, IdentifiedStructType) {
            return ((self.name == other.name) and (self.packed == other.packed));
        }
        return False;
    }

    def __hash__(self: IdentifiedStructType) -> int {
        return hash("IdentifiedStructType")
            + hash(self.name)
            + (1 if self.packed else 0);
    }

    def set_body(self: IdentifiedStructType, *elems: Type) {
        members = self._elements;
        if members is not None {
            raise RuntimeError(f"{self.name} is already defined");
        }
        self._elements = `list(elems);
    }
}
