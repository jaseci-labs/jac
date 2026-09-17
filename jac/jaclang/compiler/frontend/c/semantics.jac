"""C declaration types and arithmetic rules, independent of Jac emission."""
import from jaclang.compiler.frontend.unitree_c { CNode }
import math;
import struct;
import from fractions { Fraction }
obj CEmitConfig {
    has abi: str = "lp64",
        char_signed: bool = True,
        enum_model: str = "gnu",
        function_pointer_interop: bool = False,
        source_paths: list[str] = [];

    def size_type -> CScalar {
        return CScalar(32 if self.abi == "ilp32" else 64, False,
            3 if self.abi == "ilp32" else (4 if self.abi == "lp64" else 5));
    }

    def scalar_atomic_storage(typ: CType) -> bool {
        base = unqualified(typ);
        return isinstance(base, CPointer) or (isinstance(base, CScalar)
            and base.category == "integer" and base.width in [8, 16, 32, 64]
            and base.width <= self.size_type().width);
    }

    def enum_type(values: list[int]) -> CScalar {
        if self.enum_model not in ["gnu", "int32"] { raise ValueError("Unknown C enum model: " + self.enum_model); }
        signed = self.enum_model == "int32" or any(value < 0 for value in values);
        lower = -(1 << 31) if signed else 0;
        upper = (1 << (31 if signed else 32)) - 1;
        if any(value < lower or value > upper for value in values) {
            raise ValueError("Enum value range requires a wider target enum storage model");
        }
        return CScalar(32, signed, 3);
    }
}


obj CType {}

obj CScalar(CType) {
    has width: int = 32,
        signed: bool = True,
        rank: int = 3,
        category: str = "integer";
    has jac: str {
        getter {
            if self.category == "void" { return "None"; }
            if self.category == "bool" { return "bool"; }
            if self.category == "floating" and self.width in [32, 64] {
                return "f" + str(self.width);
            }
            if self.category != "integer" or self.width not in [8, 16, 32, 64] {
                raise ValueError("C scalar needs additional native representation support");
            }
            return ("i" if self.signed else "u") + str(self.width);
        }
    }
}


obj CPointer(CType) {
    has pointee: CType;
}

obj CArray(CType) {
    has element: CType,
        length: int | None = None,
        bound: CNode | None = None,
        variable: bool = False,
        parameter_qualifiers: tuple[str, ...] = ();
}

obj CFunctionType(CType) {
    has returns: CType,
        parameters: list[CType] = [],
        variadic: bool = False,
        prototype: bool = True;
}

obj CField {
    has name: str,
        typ: CType,
        declaration: CNode,
        bit_width: CNode | None = None,
        ordinal: int = 0,
        bit_count: int | None = None;

}

obj CBitfield {
    has field: CField,
        storage_ordinal: int,
        shift: int,
        width: int;

    has storage_name: str { getter { return "_c2jac_bits_" + str(self.storage_ordinal); } }
}

