import from _repr { repr_str }


glob:pub DEFAULTSECT: str = "DEFAULT",
     MAX_INTERPOLATION_DEPTH: int = 10;

glob _INDENT_MAX: int = 2147483647;


obj _NoFallback {}


glob _NO_FALLBACK: _NoFallback = _NoFallback();


def _pad2(n: int) -> str;


def _is_ws(s: str, at: int) -> bool;


def _starts_at(s: str, sub: str, at: int) -> bool;
def _strict_float(raw: str) -> float;


def _find_from(s: str, sub: str, start: int) -> int;


def _lstrip(s: str) -> str;


def _rstrip(s: str) -> str;


def _strip(s: str) -> str;


def _join_nl(parts: list[str]) -> str;


def _cat(parts: list[str]) -> str;


def _remove_all(s: str, sub: str) -> str;


def _match_keyref(s: str, i: int) -> int;


def _strip_refs(s: str) -> str;


def _split_keepends(s: str) -> list[str];


def _dict_without(d: dict[str, str], key: str) -> dict[str, str];


def _sect_without(d: dict[str, dict[str, str]], key: str) -> dict[str, dict[str, str]];


obj:pub Error(Exception) {}


obj:pub InterpolationError(Error) {}


obj:pub NoSectionError(Error) {
    has section: str;

    def init(section: str);
    def __str__ -> str;
}


obj:pub DuplicateSectionError(Error) {
    has section: str,
        source: str = "",
        lineno: int = 0,
        _has_source: bool = False;

    def init(
        section: str, source: str = "", lineno: int = 0, has_source: bool = False
    );

    def __str__ -> str;
}


obj:pub DuplicateOptionError(Error) {
    has section: str,
        option: str,
        source: str = "",
        lineno: int = 0,
        _has_source: bool = False;

    def init(
        section: str,
        option: str,
        source: str = "",
        lineno: int = 0,
        has_source: bool = False
    );

    def __str__ -> str;
}


obj:pub NoOptionError(Error) {
    has option: str,
        section: str;

    def init(option: str, section: str);
    def __str__ -> str;
}


obj:pub InterpolationMissingOptionError(InterpolationError) {
    has option: str,
        section: str,
        rawval: str,
        reference: str;

    def init(option: str, section: str, rawval: str, reference: str);
    def __str__ -> str;
}


obj:pub InterpolationSyntaxError(InterpolationError) {
    has option: str,
        section: str,
        msg: str;

    def init(option: str, section: str, msg: str);
    def __str__ -> str;
}


obj:pub InterpolationDepthError(InterpolationError) {
    has option: str,
        section: str,
        rawval: str;

    def init(option: str, section: str, rawval: str);
    def __str__ -> str;
}


obj:pub ParsingError(Error) {
    has source: str,
        msg: str = "",
        n_errors: int = 0;

    def init(source: str);
    def append(lineno: int, line: str);
    def __str__ -> str;
}


obj:pub MissingSectionHeaderError(ParsingError) {
    has source: str,
        lineno: int,
        line: str;

    def init(source: str, lineno: int, line: str);
    def __str__ -> str;
}


obj:pub ConfigParser {
    has delimiters: list[str],
        comment_prefixes: list[str],
        inline_comment_prefixes: list[str],
        _sections: dict[str, dict[str, str]],
        _defaults: dict[str, str],
        strict: bool = True,
        empty_lines_in_values: bool = True,
        default_section: str = "DEFAULT",
        interpolation: bool = True;

    def init(
        delimiters: list[str] | None = None,
        comment_prefixes: list[str] | None = None,
        strict: bool = True,
        empty_lines_in_values: bool = True,
        default_section: str = "DEFAULT",
        interpolation: bool = True,
        inline_comment_prefixes: list[str] | None = None,
    );

    def defaults -> dict[str, str];
    def sections -> list[str];
    def has_section(section: str) -> bool;
    def add_section(section: str);
    def options(section: str) -> list[str];
    def has_option(section: str, option: str) -> bool;
    def set(section: str, option: str, value: str);
    def remove_option(section: str, option: str) -> bool;
    def remove_section(section: str) -> bool;
    def get(
        section: str, option: str, raw: bool = False, fallback: any = _NO_FALLBACK
    ) -> any;

    def getint(
        section: str, option: str, raw: bool = False, fallback: any = _NO_FALLBACK
    ) -> any;

    def getfloat(
        section: str, option: str, raw: bool = False, fallback: any = _NO_FALLBACK
    ) -> any;

    def getboolean(
        section: str, option: str, raw: bool = False, fallback: any = _NO_FALLBACK
    ) -> any;

    def items(section: str, raw: bool = False) -> list[tuple[(str, str)]];
    def read_string(s: str, source: str = "<string>");
    def read_file(lines: list[str]);
    def read_dict(dictionary: dict[str, dict[str, str]]);
    def write -> str;
    def _write_section(name: str, opts: dict[str, str], delim: str) -> str;
    def _validate_write_option(option: str);
    def _write_value(value: str) -> str;
    def _before_set(value: str) -> str;
    def _interp_some(
        option: str,
        section: str,
        rawval: str,
        mvals: dict[str, str],
        depth: int,
        acc: list[str],
        topval: str
    );

    def _strip_comments(text: str) -> str;
    def _sect_header(clean: str) -> str;
    def _find_delim(clean: str) -> int;
    def _delim_len(clean: str, pos: int) -> int;
    def _read_lines(lines: list[str], source: str);
}
