def:pub loads(s: str) -> dict[str, any];


glob _FROZEN: int = 0,
     _EXPLICIT: int = 1,
     _I64_MAX: int = 9223372036854775807,
     _DEC_OVF: int = 922337203685477580;


obj TOMLDecodeError(Exception) {
    has msg: str = "",
        doc: str = "",
        pos: int = 0,
        lineno: int = 0,
        colno: int = 0,
        at_eod: bool = False;

    def init(msg: str, doc: str, pos: int);
    def __str__ -> str;
}


obj _TDate {
    has year: int = 0,
        month: int = 0,
        day: int = 0;

    def isoformat -> str;
    def __str__ -> str;
}


obj _TTime {
    has hour: int = 0,
        minute: int = 0,
        second: int = 0,
        microsecond: int = 0;

    def isoformat -> str;
    def __str__ -> str;
}


obj _TDatetime {
    has year: int = 0,
        month: int = 0,
        day: int = 0,
        hour: int = 0,
        minute: int = 0,
        second: int = 0,
        microsecond: int = 0,
        offset_minutes: int = 0,
        has_offset: bool = False;

    def isoformat(sep: str = "T") -> str;
    def __str__ -> str;
}


obj _Flags {
    has m: dict[str, int] = {},
        pk: list[str] = [],
        pf: list[int] = [];

    def init;
    def _join(parts: list[str]) -> str;
    def _is(parts: list[str], flag: int) -> bool;
    def _set_joined(path: str, flag: int, recursive: bool);
    def _set(parts: list[str], flag: int, recursive: bool);
    def _unset_all(parts: list[str]);
    def _add_pending(parts: list[str], flag: int);
    def _finalize_pending;
}


obj _Data {
    has top: dict[str, any] = {};

    def init;
    def _get_or_create_nest(parts: list[str], access_lists: bool) -> dict[str, any];
    def _append_nest_to_list(parts: list[str]);
}


obj _Parser {
    has src: str = "",
        pos: int = 0,
        out_data: _Data = _Data(),
        out_flags: _Flags = _Flags(),
        header: list[str] = [];

    def init(s: str);
    def _cc(p: int) -> int;
    def _at(p: int) -> str;
    def _starts_at(q: str, p: int) -> bool;
    def _err(msg: str, p: int);
    def _skip_ws(p: int) -> int;
    def _skip_ws_nl(p: int) -> int;
    def _skip_comment(p: int) -> int;
    def _skip_array_ws(p: int) -> int;
    def _run -> dict[str, any];
    def _create_dict_rule;
    def _create_list_rule;
    def _key_value_rule;
    def _parse_key_value_pair -> tuple[(list[str], any)];
    def _parse_key -> list[str];
    def _parse_key_part -> str;
    def _parse_value -> any;
    def _parse_array -> any;
    def _parse_inline_table -> any;
    def _parse_literal_str -> str;
    def _scan_ml_literal -> str;
    def _parse_multiline_str(literal: bool) -> str;
    def _parse_basic_str(multiline: bool) -> str;
    def _parse_escape(multiline: bool) -> str;
    def _parse_hex_char(n: int) -> str;
    def _match_time_tail(p: int, with_offset: bool) -> int;
    def _match_datetime(p: int) -> int;
    def _match_localtime(p: int) -> int;
    def _match_digits(j: int) -> int;
    def _match_radix_digits(j: int, kind: int) -> int;
    def _match_dec_float(start: int, j: int) -> int;
    def _match_number(p: int) -> int;
    def _build_datetime(start: int, end: int) -> any;
    def _build_localtime(start: int, end: int) -> any;
    def _build_number(start: int, end: int) -> any;
}


def _is_dig(c: int) -> bool;


def _is_bare(c: int) -> bool;


def _is_key_init(c: int) -> bool;


def _is_hexdig(c: int) -> bool;


def _hexval(c: int) -> int;


def _rad_val(c: int, kind: int) -> int;


def _is_illegal_basic(c: int) -> bool;


def _is_illegal_ml_basic(c: int) -> bool;


def _dig2(s: str, i: int) -> int;


def _dig4(s: str, i: int) -> int;


def _day_valid(year: int, month: int, day: int) -> bool;


def _pad2(n: int) -> str;


def _pad4(n: int) -> str;


def _pad6(n: int) -> str;


def _offset_str(offset_min: int) -> str;


def _char_repr(ch: int) -> str;


def _str_repr(s: str) -> str;


def _char_count(s: str) -> int;


def _hex2(v: int) -> str;


def _hex1(v: int) -> str;


def _fmt_key(parts: list[str]) -> str;


def _all_but_last(parts: list[str]) -> list[str];


def _prefix(parts: list[str], n: int) -> list[str];


def _concat(a: list[str], b: list[str]) -> list[str];


def _strip_underscore(s: str, start: int, end: int) -> str;
