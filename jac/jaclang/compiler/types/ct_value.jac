import math;
import from jaclang.compiler.types.ct_int {
    MAX_STR_DIGITS,
    mag_add_small,
    mag_bit_length,
    mag_cmp,
    mag_decimal_digits,
    mag_from_int,
    mag_shl,
    mag_to_int
}
import type from jaclang.compiler.frontend.unitree { Ability }
import type from jaclang.compiler.types.types { ClassType, TypeBase }

class CtNotComptime(Exception) {}

class CtError(Exception) {}

class CtDeferredSignal(Exception) {}

obj CtEnvironment {
    has os: str = "linux",
        arch: str = "";
}

obj CtValue {
    has is_deferred: bool { getter; }

    def __repr__ -> str {
        return ct_repr(self);
    }
}

impl CtValue.is_deferred.getter -> bool {
    return isinstance(self, CtDeferred);
}

obj CtDeferred(CtValue) {}

obj CtNone(CtValue) {}

obj CtBool(CtValue) {
    has value: bool = False;
}

obj CtInt(CtValue) {
    has small: int = 0,
        mag: list[int] = [],
        neg: bool = False;
}

obj CtFloat(CtValue) {
    has value: float = 0.0;
}

obj CtStr(CtValue) {
    has value: str = "";
}

obj CtBytes(CtValue) {
    has value: bytes = b"";
}

obj CtTuple(CtValue) {
    has items: list[CtValue] = [];
}

obj CtList(CtValue) {
    has items: list[CtValue] = [];
}

obj CtDict(CtValue) {
    has keys: list[CtValue] = [],
        vals: list[CtValue] = [],
        index: dict[str, int] = {};
}

obj CtSet(CtValue) {
    has items: list[CtValue] = [],
        index: dict[str, int] = {},
        frozen: bool = False;
}

obj CtRange(CtValue) {
    has start: int = 0,
        stop: int = 0,
        step: int = 1;
}

obj CtView(CtValue) {
    has kind: str,
        source: CtDict;
}

obj CtType(CtValue) {
    has name: str,
        module: str = "",
        typ: (TypeBase | None) = None,
        ct_args: (dict[str, CtValue] | None) = None;
}

obj CtFunc(CtValue) {
    has qualname: str,
        module: str = "",
        ability: (Ability | None) = None,
        lazy: bool = False;
}

obj CtBound(CtValue) {
    has self_val: CtValue,
        ability: Ability;
}

obj CtBuiltin(CtValue) {
    has name: str;
}

obj CtMethod(CtValue) {
    has owner: str,
        name: str,
        recv: (CtValue | None) = None;
}

obj CtModule(CtValue) {
    has name: str;
}

obj CtRecord(CtValue) {
    has class_name: str,
        module: str = "",
        fields: dict[str, CtValue] = {},
        class_type: (ClassType | None) = None,
        home: str = "",
        ct_args: (dict[str, CtValue] | None) = None;
}

obj CtEnumMember(CtValue) {
    has enum_name: str,
        member: str,
        value: CtValue = CtNone(),
        module: str = "",
        enum_type: (ClassType | None) = None;
}

obj CtExc(CtValue) {
    has kind: str,
        args: list[CtValue] = [];
}

obj CtCaller {
    def call_value(
        callee: CtValue, args: list[CtValue], kwargs: dict[str, CtValue]
    ) -> CtValue abst;

    def ct_isinstance(v: CtValue, t: CtValue) -> bool abst;
}

obj CtRaise(Exception) {
    has exc: CtExc,
        user: bool = False;

    def __str__ -> str {
        return ct_str(self.exc);
    }
}

glob CT_SMALL_BOUND: int = 4611686018427387904,
     CT_NONE: CtNone = CtNone(),
     CT_TRUE: CtBool = CtBool(value=True),
     CT_FALSE: CtBool = CtBool(value=False),
     CT_DEFERRED: CtDeferred = CtDeferred(),
     CT_EXC_PARENT: dict[str, str] = {
         "BaseException": "",
         "Exception": "BaseException",
         "ArithmeticError": "Exception",
         "ZeroDivisionError": "ArithmeticError",
         "OverflowError": "ArithmeticError",
         "LookupError": "Exception",
         "KeyError": "LookupError",
         "IndexError": "LookupError",
         "ValueError": "Exception",
         "TypeError": "Exception",
         "AttributeError": "Exception",
         "AssertionError": "Exception",
         "StopIteration": "Exception",
         "RuntimeError": "Exception",
         "NotImplementedError": "RuntimeError",
         "RecursionError": "RuntimeError"
     };

