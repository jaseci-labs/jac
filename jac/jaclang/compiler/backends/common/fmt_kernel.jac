def _jac_fmt_is_align(ch: str) -> bool;

def _jac_fmt_is_digit(ch: str) -> bool;

def _jac_fmt_parse(
    spec: str
) -> tuple[str, str, str, int, int, int, int, str, int, str];

def _jac_fmt_rep(fill: str, count: int) -> str;

def _jac_fmt_pad(body: str, fill: str, align: str, width: int) -> str;

def _jac_fmt_group(digits: str, sep: str, gsize: int) -> str;

def _jac_fmt_has_digit(s: str) -> bool;

def _jac_fmt_all_zero_val(s: str) -> bool;

def _jac_fmt_finish(
    intpart: str,
    rest: str,
    sign_str: str,
    prefix: str,
    fill: str,
    align: str,
    zero: int,
    width: int,
    grouping: str,
    gsize: int
) -> str;

def _jac_fmt_sign_str(neg: bool, sign: str) -> str;

def _jac_fmt_strip_zeros(s: str, keep_one: int) -> str;

def _jac_fmt_float_none_prec(v: float, prec: int) -> str;

def jac_fmt_int(v: int, spec: str) -> str;

def jac_fmt_float(v: float, spec: str) -> str;

def jac_fmt_str(s: str, spec: str) -> str;

def jac_fmt_bool(v: bool, spec: str) -> str;

def _jac_hex_digit(ch: str) -> int;

def _jac_int_digit(ch: str) -> int;

def _jac_int_bad(text: str, base: int);

def jac_int_parse(text: str, base: int) -> int;

def jac_bytes_hex(data: bytes) -> str;

def jac_bytes_fromhex(text: str) -> bytes;

def _jac_bytes_is_space(v: int) -> bool;

def jac_bytes_upper(data: bytes) -> bytes;

def jac_bytes_lower(data: bytes) -> bytes;

def jac_bytes_strip(data: bytes, chars: bytes, has_chars: bool, which: int) -> bytes;

def _jac_bytes_split_ws(data: bytes, maxsplit: int) -> list[bytes];

def jac_bytes_split(
    data: bytes, sep: bytes, has_sep: bool, maxsplit: int
) -> list[bytes];

def jac_bytes_replace(data: bytes, old: bytes, new: bytes, count: int) -> bytes;

def jac_bytes_join(sep: bytes, parts: list[bytes]) -> bytes;
