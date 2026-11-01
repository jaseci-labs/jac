def _fill_head(limit: int) -> int;


def _fill_tail(limit: int) -> int;


def _cplen(s: str) -> int;


def _ellipsize(s: str, limit: int) -> str;


def _fill(s: str, limit: int) -> str;


def _dict_keys(d: dict[str, any]) -> list[str];


obj:pub Repr {
    has maxlevel: int = 6,
        maxtuple: int = 6,
        maxlist: int = 6,
        maxdict: int = 4,
        maxset: int = 4,
        maxfrozenset: int = 4,
        maxstring: int = 30,
        maxlong: int = 40,
        maxother: int = 30;

    def _iter(x: list[any], level: int, left: str, right: str, maxiter: int) -> str;
    def repr1(x: any, level: int) -> str;
    def repr(x: any) -> str;
}


glob _AREPR: Repr = Repr();


def:pub repr(x: any) -> str;
