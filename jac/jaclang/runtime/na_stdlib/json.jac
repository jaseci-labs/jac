def:pub loads(s: str) -> any;


def:pub load(fp: File) -> any;


def:pub dumps(
    `obj: any,
    sort_keys: bool = False,
    separators: (tuple[str, str] | None) = None,
    ensure_ascii: bool = True
) -> str;


obj _JsonStyle {
    has sort_keys: bool = False,
        ensure_ascii: bool = True,
        item_sep: str = ", ",
        key_sep: str = ": ";
}


obj _JsonParser {
    has buf: bytes,
        n: int,
        pos: int = 0;

    def _cc -> int;
    def _skip_ws;
    def _parse_value -> any;
    def _parse_string -> str;
    def _hex4 -> int;
    def _hex4_pair -> int;
    def _parse_number -> any;
    def _parse_array -> any;
    def _parse_object -> any;
}


def _is_digit(c: int) -> bool;


def _hex_digit(v: int) -> str;


def _hex4_str(n: int) -> str;


def _dump_plain(ch: int, ensure_ascii: bool) -> bool;


def _dump_str(s: str, ensure_ascii: bool) -> str;


def _dump_float(f_val: float) -> str;


def _dump_items(items: list[any], style: _JsonStyle) -> str;


def _dump_value(value: any, style: _JsonStyle) -> str;
