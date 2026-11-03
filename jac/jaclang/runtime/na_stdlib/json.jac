obj:pub JSONDecodeError(ValueError) {
    has msg: str = "",
        doc: str = "",
        pos: int = 0,
        lineno: int = 1,
        colno: int = 1;

    def init(msg: str, doc: str, pos: int);
    def __str__ -> str;
}


obj:pub JSONDecoder {
    has object_hook: (Callable[[any], any] | None) = None,
        parse_float: (Callable[[any], any] | None) = None,
        parse_int: (Callable[[any], any] | None) = None,
        parse_constant: (Callable[[any], any] | None) = None,
        strict: bool = True,
        object_pairs_hook: (Callable[[any], any] | None) = None;

    def decode(s: str) -> any;
    def raw_decode(s: str, idx: int = 0) -> tuple[any, int];
    def _mkparser(s: str) -> _JsonParser;
}


obj:pub JSONEncoder {
    has skipkeys: bool = False,
        ensure_ascii: bool = True,
        check_circular: bool = True,
        allow_nan: bool = True,
        sort_keys: bool = False,
        indent: (int | str | None) = None,
        separators: (tuple[str, str] | None) = None,
        _default_fn: (Callable[[any], any] | None) = None;

    def init(
        skipkeys: bool = False,
        ensure_ascii: bool = True,
        check_circular: bool = True,
        allow_nan: bool = True,
        sort_keys: bool = False,
        indent: (int | str | None) = None,
        separators: (tuple[str, str] | None) = None,
        `default: (Callable[[any], any] | None) = None
    );

    def `default(o: any) -> any;
    def encode(o: any) -> str;
    def iterencode(o: any) -> list[str];
}


def:pub load(
    fp: File,
    cls: (type | None) = None,
    object_hook: (Callable[[any], any] | None) = None,
    parse_float: (Callable[[any], any] | None) = None,
    parse_int: (Callable[[any], any] | None) = None,
    parse_constant: (Callable[[any], any] | None) = None,
    object_pairs_hook: (Callable[[any], any] | None) = None
) -> any;


def:pub loads(
    s: str,
    cls: (type | None) = None,
    object_hook: (Callable[[any], any] | None) = None,
    parse_float: (Callable[[any], any] | None) = None,
    parse_int: (Callable[[any], any] | None) = None,
    parse_constant: (Callable[[any], any] | None) = None,
    object_pairs_hook: (Callable[[any], any] | None) = None
) -> any;


def:pub dump(
    `obj: any,
    fp: File,
    skipkeys: bool = False,
    ensure_ascii: bool = True,
    check_circular: bool = True,
    allow_nan: bool = True,
    cls: (type | None) = None,
    indent: (int | str | None) = None,
    separators: (tuple[str, str] | None) = None,
    `default: (Callable[[any], any] | None) = None,
    sort_keys: bool = False
);


def:pub dumps(
    `obj: any,
    skipkeys: bool = False,
    ensure_ascii: bool = True,
    check_circular: bool = True,
    allow_nan: bool = True,
    cls: (type | None) = None,
    indent: (int | str | None) = None,
    separators: (tuple[str, str] | None) = None,
    `default: (Callable[[any], any] | None) = None,
    sort_keys: bool = False
) -> str;


obj _JsonStyle {
    has sort_keys: bool = False,
        ensure_ascii: bool = True,
        skipkeys: bool = False,
        check_circular: bool = True,
        allow_nan: bool = True,
        item_sep: str = ", ",
        key_sep: str = ": ",
        indent: (str | None) = None,
        default_fn: (Callable[[any], any] | None) = None;
}


obj _JsonParser {
    has buf: bytes,
        n: int,
        pos: int = 0,
        strict: bool = True,
        object_hook: (Callable[[any], any] | None) = None,
        object_pairs_hook: (Callable[[any], any] | None) = None,
        parse_float: (Callable[[any], any] | None) = None,
        parse_int: (Callable[[any], any] | None) = None,
        parse_constant: (Callable[[any], any] | None) = None;

    def _cc -> int;
    def _skip_ws;
    def _doc -> str;
    def _fail(msg: str, pos: int);
    def _match(w: bytes) -> bool;
    def _parse_value -> any;
    def _parse_scalar -> any;
    def _parse_string -> str;
    def _hex4 -> int;
    def _hex4_pair -> int;
    def _parse_number -> any;
    def _parse_const(txt: str) -> any;
    def _parse_array -> any;
    def _parse_object -> any;
    def _finish_obj(out: dict[str, any], pairs: list[any]) -> any;
}


def _apply_hook(f: Callable[[any], any], v: any) -> any;


def _is_digit(c: int) -> bool;


def _hex_digit(v: int) -> str;


def _hex4_str(n: int) -> str;


def _type_name(v: any) -> str;


def _indent_str(indent: (int | str | None)) -> (str | None);


def _make_style(
    skipkeys: bool,
    ensure_ascii: bool,
    check_circular: bool,
    allow_nan: bool,
    sort_keys: bool,
    indent: (int | str | None),
    separators: (tuple[str, str] | None),
    default_fn: (Callable[[any], any] | None)
) -> _JsonStyle;


def _dump_plain(ch: int, ensure_ascii: bool) -> bool;


def _dump_str(s: str, ensure_ascii: bool) -> str;


def _dump_float(f_val: float, allow_nan: bool) -> str;


def _key_text(k: any, style: _JsonStyle) -> (str | None);


def _dump_items(items: any, style: _JsonStyle, depth: int, seen: list[any]) -> str;


def _dump_dict(
    d: dict[str, any], style: _JsonStyle, depth: int, seen: list[any]
) -> str;


def _dump_value(value: any, style: _JsonStyle, depth: int, seen: list[any]) -> str;
