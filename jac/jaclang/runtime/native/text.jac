"""Text runtime: a byte builder, code point indexing over UTF-8 with the
per-thread cursor cache, and the str methods.

A str is the `JacStr` descriptor's parts: the owning object, the first
byte (data) and the byte length. Every function here takes those parts and
returns a fresh string (`ptr[u8]`, owned by the caller), so a result never
aliases its input.

Code point positions: an ASCII string (its header tag at -8 has the ASCII bit
and covers exactly the bytes asked about) maps a position to the same byte
offset. Other strings walk the bytes. A heap string of at least
UTF8_CURSOR_MIN_BYTES bytes that is not ASCII keeps a cursor in the calling
thread's cache: a block of 1 + 4 * 8 words reached through the pthread key at
`__jac_utf8_tls_key` (ready once `__jac_utf8_tls_state` is 1). Word 0 is a
clock; each of the four ways holds base, data, len, epoch, total code points
(-1 until counted), the cursor's code point and byte offset, and the clock
value of its last use. A way is valid only while its epoch equals
`__jac_utf8_epoch`; rc.jac's `_utf8_forget` bumps the epoch whenever such a
string is freed and clears the ways that named it, so a reused address never
reads a stale cursor.

A builder is a malloc'd 24-byte record {len, cap, data}, not a refcounted
object: `__jac_rt_sb_finish` turns it into a string and frees it.

Whitespace and line breaks follow Python's str methods (ASCII whitespace with
\\x1c-\\x1f, plus the Unicode spaces), and the case and character-class
methods map ASCII letters only, as the C library does in the C locale."""
import from c {
    def malloc(n: int) -> int;  def realloc(p: int, n: int) -> int;  def free(
        p: int
    ) -> None;  def calloc(n: int, size: int) -> int;  def memcpy(
        dst: int, src: int, n: int
    ) -> int;  def memcmp(a: int, b: int, n: int) -> i32;  def pthread_key_create(
        key: int, dtor: int
    ) -> i32;  def pthread_getspecific(key: int) -> int;  def pthread_setspecific(
        key: int, value: int
    ) -> i32;  def strlen(text: int) -> int;  def fflush(stream: ptr[u8]) -> i32;  def __jac_stdio(
        fd: i32
    ) -> ptr[u8];
}

glob KIND_STR: int = 3,
     SB_LEN: int = 0,
     SB_CAP: int = 8,
     SB_DATA: int = 16,
     SB_SIZE: int = 24,
     SB_MIN_CAP: int = 16,
     STR_TAG_OFF: int = -8,
     STR_LEN_PAYLOAD_MASK: int = 9223372036854775807,
     STR_KEYED_BITS: int = -9223372036854775807,
     LOW32: int = 4294967295,
     HIGH_BIT32: int = 2147483648,
     SPAN32: int = 4294967296,
     STOP_MAX: int = 4611686018427387904;

glob UTF8_CURSOR_MIN_BYTES: int = 64,
     UTF8_CURSOR_WAYS: int = 4,
     UTF8_CURSOR_WORDS: int = 8,
     UTF8_BLOCK_BYTES: int = 264,
     CUR_BASE: int = 0,
     CUR_DATA: int = 8,
     CUR_LEN: int = 16,
     CUR_EPOCH: int = 24,
     CUR_TOTAL: int = 32,
     CUR_K: int = 40,
     CUR_OFF: int = 48,
     CUR_USED: int = 56;

glob CASE_UPPER: int = 0,
     CASE_LOWER: int = 1,
     CASE_SWAP: int = 2,
     CASE_TITLE: int = 3,
     CASE_CAPITALIZE: int = 4;

glob TEST_DIGIT: int = 0,
     TEST_ALPHA: int = 1,
     TEST_SPACE: int = 2,
     TEST_ALNUM: int = 3,
     TEST_UPPER: int = 4,
     TEST_LOWER: int = 5,
     TEST_ASCII: int = 6,
     TEST_IDENTIFIER: int = 7,
     TEST_TITLE: int = 8,
     TEST_PRINTABLE: int = 9;

glob JUST_LEFT: int = 0,
     JUST_RIGHT: int = 1,
     JUST_CENTER: int = 2,
     STRIP_BOTH: int = 0,
     STRIP_LEFT: int = 1,
     STRIP_RIGHT: int = 2;

def:pub __jac_rt_utf8_width(data: ptr[u8], n: int, off: int) -> int;

def:pub __jac_rt_str_cp_offset(owner: ptr[u8], data: ptr[u8], n: int, k: int) -> int;

def:pub __jac_rt_str_cp_total(owner: ptr[u8], data: ptr[u8], n: int) -> int;

def:pub __jac_rt_sb_new(cap: int) -> int;

def:pub __jac_rt_sb_add(sb: int, data: ptr[u8], n: int);

def:pub __jac_rt_sb_byte(sb: int, byte: int);

def:pub __jac_rt_sb_int(sb: int, value: int);

def:pub __jac_rt_sb_len(sb: int) -> int;

def:pub __jac_rt_sb_data(sb: int) -> int;

def:pub __jac_rt_sb_truncate(sb: int, n: int);

def:pub __jac_rt_sb_drop(sb: int);

