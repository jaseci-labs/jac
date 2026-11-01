def _zeros(n: int) -> list[int];


def _popular_flags(b: str, autojunk: bool) -> list[int];


def _find_longest_match(
    a: str, b: str, alo: int, ahi: int, blo: int, bhi: int, popular: list[int]
) -> list[int];


def _matching_blocks(a: str, b: str, autojunk: bool) -> list[list[int]];


def _block_lt(x: list[int], y: list[int]) -> bool;


def _sort_blocks(blocks: list[list[int]]);


def _ratio(a: str, b: str, autojunk: bool) -> float;


obj:pub Match {
    has a: int = 0,
        b: int = 0,
        size: int = 0;
}


obj:pub SequenceMatcher {
    has a: str = "",
        b: str = "",
        _isjunk: any = None,
        _autojunk: bool = True;

    def init(isjunk: any = None, a: str = "", b: str = "", autojunk: bool = True);
    def set_seq1(a: str);
    def set_seq2(b: str);
    def get_matching_blocks -> list[Match];
    def ratio -> float;
}


def _before(ra: float, wa: str, rb: float, wb: str) -> bool;


def:pub get_close_matches(
    word: str, possibilities: list[str], n: int = 3, cutoff: float = 0.6
) -> list[str];