def ct_exc(kind: str, msg: str) -> CtRaise {
    return CtRaise(exc=CtExc(kind=kind, args=[mk_str(msg)]));
}

def ct_exc_value(kind: str, arg: CtValue) -> CtRaise {
    return CtRaise(exc=CtExc(kind=kind, args=[arg]));
}

def ct_exc_is(kind: str, ancestor: str) -> bool {
    cur = kind;
    while cur {
        if cur == ancestor {
            return True;
        }
        cur = CT_EXC_PARENT.get(cur, "");
    }
    return False;
}

def mk_bool(b: bool) -> CtBool {
    return CT_TRUE if b else CT_FALSE;
}

def mk_int(v: int) -> CtInt {
    if -CT_SMALL_BOUND < v and v < CT_SMALL_BOUND {
        return CtInt(small=v);
    }
    if v < 0 {
        return CtInt(mag=mag_add_small(mag_from_int(-(v + 1)), 1), neg=True);
    }
    return CtInt(mag=mag_from_int(v));
}

def mk_int_mag(neg: bool, mag: list[int]) -> CtInt {
    if mag_bit_length(mag) <= 62 {
        val = mag_to_int(mag);
        return CtInt(small=-val if neg else val);
    }
    return CtInt(mag=mag, neg=neg);
}

def mk_float(f: float) -> CtFloat {
    return CtFloat(value=f);
}

def mk_str(s: str) -> CtStr {
    return CtStr(value=s);
}

def mk_bytes(b: bytes) -> CtBytes {
    return CtBytes(value=b);
}

def mk_list(items: list[CtValue]) -> CtList {
    return CtList(items=items);
}

def mk_tuple(items: list[CtValue]) -> CtTuple {
    return CtTuple(items=items);
}

def mk_dict -> CtDict {
    return CtDict(keys=[], vals=[], index={});
}

def mk_set(items: list[CtValue], frozen: bool = False) -> CtSet {
    out = CtSet(items=[], index={}, frozen=frozen);
    for item in items {
        set_add(out, item);
    }
    return out;
}

def int_is_big(v: CtInt) -> bool {
    return len(v.mag) > 0;
}

def int_sign_mag(v: CtInt) -> tuple[bool, list[int]] {
    if v.mag {
        return (v.neg, v.mag);
    }
    if v.small < 0 {
        return (True, mag_from_int(-v.small));
    }
    return (False, mag_from_int(v.small));
}

def int_host(v: CtInt) -> int {
    if not v.mag {
        return v.small;
    }
    val = mag_to_int(v.mag);
    return -val if v.neg else val;
}

def int_decimal(v: CtInt) -> str {
    if not v.mag {
        return str(v.small);
    }
    digits = mag_decimal_digits(v.mag);
    if len(digits) > MAX_STR_DIGITS {
        raise ct_exc(
            "ValueError",
            f"Exceeds the limit ({MAX_STR_DIGITS} digits) for integer string conversion; use sys.set_int_max_str_digits() to increase the limit"
        );
    }
    return ("-" if v.neg else "") + digits;
}

def as_ct_int(v: CtValue) -> (CtInt | None) {
    if isinstance(v, CtInt) {
        return v;
    }
    if isinstance(v, CtBool) {
        return CtInt(small=1 if v.value else 0);
    }
    return None;
}

def ct_is_unhashable(v: CtValue) -> bool {
    return _unhashable_name(v) != "";
}

def _unhashable_name(v: CtValue) -> str {
    if isinstance(v, (CtList, CtDict, CtView, CtRecord)) {
        return ct_type_name(v);
    }
    if isinstance(v, CtSet) {
        return "" if v.frozen else "set";
    }
    if isinstance(v, CtTuple) {
        for item in v.items {
            inner = _unhashable_name(item);
            if inner {
                return inner;
            }
        }
    }
    return "";
}

def _role_key(v: CtValue, role: str) -> str {
    inner = _unhashable_name(v);
    if inner {
        raise ct_exc(
            "TypeError",
            f"cannot use '{ct_type_name(v)}' as {role} (unhashable type: '{inner}')"
        );
    }
    return ct_key(v);
}