obj CRecord(CType) {
    has name: str,
        identity: int,
        kind: str = "struct",
        complete: bool = False,
        fields: list[CField] = [],
        definition: CNode | None = None,
        attributes: list[CNode] = [],
        assertions: list[CNode] = [];

    def is_packed -> bool {
        return self.kind == "struct" and any(
            part.kind == "attribute_name" and part.value == "packed"
            and not part.operands
            for attribute in self.attributes for part in attribute.operands);
    }

    def byte_bitfields -> list[CBitfield] | None {
        if self.kind != "struct" or not any(field.bit_width is not None for field in self.fields) { return None; }
        result: list[CBitfield] = []; used = 0; ordinal = -1;
        for field in self.fields {
            if field.bit_width is None { used = 0; ordinal = -1; continue; }
            scalar = unqualified(field.typ); count = field.bit_count;
            if not isinstance(scalar, CScalar) or scalar.category != "integer" or scalar.width != 8
                or scalar.signed or count is None or count <= 0 or count > 8 or not field.name
                or lowering_attributes(attributes_of(field.typ)) or "_Atomic" in qualifiers_of(field.typ) { return None; }
            if ordinal < 0 or used + count > 8 { ordinal = field.ordinal; used = 0; }
            result.append(CBitfield(field, ordinal, used, count));
            used += count;
        }
        return result;
    }

    def full_bitfield_units -> int | None {
        if self.kind != "struct" or not self.fields { return None; }
        used = 0; units = 0;
        for field in self.fields {
            scalar = unqualified(field.typ); count = field.bit_count;
            if field.bit_width is None or count is None or count <= 0
                or not isinstance(scalar, CScalar) or scalar.category != "integer"
                or scalar.width != 32 or scalar.rank != 3
                or any(q not in ["const", "restrict"] for q in qualifiers_of(field.typ)) {
                return None;
            }
            # No field crosses an allocation unit, and no partial unit is
            # exposed to following fields. Bit ordering is irrelevant while
            # these units are copied as opaque words.
            if used + count > 32 { return None; }
            used += count;
            if used == 32 { units += 1; used = 0; }
        }
        return units if used == 0 else None;
    }

    def member_paths(active: set[int] | None = None) -> dict[str, list[CField]] {
        ancestors = set(active or set());
        if self.identity in ancestors { raise ValueError("Recursive anonymous C record storage"); }
        ancestors.add(self.identity);
        paths: dict[str, list[CField]] = {};
        for field in self.fields {
            promoted: dict[str, list[CField]] = {};
            if field.name { promoted[field.name] = [field]; }
            elif field.bit_width is None {
                nested = unqualified(field.typ);
                if not isinstance(nested, CRecord) { raise ValueError("Unnamed member must be a record or bitfield"); }
                for (name, path) in nested.member_paths(ancestors).items() {
                    promoted[name] = [field] + path;
                }
            }
            for (name, path) in promoted.items() {
                if name in paths { raise ValueError("Ambiguous C record member " + name); }
                paths[name] = path;
            }
        }
        return paths;
    }
}

obj CEnum(CScalar) {
    has name: str = "",
        identity: int = 0,
        definition: CNode | None = None,
        complete: bool = False;
}

obj CQualified(CType) {
    has base: CType,
        qualifiers: tuple[str, ...];
}

obj CAttributed(CType) {
    has base: CType,
        attributes: list[CNode];
}

obj COpaque(CType) {
    has name: str;
}

def unqualified(typ: CType) -> CType {
    while isinstance(typ, (CQualified, CAttributed)) {
        typ = typ.base;
    }
    return typ;
}

def qualifiers_of(typ: CType) -> set[str] {
    qualifiers: set[str] = set();
    while isinstance(typ, (CQualified, CAttributed)) {
        if isinstance(typ, CQualified) { qualifiers.update(typ.qualifiers); }
        typ = typ.base;
    }
    return qualifiers;
}

def attributes_of(typ: CType) -> list[CNode] {
    attributes: list[CNode] = [];
    while isinstance(typ, (CQualified, CAttributed)) {
        if isinstance(typ, CAttributed) { attributes.extend(typ.attributes); }
        typ = typ.base;
    }
    return attributes;
}

"""Attributes whose effects still require an explicit source translation.

Diagnostic and optimization promises do not change defined C execution when
omitted. Keep every unknown, storage, linkage and calling-convention attribute
so lowering cannot accidentally erase an ABI requirement.
"""
def lowering_attributes(attributes: list[CNode], handled: set[str] | None = None) -> list[CNode] {
    hints = {"always_inline", "noinline", "artificial", "pure", "const", "nothrow",
        "noreturn", "unused", "maybe_unused", "deprecated", "nodiscard", "nonnull",
        "warn_unused_result", "format", "format_arg", "access", "alloc_size",
        "alloc_align", "assume_aligned", "hot", "cold", "leaf", "flatten",
        "returns_nonnull", "malloc"};
    if handled is not None { hints.update(handled); }
    remaining: list[CNode] = [];
    for attribute in attributes {
        names = [part for part in attribute.operands if part.kind == "attribute_name"];
        supported = bool(names);
        for name in names {
            # Ordinary Jac native symbols already have default visibility.
            # Other visibility values must retain their explicit linkage effect.
            default_visibility = name.value == "visibility" and len(name.operands) == 1
                and name.operands[0].value == '"default"';
            supported = supported and (name.value in hints or default_visibility);
        }
        if attribute.kind != "attribute" or not supported {
            remaining.append(attribute);
        }
    }
    return remaining;
}

