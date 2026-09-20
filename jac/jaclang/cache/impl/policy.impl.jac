import fnmatch;
import os;
import shutil;
import time;
import from pathlib { Path }
import from jaclang.cache.home { CACHEDIR_TAG }

glob _SWEPT_ROOTS: set[str] = set();

def _env_days(name: str) -> float | None {
    raw = os.environ.get(name, "").strip();
    if not raw {
        return None;
    }
    try {
        return max(0.0, float(raw));
    } except ValueError {
        return None;
    }
}

impl Policy.ttl_seconds -> float {
    days = self.ttl_days;
    generic = _env_days(TTL_ENV);
    if generic is not None {
        days = generic;
    }
    if self.ttl_env {
        specific = _env_days(self.ttl_env);
        if specific is not None {
            days = specific;
        }
    }
    return days * DAY_SECONDS;
}

impl Policy.describe -> str {
    if self.retention == Retention.EXTERNAL {
        return "external: managed by its own tool, reported only";
    }
    if self.retention == Retention.PINNED {
        return "pinned: never collected, jac cache purge removes it";
    }
    ttl = self.ttl_seconds();
    parts: list[str] = [];
    if ttl > 0.0 {
        parts.append(f"unused {ttl / DAY_SECONDS:g} days");
    } else {
        parts.append("no age limit");
    }
    if self.max_entries > 0 {
        parts.append(f"at most {self.max_entries} entries");
    }
    return ", ".join(parts);
}

impl Policy.matches(name: str) -> bool {
    for pat in self.pattern.split("|") {
        if fnmatch.fnmatchcase(name, pat) {
            return True;
        }
    }
    return False;
}

impl Policy.is_kept(rel: str, name: str, keep: set[str]) -> bool {
    if rel in keep or name in keep {
        return True;
    }
    if self.keep_match == KeepMatch.FRAGMENT {
        for key in keep {
            if key and key in name {
                return True;
            }
        }
    }
    return False;
}

impl touch(path: Path | str) -> None {
    try {
        os.utime(str(path), None);
    } except OSError {}
}

impl Policy.note_hit(item: Path) -> None {
    target = item / self.markers[0] if self.markers and item.is_dir() else item;
    try {
        target.touch();
    } except OSError {}
}

impl dir_size(path: Path | str) -> int {
    p = Path(path);
    try {
        st = p.lstat();
    } except OSError {
        return 0;
    }
    if p.is_symlink() or not p.is_dir() {
        return st.st_size;
    }
    total = 0;
    for (dirpath, dirnames, filenames) in os.walk(str(p)) {
        for name in filenames
            + [
                d
                for d in dirnames
                if os.path.islink(os.path.join(dirpath, d))
            ] {
            try {
                total += os.lstat(os.path.join(dirpath, name)).st_size;
            } except OSError {
                continue;
            }
        }
    }
    return total;
}

impl format_bytes(size: int) -> str {
    units = ["B", "KB", "MB", "GB", "TB"];
    value = float(size);
    idx = 0;
    while value >= 1024.0 and idx < len(units) - 1 {
        value /= 1024.0;
        idx += 1;
    }
    if idx == 0 {
        return f"{size} B";
    }
    return f"{value:.1f} {units[idx]}";
}