def dict_key_of(v: CtValue) -> str {
    return _role_key(v, "a dict key");
}

def set_key_of(v: CtValue) -> str {
    return _role_key(v, "a set element");
}

def dict_get(d: CtDict, key: CtValue) -> (CtValue | None) {
    idx = d.index.get(dict_key_of(key));
    if idx is None {
        return None;
    }
    return d.vals[idx];
}

def dict_set(d: CtDict, key: CtValue, val: CtValue) {
    k = dict_key_of(key);
    idx = d.index.get(k);
    if idx is None {
        d.index[k] = len(d.keys);
        d.keys.append(key);
        d.vals.append(val);
    } else {
        d.vals[idx] = val;
    }
}

def dict_delete(d: CtDict, key: CtValue) -> bool {
    k = dict_key_of(key);
    idx = d.index.get(k);
    if idx is None {
        return False;
    }
    d.keys.pop(idx);
    d.vals.pop(idx);
    d.index = {};
    for (i, kk) in enumerate(d.keys) {
        d.index[ct_key(kk)] = i;
    }
    return True;
}

def dict_copy(d: CtDict) -> CtDict {
    return CtDict(keys=d.keys.copy(), vals=d.vals.copy(), index=d.index.copy());
}

def set_has(s: CtSet, item: CtValue) -> bool {
    return set_key_of(item) in s.index;
}

def set_add(s: CtSet, item: CtValue) {
    k = set_key_of(item);
    if k not in s.index {
        s.index[k] = len(s.items);
        s.items.append(item);
    }
}

def set_discard(s: CtSet, item: CtValue) -> bool {
    k = set_key_of(item);
    idx = s.index.get(k);
    if idx is None {
        return False;
    }
    s.items.pop(idx);
    s.index = {};
    for (i, it) in enumerate(s.items) {
        s.index[ct_key(it)] = i;
    }
    return True;
}

def range_len(r: CtRange) -> int {
    if r.step > 0 {
        if r.start >= r.stop {
            return 0;
        }
        return (r.stop - r.start - 1) // r.step + 1;
    }
    if r.start <= r.stop {
        return 0;
    }
    return (r.start - r.stop - 1) // (-r.step) + 1;
}

def ct_type_name(v: CtValue) -> str {
    if isinstance(v, CtNone) {
        return "NoneType";
    }
    if isinstance(v, CtBool) {
        return "bool";
    }
    if isinstance(v, CtInt) {
        return "int";
    }
    if isinstance(v, CtFloat) {
        return "float";
    }
    if isinstance(v, CtStr) {
        return "str";
    }
    if isinstance(v, CtBytes) {
        return "bytes";
    }
    if isinstance(v, CtTuple) {
        return "tuple";
    }
    if isinstance(v, CtList) {
        return "list";
    }
    if isinstance(v, CtDict) {
        return "dict";
    }
    if isinstance(v, CtSet) {
        return "frozenset" if v.frozen else "set";
    }
    if isinstance(v, CtRange) {
        return "range";
    }
    if isinstance(v, CtView) {
        return "dict_" + v.kind;
    }
    if isinstance(v, CtExc) {
        return v.kind;
    }
    if isinstance(v, (CtBuiltin, CtMethod)) {
        return "builtin_function_or_method";
    }
    if isinstance(v, CtModule) {
        return "module";
    }
    if isinstance(v, CtType) {
        return "CtType";
    }
    if isinstance(v, CtFunc) {
        return "CtFunc";
    }
    if isinstance(v, CtBound) {
        return "CtBound";
    }
    if isinstance(v, CtRecord) {
        return "CtRecord";
    }
    if isinstance(v, CtEnumMember) {
        return "CtEnumMember";
    }
    return "CtDeferred";
}

def ct_truthy(v: CtValue) -> bool {
    if isinstance(v, CtNone) {
        return False;
    }
    if isinstance(v, CtBool) {
        return v.value;
    }
    if isinstance(v, CtInt) {
        return len(v.mag) > 0 or v.small != 0;
    }
    if isinstance(v, CtFloat) {
        return v.value != 0.0;
    }
    if isinstance(v, CtStr) {
        return len(v.value) > 0;
    }
    if isinstance(v, CtBytes) {
        return len(v.value) > 0;
    }
    if isinstance(v, (CtTuple, CtList)) {
        return len(v.items) > 0;
    }
    if isinstance(v, CtDict) {
        return len(v.keys) > 0;
    }
    if isinstance(v, CtSet) {
        return len(v.items) > 0;
    }
    if isinstance(v, CtRange) {
        return range_len(v) > 0;
    }
    if isinstance(v, CtView) {
        return len(v.source.keys) > 0;
    }
    return True;
}

