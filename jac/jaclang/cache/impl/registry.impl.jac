import os;
import from pathlib { Path }
import from jaclang.cache.home {
    CACHEDIR_TAG,
    cache_home,
    ensure_root,
    ensure_cache_dir
}
import from jaclang.cache.policy {
    CacheEntry,
    EntryKind,
    Retention,
    SWEEP_SENTINEL,
    dir_size,
    scan_entries,
    TemporaryClaim,
    maybe_sweep_dir,
    remove_entry,
    sweep_dir,
    touch
}

def _override_root(root_env: str) -> Path | None {
    custom = os.environ.get(root_env, "").strip() if root_env else "";
    return Path(custom).expanduser() if custom else None;
}

def _resolve_path(relpath: str, root_env: str = "", root_prefix: str = "") -> Path {
    custom = _override_root(root_env);
    if custom is None {
        return cache_home() / relpath;
    }
    rest = relpath[len(root_prefix):].lstrip("/");
    return custom / rest if rest else custom;
}

impl Bucket.path -> Path {
    if self.root_dir {
        return Path(self.root_dir);
    }
    return _resolve_path(self.relpath, self.root_env, self.root_prefix);
}

impl Bucket.ensure -> Path {
    ensure_root();
    p = self.path();
    return ensure_cache_dir(p) if not self.is_external() else p;
}

impl Bucket.is_external -> bool {
    return self.policy.retention == Retention.EXTERNAL;
}

impl Bucket.note_hit(item: Path) -> None {
    self.ensure();
    self.policy.note_hit(item);
}

def _registered(name: str) -> Bucket | None {
    for b in BUCKETS {
        if b.name == name {
            return b;
        }
    }
    return None;
}

impl project_bucket -> Bucket | None {
    import from jaclang.project.config { get_config }
    modules = _registered("jir-modules");
    if modules is None {
        return None;
    }
    try {
        cfg = get_config();
        if cfg is None or not cfg.is_valid() or cfg.project_root is None {
            return None;
        }
        cache_dir = cfg.get_cache_dir();
    } except Exception {
        return None;
    }
    return Bucket(
        name="project",
        relpath="",
        policy=modules.policy,
        summary="this project's compiled modules (<project>/.jac/cache)",
        root_dir=str(cache_dir)
    );
}

impl all_buckets -> list[Bucket] {
    found = list(BUCKETS);
    local = project_bucket();
    if local is not None {
        found.append(local);
    }
    return found;
}

impl bucket(name: str) -> Bucket {
    for b in all_buckets() {
        if b.name == name {
            return b;
        }
    }
    raise KeyError(
        f"unknown cache bucket {name!r}; `jac cache status` lists the registered ones"
    );
}

impl managed_buckets -> list[Bucket] {
    return [
        b
        for b in all_buckets()
        if not b.is_external()
    ];
}

impl external_buckets -> list[Bucket] {
    return [
        b
        for b in all_buckets()
        if b.is_external()
    ];
}

impl maybe_sweep(name: str, keep: set[str] | None = None, force: bool = False) -> bool {
    b = bucket(name);
    return maybe_sweep_dir(b.ensure(), b.policy, keep=keep, force=force);
}

def _live_for(live: dict[str, set[str]] | None, name: str) -> set[str] {
    if live is None {
        return set();
    }
    return live.get(name) or set();
}

def _entries(b: Bucket) -> list[CacheEntry] {
    return scan_entries(
        b.path(),
        b.policy,
        exclude={
            str(other.path())
            for other in all_buckets()
            if other.name != b.name
        }
    );
}

impl status -> list[BucketStatus] {
    rows: list[BucketStatus] = [];
    for b in all_buckets() {
        p = b.path();
        exists = p.is_dir();
        found = [
            e
            for e in _entries(b)
            if e.kind != EntryKind.UNKNOWN
        ]
            if exists
            else [];
        rows.append(
            BucketStatus(
                name=b.name,
                path=p,
                exists=exists,
                entries=len(
                    [
                        e
                        for e in found
                        if e.kind != EntryKind.METADATA
                    ]
                ),
                size_bytes=sum([dir_size(e.path) for e in found]),
                policy=b.policy.describe(),
                external=b.is_external(),
                summary=b.summary
            )
        );
    }
    return rows;
}

def _unmanaged_children(parent: Path, owned: set[str], out: set[str]) {
    try {
        children: list[Path] = sorted(parent.iterdir());
    } except OSError {
        return;
    }
    for child in children {
        path = str(child);
        if path in owned or child.name in [CACHEDIR_TAG, SWEEP_SENTINEL] {
            continue;
        }
        if not child.is_symlink()
            and any([p.startswith(path + os.sep) for p in owned]) {
            _unmanaged_children(child, owned, out);
        } else {
            out.add(path);
        }
    }
}