impl scan_entries(
    base: Path | str, policy: Policy, exclude: set[str] | None = None
) -> list[CacheEntry] {
    level: list[Path] = [Path(base)];
    found: list[CacheEntry] = [];
    excluded = exclude if exclude is not None else set();
    for step in range(policy.depth) {
        last = step == policy.depth - 1;
        temp_patterns = ["*.tmp.*", "*.tmp"] + (policy.temp_patterns if last else []);
        next_level: list[Path] = [];
        for parent in level {
            try {
                children: list[Path] = sorted(parent.iterdir());
            } except OSError {
                continue;
            }
            for child in children {
                if str(child) in excluded {
                    continue;
                }
                name = child.name;
                temporary = any(
                    [fnmatch.fnmatchcase(name, pat) for pat in temp_patterns]
                );
                if temporary {
                    found.append(CacheEntry(child, EntryKind.TEMPORARY));
                } elif name in [SWEEP_SENTINEL, CACHEDIR_TAG]
                    or name.endswith(".lock") {
                    found.append(CacheEntry(child, EntryKind.METADATA));
                } elif not last and child.is_dir() and not child.is_symlink() {
                    next_level.append(child);
                } else {
                    kind = EntryKind.STORED
                        if last and policy.matches(name)
                        else EntryKind.UNKNOWN;
                    found.append(CacheEntry(child, kind));
                }
            }
        }
        level = next_level;
    }
    return found;
}

impl temporary_owner(path: Path) -> WriterState {
    name = path.name;
    owner = "";
    if ".tmp." in name {
        owner = name.split(".tmp.")[-1].split(".")[0];
    } elif name.endswith(".tmp") {
        owner = name.split(".")[-2];
    }
    if not owner.isdecimal() or int(owner) <= 0 {
        return WriterState.UNKNOWN;
    }
    if os.name == "nt" {
        import csv;
        import subprocess;
        try {
            result = subprocess.run(
                ["tasklist", "/FI", f"PID eq {owner}", "/FO", "CSV", "/NH"],
                capture_output=True,
                text=True,
                timeout=5
            );
            if result.returncode != 0 {
                return WriterState.UNKNOWN;
            }
            active = any(
                [
                    len(row) > 1 and row[1] == owner
                    for row in csv.reader(result.stdout.splitlines())
                ]
            );
            return WriterState.ACTIVE if active else WriterState.INACTIVE;
        } except (OSError, subprocess.TimeoutExpired) {
            return WriterState.UNKNOWN;
        }
    }
    try {
        os.kill(int(owner), 0);
        return WriterState.ACTIVE;
    } except ProcessLookupError {
        return WriterState.INACTIVE;
    } except (OSError, OverflowError) {
        return WriterState.UNKNOWN;
    }
}

impl TemporaryClaim.__enter__ -> TemporaryClaim {
    state = temporary_owner(self.path);
    if state != WriterState.UNKNOWN {
        self.reclaimable = state == WriterState.INACTIVE;
        return self;
    }
    if self.policy.temp_lock == TempLock.NONE
        or not any(
            [
                fnmatch.fnmatchcase(self.path.name, pat)
                for pat in self.policy.temp_patterns
            ]
        ) {
        return self;
    }
    try {
        paths: list[Path] = [self.path.with_suffix(".lock")]
            if self.policy.temp_lock == TempLock.SUFFIX
            else sorted(self.path.parent.glob("*.lock"));
        if not paths {
            return self;
        }
        for p in paths {
            lock = FileLock(p);
            if not lock.acquire(create=False) {
                return self;
            }
            self.locks.append(lock);
        }
        self.reclaimable = True;
    } except OSError {}
    return self;
}

impl TemporaryClaim.__exit__(
    _exc_type: object, _exc_value: object, _traceback: object
) {
    for lock in self.locks {
        lock.release();
    }
    self.locks.clear();
    self.reclaimable = False;
}

impl last_use(item: Path, policy: Policy) -> float {
    for marker in policy.markers {
        m = item / marker;
        try {
            if m.is_file() {
                return m.stat().st_mtime;
            }
        } except OSError {
            continue;
        }
    }
    try {
        return item.lstat().st_mtime;
    } except OSError {
        return 0.0;
    }
}

impl remove_entry(path: Path) -> tuple[bool, int, str] {
    size = dir_size(path);
    try {
        if path.is_dir() and not path.is_symlink() {
            shutil.rmtree(str(path), ignore_errors=True);
            if path.exists() {
                return (False, 0, f"could not fully remove {path}");
            }
        } else {
            path.unlink();
        }
    } except OSError as e {
        return (False, 0, f"could not remove {path}: {e}");
    }
    return (True, size, "");
}