def _float_is_integral(f: float) -> bool {
    if f != f or f - f != 0.0 {
        return False;
    }
    if abs(f) >= 4503599627370496.0 {
        return True;
    }
    return float(int(f)) == f;
}

def _len_prefixed(s: str) -> str {
    return str(len(s)) + ":" + s;
}

def ct_key(v: CtValue) -> str {
    if isinstance(v, CtNone) {
        return "N";
    }
    if isinstance(v, CtBool) {
        return "i1" if v.value else "i0";
    }
    if isinstance(v, CtInt) {
        if not v.mag {
            return "i" + str(v.small);
        }
        return "i" + ("-" if v.neg else "") + mag_decimal_digits(v.mag);
    }
    if isinstance(v, CtFloat) {
        f = v.value;
        if f != f {
            return "fnan";
        }
        if _float_is_integral(f) {
            return "i" + float_integral_decimal(f);
        }
        return "f" + repr(f);
    }
    if isinstance(v, CtStr) {
        return "s" + _len_prefixed(v.value);
    }
    if isinstance(v, CtBytes) {
        return "b" + _len_prefixed(v.value.hex());
    }
    if isinstance(v, CtTuple) {
        parts: list[str] = [];
        for item in v.items {
            parts.append(_len_prefixed(ct_key(item)));
        }
        return "t" + "".join(parts);
    }
    if isinstance(v, CtSet) and v.frozen {
        parts2: list[str] = [];
        for item in v.items {
            parts2.append(_len_prefixed(ct_key(item)));
        }
        parts2.sort();
        return "F" + "".join(parts2);
    }
    if isinstance(v, CtRange) {
        n = range_len(v);
        if n == 0 {
            return "R0";
        }
        if n == 1 {
            return f"R1:{v.start}";
        }
        return f"R{n}:{v.start}:{v.step}";
    }
    if isinstance(v, CtType) {
        return "T" + _len_prefixed(v.module) + v.name;
    }
    if isinstance(v, CtEnumMember) {
        return "E" + _len_prefixed(v.enum_name) + v.member;
    }
    if isinstance(v, CtFunc) {
        return "C" + _len_prefixed(v.module) + v.qualname;
    }
    if isinstance(v, CtBuiltin) {
        return "B" + v.name;
    }
    if isinstance(v, CtModule) {
        return "M" + v.name;
    }
    if isinstance(v, (CtExc, CtBound, CtMethod, CtDeferred)) {
        raise CtError(
            f"a '{ct_type_name(
                v
            )}' value cannot be a dict key or set element in comptime code"
        );
    }
    raise ct_exc("TypeError", f"unhashable type: '{_unhashable_name(v)}'");
}

def float_integral_decimal(f: float) -> str {
    if abs(f) < 4611686018427387904.0 {
        return str(int(f));
    }
    return int_decimal(float_to_ct_int(f));
}

def float_to_ct_int(f: float) -> CtInt {
    if f != f {
        raise ct_exc("ValueError", "cannot convert float NaN to integer");
    }
    if f - f != 0.0 {
        raise ct_exc("OverflowError", "cannot convert float infinity to integer");
    }
    if abs(f) < 4611686018427387904.0 {
        return CtInt(small=int(f));
    }
    (m, e) = math.frexp(abs(f));
    mant = int(m * 9007199254740992.0);
    return mk_int_mag(f < 0.0, mag_shl(mag_from_int(mant), e - 53));
}

def ct_same_or_eq(a: CtValue, b: CtValue) -> bool {
    return a is b or ct_eq(a, b);
}