impl unmanaged -> list[tuple[str, int]] {
    base = cache_home();
    roots: set[str] = {str(base)};

    owned: set[str] = {str(b.path()) for b in BUCKETS};
    paths: set[str] = set();
    for b in BUCKETS {
        custom = _override_root(b.root_env);
        if custom is not None {
            roots.add(str(custom));
        }
        for candidate in _entries(b) {
            if candidate.kind == EntryKind.UNKNOWN {
                paths.add(str(candidate.path));
            }
        }
    }
    for location in roots {
        if location not in owned {
            _unmanaged_children(Path(location), owned, paths);
        }
    }
    out: list[tuple[str, int]] = [];
    for path in sorted(paths) {
        p = Path(path);
        label = p.relative_to(base).as_posix() if p.is_relative_to(base) else path;
        out.append((label, dir_size(p)));
    }
    return out;
}

def _reclaim_into(result: PurgeReport, path: Path, label: str, dry_run: bool) {
    if dry_run {
        result.removed.append(label);
        result.reclaimed_bytes += dir_size(path);
        return;
    }
    (ok, size, err) = remove_entry(path);
    if ok {
        result.removed.append(label);
        result.reclaimed_bytes += size;
    } else {
        result.errors.append(err);
    }
}

def _retired_dirs -> list[Path] {
    paths: set[Path] = set();
    for rel in RETIRED {
        paths.add(cache_home() / rel);
        for b in BUCKETS {
            if b.root_prefix and rel.startswith(b.root_prefix + "/") {
                paths.add(_resolve_path(rel, b.root_env, b.root_prefix));
            }
        }
    }
    found: list[Path] = [];
    for p in paths {
        if any([b.path().is_relative_to(p) for b in BUCKETS]) {
            continue;
        }
        if p.exists() or p.is_symlink() {
            found.append(p);
        }
    }
    found.sort();
    return found;
}

impl gc(
    dry_run: bool = False, live: dict[str, set[str]] | None = None
) -> list[SweepReport] {
    if not dry_run {
        ensure_root();
    }
    reports: list[SweepReport] = [];
    for b in managed_buckets() {
        p = b.path();
        if not p.is_dir() {
            continue;
        }
        reports.append(
            sweep_dir(
                p,
                b.policy,
                keep=_live_for(live, b.name),
                dry_run=dry_run,
                bucket=b.name
            )
        );
        if not dry_run and (p / SWEEP_SENTINEL).exists() {
            touch(p / SWEEP_SENTINEL);
        }
    }
    for p in _retired_dirs() {
        result = SweepReport(bucket=p.name, base=str(p), dry_run=dry_run);
        purge_report = PurgeReport();
        _reclaim_into(purge_report, p, p.name, dry_run);
        result.removed = purge_report.removed;
        result.reclaimed_bytes = purge_report.reclaimed_bytes;
        result.errors = purge_report.errors;
        reports.append(result);
    }
    return reports;
}

def _purge_bucket(b: Bucket, keep: set[str], dry_run: bool, result: PurgeReport) {
    p = b.path();
    if not p.is_dir() {
        return;
    }
    for candidate in _entries(b) {
        item = candidate.path;
        if candidate.kind not in [EntryKind.STORED, EntryKind.TEMPORARY] {
            continue;
        }
        rel = item.relative_to(p).as_posix();
        if candidate.kind == EntryKind.TEMPORARY {
            with TemporaryClaim(item, b.policy) as claim {
                if claim.reclaimable {
                    _reclaim_into(result, item, f"{b.name}/{rel}", dry_run);
                } else {
                    result.kept.append(f"{b.name}/{rel}");
                }
            }
            continue;
        }
        if candidate.kind == EntryKind.STORED
            and b.policy.is_kept(rel, item.name, keep) {
            result.kept.append(f"{b.name}/{rel}");
            continue;
        }
        _reclaim_into(result, item, f"{b.name}/{rel}", dry_run);
    }
}

impl purge(
    names: list[str] | None = None,
    dry_run: bool = False,
    live: dict[str, set[str]] | None = None
) -> PurgeReport {
    targets = managed_buckets() if names is None else [bucket(n) for n in names];
    for b in targets {
        if b.is_external() {
            raise ValueError(
                f"{b.name} is managed by its own tool ({b.summary}); jac cache purge refuses it"
            );
        }
    }
    result = PurgeReport();
    for b in targets {
        _purge_bucket(b, _live_for(live, b.name), dry_run, result);
    }
    if names is None {
        for p in _retired_dirs() {
            _reclaim_into(result, p, p.name, dry_run);
        }
    }
    if not dry_run {
        ensure_root();
    }
    return result;
}
