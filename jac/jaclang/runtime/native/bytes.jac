import from c {
    def realloc(p: int, n: int) -> int;  def free(p: int) -> None;  def memcpy(
        dst: int, src: int, n: int
    ) -> int;  def memmove(dst: int, src: int, n: int) -> int;  def memcmp(
        a: int, b: int, n: int
    ) -> i32;  def memset(p: int, c: i32, n: int) -> int;  def strlen(
        text: int
    ) -> int;  def malloc(n: int) -> int;  def fopen(
        path: ptr[u8], mode: ptr[u8]
    ) -> int;  def fclose(stream: int) -> i32;  def fread(
        buf: int, size: int, count: int, stream: int
    ) -> int;  def fwrite(buf: int, size: int, count: int, stream: int) -> int;  def fflush(
        stream: int
    ) -> i32;  def fgetc(stream: int) -> i32;
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
     ERRORS_SURROGATEPASS: int = 3,
     ERRORS_BACKSLASH: int = 4,
     ERRORS_SURROGATEESCAPE: int = 5,
     ERRORS_ENCODE_ONLY: int = 6,
     ERRORS_UNKNOWN: int = 7,
     UTF8_BAD_START: int = -1,
     UTF8_BAD_FIRST: int = -2,
     UTF8_BAD_SECOND: int = -3,
     UTF8_BAD_THIRD: int = -4,
     UTF8_TRUNCATED: int = -5,
     CASE_UPPER: int = 0,
     CASE_LOWER: int = 1,
     STRIP_BOTH: int = 0,
     STRIP_LEFT: int = 1,
     STRIP_RIGHT: int = 2;

glob FILE_HANDLE: int = 0,
     FILE_CLOSED: int = 8,
     FILE_PATH: int = 16,
     FILE_MODE: int = 24,
     FILE_SIZE: int = 32,
     FILE_CHUNK: int = 65536;

def:pub __jac_rt_byte_single(value: int) -> int;

def:pub __jac_rt_bytes_from_ints(lst: int, array: bool) -> int;

def:pub __jac_rt_exc_message(data: ptr[u8], n: int) -> ptr[u8];

def:pub __jac_rt_file_open(path: ptr[u8], mode: ptr[u8], binary: bool) -> int;

def:pub __jac_rt_file_read(f: int, binary: bool, line: bool) -> int;

def:pub __jac_rt_file_write(f: int, data: ptr[u8], n: int) -> int;

def:pub __jac_rt_file_close(f: int);

def:pub __jac_rt_file_flush(f: int);

def:pub __jac_rt_file_closed(f: int) -> bool;

def _file_drop(f: ptr[u8]);

def _file_live(f: int) -> int;

def:pub __jac_rt_bytes_new(data: ptr[u8], n: int) -> int;

def:pub __jac_rt_bytes_zero(n: int) -> int;

def:pub __jac_rt_int_from_bytes(data: ptr[u8], n: int, big: bool, signed: bool) -> int;

def:pub __jac_rt_int_to_bytes(value: int, n: int, big: bool, signed: bool) -> int;

def:pub __jac_rt_struct_put(at: ptr[u8], bits: int, size: int, big: bool);

def:pub __jac_rt_bytes_from_list(lst: int) -> int;

def:pub __jac_rt_bytes_slice(
    data: ptr[u8], n: int, start: int, stop: int, step: int, given: int
) -> int;

def:pub __jac_rt_bytes_concat(a: ptr[u8], an: int, b: ptr[u8], bn: int) -> int;

def:pub __jac_rt_bytes_repeat(data: ptr[u8], n: int, times: int) -> int;

def:pub __jac_rt_bytes_find(
    data: ptr[u8], n: int, sub: ptr[u8], sn: int, start: int, stop: int, reverse: bool
) -> int;

def:pub __jac_rt_bytes_count(
    data: ptr[u8], n: int, sub: ptr[u8], sn: int, start: int, stop: int
) -> int;

def:pub __jac_rt_bytes_has(data: ptr[u8], n: int, value: int) -> bool;

def:pub __jac_rt_bytes_affix(
    data: ptr[u8], n: int, x: ptr[u8], xn: int, start: int, stop: int, suffix: bool
) -> bool;

def:pub __jac_rt_bytes_decode(
    data: ptr[u8],
    n: int,
    encoding: ptr[u8],
    errors: ptr[u8],
    failure: i32,
    lookup: i32,
    wrong: i32
) -> ptr[u8];

def:pub __jac_rt_codec_lookup(name: ptr[u8]) -> int;

def:pub __jac_rt_str_encode(
    data: ptr[u8], n: int, codec: int, errors: int, failure: i32
) -> int;

def:pub __jac_rt_bytes_hex(data: ptr[u8], n: int) -> ptr[u8];

def:pub __jac_rt_bytes_fromhex(data: ptr[u8], n: int) -> int;

def:pub __jac_rt_bytes_case(data: ptr[u8], n: int, mode: int) -> int;

def:pub __jac_rt_bytes_strip(
    data: ptr[u8], n: int, chars: ptr[u8], cn: int, has_chars: bool, which: int
) -> int;

def:pub __jac_rt_bytes_split(
    data: ptr[u8], n: int, sep: ptr[u8], sn: int, has_sep: bool, maxsplit: int
) -> int;

def:pub __jac_rt_bytes_replace(
    data: ptr[u8], n: int, old: ptr[u8], on: int, repl: ptr[u8], rn: int, count: int
) -> int;

def:pub __jac_rt_bytes_join(sep: ptr[u8], sn: int, parts: int) -> int;

def:pub __jac_rt_bytes_repr(data: ptr[u8], n: int) -> ptr[u8];

def:pub __jac_rt_bytearray_new(data: ptr[u8], n: int) -> int;

def:pub __jac_rt_bytearray_push(ba: int, value: int);

def:pub __jac_rt_bytearray_set(ba: int, i: int, value: int);

def:pub __jac_rt_bytearray_extend(ba: int, data: ptr[u8], n: int);

def:pub __jac_rt_bytearray_pop(ba: int, i: int) -> int;

def:pub __jac_rt_bytearray_splice(
    ba: int, start: int, stop: int, data: ptr[u8], n: int
);

def:pub __jac_rt_bytearray_clear(ba: int);

def _byte(at: int) -> int;

def _is_space(c: int) -> bool;

def _hex_value(c: int) -> int;

def _hex_digit(value: int) -> int;

def _sb_text(sb: int, text: ptr[u8]);

def _from_sb(sb: int) -> int;

def _find(hay: int, lo: int, hi: int, needle: int, nn: int, reverse: bool) -> int;

def _name_is(d: int, n: int, name: ptr[u8]) -> bool;

def _codec_match(d: int, n: int, modules: bool) -> int;

def _errors_lookup(name: ptr[u8]) -> int;

def _is_cont(c: int) -> bool;

def _utf8_step(d: int, n: int, i: int) -> int;

def _decode_error(
    codec: ptr[u8], d: int, start: int, stop: int, reason: ptr[u8]
) -> ptr[u8];

def _named_error(prefix: ptr[u8], name: ptr[u8], suffix: ptr[u8]) -> ptr[u8];

def _sb_code_point(sb: int, cp: int);

def _encode_error(codec: ptr[u8], cp: int, position: int, limit: ptr[u8]) -> ptr[u8];

def _fromhex_error(position: int) -> ptr[u8];

def _in_set(c: int, chars: int, cn: int) -> bool;

def _push_bytes(lst: int, at: int, n: int);

def _bytearray_drop(o: int);

def _bytearray_reserve(ba: int, need: int);
