import from datetime { date, datetime, time, timedelta, timezone }

obj:pub TOMLDecodeError(ValueError) {
    has msg: str = "",
        doc: str = "",
        pos: int = 0,
        lineno: int = 0,
        colno: int = 0;

    def postinit;
    def __str__ -> str;
}

def:pub loads(s: str) -> dict[str, any];

def:pub load(fp: File) -> dict[str, any];

glob _PATH_SEP: str = "\x1f";

def _join_path(path: str, key: str) -> str;

def _is_bare_key_char(c: str) -> bool;

def _is_digit(c: str) -> bool;

def _is_hex_digit(c: str) -> bool;

def _is_control(c: str, allow_newline: bool) -> bool;

def _digit_value(c: str) -> int;

obj _TomlParser {
    has src: str,
        n: int = 0,
        pos: int = 0,
        doc: dict[str, any] = {},
        current: dict[str, any] = {},
        current_path: str = "",
        explicit: set[str] = set(),
        implicit: set[str] = set(),
        frozen: set[str] = set(),
        section_dotted: set[str] = set(),
        closed: set[str] = set(),
        arrays: set[str] = set();

    def postinit;
    def error(message: str) -> TOMLDecodeError;
    def at(offset: int = 0) -> str;
    def starts(text: str) -> bool;
    def eof -> bool;
    def parse -> dict[str, any];
    def skip_ws;
    def skip_comment;
    def skip_blank;
    def skip_array_ws;
    def end_of_line;
    def parse_key -> list[str];
    def parse_simple_key -> str;
    def parse_table_header;
    def parse_array_table_header;
    def close_section;
    def descend_header(keys: list[str]) -> tuple[dict[str, any], str];
    def descend_dotted(
        table: dict[str, any], path: str, keys: list[str]
    ) -> tuple[dict[str, any], str];

    def parse_key_value(table: dict[str, any], path: str);
    def parse_value(path: str) -> any;
    def parse_basic_string -> str;
    def parse_multiline_basic_string -> str;
    def parse_literal_string -> str;
    def parse_multiline_literal_string -> str;
    def parse_escape -> str;
    def parse_array(path: str) -> list[any];
    def parse_inline_table(path: str) -> dict[str, any];
    def scan_token -> str;
    def parse_number_or_datetime -> any;
    def parse_special_float(sign: str) -> float;
    def parse_integer(token: str) -> int;
    def parse_float(token: str) -> float;
    def check_digits(text: str, allow_hex: bool);
    def looks_like_date -> bool;
    def looks_like_time -> bool;
    def parse_date -> date;
    def parse_time_parts -> tuple[int, int, int, int];
    def parse_offset -> (timezone | None);
    def read_digits(count: int) -> int;
}