def compatible(a: CType, b: CType, ignore_qualifiers: bool = False) -> bool {
    if not ignore_qualifiers and qualifiers_of(a) != qualifiers_of(b) { return False; }
    left = unqualified(a); right = unqualified(b);
    if left is right { return True; }
    if isinstance(left, CEnum) and isinstance(right, CEnum) {
        return left.identity == right.identity;
    }
    if isinstance(left, CScalar) and isinstance(right, CScalar) {
        return left.width == right.width and left.signed == right.signed
            and left.rank == right.rank and left.category == right.category;
    }
    if isinstance(left, CPointer) and isinstance(right, CPointer) {
        return compatible(left.pointee, right.pointee);
    }
    if isinstance(left, CArray) and isinstance(right, CArray) {
        return compatible(left.element, right.element)
            and (left.length is None or right.length is None or left.length == right.length);
    }
    if isinstance(left, CFunctionType) and isinstance(right, CFunctionType) {
        if not compatible(left.returns, right.returns) { return False; }
        if left.prototype != right.prototype { return False; }
        if left.variadic != right.variadic or len(left.parameters) != len(right.parameters) { return False; }
        return all(compatible(x, y, ignore_qualifiers=True)
            for (x, y) in zip(left.parameters, right.parameters));
    }
    if isinstance(left, COpaque) and isinstance(right, COpaque) { return left.name == right.name; }
    return False;
}


def promote(typ: CScalar) -> CScalar {
    if isinstance(typ, CEnum) {
        if not typ.complete { raise ValueError("Incomplete enum has no integer representation"); }
        return CScalar(typ.width, typ.signed, typ.rank);
    }
    return CScalar() if typ.category in ["integer", "bool"] and typ.rank < 3 else typ;
}


def common(a: CScalar, b: CScalar) -> CScalar {
    if a.category == "floating" or b.category == "floating" {
        if a.category != "floating" { return b; }
        if b.category != "floating" { return a; }
        return a if a.rank >= b.rank else b;
    }
    left = promote(a); right = promote(b);
    if left.signed == right.signed { return left if left.rank >= right.rank else right; }
    unsigned = right if left.signed else left; signed = left if left.signed else right;
    if unsigned.rank >= signed.rank { return unsigned; }
    if signed.width > unsigned.width { return signed; }
    return CScalar(signed.width, False, signed.rank);
}


obj CDeferred(CType) {
    has expression: CNode;
}

def is_floating_literal(spelling: str) -> bool {
    lower = spelling.lower();
    return "." in lower or ("p" in lower if lower.startswith("0x") else "e" in lower);
}

def floating_literal(spelling: str) -> tuple[float, CScalar] {
    suffix = spelling[-1].lower();
    if suffix == "l" { raise ValueError("Long double literals require a target extended-precision representation"); }
    narrow = suffix == "f";
    digits = spelling[:-1] if narrow else spelling;
    try { value = float.fromhex(digits) if digits.lower().startswith("0x") else float(digits); }
    except (ValueError, OverflowError) { raise ValueError("Invalid or out-of-range C floating literal: " + spelling); }
    if not math.isfinite(value) { raise ValueError("C floating literal exceeds the supported finite representation"); }
    if not narrow { return (value, CScalar(64, True, 2, "floating")); }
    if value == 0.0 { return (0.0, CScalar(32, True, 1, "floating")); }
    # Select the nearest binary32 value from the exact spelling. Going through
    # binary64 alone can double-round a decimal literal close to a midpoint.
    if digits.lower().startswith("0x") {
        (mantissa, exponent) = digits.lower()[2:].split("p");
        fraction_digits = len(mantissa.split(".")[1]) if "." in mantissa else 0;
        exact = Fraction(int(mantissa.replace(".", ""), 16), 16 ** fraction_digits);
        power = int(exponent);
        exact *= Fraction(1 << power, 1) if power >= 0 else Fraction(1, 1 << (-power));
    } else { exact = Fraction(digits); }
    if exact >= Fraction((1 << 128) - (1 << 103), 1) {
        raise ValueError("C float literal exceeds binary32 range");
    }
    try { bits = int(struct.unpack(">I", struct.pack(">f", value))[0]); }
    except OverflowError { bits = 0x7f7fffff; }
    bits = min(bits, 0x7f7fffff);
    best = value; distance: Fraction | None = None; best_bits = bits;
    for candidate_bits in range(max(0, bits - 1), min(0x7f7fffff, bits + 1) + 1) {
        candidate = float(struct.unpack(">f", struct.pack(">I", candidate_bits))[0]);
        candidate_distance = abs(Fraction(candidate) - exact);
        if distance is None or candidate_distance < distance
            or (candidate_distance == distance and candidate_bits % 2 < best_bits % 2) {
            best = candidate; best_bits = candidate_bits; distance = candidate_distance;
        }
    }
    return (best, CScalar(32, True, 1, "floating"));
}

