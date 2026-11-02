"""Number formatting runtime: float repr, format specs, parsing, rounding,
powers and hashing.

Floats are printed from their exact binary value with big-integer digit
generation (Steele and White's free-format algorithm as Burger and Dybvig
state it): mode DTOA_SHORTEST yields the shortest digits that read back to
the same float, DTOA_DIGITS a given number of significant digits and
DTOA_PLACES a given number of digits past the point, both correctly rounded
with ties to even. A big integer is BIG_LIMBS limbs of LIMB_BITS bits, each in
an 8-byte word, enough for every finite double scaled by its power of ten; the
five of them live in a thread-local work block. Every operation stays within
signed 64-bit arithmetic, since native int arithmetic is overflow-checked.

`repr` uses exponent notation when the decimal point falls before the fourth
leading zero or after the sixteenth digit, as Python does. Format specs follow
Python's mini-language for int, float, str and bool; the parsed spec lives in
a thread-local record (SP_* offsets). Errors raise ValueError with Python's
messages.

Hashes match CPython for int and float (reduction modulo 2**61 - 1, -1 maps to
-2) and combine tuple members with CPython's xxHash-based tuple hash; str and
bytes hash with djb2 in text.jac, as the previous native backend did."""
import from c {
    def malloc(n: int) -> int;  def free(p: int) -> None;  def memcpy(
        dst: int, src: int, n: int
    ) -> int;  def strlen(text: int) -> int;  def strtod(text: int, end: int) -> float;  def pow(
        x: float, y: float
    ) -> float;
}

glob BIG_LIMBS: int = 48,
     BIG_BYTES: int = 384,
     LIMB_BITS: int = 28,
     LIMB_MASK: int = 268435455,
     LIMB_BASE: int = 268435456,
     LOG10_2: float = 0.30102999566398114,
     DTOA_SHORTEST: int = 0,
     DTOA_DIGITS: int = 2,
     DTOA_PLACES: int = 3;

glob MANT_MASK: int = 4503599627370495,
     HIDDEN_BIT: int = 4503599627370496,
     ABS_MASK: int = 9223372036854775807,
     WORD_MAX: int = 9223372036854775807,
     SIGN_BIT: int = -9223372036854775807 - 1,
     INF_BITS: int = 9218868437227405312,
     NAN_BITS: int = 9221120237041090560;

glob SP_FILL_AT: int = 0,
     SP_FILL_LEN: int = 8,
     SP_ALIGN: int = 16,
     SP_SIGN: int = 24,
     SP_ALT: int = 32,
     SP_ZERO: int = 40,
     SP_ZC: int = 48,
     SP_WIDTH: int = 56,
     SP_GROUP: int = 64,
     SP_PREC: int = 72,
     SP_TYPE: int = 80,
     SCAN_INT: int = 0,
     SCAN_FRAC: int = 1,
     SCAN_EXP: int = 2;

glob HASH_MODULUS: int = 2305843009213693951,
     LOW60: int = 1152921504606846975,
     LOW32: int = 4294967295,
     LOW16: int = 65535,
     XXPRIME_1: int = -7046029288634856825,
     XXPRIME_2: int = -4417276706812531889,
     XXPRIME_5: int = 2870177450012600261,
     XXPRIME_5_LEN: int = 2870177450013471926;

def:pub __jac_rt_float_repr(v: float) -> ptr[u8];

def:pub __jac_rt_format_int(v: int, spec: ptr[u8], sn: int) -> ptr[u8];

def:pub __jac_rt_format_bool(v: bool, spec: ptr[u8], sn: int) -> ptr[u8];

def:pub __jac_rt_format_float(v: float, spec: ptr[u8], sn: int) -> ptr[u8];

def:pub __jac_rt_format_str(data: ptr[u8], n: int, spec: ptr[u8], sn: int) -> ptr[u8];

def:pub __jac_rt_int_text(v: int, base: int) -> ptr[u8];

def:pub __jac_rt_obj_text(name: ptr[u8], address: int) -> ptr[u8];

def:pub __jac_rt_int_parse(data: ptr[u8], n: int, base: int) -> int;

def:pub __jac_rt_float_parse(data: ptr[u8], n: int) -> float;

def:pub __jac_rt_float_round(v: float, ndigits: int) -> float;

def:pub __jac_rt_float_round_int(v: float) -> int;

def:pub __jac_rt_int_round(v: int, ndigits: int) -> int;

def:pub __jac_rt_int_pow(base: int, exp: int) -> int;

def:pub __jac_rt_float_pow(base: float, exp: float) -> float;

def:pub __jac_rt_int_pow_float(base: int, exp: int) -> float;

def:pub __jac_rt_hash_int(v: int) -> int;

def:pub __jac_rt_hash_float(v: float) -> int;

def:pub __jac_rt_hash_pointer(address: int) -> int;

def:pub __jac_rt_hash_tuple_start -> int;

def:pub __jac_rt_hash_tuple_add(acc: int, lane: int) -> int;

def:pub __jac_rt_hash_tuple_end(acc: int, count: int) -> int;

def _byte(at: int) -> int;

def _big_set(a: int, value: int);

def _big_copy(dst: int, src: int);

def _big_mul_small(a: int, m: int);

def _big_shl(a: int, bits: int);

def _big_pow10(a: int, k: int);

def _big_cmp(a: int, b: int) -> int;

def _big_add(dst: int, a: int, b: int);

def _big_sub(a: int, b: int);

def _big_is_zero(a: int) -> bool;

def _big_digit(r: int, s: int) -> int;

def _round_half(r: int, s: int, t: int, last: int) -> bool;

def _round_up(sb: int) -> bool;

def _dtoa(v: float, mode: int, ndigits: int, sb: int) -> int;

def _sb_text(sb: int, text: ptr[u8]);

def _sb_zeros(sb: int, count: int);

def _sb_exp(sb: int, exp: int, upper: bool);

def _special(sb: int, bits: int, upper: bool) -> bool;

def _repr_into(sb: int, v: float);

def _fixed_into(sb: int, mag: float, prec: int, alt: bool);

def _exp_into(sb: int, mag: float, prec: int, alt: bool, upper: bool);

def _general_into(sb: int, mag: float, prec: int, alt: bool, upper: bool, add_dot: bool);

def _is_align(c: int) -> bool;

def _is_digit(c: int) -> bool;

def _message(head: ptr[u8], text: int, tn: int, kind: ptr[u8]) -> ptr[u8];

def _message_with(head: ptr[u8], c: int, tail: ptr[u8]) -> ptr[u8];

def _spec_parse(spec: int, sn: int, kind: ptr[u8]) -> int;

def _unknown_code(rec: int, kind: ptr[u8]);

def _grouped_len(m: int, group: int, gsize: int) -> int;

def _emit_grouped(sb: int, zeros: int, digits: int, ip: int, group: int, gsize: int);

def _emit_fill(sb: int, fill_at: int, fill_len: int, count: int);

def _finish(rec: int, body: int, ip: int, bn: int, neg: bool, prefix: int, gsize: int) -> ptr[u8];

def _digits_into(sb: int, value: int, base: int, upper: bool);

def _is_space(c: int) -> bool;

def _digit_value(c: int) -> int;

def _bad_literal(text: int, n: int, head: ptr[u8], base: int) -> ptr[u8];

def _word_at(d: int, i: int, j: int, word: ptr[u8]) -> bool;

def _rotl61(x: int, s: int) -> int;

def _ushr(x: int, n: int) -> int;

def _wshl(x: int, n: int) -> int;

def _wadd(a: int, b: int) -> int;

def _wmul(a: int, b: int) -> int;