def:pub __jac_rt_sb_finish(sb: int) -> ptr[u8];

def:pub __jac_rt_str_index(owner: ptr[u8], data: ptr[u8], n: int, i: int) -> ptr[u8];

def:pub __jac_rt_str_slice(owner: ptr[u8], data: ptr[u8], n: int, start: int, stop: int, step: int, given: int) -> ptr[u8];

def:pub __jac_rt_str_find(owner: ptr[u8], data: ptr[u8], n: int, sub: ptr[u8], sn: int, start: int, stop: int, reverse: bool) -> int;

def:pub __jac_rt_str_count(owner: ptr[u8], data: ptr[u8], n: int, sub: ptr[u8], sn: int, start: int, stop: int) -> int;

def:pub __jac_rt_str_contains(data: ptr[u8], n: int, sub: ptr[u8], sn: int) -> bool;

def:pub __jac_rt_str_affix(owner: ptr[u8], data: ptr[u8], n: int, x: ptr[u8], xn: int, start: int, stop: int, suffix: bool) -> bool;

def:pub __jac_rt_str_repeat(data: ptr[u8], n: int, times: int) -> ptr[u8];

def:pub __jac_rt_str_replace(data: ptr[u8], n: int, old: ptr[u8], on: int, repl: ptr[u8], rn: int, count: int) -> ptr[u8];

def:pub __jac_rt_str_case(data: ptr[u8], n: int, mode: int) -> ptr[u8];

def:pub __jac_rt_str_test(data: ptr[u8], n: int, mode: int) -> bool;

def:pub __jac_rt_str_strip(data: ptr[u8], n: int, chars: ptr[u8], cn: int, has_chars: bool, which: int) -> ptr[u8];

def:pub __jac_rt_str_pad(owner: ptr[u8], data: ptr[u8], n: int, width: int, fill: ptr[u8], fn_len: int, mode: int) -> ptr[u8];

def:pub __jac_rt_str_zfill(data: ptr[u8], n: int, width: int) -> ptr[u8];

def:pub __jac_rt_str_split(data: ptr[u8], n: int, sep: ptr[u8], sn: int, has_sep: bool, maxsplit: int, reverse: bool) -> int;

def:pub __jac_rt_str_splitlines(data: ptr[u8], n: int, keep: bool) -> int;

def:pub __jac_rt_str_join(sep: ptr[u8], sn: int, parts: int) -> ptr[u8];

def:pub __jac_rt_str_partition(data: ptr[u8], n: int, sep: ptr[u8], sn: int, reverse: bool) -> int;

def:pub __jac_rt_str_remove_affix(data: ptr[u8], n: int, x: ptr[u8], xn: int, suffix: bool) -> ptr[u8];

def:pub __jac_rt_str_ord(owner: ptr[u8], data: ptr[u8], n: int) -> int;

def:pub __jac_rt_str_chr(cp: int) -> ptr[u8];

def:pub __jac_rt_str_repr(data: ptr[u8], n: int) -> ptr[u8];

def:pub __jac_rt_str_ascii(data: ptr[u8], n: int) -> ptr[u8];

def:pub __jac_rt_hash_bytes(data: ptr[u8], n: int) -> int;

def:pub __jac_rt_flush(fd: int);

def:pub __jac_rt_repr_enter(o: int) -> int;

def:pub __jac_rt_repr_leave(depth: int);

def _byte(at: int) -> int;

def _cont(byte: int) -> bool;

def _width_at(data: int, n: int, off: int) -> int;

def _start_before(data: int, off: int) -> int;

def _decode_at(data: int, n: int, off: int) -> int;

def _count_starts(data: int, lo: int, hi: int) -> int;

def _seek(data: int, n: int, k0: int, off0: int, k: int) -> int;

def _seek_back(data: int, k0: int, off0: int, k: int) -> int;

def _is_ascii(owner: int, data: int, n: int) -> bool;

def _utf8_block_free(block: int);

def _utf8_block -> int;

def _utf8_fill(at: int, base: int, data: int, n: int, epoch: int, tick: int);

def _utf8_entry(owner: int, data: int, n: int) -> int;

def _cp_offset(owner: int, data: int, n: int, k: int) -> int;

def _cp_total(owner: int, data: int, n: int) -> int;

def _sb_reserve(sb: int, extra: int);

def _sb_range(sb: int, at: int, n: int);

def _sb_repeat(sb: int, at: int, n: int, times: int);

def _find(hay: int, lo: int, hi: int, needle: int, nn: int, reverse: bool) -> int;

def _is_upper(byte: int) -> bool;

def _is_lower(byte: int) -> bool;

def _is_digit(byte: int) -> bool;

def _space_width(data: int, n: int, off: int) -> int;

def _line_break_width(data: int, n: int, off: int) -> int;

def _in_chars(data: int, off: int, w: int, chars: int, cn: int) -> bool;

def _push_text(lst: int, data: int, n: int);

def _type_error_length(prefix: ptr[u8], count: int, suffix: ptr[u8]) -> ptr[u8];

def _hex_digit(value: int) -> int;

def _sb_hex(sb: int, value: int, digits: int);

def _escape_cp(sb: int, cp: int, quote: int);

def _shown_raw(cp: int) -> bool;
