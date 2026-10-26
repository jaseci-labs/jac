import from c { def memchr(s: int, c: i32, n: u64) -> int;  }
import from c { def sched_yield -> i32;  }

glob:pub I: int = 2,
     IGNORECASE: int = 2,
     L: int = 4,
     LOCALE: int = 4,
     M: int = 8,
     MULTILINE: int = 8,
     S: int = 16,
     DOTALL: int = 16,
     U: int = 32,
     UNICODE: int = 32,
     X: int = 64,
     VERBOSE: int = 64,
     A: int = 256,
     ASCII: int = 256,
     T: int = 1,
     TEMPLATE: int = 1;

enum _K: int {
    SEQ = 1,
    ALT = 2,
    CHAR = 3,
    ANY = 4,
    CLASS = 5,
    AT = 6,
    GROUP = 7,
    REP = 8,
    BACKREF = 9,
    LOOK = 10,
    FLAGS = 11
}


enum _AT: int {
    BOS = 1,
    BEG = 2,
    BEGLINE = 3,
    EOS = 4,
    END = 5,
    ENDLINE = 6,
    WB = 7,
    WNB = 8
}


glob _O_MATCH: int = 0,
     _O_CHAR: int = 1,
     _O_CHAR2: int = 2,
     _O_ANY: int = 3,
     _O_ANYALL: int = 4,
     _O_CLASS: int = 5,
     _O_SPLIT: int = 6,
     _O_JMP: int = 7,
     _O_MARK: int = 8,
     _O_JMPNZ: int = 9,
     _O_SAVE: int = 10,
     _O_BOS: int = 11,
     _O_BEGLINE: int = 12,
     _O_END: int = 13,
     _O_ENDLINE: int = 14,
     _O_EOS: int = 15,
     _O_WB: int = 16,
     _O_NWB: int = 17,
     _O_BACKREF: int = 18,
     _O_BACKREFI: int = 19,
     _O_LOOK: int = 20,
     _O_REPG: int = 21,
     _O_REPL: int = 22;

glob _T_SPLIT: int = 1,
     _T_SAVE: int = 2,
     _T_MARK: int = 3,
     _T_REPG: int = 4,
     _T_REPL: int = 5;

glob _MAXCP: int = 1114111;

glob _MAXCACHE: int = 512;

glob _MAXPOS: int = 9223372036854775807;

glob _ESCAPE_SPECIAL: str = "()[]{}?*+-|^$\\.&~# \t\n\r\x0b\x0c";

glob _DIGIT_PRS: list[int] = [48, 57],
     _NDIGIT_PRS: list[int] = [0, 47, 58, 1114111],
     _SPACE_PRS: list[int] = [9, 13, 32, 32],
     _NSPACE_PRS: list[int] = [0, 8, 14, 31, 33, 1114111],
     _WORD_PRS: list[int] = [48, 57, 65, 90, 95, 95, 97, 122],
     _NWORD_PRS: list[int] = [0, 47, 58, 64, 91, 94, 96, 96, 123, 1114111];


def _push_prs(dst: list[int], src: list[int]);


def _in_pairs(pairs: list[int], c: int) -> bool;


def _name_index(names: dict[str, int], nm: str) -> int;


def _num_esc(cps: list[int], i: int, e: int, bp: int) -> tuple[(int, int)];


def _clamp(v: int, n: int) -> int;


obj _Node {
    has kind: _K = _K.SEQ,
        ch: int = 0,
        at: _AT = _AT.BOS,
        lo: int = 0,
        hi: int = -1,
        neg: bool = False,
        greedy: bool = True,
        pairs: list[int] = [],
        kids: list[_Node] = [],
        name: str = "";
}


def _cat(base: int, wide: bool, pos: int) -> int;


obj _Cls {
    has pairs: list[int] = [],
        neg: bool = False,
        wide: bool = False;
}


obj _P {
    has cps: list[int] = [],
        n: int = 0,
        i: int = 0,
        flags: int = 0,
        ngroups: int = 0,
        names: dict[str, int] = {},
        opengroups: list[int] = [],
        depth: int = 0,
        top_items: int = 0;

    def _err(msg: str, pos: int);
    def _skip_verbose;
    def _is_repeat_spec(pos: int) -> bool;
    def _rep_spec(pos: int) -> list[int];
    def _atom -> (_Node | None);
    def _piece -> (_Node | None);
    def _seq -> _Node;
    def _alt -> _Node;
    def _expect_close(open_pos: int);
    def _flagval(c: int) -> int;
    def _group -> (_Node | None);
    def _class_item(pairs: list[int]) -> int;
    def _class -> _Node;
    def _escape_atom -> _Node;
    def _parse -> _Node;
}


obj _Re {
    has prog: list[int] = [],
        cbits: list[int] = [],
        classes: list[_Cls] = [],
        ngroups: int = 0,
        names: dict[str, int] = {},
        nmarks: int = 0,
        flags: int = 0,
        pattern: str = "",
        anchored: bool = False,
        prefix: str = "",
        plen: int = 0,
        pcps: list[int] = [],
        has_fs: bool = False,
        fs: list[int] = [],
        fs_wide: bool = False,
        empty: list[int] = [];
}


obj _FS {
    has bits: list[int] = [],
        wide: bool = False,
        all: bool = False;
}


def _cls_bits(pairs: list[int], neg: bool, icase: bool) -> list[int];