def ct_eq(a: CtValue, b: CtValue) -> bool {
    ai = as_ct_int(a);
    bi = as_ct_int(b);
    if ai is not None and bi is not None {
        if not ai.mag and not bi.mag {
            return ai.small == bi.small;
        }
        return ai.neg == bi.neg and ai.mag == bi.mag;
    }
    if isinstance(a, CtFloat) or isinstance(b, CtFloat) {
        if isinstance(a, CtFloat) and isinstance(b, CtFloat) {
            return a.value == b.value;
        }
        if isinstance(a, CtFloat) and bi is not None {
            return int_float_cmp(bi, a.value) == 0;
        }
        if isinstance(b, CtFloat) and ai is not None {
            return int_float_cmp(ai, b.value) == 0;
        }
        return False;
    }
    if isinstance(a, CtNone) or isinstance(b, CtNone) {
        return isinstance(a, CtNone) and isinstance(b, CtNone);
    }
    if isinstance(a, CtStr) {
        return isinstance(b, CtStr) and a.value == b.value;
    }
    if isinstance(a, CtBytes) {
        return isinstance(b, CtBytes) and a.value == b.value;
    }
    if isinstance(a, CtList) {
        return isinstance(b, CtList) and _items_eq(a.items, b.items);
    }
    if isinstance(a, CtTuple) {
        return isinstance(b, CtTuple) and _items_eq(a.items, b.items);
    }
    if isinstance(a, CtDict) {
        if not isinstance(b, CtDict) or len(a.keys) != len(b.keys) {
            return False;
        }
        for (i, k) in enumerate(a.keys) {
            other = dict_get(b, k);
            if other is None or not ct_same_or_eq(a.vals[i], other) {
                return False;
            }
        }
        return True;
    }
    if isinstance(a, CtSet) {
        if not isinstance(b, CtSet) or len(a.items) != len(b.items) {
            return False;
        }
        for item in a.items {
            if not set_has(b, item) {
                return False;
            }
        }
        return True;
    }
    if isinstance(a, CtRange) {
        if not isinstance(b, CtRange) {
            return False;
        }
        n = range_len(a);
        if n != range_len(b) {
            return False;
        }
        if n == 0 {
            return True;
        }
        if a.start != b.start {
            return False;
        }
        return n == 1 or a.step == b.step;
    }
    if isinstance(a, CtView) {
        if not isinstance(b, CtView) or a.kind == "values" or b.kind == "values" {
            return a is b;
        }
        return ct_eq(view_items_set(a), view_items_set(b));
    }
    if isinstance(a, CtType) {
        return isinstance(b, CtType) and a.name == b.name and a.module == b.module;
    }
    if isinstance(a, CtEnumMember) {
        return (
            isinstance(b, CtEnumMember)
            and a.enum_name == b.enum_name
            and a.member == b.member
        );
    }
    if isinstance(a, CtFunc) {
        return (
            isinstance(b, CtFunc) and a.qualname == b.qualname and a.module == b.module
        );
    }
    if isinstance(a, CtRecord) {
        if not isinstance(b, CtRecord) or a.class_name != b.class_name {
            return False;
        }
        if len(a.fields) != len(b.fields) {
            return False;
        }
        for (k, av) in a.fields.items() {
            if k not in b.fields or not ct_same_or_eq(av, b.fields[k]) {
                return False;
            }
        }
        return True;
    }
    if isinstance(a, CtBuiltin) {
        return isinstance(b, CtBuiltin) and a.name == b.name;
    }
    if isinstance(a, CtModule) {
        return isinstance(b, CtModule) and a.name == b.name;
    }
    if isinstance(a, CtMethod) {
        return (
            isinstance(b, CtMethod)
            and a.owner == b.owner
            and a.name == b.name
            and a.recv is b.recv
        );
    }
    return a is b;
}

def _items_eq(a: list[CtValue], b: list[CtValue]) -> bool {
    if len(a) != len(b) {
        return False;
    }
    for i in range(len(a)) {
        if not ct_same_or_eq(a[i], b[i]) {
            return False;
        }
    }
    return True;
}

def view_items_set(v: CtView) -> CtSet {
    out = CtSet(items=[], index={}, frozen=False);
    if v.kind == "keys" {
        for k in v.source.keys {
            set_add(out, k);
        }
    } else {
        for (i, k) in enumerate(v.source.keys) {
            set_add(out, mk_tuple([k, v.source.vals[i]]));
        }
    }
    return out;
}

