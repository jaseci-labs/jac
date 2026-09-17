import os;
import from pathlib { Path }
import from jaclang.cache.home { CACHEDIR_TAG, cache_home, ensure_root }
import from jaclang.cache.policy {
    Retention,
    SWEEP_SENTINEL,
    dir_size,
    entries_at,
    maybe_sweep_dir,
    remove_entry,
    sweep_dir,
    touch
}

def _override_root(root_env: str) -> Path | None {
    custom = os.environ.get(root_env, "").strip() if root_env else "";
    return Path(custom).expanduser() if custom else None;
}

impl Bucket.path -> Path {
    custom = _override_root(self.root_env);
    if custom is None {
        return cache_home() / self.relpath;
    }
    rest = self.relpath[len(self.root_prefix):].lstrip("/");
    return custom / rest if rest else custom;
}

impl family_root(prefix: str) -> Path {
    for b in BUCKETS {
        if b.root_prefix == prefix {
            custom = _override_root(b.root_env);
            if custom is not None {
                return custom;
            }
            break;
        }
    }
    return cache_home() / prefix;
}

impl Bucket.is_external -> bool {
    return self.policy.retention == Retention.EXTERNAL;
}

impl Bucket.note_hit(item: Path) -> None {
    self.policy.note_hit(item);
}

impl bucket(name: str) -> Bucket {
    for b in BUCKETS {
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
        for b in BUCKETS
        if not b.is_external()
    ];
}

impl external_buckets -> list[Bucket] {
    return [
        b
        for b in BUCKETS
        if b.is_external()
    ];
}

impl maybe_sweep(name: str, keep: set[str] | None = None, force: bool = False) -> bool {
    b = bucket(name);
    return maybe_sweep_dir(b.path(), b.policy, keep=keep, force=force);
}

def _live_for(live: dict[str, set[str]] | None, name: str) -> set[str] {
    if live is None {
        return set();
    }
    return live.get(name) or set();
}

impl status -> list[BucketStatus] {
    rows: list[BucketStatus] = [];
    for b in BUCKETS {
        p = b.path();
        exists = p.is_dir();
        found = entries_at(p, b.policy) if exists else [];
        rows.append(
            BucketStatus(
                name=b.name,
                path=p,
                exists=exists,
                entries=len(found),
                size_bytes=sum([dir_size(e) for e in found]),
                policy=b.policy.describe(),
                external=b.is_external(),
                summary=b.summary
            )
        );
    }
    return rows;
}

def _claimed(rel: str) -> bool {
    for b in BUCKETS {
        if rel == b.relpath
            or b.relpath.startswith(rel + "/")
            or rel.startswith(b.relpath + "/") {
            return True;
        }
    }
    return False;
}

impl unmanaged -> list[tuple[str, int]] {
    base = cache_home();
    out: list[tuple[str, int]] = [];
    for parent_rel in ["", "toolchains"] {
        parent = base / parent_rel if parent_rel else base;
        try {
            children = sorted(parent.iterdir());
        } except OSError {
            continue;
        }
        for child in children {
            name = child.name;
            if name.startswith(".") or name == CACHEDIR_TAG {
                continue;
            }
            rel = f"{parent_rel}/{name}" if parent_rel else name;
            if _claimed(rel) {
                continue;
            }
            out.append((rel, dir_size(child)));
        }
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
    base = cache_home();
    return [
        base / name
        for name in RETIRED
        if (base / name).exists() or (base / name).is_symlink()
    ];
}

impl gc(
    dry_run: bool = False, live: dict[str, set[str]] | None = None
) -> list[SweepReport] {
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
    for item in entries_at(p, b.policy) {
        rel = item.relative_to(p).as_posix();
        if b.policy.is_kept(rel, item.name, keep) {
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
