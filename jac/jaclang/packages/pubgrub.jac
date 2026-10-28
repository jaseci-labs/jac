import from enum { StrEnum }

enum CauseKind(StrEnum) {
    ROOT = "root_name",
    DEPENDENCY = "dependency",
    NO_VERSIONS = "no_versions",
    UNAVAILABLE = "unavailable",
    DERIVED = "derived"
}

obj Term {
    has package: str,
        versions: VersionSet,
        positive: bool = True;

    def negate -> Term;
    def satisfies(other: Term) -> bool;
    def is_disjoint(other: Term) -> bool;
    def intersect(other: Term) -> Term;
    def difference(other: Term) -> Term;
    def is_empty -> bool;
    def describe -> str;
}

obj Incompatibility {
    has terms: dict[str, Term],
        kind: CauseKind,
        left: Incompatibility | None = None,
        right: Incompatibility | None = None,
        note: str = "";

    static def of(
        terms: list[Term],
        kind: CauseKind,
        left: Incompatibility | None = None,
        right: Incompatibility | None = None,
        note: str = ""
    ) -> Incompatibility;

    def is_failure(root_name: str) -> bool;
    def describe(root_name: str) -> str;
}

def _subject(t: Term, root_name: str) -> str;

obj Assignment {
    has term: Term,
        level: int,
        cause: Incompatibility | None = None;

    def is_decision -> bool;
}

obj SolveFailure(Exception) {
    has incompatibility: Incompatibility,
        root_name: str;

    def postinit;
}

obj PackageSource {
    def versions(name: str) -> list[Version] abst;
    def dependencies(name: str, version: Version) -> dict[str, Requirement] abst;
    def unavailable_reason(name: str, version: Version) -> str abst;
    def preferred(name: str) -> Version | None abst;
}

obj Solver {
    has source: PackageSource,
        root_name: str,
        root_version: Version,
        incompatibilities: dict[str, list[Incompatibility]] = {},
        assignments: list[Assignment] = [],
        decisions: dict[str, Version] = {},
        level: int = 0,
        _candidates: dict[str, list[Version]] = {},
        _requirements: dict[tuple[str, str], dict[str, Requirement]] = {},
        _universe: dict[str, set[str]] | None = None,
        _namers: dict[str, set[str]] = {},
        _ranges_on: dict[str, list[VersionSet]] = {};

    def solve -> dict[str, Version];
    def _add(incompat: Incompatibility);
    def _accumulated(name: str) -> Term | None;
    def _relation(incompat: Incompatibility) -> tuple[str, Term | None];
    def _propagate(package: str);
    def _derive(term: Term, cause: Incompatibility);
    def _satisfier(incompat: Incompatibility) -> tuple[int, int];
    def _previous_level(incompat: Incompatibility, sat_idx: int) -> int;
    def _resolve_conflict(incompat: Incompatibility) -> Incompatibility;
    def _backtrack(level: int);
    def _candidates_for(name: str) -> list[Version];
    def _dependencies(name: str, version: Version) -> dict[str, Requirement];
    def _granted(name: str) -> bool;
    def _allowed(name: str, term: Term) -> list[Version];
    def _has_prerelease_candidate(name: str, term: Term) -> bool;
    def _universe_edges -> dict[str, set[str]];
    def _downstream(starts: set[str]) -> set[str];
    def _interchangeable(owner: str, v: Version, current: Version) -> bool;
    def _prerelease_gap(name: str, term: Term) -> Incompatibility;
    def _decide -> str | None;
    def _decide_version(name: str, version: Version);
    def _would_satisfy(incompat: Incompatibility, name: str, version: Version) -> bool;
}

def explain(incompat: Incompatibility, root_name: str) -> str;

def solve(
    source: PackageSource,
    root_name: str,
    root_version: Version,
    root_deps: dict[str, Requirement]
) -> dict[str, Version];

obj _RootedSource(PackageSource) {
    has inner: PackageSource,
        root_name: str,
        root_version: Version,
        root_deps: dict[str, Requirement];

    override def versions(name: str) -> list[Version];
    override def dependencies(name: str, version: Version) -> dict[str, Requirement];
    override def unavailable_reason(name: str, version: Version) -> str;
    override def preferred(name: str) -> Version | None;
}