def int_float_cmp(a: CtInt, f: float) -> int {
    if f != f {
        return 2;
    }
    if f - f != 0.0 {
        return -1 if f > 0.0 else 1;
    }
    if not a.mag and abs(a.small) <= 9007199254740992 {
        af = float(a.small);
        if af < f {
            return -1;
        }
        return 1 if af > f else 0;
    }
    fl = float_floor(f);
    fl_int = float_to_ct_int(fl);
    c = int_cmp(a, fl_int);
    if c != 0 {
        return c;
    }
    return 0 if fl == f else -1;
}

def float_floor(f: float) -> float {
    if f != f or f - f != 0.0 or abs(f) >= 4503599627370496.0 {
        return f;
    }
    t = float(int(f));
    if t > f {
        t -= 1.0;
    }
    return t;
}

def float_ceil(f: float) -> float {
    return -float_floor(-f);
}

def int_cmp(a: CtInt, b: CtInt) -> int {
    if not a.mag and not b.mag {
        if a.small < b.small {
            return -1;
        }
        return 1 if a.small > b.small else 0;
    }
    (an, am) = int_sign_mag(a);
    (bn, bm) = int_sign_mag(b);
    if an != bn {
        return -1 if an else 1;
    }
    c = mag_cmp(am, bm);
    return -c if an else c;
}

def bytes_has(data: bytes, byte: int) -> bool {
    for b in data {
        if b == byte {
            return True;
        }
    }
    return False;
}

def bytes_repr(data: bytes) -> str {
    quote = "'";
    if bytes_has(data, 39) and not bytes_has(data, 34) {
        quote = "\"";
    }
    out = "b" + quote;
    hexd = "0123456789abcdef";
    for byte in data {
        if byte == ord(quote) or byte == 92 {
            out += "\\" + chr(byte);
        } elif byte == 9 {
            out += "\\t";
        } elif byte == 10 {
            out += "\\n";
        } elif byte == 13 {
            out += "\\r";
        } elif byte < 32 or byte >= 127 {
            out += "\\x" + hexd[byte >> 4] + hexd[byte & 15];
        } else {
            out += chr(byte);
        }
    }
    return out + quote;
}

def ct_repr(v: CtValue) -> str {
    return _repr_in(v, []);
}

def _seen_in(v: CtValue, seen: list[CtValue]) -> bool {
    for s in seen {
        if s is v {
            return True;
        }
    }
    return False;
}

def _repr_items(items: list[CtValue], seen: list[CtValue]) -> str {
    parts: list[str] = [];
    for item in items {
        parts.append(_repr_in(item, seen));
    }
    return ", ".join(parts);
}

def _repr_in(v: CtValue, seen: list[CtValue]) -> str {
    if isinstance(v, CtNone) {
        return "None";
    }
    if isinstance(v, CtBool) {
        return "True" if v.value else "False";
    }
    if isinstance(v, CtInt) {
        return int_decimal(v);
    }
    if isinstance(v, CtFloat) {
        return repr(v.value);
    }
    if isinstance(v, CtStr) {
        return repr(v.value);
    }
    if isinstance(v, CtBytes) {
        return bytes_repr(v.value);
    }
    if isinstance(v, CtRange) {
        if v.step == 1 {
            return f"range({v.start}, {v.stop})";
        }
        return f"range({v.start}, {v.stop}, {v.step})";
    }
    if isinstance(v, (CtList, CtTuple, CtDict, CtSet, CtView, CtRecord)) {
        if _seen_in(v, seen) {
            if isinstance(v, CtList) {
                return "[...]";
            }
            if isinstance(v, CtDict) {
                return "{...}";
            }
            return "...";
        }
        seen.append(v);
        try {
            return _repr_container(v, seen);
        } finally {
            seen.pop();
        }
    }
    if isinstance(v, CtType) {
        return f"<type {v.name}>";
    }
    if isinstance(v, CtFunc) {
        return f"<function {v.module}.{v.qualname}>";
    }
    if isinstance(v, CtEnumMember) {
        return f"{v.enum_name}.{v.member}";
    }
    if isinstance(v, CtBound) {
        name = v.ability.name_ref.sym_name if v.ability.name_ref else "unnamed";
        return f"<bound method {name} of {_repr_in(v.self_val, seen)}>";
    }
    if isinstance(v, CtBuiltin) {
        return f"<built-in function {v.name}>";
    }
    if isinstance(v, CtMethod) {
        if v.recv is None {
            return f"<method '{v.name}' of '{v.owner}' objects>";
        }
        return f"<built-in method {v.name} of {v.owner} object>";
    }
    if isinstance(v, CtModule) {
        return f"<module '{v.name}' (built-in)>";
    }
    if isinstance(v, CtExc) {
        return v.kind + "(" + _repr_items(v.args, seen) + ")";
    }
    return "<comptime deferred>";
}

