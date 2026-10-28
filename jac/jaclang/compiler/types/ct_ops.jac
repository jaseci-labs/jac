import math;

glob CT_POW_BITS_LIMIT: int = 4000000,
     CT_SHIFT_LIMIT: int = 4000000,
     CT_INDEX_MAX: int = 9223372036854775807,
     CT_OP_SYMBOLS: dict[str, str] = {
         "PLUS": "+",
         "MINUS": "-",
         "STAR_MUL": "*",
         "DIV": "/",
         "FLOOR_DIV": "//",
         "MOD": "%",
         "STAR_POW": "**",
         "BW_AND": "&",
         "BW_OR": "|",
         "BW_XOR": "^",
         "LSHIFT": "<<",
         "RSHIFT": ">>",
         "LT": "<",
         "LTE": "<=",
         "GT": ">",
         "GTE": ">="
     };

def ct_symbol(opn: str) -> str;

def int_neg(a: CtInt) -> CtInt;

def int_abs(a: CtInt) -> CtInt;

def int_is_zero(a: CtInt) -> bool;

def int_is_neg(a: CtInt) -> bool;

def _signed_add(an: bool, am: list[int], bn: bool, bm: list[int]) -> CtInt;

def int_add(a: CtInt, b: CtInt) -> CtInt;

def int_sub(a: CtInt, b: CtInt) -> CtInt;

def int_mul(a: CtInt, b: CtInt) -> CtInt;

def int_divmod(a: CtInt, b: CtInt) -> tuple[CtInt, CtInt];

def int_bit_length(a: CtInt) -> int;

def int_small_index(a: CtInt) -> int;

def int_pow(a: CtInt, b: CtInt) -> CtValue;

def int_lshift(a: CtInt, b: CtInt) -> CtInt;

def int_rshift(a: CtInt, b: CtInt) -> CtInt;

def int_invert(a: CtInt) -> CtInt;

def int_bitop(a: CtInt, b: CtInt, op: str) -> CtInt;

def int_to_float(a: CtInt) -> float;

def int_truediv(a: CtInt, b: CtInt) -> float;

def float_divmod(vx: float, wx: float) -> tuple[float, float];

def c_fmod(vx: float, wx: float) -> float;

def float_pow(v: float, w: float) -> CtValue;

def _float_is_odd_int(w: float) -> bool;

def to_float_operand(v: CtValue) -> (float | None);

def _unsupported(sym: str, l: CtValue, r: CtValue) -> CtRaise;

def _repeat_count(n: CtInt) -> int;

def ct_binop(sym: str, l: CtValue, r: CtValue) -> CtValue;

def set_algebra(sym: str, l: CtSet, r: CtSet, frozen: bool) -> CtSet;

def _repeat(seq: CtValue, n: int) -> CtValue;

def _int_binop(sym: str, a: CtInt, b: CtInt, l: CtValue, r: CtValue) -> CtValue;

def _float_binop(sym: str, l: CtValue, r: CtValue) -> CtValue;

def ct_unary(op: str, v: CtValue) -> CtValue;

def _num_cmp(l: CtValue, r: CtValue) -> (int | None);

def _apply_cmp(sym: str, c: int) -> bool;

def ct_order(sym: str, l: CtValue, r: CtValue) -> bool;

def _subset(a: CtSet, b: CtSet) -> bool;

def ct_lt(a: CtValue, b: CtValue) -> bool;

def ct_contains(container: CtValue, item: CtValue) -> bool;

def ct_is(l: CtValue, r: CtValue) -> bool;

def ct_compare(sym: str, l: CtValue, r: CtValue) -> bool;

def _index_of(base: CtValue, key: CtValue, what: str) -> int;

def ct_getitem(base: CtValue, key: CtValue) -> CtValue;

def _slice_bound(v: (CtValue | None)) -> (int | None);

def slice_indices(
    length: int, lo_v: (CtValue | None), hi_v: (CtValue | None), st_v: (CtValue | None)
) -> tuple[int, int, int, int];

def ct_getslice(
    base: CtValue, lo: (CtValue | None), hi: (CtValue | None), st: (CtValue | None)
) -> CtValue;

def ct_setitem(base: CtValue, key: CtValue, val: CtValue);

def ct_int_parse(text: str, base: int) -> (CtInt | None);

def ct_int_literal(text: str) -> CtInt;

def int_to_base_str(a: CtInt, base: int) -> str;

def int_prefixed(a: CtInt, base: int) -> str;

def int_round(a: CtInt, ndigits: int) -> CtInt;

def float_round_to_int(f: float) -> CtInt;

glob HASH_MODULUS: int = 2305843009213693951,
     HASH_BITS: int = 61;

def _hash_rotl(x: int, bits: int) -> int;

def hash_int(a: CtInt) -> int;

def hash_float(f: float) -> int;

glob U64_MASK_MAG: list[int] = [1073741823, 1073741823, 15],
     U64_MOD_MAG: list[int] = [0, 0, 16],
     XXPRIME_1: list[int] = [99338887, 954066630, 9],
     XXPRIME_2: list[int] = [668265295, 181057780, 12],
     XXPRIME_5: list[int] = [374761413, 525577404, 2];

def _u64(m: list[int]) -> list[int];

def _u64_of(v: CtInt) -> list[int];

def _u64_rotl31(m: list[int]) -> list[int];

def hash_tuple(items: list[CtValue]) -> CtInt;

def ct_hash(v: CtValue) -> CtInt;
