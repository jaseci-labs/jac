obj CtFormatSpec {
    has fill: str = " ",
        align: str = "",
        sign: str = "",
        no_neg_0: bool = False,
        alternate: bool = False,
        width: int = -1,
        grouping: str = "",
        group_size: int = 3,
        frac_grouping: str = "",
        precision: int = -1,
        kind: str = "";
}

def _read_int(spec: str, pos: int) -> tuple[int, int];

def parse_format_spec(
    spec: str, owner: str, default_type: str, default_align: str
) -> CtFormatSpec;

def _bad_separator(sep: str, kind: str) -> str;

def _unknown_code(kind: str, owner: str) -> str;

def group_digits(digits: str, min_width: int, sep: str, size: int) -> str;

def _layout_number(
    fs: CtFormatSpec,
    negative: bool,
    prefix: str,
    digits: str,
    remainder: str,
    sep: str,
    group_size: int
) -> str;

def format_int(v: CtInt, spec: str, owner: str) -> str;

def format_str(s: str, spec: str) -> str;

def pad_text(text: str, width: int, align: str, fill: str) -> str;

def format_float(f: float, spec: str) -> str;

def ct_format(v: CtValue, spec: str) -> str;

def ct_convert(v: CtValue, conv: str) -> CtValue;

def _percent_int_digits(
    v: CtInt, conv: str, prec: int, alternate: bool
) -> tuple[bool, str, str];

def _percent_number_arg(v: CtValue, conv: str) -> CtInt;

def ct_percent_format(fmt: str, args: CtValue) -> str;

obj CtFormatState {
    has args: list[CtValue],
        kwargs: dict[str, CtValue],
        auto_idx: int = 0,
        mode: str = "";
}

def ct_str_format(fmt: str, args: list[CtValue], kwargs: dict[str, CtValue]) -> str;

def _str_format(fmt: str, st: CtFormatState, depth: int) -> str;

def _render_field(field: str, st: CtFormatState, depth: int) -> str;

def _field_value(name: str, st: CtFormatState) -> CtValue;

def _positional(st: CtFormatState, idx: int) -> CtValue;

def _format_attr(value: CtValue, attr: str) -> CtValue;

def ct_binary(sym: str, l: CtValue, r: CtValue) -> CtValue;

def ct_inplace(sym: str, cur: CtValue, val: CtValue) -> CtValue;