def _rel(base: Path, item: Path) -> str {
    try {
        return item.relative_to(base).as_posix();
    } except ValueError {
        return item.name;
    }
}

def _prune_empty_parents(base: Path, item: Path, depth: int) {
    parent = item.parent;
    for step in range(depth - 1) {
        if parent == base {
            return;
        }
        try {
            parent.rmdir();
        } except OSError {
            return;
        }
        parent = parent.parent;
    }
}

def _reclaim(base: Path, item: Path, depth: int, dry_run: bool, result: SweepReport) {
    rel = _rel(base, item);
    if dry_run {
        result.removed.append(rel);
        result.reclaimed_bytes += dir_size(item);
        return;
    }
    (ok, size, err) = remove_entry(item);
    if not ok {
        result.errors.append(err);
        return;
    }
    result.removed.append(rel);
    result.reclaimed_bytes += size;
    _prune_empty_parents(base, item, depth);
}

impl sweep_dir(
    base: Path | str,
    policy: Policy,
    keep: set[str] | None = None,
    now: float = 0.0,
    dry_run: bool = False,
    bucket: str = ""
) -> SweepReport {
    base = Path(base);
    result = SweepReport(bucket=bucket, base=str(base), dry_run=dry_run);
    if policy.retention != Retention.LAST_USE or not base.is_dir() {
        return result;
    }
    stamp_now = now if now > 0.0 else time.time();
    kept_names: set[str] = keep if keep is not None else set();
    ttl = policy.ttl_seconds();
    live: list[tuple[float, Path]] = [];
    doomed: list[Path] = [];
    for candidate in scan_entries(base, policy) {
        item = candidate.path;
        if candidate.kind == EntryKind.TEMPORARY {
            with TemporaryClaim(item, policy) as claim {
                if claim.reclaimable
                    and stamp_now - last_use(item, Policy()) > TMP_TTL_SECONDS {
                    _reclaim(base, item, policy.depth, dry_run, result);
                } else {
                    result.kept += 1;
                }
            }
            continue;
        }
        if candidate.kind != EntryKind.STORED {
            continue;
        }
        rel = _rel(base, item);
        if policy.is_kept(rel, item.name, kept_names) {
            result.kept += 1;
            continue;
        }
        stamp = last_use(item, policy);
        if ttl > 0.0 and stamp_now - stamp > ttl {
            doomed.append(item);
        } else {
            live.append((stamp, item));
        }
    }
    if policy.max_entries > 0 and len(live) > policy.max_entries {
        live.sort();
        overflow = len(live) - policy.max_entries;
        for item in live[:overflow] {
            doomed.append(item[1]);
        }
        live = live[overflow:];
    }
    for item in doomed {
        _reclaim(base, item, policy.depth, dry_run, result);
    }
    result.kept += len(live);
    return result;
}

impl maybe_sweep_dir(
    base: Path | str,
    policy: Policy,
    keep: set[str] | None = None,
    force: bool = False,
    once_per_process: bool = True,
    interval: float = SWEEP_INTERVAL_SECONDS
) -> bool {
    if policy.retention != Retention.LAST_USE {
        return False;
    }
    base = Path(base);
    key = str(base);
    sentinel = base / SWEEP_SENTINEL;
    if not force {
        if once_per_process {
            if key in _SWEPT_ROOTS {
                return False;
            }
            _SWEPT_ROOTS.add(key);
        }
        try {
            if time.time() - sentinel.stat().st_mtime < interval {
                return False;
            }
        } except OSError {}
    }
    try {
        base.mkdir(parents=True, exist_ok=True);
        sentinel.touch();
    } except OSError {
        return False;
    }
    try {
        sweep_dir(base, policy, keep=keep);
    } except Exception {
        return False;
    }
    return True;
}
