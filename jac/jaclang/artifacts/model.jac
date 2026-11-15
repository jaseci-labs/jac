import from enum { StrEnum }

enum ArtifactKind(StrEnum) { ACCELERATOR = "accelerator", CAPABILITY = "capability" }

enum ReleasePolicy(StrEnum) {
    REQUIRED = "required",
    FLOOR = "floor",
    ON_DEMAND = "on-demand"
}

enum Source(StrEnum) {
    SEALED = "sealed",
    CHECKOUT = "checkout",
    KIT = "kit",
    CONFIGURED = "configured",
    CACHE = "cache",
    SYSTEM = "system"
}

class ArtifactUnavailable(RuntimeError) {}

obj Found {
    has source: Source,
        path: str,
        record: dict[str, any] = {};
}

obj Probe {
    has found: (Found | None) = None,
        drift: list[str] = [],
        omitted: bool = False,
        absent: bool = False;

    static def hit(source: Source, path: str, record: dict[str, any]) -> Probe;
    static def stale(drift: list[str]) -> Probe;
    static def missing(why: str = "not built") -> Probe;
    static def by_design -> Probe;
    def describe -> str;
}

obj Resolution {
    has name: str,
        found: (Found | None) = None,
        reason: str = "",
        quiet: bool = False,
        deferred: bool = False;

    def on_floor -> bool;
}

obj Artifact {
    has name: str,
        kind: ArtifactKind,
        release: ReleasePolicy,
        summary: str,
        floor: str = "",
        variant: str = "",
        requires: list[str] = [],
        consumes: list[str] = [],
        hosts: list[str] = [],
        provision: bool = False;

    def disabled -> bool;
    def unavailable_reason -> str;
    def probe_sealed -> (Probe | None);
    def probe_checkout -> Probe abst;
    def probe_kit -> Probe;
    def checkout_path -> str abst;
    def built -> Probe;
    def build(log: Callable[[str], None], force: bool, exact: bool) -> None abst;
    def host_supported -> bool;
    def build_blocker -> str;
    def provide_floor(log: Callable[[str], None]) -> None;
    def floor_present -> bool;
}