def _repr_container(v: CtValue, seen: list[CtValue]) -> str {
    if isinstance(v, CtList) {
        return "[" + _repr_items(v.items, seen) + "]";
    }
    if isinstance(v, CtTuple) {
        if len(v.items) == 1 {
            return "(" + _repr_in(v.items[0], seen) + ",)";
        }
        return "(" + _repr_items(v.items, seen) + ")";
    }
    if isinstance(v, CtDict) {
        parts: list[str] = [];
        for (i, k) in enumerate(v.keys) {
            parts.append(_repr_in(k, seen) + ": " + _repr_in(v.vals[i], seen));
        }
        return "{" + ", ".join(parts) + "}";
    }
    if isinstance(v, CtSet) {
        if not v.items {
            return "frozenset()" if v.frozen else "set()";
        }
        body = "{" + _repr_items(v.items, seen) + "}";
        return f"frozenset({body})" if v.frozen else body;
    }
    if isinstance(v, CtView) {
        src = v.source;
        parts2: list[str] = [];
        for (i, k) in enumerate(src.keys) {
            if v.kind == "keys" {
                parts2.append(_repr_in(k, seen));
            } elif v.kind == "values" {
                parts2.append(_repr_in(src.vals[i], seen));
            } else {
                parts2.append(
                    "(" + _repr_in(k, seen) + ", " + _repr_in(src.vals[i], seen) + ")"
                );
            }
        }
        return f"dict_{v.kind}([" + ", ".join(parts2) + "])";
    }
    if isinstance(v, CtRecord) {
        parts3: list[str] = [];
        for (k, fv) in v.fields.items() {
            parts3.append(f"{k}={_repr_in(fv, seen)}");
        }
        return f"{v.class_name}(" + ", ".join(parts3) + ")";
    }
    return "";
}

def ct_str(v: CtValue) -> str {
    if isinstance(v, CtStr) {
        return v.value;
    }
    if isinstance(v, CtExc) {
        if not v.args {
            return "";
        }
        if len(v.args) == 1 {
            if v.kind == "KeyError" {
                return ct_repr(v.args[0]);
            }
            return ct_str(v.args[0]);
        }
        return ct_repr(mk_tuple(v.args));
    }
    return ct_repr(v);
}

def ascii_escape(text: str) -> str {
    out = "";
    hexd = "0123456789abcdef";
    for ch in text {
        o = ord(ch);
        if o < 128 {
            out += ch;
        } elif o < 256 {
            out += "\\x" + hexd[o >> 4] + hexd[o & 15];
        } elif o < 65536 {
            out += "\\u"
                + hexd[(o >> 12) & 15]
                + hexd[(o >> 8) & 15]
                + hexd[(o >> 4) & 15]
                + hexd[o & 15];
        } else {
            digits = "";
            for shift in [28, 24, 20, 16, 12, 8, 4, 0] {
                digits += hexd[(o >> shift) & 15];
            }
            out += "\\U" + digits;
        }
    }
    return out;
}

def ct_iter(v: CtValue) -> list[CtValue] {
    if isinstance(v, (CtList, CtTuple)) {
        return v.items.copy();
    }
    if isinstance(v, CtStr) {
        out: list[CtValue] = [];
        for ch in v.value {
            out.append(mk_str(ch));
        }
        return out;
    }
    if isinstance(v, CtBytes) {
        out2: list[CtValue] = [];
        for byte in v.value {
            out2.append(CtInt(small=byte));
        }
        return out2;
    }
    if isinstance(v, CtDict) {
        return v.keys.copy();
    }
    if isinstance(v, CtSet) {
        return v.items.copy();
    }
    if isinstance(v, CtRange) {
        out3: list[CtValue] = [];
        cur = v.start;
        for _ in range(range_len(v)) {
            out3.append(mk_int(cur));
            cur += v.step;
        }
        return out3;
    }
    if isinstance(v, CtView) {
        src = v.source;
        if v.kind == "keys" {
            return src.keys.copy();
        }
        if v.kind == "values" {
            return src.vals.copy();
        }
        out4: list[CtValue] = [];
        for (i, k) in enumerate(src.keys) {
            out4.append(mk_tuple([k, src.vals[i]]));
        }
        return out4;
    }
    if isinstance(v, CtDeferred) {
        raise CtDeferredSignal();
    }
    raise ct_exc("TypeError", f"'{ct_type_name(v)}' object is not iterable");
}

