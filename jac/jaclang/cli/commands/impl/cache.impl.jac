import from enum { StrEnum }
import from jaclang.cli.console { console }
import from jaclang.cache.home { cache_home }
import from jaclang.cache.policy { format_bytes }
import from jaclang.cache.registry { RETIRED, gc, purge, status, unmanaged }


enum CacheAction(StrEnum) { STATUS = "status", GC = "gc", PURGE = "purge" }


def _parse_action(action: str) -> (CacheAction | None) {
    for candidate in CacheAction {
        if candidate.value == action {
            return candidate;
        }
    }
    return None;
}


def _live_keys -> dict[str, set[str]] {
    live: dict[str, set[str]] = {};
    try {
        import from jaclang.dist.fused_binary { running_runtime_entries }
        entries = running_runtime_entries();
        if entries {
            live["rt"] = entries;
        }
    } except Exception {}
    try {
        import from jaclang.compiler.driver.jir { compiler_generation }
        live["jir-modules"] = {compiler_generation()};
    } except Exception {}
    try {
        import from jaclang.compiler.backends.common.kernel_units { live_unit_digests }
        live["jir-kernel-units"] = live_unit_digests();
    } except Exception {}
    return live;
}


def _cache_status -> int {
    console.print(f"cache root: {cache_home()}");
    rows: list[list[str]] = [];
    total = 0;
    for row in status() {
        total += row.size_bytes;
        rows.append(
            [
                row.name,
                str(row.entries) if row.exists else "-",
                format_bytes(row.size_bytes) if row.exists else "-",
                "external" if row.external else "managed",
                row.policy,
                str(row.path)
            ]
        );
    }
    console.print_table(["bucket", "entries", "size", "kind", "policy", "path"], rows);
    extra = unmanaged();
    if extra {
        console.print("");
        console.print("not owned by any bucket:");
        for (rel, size) in extra {
            note = "  (retired; jac cache gc removes it)" if rel in RETIRED else "";
            console.print(f"  {rel:<28} {format_bytes(size):>10}{note}");
            total += size;
        }
    }
    console.print("");
    console.print(f"total: {format_bytes(total)}");
    return 0;
}


def _cache_gc(dry_run: bool) -> int {
    verb = "would reclaim" if dry_run else "reclaimed";
    total = 0;
    failed = 0;
    for result in gc(dry_run=dry_run, live=_live_keys()) {
        if not result.removed and not result.errors {
            continue;
        }
        total += result.reclaimed_bytes;
        failed += len(result.errors);
        console.print(
            f"{result.bucket}: {verb} {format_bytes(result.reclaimed_bytes)} "
            f"({len(result.removed)} entries)"
        );
        for name in result.removed[:20] {
            console.print(f"  - {name}");
        }
        if len(result.removed) > 20 {
            console.print(f"  ... and {len(result.removed) - 20} more");
        }
        for err in result.errors {
            console.warning(err);
        }
    }
    console.print(f"{verb} {format_bytes(total)} in total");
    if failed {
        console.error(f"{failed} entries could not be removed");
        return 1;
    }
    return 0;
}


def _cache_purge(bucket_name: str, dry_run: bool) -> int {
    names = [bucket_name] if bucket_name else None;
    try {
        result = purge(names, dry_run=dry_run, live=_live_keys());
    } except KeyError as e {
        console.error(str(e.args[0]) if e.args else str(e));
        return 1;
    } except ValueError as e {
        console.error(str(e));
        return 1;
    }
    verb = "would remove" if dry_run else "removed";
    for label in result.removed {
        console.print(f"  {verb} {label}");
    }
    for label in result.kept {
        console.print(f"  kept {label} (the runtime this process runs on)");
    }
    for err in result.errors {
        console.warning(err);
    }
    console.print(f"{verb} {format_bytes(result.reclaimed_bytes)}");
    if result.errors {
        console.error(f"{len(result.errors)} entries could not be removed");
        return 1;
    }
    return 0;
}


impl cache(action: str = "status", bucket: str = "", dry_run: bool = False) -> int {
    verb = _parse_action(action);
    if verb is None {
        console.error(f"unknown action: {action} (expected status, gc or purge)");
        return 1;
    }
    if verb == CacheAction.STATUS {
        return _cache_status();
    }
    if verb == CacheAction.GC {
        return _cache_gc(dry_run);
    }
    return _cache_purge(bucket, dry_run);
}
