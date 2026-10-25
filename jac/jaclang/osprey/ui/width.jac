import from unicodedata { east_asian_width, category }


obj Grapheme {
    has text: str = "",
        index: int = 0;
}


def _is_mark(cat: str) -> bool;


def _is_non_printing(cat: str) -> bool;


def _char_east_asian_cols(cp: int) -> int;


def _is_regional_indicator(cp: int) -> bool;


def _is_variation_selector(cp: int) -> bool;


def _is_emojiish(seg: str) -> bool;


def _strip_leading_non_printing(seg: str) -> str;


def _is_zero_width_segment(seg: str) -> bool;


def segment_graphemes(text: str) -> list[Grapheme];


def grapheme_width(seg: str) -> int;


obj AnsiToken {
    has code: str = "",
        length: int = 0;
}


def extract_ansi(text: str, pos: int) -> AnsiToken | None;


def strip_ansi(text: str) -> str;


def _is_printable_ascii(text: str) -> bool;


def display_width(text: str) -> int;


def _simple_char_width(ch: str) -> int;


glob _CHAR_WIDTHS: dict[str, int] = {};


obj TruncatedSpan {
    has text: str = "",
        width: int = 0;
}


def _truncate_plain(text: str, max_width: int) -> TruncatedSpan;


def truncate_text(
    text: str, max_width: int, ellipsis: str = "...", pad: bool = False,
) -> str;


def wrap_text(text: str, width: int) -> list[str];


def wrap_text_joined(text: str, width: int) -> str;


def wrap_words(text: str, width: int) -> list[str];