def integer_literal(spelling: str, config: CEmitConfig) -> tuple[int, CScalar] {
    end = len(spelling);
    while end and spelling[end - 1] in "uUlL" { end -= 1; }
    digits = spelling[:end]; original_suffix = spelling[end:];
    suffix = original_suffix.lower();
    if suffix not in ["", "u", "l", "ul", "lu", "ll", "ull", "llu"] {
        raise ValueError("Invalid C integer literal suffix: " + original_suffix);
    }
    long_suffix = original_suffix.replace("u", "").replace("U", "");
    if len(long_suffix) == 2 and long_suffix not in ["ll", "LL"] {
        raise ValueError("Mixed-case long long suffix: " + original_suffix);
    }
    base = 10;
    if digits.lower().startswith("0x") { base = 16; }
    elif digits.lower().startswith("0b") { base = 2; }
    elif len(digits) > 1 and digits.startswith("0") { base = 8; }
    try { number = int(digits, base); }
    except ValueError { raise ValueError("Literal is not a supported C integer: " + spelling); }
    minimum = 5 if "ll" in suffix else (4 if "l" in suffix else 3);
    for rank in range(minimum, 6) {
        width = 64 if rank == 5 or (rank == 4 and config.abi == "lp64") else 32;
        candidates = [False] if "u" in suffix else ([True, False] if base != 10 else [True]);
        for signed in candidates {
            if number < (1 << (width - (1 if signed else 0))) {
                return (number, CScalar(width, signed, rank));
            }
        }
    }
    raise ValueError("Integer literal exceeds the selected C data model");
}

# Literal decoding is independent of the host Python string escape rules.
def execution_bytes(body: str) -> bytes {
    result = bytearray(); position = 0;
    escapes = {"a": 7, "b": 8, "f": 12, "n": 10, "r": 13, "t": 9,
        "v": 11, "\\": 92, "'": 39, '"': 34, "?": 63};
    while position < len(body) {
        character = body[position]; position += 1;
        if character != "\\" {
            value = ord(character);
            if value > 127 { raise ValueError("Non-ASCII literal requires an execution character set"); }
            result.append(value); continue;
        }
        if position == len(body) { raise ValueError("Incomplete C escape sequence"); }
        character = body[position]; position += 1;
        if character in escapes { result.append(escapes[character]); continue; }
        start = position;
        if character == "x" {
            while position < len(body) and body[position] in "0123456789abcdefABCDEF" { position += 1; }
            if position == start { raise ValueError("Hexadecimal escape requires at least one digit"); }
            value = int(body[start:position], 16);
        } elif character in "01234567" {
            start -= 1;
            while position < min(len(body), start + 3) and body[position] in "01234567" { position += 1; }
            value = int(body[start:position], 8);
        } else { raise ValueError("Unsupported C escape sequence: " + character); }
        if value > 255 { raise ValueError("Escape value does not fit an 8-bit execution character"); }
        result.append(value);
    }
    return bytes(result);
}

def string_literal(spelling: str) -> bytes {
    if not spelling.startswith('"') or not spelling.endswith('"') {
        raise ValueError("Prefixed string literal requires an execution character set");
    }
    return execution_bytes(spelling[1:-1]);
}

def character_literal(spelling: str) -> int {
    if not spelling.startswith("'") or not spelling.endswith("'") {
        raise ValueError("Wide character constant requires an execution character set");
    }
    value = execution_bytes(spelling[1:-1]);
    if len(value) != 1 or value[0] > 127 {
        raise ValueError("Character constant requires implementation-defined encoding or multicharacter rules");
    }
    return value[0];
}

def string_bytes(nd: CNode) -> bytes {
    if nd.kind != "string" { raise ValueError("Expected a C string literal"); }
    return string_literal(nd.value) + b"".join(string_literal(part.value) for part in nd.operands);
}
