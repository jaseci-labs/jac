def print_guide_hint(alert: any) -> None {
    import from jaclang.cli.console { console }
    import from jaclang.cli.guide_store { guide_for_diagnostic }
    info = alert.code;
    if info is None {
        return;
    }
    name = guide_for_diagnostic(info.code, info.category.value);
    if name is not None {
        console.print(f"  → run 'jac guide {name}' for guidance", style="muted");
    }
}

impl separator(text: str, char: str = '=', total_width: int = 80) -> str {
    text_part = f" {text} ";
    remaining = total_width - len(text_part);
    left_padding = remaining // 2;
    return char * left_padding + text_part + char * (remaining - left_padding);
}

impl print_file_progress(file_path: str, success: bool, idx: int, total: int) -> None {
    import from jaclang.cli.console { console }
    percentage = int((idx / total) * 100);
    status = "ok" if success else "FAILED";
    console.print(f"{file_path} {status} [{percentage}%]");
}

impl print_failures(failed_results: list, nowarn: bool = False) -> None {
    import from jaclang.cli.console { console }
    console.print("");
    console.print(separator("FAILURES"));
    for r in failed_results {
        console.print(separator(r['path'], char='_'));
        for e in r['errors'] {
            console.error(e.pretty_print());
            print_guide_hint(e);
        }
        if not nowarn and r['warnings'] {
            for w in r['warnings'] {
                console.warning(w.pretty_print());
                print_guide_hint(w);
            }
        }
        console.print("");
    }
}

impl print_failed_summary(failed_results: list) -> None {
    import from jaclang.cli.console { console }
    console.print(separator("failed files"));
    for r in failed_results {
        err_count = len(r['errors']);
        warn_count = len(r['warnings']);
        err_s = '' if err_count == 1 else 's';
        warn_s = '' if warn_count == 1 else 's';
        console.print(
            f"{r['path']} - {err_count} error{err_s}, {warn_count} warning{warn_s}"
        );
    }
}

impl print_final_summary(passed_count: int, failed_count: int, elapsed: float) -> None {
    import from jaclang.cli.console { console }
    parts = [f"{passed_count} passed"] if passed_count > 0 else [];
    if failed_count > 0 {
        parts.append(f"{failed_count} failed");
    }
    console.print(separator(", ".join(parts) + f" in {elapsed:.2f}s"));
}

def _census_relpath(path: str) -> str {
    import os;
    try {
        return os.path.relpath(path);
    } except ValueError {
        return path;
    }
}

impl print_native_census(census: dict) -> None {
    import from jaclang.cli.console { console }
    import from jaclang.jac0core.codeinfo { effective_default_codespace }
    console.print("");
    console.print(separator("native census"));
    console.print(f"default codespace: {effective_default_codespace()}");
    counts: dict[str, int] = {};
    for rec in census.values() {
        counts[rec['outcome']] = counts.get(rec['outcome'], 0) + 1;
    }
    console.print(
        ", ".join(f"{counts.get(k, 0)} {k}" for k in ('native', 'demoted', 'server'))
    );
    native_paths = sorted(
        _census_relpath(p)
        for (p, rec) in census.items()
        if rec['outcome'] == 'native'
    );
    if native_paths {
        console.print("");
        console.print("native modules:");
        for p in native_paths {
            console.print(f"  {p}");
        }
    }
    demoted = [
        (p, rec)
        for (p, rec) in census.items()
        if rec['outcome'] == 'demoted'
    ];
    if demoted {
        console.print("");
        console.print("demotions (ranked by first error code):");
        by_code: dict[str, list] = {};
        for (p, rec) in demoted {
            by_code.setdefault(rec['code'] or '<uncoded>', []).append((p, rec));
        }
        ranked = sorted(by_code.items(), key=lambda (x: tuple) { (-len(x[1]), x[0]); });
        for (code, entries) in ranked {
            console.print(f"  {code}  ({len(entries)})");
            for (p, rec) in sorted(entries) {
                console.print(f"    {_census_relpath(p)}  {rec['detail']}");
            }
        }
    }
    server = [
        (p, rec)
        for (p, rec) in census.items()
        if rec['outcome'] == 'server'
    ];
    if server {
        console.print("");
        console.print("server modules (ranked by classifier signal):");
        by_reason: dict[str, list] = {};
        for (p, rec) in server {
            by_reason.setdefault(rec['detail'] or '<unknown>', []).append(p);
        }
        ranked_r = sorted(
            by_reason.items(), key=lambda (x: tuple) { (-len(x[1]), x[0]); }
        );
        for (reason, paths) in ranked_r {
            console.print(f"  {reason}  ({len(paths)})");
            for p in sorted(paths) {
                console.print(f"    {_census_relpath(p)}");
            }
        }
    }
    seamed = [
        (p, rec)
        for (p, rec) in census.items()
        if rec['seams']
    ];
    if seamed {
        console.print("");
        console.print("native modules with demoted methods (seams):");
        for (p, rec) in sorted(seamed) {
            console.print(f"  {_census_relpath(p)}");
            for s in rec['seams'] {
                console.print(f"    {s}");
            }
        }
    }
}

impl print_placement_report(rows_by_module: dict) -> None {
    import from jaclang.cli.console { console }
    console.print("");
    console.print(separator("placements"));
    if not rows_by_module {
        console.print("no modules compiled");
        return;
    }
    counts: dict[str, int] = {};
    for entry in rows_by_module.values() {
        for row in entry['rows'] {
            key = 'dual' if row['dual'] else row['space'];
            counts[key] = counts.get(key, 0) + 1;
        }
    }
    total_crossings = 0;
    for entry in rows_by_module.values() {
        total_crossings += entry.get('crossings', 0);
    }
    console.print(
        ", ".join(
            f"{counts.get(k, 0)} {k}" for k in ('server', 'client', 'native', 'dual')
        )
    );
    console.print(
        f"estimated boundary crossings: {total_crossings} "
        f"(client import items bridged over RPC)"
    );
    for path in sorted(rows_by_module.keys()) {
        entry = rows_by_module[path];
        decided = entry['decided'];
        rel = _census_relpath(path);
        suffix = '';
        if decided {
            suffix = f"  [decided {decided}]";
        }
        console.print("");
        console.print(rel + suffix);
        for row in entry['rows'] {
            row_space = row['space'];
            if row['dual'] {
                row_space = row_space + ' (dual)';
            }
            nm = row['name'];
            knd = row['kind'];
            label = f"{nm} ({knd})";
            console.print("  " + label.ljust(44) + " " + row_space);
            for note in row['evidence'] {
                console.print("      - " + note);
            }
        }
    }
}
