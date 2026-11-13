import os;
import from os.path { join, exists, abspath }
import from locale { normalize }

glob _OP_CONST: int = 0,
     _OP_N: int = 1,
     _OP_NOT: int = 2,
     _OP_OR: int = 3,
     _OP_AND: int = 4,
     _OP_EQ: int = 5,
     _OP_NE: int = 6,
     _OP_LT: int = 7,
     _OP_GT: int = 8,
     _OP_LE: int = 9,
     _OP_GE: int = 10,
     _OP_ADD: int = 11,
     _OP_SUB: int = 12,
     _OP_MUL: int = 13,
     _OP_DIV: int = 14,
     _OP_MOD: int = 15,
     _OP_IF: int = 16;


obj _PNode {
    has op: int,
        val: int = 0,
        a: _PNode | None = None,
        b: _PNode | None = None,
        c: _PNode | None = None;
}


obj _Toks {
    has items: list[str],
        i: int = 0;

    def peek -> str;
    def next -> str;
}


def _is_digit(c: str) -> bool;


def _plural_tokens(src: str) -> list[str];


def _binop_prio(tok: str) -> int;


def _binop_code(tok: str) -> int;


def _perror(value: str) -> str;


def _parse_plural(ts: _Toks, priority: int) -> _PNode;


def _peval(nd: _PNode, n: int) -> int;


def c2py_ast(plural: str) -> _PNode;


def plural_index(tree: _PNode, n: int) -> int;


def:pub c2py(plural: str) -> Callable[[int], int];


def _expand_lang(loc: str) -> list[str];


obj:pub NullTranslations {
    has _info: dict[str, str],
        _charset: str,
        _fallback: NullTranslations | None;

    def init;
    def add_fallback(fallback: NullTranslations);
    def gettext(message: str) -> str;
    def ngettext(msgid1: str, msgid2: str, n: int) -> str;
    def pgettext(context: str, message: str) -> str;
    def npgettext(context: str, msgid1: str, msgid2: str, n: int) -> str;
    def info -> dict[str, str];
    def charset -> str;
}


def _u32(buf: bytes, off: int, little: bool) -> int;


def _split_nul(data: bytes) -> list[bytes];


obj:pub GNUTranslations(NullTranslations) {
    has _catalog: dict[str, str],
        _plurals: dict[str, list[str]],
        _plural_ast: _PNode | None;

    def init(data: bytes = b"");
    def _plural(n: int) -> int;
    def _parse_mo(buf: bytes);
    def _read_headers(tmsg: bytes);
    def gettext(message: str) -> str;
    def ngettext(msgid1: str, msgid2: str, n: int) -> str;
    def pgettext(context: str, message: str) -> str;
    def npgettext(context: str, msgid1: str, msgid2: str, n: int) -> str;
}


glob:pub _default_localedir: str = "/usr/share/locale";


def _env_languages -> list[str];


def _nelangs(languages: (list[str] | None)) -> list[str];


def find_all(
    domain: str, localedir: str = "", languages: (list[str] | None) = None
) -> list[str];


def:pub find(
    domain: str, localedir: str = "", languages: (list[str] | None) = None
) -> str | None;


def:pub translation(
    domain: str,
    localedir: str = "",
    languages: (list[str] | None) = None,
    fallback: bool = False
) -> NullTranslations;


obj _Domain {
    has name: str,
        dirs: dict[str, str];

    def init;
}

glob _CUR: _Domain = _Domain();


def:pub textdomain(domain: str = "") -> str;


def:pub bindtextdomain(domain: str, localedir: str = "") -> str;


def _domain_dir(domain: str) -> str;


def:pub dgettext(domain: str, message: str) -> str;


def:pub dngettext(domain: str, msgid1: str, msgid2: str, n: int) -> str;


def:pub dpgettext(domain: str, context: str, message: str) -> str;


def:pub dnpgettext(domain: str, context: str, msgid1: str, msgid2: str, n: int) -> str;


def:pub gettext(message: str) -> str;


def:pub ngettext(msgid1: str, msgid2: str, n: int) -> str;


def:pub pgettext(context: str, message: str) -> str;


def:pub npgettext(context: str, msgid1: str, msgid2: str, n: int) -> str;
