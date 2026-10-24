import from ._locale_native {
    loc_categories,
    loc_query,
    loc_set,
    loc_conv_str,
    loc_conv_char,
    loc_codeset,
    loc_strcoll,
    loc_strxfrm
}
import os;

glob:pub CHAR_MAX: int = 127;

glob:pub LC_CTYPE: int = loc_categories()[0],
     LC_NUMERIC: int = loc_categories()[1],
     LC_TIME: int = loc_categories()[2],
     LC_COLLATE: int = loc_categories()[3],
     LC_MONETARY: int = loc_categories()[4],
     LC_MESSAGES: int = loc_categories()[5],
     LC_ALL: int = loc_categories()[6];

glob:pub locale_alias: dict[str, str] = _load_alias(),
     locale_encoding_alias: dict[str, str] = _load_encalias();


obj:pub Error(Exception) {}


def:pub setlocale(category: int, locale: (str | None) = None) -> str;


def:pub getencoding -> str;


def:pub getpreferredencoding(do_setlocale: bool = True) -> str;


def _cs(index: int) -> str;


def _cc(index: int) -> int;


def _cgroup(index: int) -> list[int];


def:pub localeconv -> dict[str, any];


def:pub strcoll(a: str, b: str) -> int;


def:pub strxfrm(s: str) -> str;


def _normalize_encoding(enc: str) -> str;


def _replace_encoding(code: str, encoding: str) -> str;


def _append_modifier(code: str, modifier: str) -> str;


def:pub normalize(localename: str) -> str;


def _parse_localename(localename: str) -> tuple[str | None, str | None];


def _build_localename(language: str = "", encoding: str = "") -> str;


def:pub getlocale(category: int = -1) -> tuple[str | None, str | None];


def:pub getdefaultlocale -> tuple[str | None, str | None];


def _grouping_intervals(grouping: list[int], width: int) -> list[int];


def _is_digit(c: str) -> bool;


def _group(s: str, monetary: bool = False) -> tuple[str, int];


def _strip_padding(s: str, amount: int) -> str;


def:pub localize(string: str, grouping: bool = False, monetary: bool = False) -> str;


def:pub delocalize(string: str) -> str;


def:pub atof(string: str) -> float;


def:pub atoi(string: str) -> int;


def:pub format_string(
    f: str, val: float, grouping: bool = False, monetary: bool = False
) -> str;


def:pub currency(
    val: float, symbol: bool = True, grouping: bool = False, international: bool = False
) -> str;