def _cls_wide(pairs: list[int], neg: bool) -> bool;


def _cls_build(pairs: list[int], neg: bool, icase: bool, re: _Re) -> int;


def _cls_wide_has(re: _Re, k: int, c: int) -> bool;


def _item_ok(re: _Re, kind: int, arg: int, c: int) -> bool;


def _emit(re: _Re, op: int, a: int, b: int, c: int, d: int) -> int;


def _single_item(nd: _Node, flags: int, re: _Re) -> tuple[(int, int)];


def _compile_node(nd: _Node, re: _Re, flags: int);


def _fs_add(fs: _FS, c: int);


def _first(nd: _Node, flags: int, fs: _FS) -> bool;


def _analyze(tree: _Node, re: _Re);


obj _St {
    has cps: list[int] = [],
        base: int = 0,
        wide: bool = False,
        n: int = 0,
        slots: list[int] = [],
        marks: list[int] = [],
        stk: list[int] = [],
        sp: int = 0,
        adv_pos: int = -1,
        match_all: bool = False;
}


def _new_st(re: _Re) -> _St;


def _prep(st: _St, string: str, endpos: int);


def _grow(st: _St, need: int) -> int;


def _unwind(st: _St, sp0: int, keep_undo: bool);


def _exec(re: _Re, st: _St, pc0: int, start: int, mode: int) -> int;


def _hit(re: _Re, st: _St, string: str, b0: int, b1: int) -> Match;


def _one(
    re: _Re, st: _St, string: str, pos: int, endpos: int, mode: int
) -> (Match | None);


def _iter(re: _Re, st: _St, string: str, pos: int, endpos: int) -> list[Match];


def _all(re: _Re, st: _St, string: str, pos: int, endpos: int) -> list[str];


def _split(re: _Re, st: _St, string: str, maxsplit: int) -> list[any];


def _subn_core(
    re: _Re, st: _St, rp: _Repl, string: str, count: int
) -> tuple[(str, int)];


obj:pub Match {
    has _re: _Re,
        string: str,
        pos: int,
        endpos: int,
        _s0: int,
        _e0: int,
        _slots: list[int];

    def init(
        _re: _Re, string: str, pos: int, endpos: int, s0: int, e0: int, slots: list[int]
    );

    def _lo(g: int) -> int;
    def _hi(g: int) -> int;
    def _gtext(num: int) -> str;
    def _gnum(i: (int | str)) -> int;
    def group(i: (int | str) = 0) -> any;
    def groups(`default: any = None) -> list[any];
    def groupdict(`default: any = None) -> dict[str, any];
    def start(i: (int | str) = 0) -> int;
    def end(i: (int | str) = 0) -> int;
    def span(i: (int | str) = 0) -> tuple[(int, int)];
    def expand(template: str) -> str;
}


obj _Repl {
    has lits: list[str] = [],
        grps: list[int] = [],
        literal: bool = True;
}


def _compile_repl(template: str, re: _Re) -> _Repl;


def _apply_repl(rp: _Repl, string: str, s0: int, e0: int, slots: list[int]) -> str;


obj:pub Pattern {
    has _re: _Re,
        _st: _St,
        pattern: str = "",
        flags: int = 0,
        groups: int = 0,
        groupindex: dict[str, int] = {},
        _lk: list[int] = [],
        _lock: int = 0;

    def init(pattern: str, flags: int = 0);
    def _acquire -> bool;
    def _release;
    def search(string: str, pos: int = 0, endpos: int = _MAXPOS) -> (Match | None);
    def `match(string: str, pos: int = 0, endpos: int = _MAXPOS) -> (Match | None);
    def fullmatch(string: str, pos: int = 0, endpos: int = _MAXPOS) -> (Match | None);
    def finditer(string: str, pos: int = 0, endpos: int = _MAXPOS) -> list[Match];
    def findall(string: str, pos: int = 0, endpos: int = _MAXPOS) -> list[str];
    def split(string: str, maxsplit: int = 0) -> list[any];
    def _subn(repl: str, string: str, count: int) -> tuple[(str, int)];
    def sub(repl: str, string: str, count: int = 0) -> str;
    def subn(repl: str, string: str, count: int = 0) -> tuple[(str, int)];
}


glob _CACHE: dict[str, Pattern] = {},
     _CACHEF: dict[str, Pattern] = {},
     _CLK: list[int] = [0];


def _cache_lock;


def _cache_unlock;


def _cached(pattern: str, flags: int) -> Pattern;


def _compile_re(pattern: str, flags: int) -> _Re;


def:pub compile(pattern: str, flags: int = 0) -> Pattern;


def:pub search(pattern: str, string: str, flags: int = 0) -> (Match | None);


def:pub `match(pattern: str, string: str, flags: int = 0) -> (Match | None);


def:pub fullmatch(pattern: str, string: str, flags: int = 0) -> (Match | None);


def:pub findall(pattern: str, string: str, flags: int = 0) -> list[str];


def:pub finditer(pattern: str, string: str, flags: int = 0) -> list[Match];


def:pub split(
    pattern: str, string: str, maxsplit: int = 0, flags: int = 0
) -> list[any];


def:pub sub(
    pattern: str, repl: str, string: str, count: int = 0, flags: int = 0
) -> str;


def:pub subn(
    pattern: str, repl: str, string: str, count: int = 0, flags: int = 0
) -> tuple[(str, int)];


def:pub escape(pattern: str) -> str;


def:pub purge;
