"""Bytes and bytearray runtime.

A bytes object keeps the previous backend's `jacbytes` layout: from
`__jac_rt_alloc`, its byte length (i64 at +0) followed by the bytes (from +8),
with no drop function. A literal is an immortal global of the same shape. A
bytearray keeps the `List.u8` layout: 24 bytes of len (+0), cap (+8) and a
malloc'd byte array (+16); its drop frees the array.

Functions take a byte range (data, n) where bytes and bytearray behave alike,
so generated code passes either kind's data pointer and length. Codecs are
numbered CODEC_* and error handlers ERRORS_*; decoding and encoding follow
CPython's messages for utf-8, ascii and latin-1."""
import from c {
    def realloc(p: int, n: int) -> int;  def free(p: int) -> None;  def memcpy(
        dst: int, src: int, n: int
    ) -> int;  def memmove(dst: int, src: int, n: int) -> int;  def memcmp(
        a: int, b: int, n: int
    ) -> i32;  def memset(p: int, c: i32, n: int) -> int;  def strlen(text: int) -> int;
}

glob BYTES_LEN: int = 0,
     BYTES_DATA: int = 8,
     LIST_LEN: int = 0,
     LIST_CAP: int = 8,
     LIST_DATA: int = 16,
     LIST_SIZE: int = 24,
     BYTEARRAY_MIN_CAP: int = 16,
     HDR_DTOR_BACK: int = 8,
     HDR_TOTAL: int = 32,
     KIND_REF: int = 4;

glob CODEC_UTF8: int = 0,
     CODEC_ASCII: int = 1,
     CODEC_LATIN1: int = 2,
     ERRORS_STRICT: int = 0,
     ERRORS_REPLACE: int = 1,
     ERRORS_IGNORE: int = 2,
     CASE_UPPER: int = 0,
     CASE_LOWER: int = 1,
     STRIP_BOTH: int = 0,
     STRIP_LEFT: int = 1,
     STRIP_RIGHT: int = 2;

def:pub __jac_rt_bytes_new(data: ptr[u8], n: int) -> int;

def:pub __jac_rt_bytes_zero(n: int) -> int;

def:pub __jac_rt_bytes_from_list(lst: int) -> int;

def:pub __jac_rt_bytes_slice(data: ptr[u8], n: int, start: int, stop: int, step: int, given: int) -> int;

def:pub __jac_rt_bytes_concat(a: ptr[u8], an: int, b: ptr[u8], bn: int) -> int;

def:pub __jac_rt_bytes_repeat(data: ptr[u8], n: int, times: int) -> int;

def:pub __jac_rt_bytes_find(data: ptr[u8], n: int, sub: ptr[u8], sn: int, start: int, stop: int, reverse: bool) -> int;

def:pub __jac_rt_bytes_count(data: ptr[u8], n: int, sub: ptr[u8], sn: int, start: int, stop: int) -> int;

def:pub __jac_rt_bytes_has(data: ptr[u8], n: int, value: int) -> bool;

def:pub __jac_rt_bytes_affix(data: ptr[u8], n: int, x: ptr[u8], xn: int, start: int, stop: int, suffix: bool) -> bool;

def:pub __jac_rt_bytes_decode(data: ptr[u8], n: int, codec: int, errors: int, failure: i32) -> ptr[u8];

def:pub __jac_rt_str_encode(data: ptr[u8], n: int, codec: int, errors: int, failure: i32) -> int;

def:pub __jac_rt_bytes_hex(data: ptr[u8], n: int) -> ptr[u8];

def:pub __jac_rt_bytes_fromhex(data: ptr[u8], n: int) -> int;

def:pub __jac_rt_bytes_case(data: ptr[u8], n: int, mode: int) -> int;

def:pub __jac_rt_bytes_strip(data: ptr[u8], n: int, chars: ptr[u8], cn: int, has_chars: bool, which: int) -> int;

def:pub __jac_rt_bytes_split(data: ptr[u8], n: int, sep: ptr[u8], sn: int, has_sep: bool, maxsplit: int) -> int;

def:pub __jac_rt_bytes_replace(data: ptr[u8], n: int, old: ptr[u8], on: int, repl: ptr[u8], rn: int, count: int) -> int;

def:pub __jac_rt_bytes_join(sep: ptr[u8], sn: int, parts: int) -> int;

def:pub __jac_rt_bytes_repr(data: ptr[u8], n: int) -> ptr[u8];

def:pub __jac_rt_bytearray_new(data: ptr[u8], n: int) -> int;

def:pub __jac_rt_bytearray_push(ba: int, value: int);

def:pub __jac_rt_bytearray_set(ba: int, i: int, value: int);

def:pub __jac_rt_bytearray_extend(ba: int, data: ptr[u8], n: int);

def:pub __jac_rt_bytearray_pop(ba: int, i: int) -> int;

def:pub __jac_rt_bytearray_clear(ba: int);

def _byte(at: int) -> int;

def _is_space(c: int) -> bool;

def _hex_value(c: int) -> int;

def _hex_digit(value: int) -> int;

def _sb_text(sb: int, text: ptr[u8]);

def _from_sb(sb: int) -> int;

def _find(hay: int, lo: int, hi: int, needle: int, nn: int, reverse: bool) -> int;

def _utf8_valid(d: int, n: int, i: int) -> int;

def _decode_error(codec: ptr[u8], byte: int, position: int, reason: ptr[u8]) -> ptr[u8];

def _encode_error(codec: ptr[u8], cp: int, position: int, limit: ptr[u8]) -> ptr[u8];

def _fromhex_error(position: int) -> ptr[u8];

def _in_set(c: int, chars: int, cn: int) -> bool;

def _push_bytes(lst: int, at: int, n: int);

def _bytearray_drop(o: int);

def _bytearray_reserve(ba: int, need: int);
