import fnmatch;
import os;
import shutil;
import time;
import from pathlib { Path }

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
    if self.keep_match == "fragment" {
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
        for name in filenames {
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

def _is_temp_name(name: str) -> bool {
    return ".tmp." in name or name.endswith(".tmp");
}

def _is_hidden(name: str) -> bool {
    return name.startswith(".") or name.endswith(".lock");
}

impl entries_at(base: Path | str, policy: Policy) -> list[Path] {
    level: list[Path] = [Path(base)];
    for step in range(policy.depth) {
        last = step == policy.depth - 1;
        next_level: list[Path] = [];
        for parent in level {
            try {
                children = sorted(parent.iterdir());
            } except OSError {
                continue;
            }
            for child in children {
                name = child.name;
                if _is_hidden(name) or _is_temp_name(name) {
                    continue;
                }
                if last {
                    if policy.matches(name) {
                        next_level.append(child);
                    }
                } elif child.is_dir() and not child.is_symlink() {
                    next_level.append(child);
                }
            }
        }
        level = next_level;
    }
    return level;
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
    lock = item.with_name(item.name + ".lock");
    try {
        if lock.is_file() {
            lock.unlink();
        }
    } except OSError {}
    _prune_empty_parents(base, item, depth);
}

def _sweep_orphans(base: Path, now: float, dry_run: bool, result: SweepReport) {
    try {
        children = sorted(base.iterdir());
    } except OSError {
        return;
    }
    for child in children {
        if not _is_temp_name(child.name) {
            continue;
        }
        try {
            age = now - child.lstat().st_mtime;
        } except OSError {
            continue;
        }
        if age > TMP_TTL_SECONDS {
            _reclaim(base, child, 1, dry_run, result);
        }
    }
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
    _sweep_orphans(base, stamp_now, dry_run, result);
    ttl = policy.ttl_seconds();
    live: list[tuple[float, Path]] = [];
    doomed: list[Path] = [];
    for item in entries_at(base, policy) {
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