def ct_is_iterable(v: CtValue) -> bool {
    return isinstance(
        v, (CtList, CtTuple, CtStr, CtBytes, CtDict, CtSet, CtRange, CtView)
    );
}

def ct_len(v: CtValue) -> int {
    if isinstance(v, (CtList, CtTuple)) {
        return len(v.items);
    }
    if isinstance(v, CtStr) {
        return len(v.value);
    }
    if isinstance(v, CtBytes) {
        return len(v.value);
    }
    if isinstance(v, CtDict) {
        return len(v.keys);
    }
    if isinstance(v, CtSet) {
        return len(v.items);
    }
    if isinstance(v, CtRange) {
        return range_len(v);
    }
    if isinstance(v, CtView) {
        return len(v.source.keys);
    }
    raise ct_exc("TypeError", f"object of type '{ct_type_name(v)}' has no len()");
}

def ct_is_scalar(v: CtValue) -> bool {
    return isinstance(v, (CtNone, CtBool, CtInt, CtFloat, CtStr, CtBytes));
}

def ct_is_materializable(v: CtValue) -> bool {
    if ct_is_scalar(v) {
        return True;
    }
    if isinstance(v, (CtEnumMember, CtType, CtFunc)) {
        return True;
    }
    if isinstance(v, (CtList, CtTuple)) {
        for item in v.items {
            if not ct_is_materializable(item) {
                return False;
            }
        }
        return True;
    }
    if isinstance(v, CtSet) {
        for item in v.items {
            if not ct_is_materializable(item) {
                return False;
            }
        }
        return True;
    }
    if isinstance(v, CtDict) {
        for (i, k) in enumerate(v.keys) {
            if not ct_is_materializable(k) or not ct_is_materializable(v.vals[i]) {
                return False;
            }
        }
        return True;
    }
    if isinstance(v, CtRecord) {
        for item in v.fields.values() {
            if not ct_is_materializable(item) {
                return False;
            }
        }
        return True;
    }
    return False;
}

def ct_host_scalar(v: CtValue) -> (int | float | str | bytes | bool | None) {
    if isinstance(v, CtBool) {
        return v.value;
    }
    if isinstance(v, CtInt) {
        return int_host(v);
    }
    if isinstance(v, CtFloat) {
        return v.value;
    }
    if isinstance(v, CtStr) {
        return v.value;
    }
    if isinstance(v, CtBytes) {
        return v.value;
    }
    return None;
}

def _fnv32(data: bytes, seed: int) -> int {
    h = seed;
    for byte in data {
        h = ((h ^ byte) * 16777619) & 4294967295;
    }
    return h;
}

def ct_mangle(v: CtValue) -> str {
    if isinstance(v, CtBool) {
        return "b1" if v.value else "b0";
    }
    if isinstance(v, CtInt) {
        text = int_decimal(v);
        return "n" + text[1:] if text.startswith("-") else "i" + text;
    }
    if isinstance(v, CtFloat) {
        return "f" + repr(v.value).replace(".", "_").replace("-", "n").replace("+", "");
    }
    if isinstance(v, CtStr) {
        return "s" + "".join([c if c.isalnum() else f"_{ord(c)}_" for c in v.value]);
    }
    if isinstance(v, CtNone) {
        return "N";
    }
    if isinstance(v, CtEnumMember) {
        return f"e{v.enum_name}_{v.member}";
    }
    if isinstance(v, CtType) {
        return f"t{v.name}";
    }
    if isinstance(v, CtFunc) {
        return f"fn{v.qualname}";
    }
    if isinstance(v, (CtList, CtTuple)) {
        return "L" + "_".join([ct_mangle(x) for x in v.items]) + "_";
    }
    data = ct_repr(v).encode("utf-8");
    return "x"
        + format(_fnv32(data, 2166136261), "08x")
        + format(_fnv32(data, 3735928559), "08x");
}
