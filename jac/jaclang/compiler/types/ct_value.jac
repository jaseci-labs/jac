import math;

class CtNotComptime(Exception) {}

class CtError(Exception) {}

class CtDeferredSignal(Exception) {}

obj CtEnvironment {
    has os: str = "linux",
        arch: str = "";
}

obj CtValue {
    has is_deferred: bool { getter; }

    def __repr__ -> str;
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

    def __str__ -> str;
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

def ct_exc(kind: str, msg: str) -> CtRaise;

def ct_exc_value(kind: str, arg: CtValue) -> CtRaise;

def ct_exc_is(kind: str, ancestor: str) -> bool;

def mk_bool(b: bool) -> CtBool;

def mk_int(v: int) -> CtInt;

def mk_int_mag(neg: bool, mag: list[int]) -> CtInt;

def mk_float(f: float) -> CtFloat;

def mk_str(s: str) -> CtStr;

def mk_bytes(b: bytes) -> CtBytes;

def mk_list(items: list[CtValue]) -> CtList;

def mk_tuple(items: list[CtValue]) -> CtTuple;

def mk_dict -> CtDict;

def mk_set(items: list[CtValue], frozen: bool = False) -> CtSet;

def int_is_big(v: CtInt) -> bool;

def int_sign_mag(v: CtInt) -> tuple[bool, list[int]];

def int_host(v: CtInt) -> int;

def int_wide_bytes(v: CtInt) -> (bytes | None);

def int_decimal(v: CtInt) -> str;

def as_ct_int(v: CtValue) -> (CtInt | None);

def ct_is_unhashable(v: CtValue) -> bool;

def _unhashable_name(v: CtValue) -> str;

def _role_key(v: CtValue, role: str) -> str;

def dict_key_of(v: CtValue) -> str;

def set_key_of(v: CtValue) -> str;

def dict_get(d: CtDict, key: CtValue) -> (CtValue | None);

def dict_set(d: CtDict, key: CtValue, val: CtValue);

def dict_delete(d: CtDict, key: CtValue) -> bool;

def dict_copy(d: CtDict) -> CtDict;

def set_has(s: CtSet, item: CtValue) -> bool;

def set_add(s: CtSet, item: CtValue);

def set_discard(s: CtSet, item: CtValue) -> bool;

def range_len(r: CtRange) -> int;

def ct_type_name(v: CtValue) -> str;

def ct_truthy(v: CtValue) -> bool;

def _float_is_integral(f: float) -> bool;

def _len_prefixed(s: str) -> str;

def ct_key(v: CtValue) -> str;

def float_integral_decimal(f: float) -> str;

def float_to_ct_int(f: float) -> CtInt;

def ct_same_or_eq(a: CtValue, b: CtValue) -> bool;

def ct_eq(a: CtValue, b: CtValue) -> bool;

def _items_eq(a: list[CtValue], b: list[CtValue]) -> bool;

def view_items_set(v: CtView) -> CtSet;

def int_float_cmp(a: CtInt, f: float) -> int;

def float_floor(f: float) -> float;

def float_ceil(f: float) -> float;

def int_cmp(a: CtInt, b: CtInt) -> int;

def bytes_has(data: bytes, byte: int) -> bool;

def bytes_repr(data: bytes) -> str;

def ct_repr(v: CtValue) -> str;

def _seen_in(v: CtValue, seen: list[CtValue]) -> bool;

def _repr_items(items: list[CtValue], seen: list[CtValue]) -> str;

def _repr_in(v: CtValue, seen: list[CtValue]) -> str;

def _repr_container(v: CtValue, seen: list[CtValue]) -> str;

def ct_str(v: CtValue) -> str;

def ascii_escape(text: str) -> str;

def ct_iter(v: CtValue) -> list[CtValue];

def ct_is_iterable(v: CtValue) -> bool;

def ct_len(v: CtValue) -> int;

def ct_is_scalar(v: CtValue) -> bool;

def ct_is_materializable(v: CtValue) -> bool;

def ct_host_scalar(v: CtValue) -> (int | float | str | bytes | bool | None);

def _fnv32(data: bytes, seed: int) -> int;

def ct_mangle(v: CtValue) -> str;
