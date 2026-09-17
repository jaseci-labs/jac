import from enum { StrEnum }
import from pathlib { Path }

glob SWEEP_SENTINEL: str = ".last-sweep",
     SWEEP_INTERVAL_SECONDS: float = 86400.0,
     TMP_TTL_SECONDS: float = 3600.0,
     TTL_ENV: str = "JAC_CACHE_TTL_DAYS",
     DAY_SECONDS: float = 86400.0;

enum Retention(StrEnum) {
    LAST_USE = "last-use",
    PINNED = "pinned",
    EXTERNAL = "external"
}

obj Policy {
    has retention: Retention = Retention.LAST_USE,
        ttl_days: float = 14.0,
        max_entries: int = 0,
        depth: int = 1,
        pattern: str = "*",
        markers: list[str] = [],
        ttl_env: str = "",
        keep_match: str = "name";

    def ttl_seconds -> float;
    def is_kept(rel: str, name: str, keep: set[str]) -> bool;
    def describe -> str;
    def matches(name: str) -> bool;
    def note_hit(item: Path) -> None;
}

obj SweepReport {
    has bucket: str = "",
        base: str = "",
        dry_run: bool = False,
        removed: list[str] = [],
        reclaimed_bytes: int = 0,
        kept: int = 0,
        errors: list[str] = [];
}

def touch(path: Path | str) -> None;

def dir_size(path: Path | str) -> int;

def format_bytes(size: int) -> str;

def entries_at(base: Path | str, policy: Policy) -> list[Path];

def last_use(item: Path, policy: Policy) -> float;

def remove_entry(path: Path) -> tuple[bool, int, str];

def sweep_dir(
    base: Path | str,
    policy: Policy,
    keep: set[str] | None = None,
    now: float = 0.0,
    dry_run: bool = False,
    bucket: str = ""
) -> SweepReport;

def maybe_sweep_dir(
    base: Path | str,
    policy: Policy,
    keep: set[str] | None = None,
    force: bool = False,
    once_per_process: bool = True,
    interval: float = SWEEP_INTERVAL_SECONDS
) -> bool;
