import re;

glob VERSION_RE: re.Pattern[str] = re.compile(
         r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
         r"(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?"
         r"(?:\+([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$"
     ),
     PARTIAL_RE: re.Pattern[str] = re.compile(
         r"^(\d+|[*xX])(?:\.(\d+|[*xX]))?(?:\.(\d+|[*xX]))?"
         r"(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$"
     ),
     COMPARATOR_RE: re.Pattern[str] = re.compile(r"^(\^|~|>=|<=|>|<|==|=)?\s*(.+)$");

obj SemverError(ValueError) {}

obj Version {
    has major: int,
        minor: int,
        patch: int,
        pre: tuple[int | str, ...] = (),
        build: str = "";

    static def parse(text: str) -> Version;
    static def lowest(major: int, minor: int, patch: int) -> Version;
    def key -> tuple[int, int, int, int, tuple[tuple[int, int, str], ...]];
    def is_prerelease -> bool;
    def release -> Version;
    def bump_major -> Version;
    def bump_minor -> Version;
    def bump_patch -> Version;
    def __str__ -> str;
    def __eq__(other: object) -> bool;
    def __hash__ -> int;
    def __lt__(other: Version) -> bool;
    def __le__(other: Version) -> bool;
    def __gt__(other: Version) -> bool;
    def __ge__(other: Version) -> bool;
}

obj Bound {
    has version: Version | None = None,
        inclusive: bool = False;
}

obj Interval {
    has lo: Bound = Bound(),
        hi: Bound = Bound();

    def contains(v: Version) -> bool;
    def is_empty -> bool;
}

glob NO_KEY: tuple[int, int, int, int, tuple[tuple[int, int, str], ...]] = (
         0,
         0,
         0,
         0,
         ()
     );

def _lo_key(
    b: Bound
) -> tuple[int, tuple[int, int, int, int, tuple[tuple[int, int, str], ...]], int];

def _hi_key(
    b: Bound
) -> tuple[int, tuple[int, int, int, int, tuple[tuple[int, int, str], ...]], int];

def _max_lo(a: Bound, b: Bound) -> Bound;

def _min_hi(a: Bound, b: Bound) -> Bound;

def _touches(left: Interval, right: Interval) -> bool;

obj VersionSet {
    has intervals: list[Interval] = [];

    static def any_version -> VersionSet;
    static def none -> VersionSet;
    static def exact(v: Version) -> VersionSet;
    static def between(lo: Version | None, hi: Version | None) -> VersionSet;
    static def normalized(items: list[Interval]) -> VersionSet;
    def is_empty -> bool;
    def is_any -> bool;
    def contains(v: Version) -> bool;
    def intersect(other: VersionSet) -> VersionSet;
    def union(other: VersionSet) -> VersionSet;
    def complement -> VersionSet;
    def difference(other: VersionSet) -> VersionSet;
    def subset_of(other: VersionSet) -> bool;
    def disjoint(other: VersionSet) -> bool;
    def same_as(other: VersionSet) -> bool;
    def __str__ -> str;
}

def _partial(text: str) -> tuple[list[int | None], tuple[int | str, ...]];

def _floor(parts: list[int | None], pre: tuple[int | str, ...]) -> Version;

def _caret(parts: list[int | None], pre: tuple[int | str, ...]) -> VersionSet;

def _tilde(parts: list[int | None], pre: tuple[int | str, ...]) -> VersionSet;

def _next_after(parts: list[int | None]) -> Version;

def _comparator(op: str, operand: str) -> VersionSet;

obj Requirement {
    has text: str,
        versions: VersionSet,
        names_prerelease: bool = False;

    static def parse(text: str) -> Requirement;
    def matches(v: Version) -> bool;
}

def caret_for(v: Version) -> str;
