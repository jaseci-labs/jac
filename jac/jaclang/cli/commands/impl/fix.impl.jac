import os;

glob _PRUNE_DIRS: tuple[str, ...] = (
         'node_modules',
         '__pycache__',
         'dist',
         'build',
         'venv',
         '.venv',
         '.git',
         '.jac',
         'site-packages'
     );


def _iter_migration_files(paths: list[str]) -> list[str];


def _read_text_if_exists(path: str) -> str;


def _append_toml_entries(
    toml_path: str, header: str, entries: dict[str, str], dry_run: bool
) -> list[str];


def _append_app_table(
    toml_path: str, name: str, table: dict[str, str], dry_run: bool
) -> list[str];


def _ensure_workspace(toml_path: str, dry_run: bool) -> str;


def _service_file_for(
    target: str, importer: str, root_dir: str, scanned: list[str]
) -> str;


def _project_entry_stem(toml_path: str) -> str;


def _parses_clean(src: str, file_path: str) -> bool;


def _format_source(src: str, file_path: str) -> (str | None);


def _client_imports(file_path: str, src: str) -> dict[tuple[int, str], bool];


def _verify_claims(
    file_path: str,
    claims: list[ElementSpace],
    pins: dict[str, str],
    unverified: list[str]
);


def _apply_access_rewrites(
    path: str, rewrites: list[AccessRewrite]
) -> tuple[str, int];

def _fix_access(paths: list[str], dry_run: bool) -> int;

def _fix_dependencies(paths: list[str], dry_run: bool) -> int;

def _report_invalid_manifest(paths: list[str]) -> bool;

impl fix(
    target: str, paths: list[str], dry_run: bool = False, strip_only: bool = False
) -> int {
    if isinstance(paths, str) {
        paths = [paths];
    }
    if target == 'access' {
        if _report_invalid_manifest(paths) {
            return 2;
        }
        return _fix_access(paths, dry_run);
    }
    if target == 'dependencies' {
        return _fix_dependencies(paths, dry_run);
    }
    if target != 'placement' {
        console.error(
            f"Unknown fix target '{target}'. Available: placement, access, dependencies"
        );
        return 1;
    }
    if isinstance(paths, str) {
        paths = [paths];
    }
    files = _iter_migration_files(paths);
    if not files {
        console.error("No .jac files found to migrate.");
        return 1;
    }
    if _report_invalid_manifest(files) {
        return 2;
    }
    changed_files: list[str] = [];
    renamed: list[tuple[str, str]] = [];
    claims_by_file: dict[str, list[ElementSpace]] = {};
    sv_imports_by_file: dict[str, list[ImportSpace]] = {};
    migrated_text: dict[str, str] = {};
    scanned: list[str] = [];
    skipped: list[str] = [];
    for path in files {
        try {
            with open(path, 'r') as f {
                src = f.read();
            }
        } except Exception as e {
            skipped.append(f"{path} (unreadable: {e})");
            continue;
        }
        res = tool_session().strip_markers(path, src);
        if res.note {
            skipped.append(f"{path} ({res.note})");
            continue;
        }
        final_path = path;
        rename_suffix = '';
        if path.endswith('.sv.jac') {
            rename_suffix = '.sv.jac';
        } elif path.endswith('.native.cl.jac') {
            rename_suffix = '.native.cl.jac';
        } elif path.endswith('.cl.jac') {
            rename_suffix = '.cl.jac';
        } elif path.endswith('.na.jac') {
            rename_suffix = '.na.jac';
        }
        if rename_suffix {
            tail = '.native.jac' if rename_suffix == '.native.cl.jac' else '.jac';
            candidate = path[:-len(rename_suffix)] + tail;
            if os.path.exists(candidate) {
                skipped.append(f"{path} (rename target {candidate} exists)");
            } else {
                final_path = candidate;
                renamed.append((path, candidate));
            }
        }
        scanned.append(final_path);
        if not res.changed and final_path == path {
            continue;
        }
        out_text = res.text;
        if res.changed {
            formatted = _format_source(out_text, final_path);
            if formatted is not None {
                out_text = formatted;
            } elif _parses_clean(out_text, final_path) {
                skipped.append(f"{path} (stripped but not reformatted)");
            } else {
                skipped.append(
                    f"{path} (stripped source does not parse; migrate manually)"
                );
                continue;
            }
        }
        if not dry_run {
            if final_path != path {
                os.rename(path, final_path);
            }
            with open(final_path, 'w') as f {
                f.write(out_text);
            }
        }
        if res.changed {
            changed_files.append(final_path);
        }
        if res.claims {
            claims_by_file[final_path] = res.claims;
        }
        if res.sv_imports {
            sv_imports_by_file[final_path] = res.sv_imports;
            migrated_text[final_path] = res.text;
        }
    }

    pins_by_root: dict[str, dict[str, str]] = {};
    unverified: list[str] = [];
    if strip_only {
        claims_by_file = {};
        sv_imports_by_file = {};
    }
    if not dry_run {
        for (path, claims) in claims_by_file.items() {
            claim_root = find_jac_project_root(path);
            if not claim_root {
                unverified.append(f"{path} (no jac.toml found)");
                continue;
            }
            pins = pins_by_root.setdefault(claim_root, {});
            _verify_claims(path, claims, pins, unverified);
        }
    }
    pins_added: list[str] = [];
    for (pin_root, pins) in sorted(pins_by_root.items()) {
        if pins {
            added = _append_toml_entries(
                os.path.join(pin_root, 'jac.toml'), '[placement.pins]', pins, dry_run
            );
            pins_added.extend([f"{pin_root}: {a}" for a in added]);
        }
    }
    apps_by_root: dict[str, dict[str, dict[str, str]]] = {};
    causes_by_root: dict[str, dict[str, str]] = {};
    orphaned: list[str] = [];
    for (path, imports) in sv_imports_by_file.items() {
        app_root = find_jac_project_root(path);
        if not app_root {
            orphaned.append(path);
            continue;
        }
        entry_stem = _project_entry_stem(os.path.join(app_root, 'jac.toml'));
        tables = apps_by_root.setdefault(app_root, {});
        causes = causes_by_root.setdefault(app_root, {});
        client = _client_imports(path, migrated_text.get(path, ''));
        for imp in imports {
            tgt = imp.target;
            client_only = client.get((imp.line, tgt));
            if client_only {
                continue;
            }
            cause = f"{path}:{imp.line}";
            if client_only is None {
                unverified.append(
                    f"{cause} 'sv import from {tgt}' (placement not inferred; "
                    "treated as a server-to-server import)"
                );
            } elif dry_run and path in claims_by_file {
                unverified.append(
                    f"{cause} 'sv import from {tgt}' (the preview does not apply the "
                    "[placement.pins] this file's markers may add, which can make "
                    "the import client-side)"
                );
            }
            stem = tgt.strip('.').rsplit('.', 1)[-1];
            if not stem or stem == entry_stem or stem in tables {
                continue;
            }
            service_file = _service_file_for(tgt, path, app_root, scanned);
            if not service_file {
                skipped.append(
                    f"[apps.{stem}] (service module '{tgt}' imported by {path} "
                    "was not found; declare the app by hand)"
                );
                continue;
            }
            table: dict[str, str] = {
                'kind': 'service',
                'entry-point': os.path.relpath(service_file, app_root)[:-4].replace(
                    os.sep, '.'
                )
            };
            slug = stem[:-4] if stem.endswith('_app') else stem;
            old_route = f"/{slug}";
            if old_route != f"/api/{stem}" {
                table['route'] = old_route;
            }
            tables[stem] = table;
            causes[stem] = cause;
        }
    }

    apps_added: list[str] = [];
    for (app_root, tables) in sorted(apps_by_root.items()) {
        if not tables {
            continue;
        }
        toml_path = os.path.join(app_root, 'jac.toml');
        try {
            base_name = _ensure_workspace(toml_path, dry_run);
        } except Exception as e {
            skipped.append(
                f"{toml_path} ([project] could not be migrated into [apps]: {e}; "
                "declare the service apps by hand)"
            );
            continue;
        }
        if base_name {
            apps_added.append(
                f"{app_root}: [apps.{base_name}] migrated from [project] "
                f"kind/entry-point (default-app = \"{base_name}\")"
            );
        }
        for (name, table) in sorted(tables.items()) {
            if name == base_name {
                skipped.append(
                    f"[apps.{name}] (service module shares the project app's name; "
                    "declare it by hand)"
                );
                continue;
            }
            added = _append_app_table(toml_path, name, table, dry_run);
            if added {
                cause = causes_by_root[app_root][name];
                apps_added.append(
                    f"{app_root}: [apps.{name}] "
                        + " ".join(added)
                        + f" (from the sv import at {cause})"
                );
            }
        }
    }
    if orphaned {
        console.warning(
            "No jac.toml found for the service apps imported by: " + ", ".join(orphaned)
        );
    }

    verb = "Would migrate" if dry_run else "Migrated";
    console.print(f"{verb} {len(changed_files)} file(s).");
    for (old, new) in renamed {
        console.print(f"  rename: {old} -> {new}");
    }
    for `entry in pins_added {
        console.print(f"  [placement.pins] {`entry}");
    }
    for `entry in apps_added {
        console.print(f"  {`entry}");
    }
    for msg in skipped {
        console.warning(f"  skipped: {msg}");
    }
    for msg in unverified {
        console.warning(f"  unverified: {msg}");
    }
    if pins_added {
        console.print(
            "Pinned elements whose inferred placement differs from their old "
            "marker; review the [placement.pins] entries and delete any you "
            "trust inference to own.",
            style="muted"
        );
    }
    return 0;
}

impl _iter_migration_files(paths: list[str]) -> list[str] {
    files: list[str] = [];
    for p in paths {
        if os.path.isfile(p) {
            if p.endswith('.jac') {
                files.append(p);
            }
            continue;
        }
        if not os.path.isdir(p) {
            console.error(f"Path '{p}' does not exist.");
            continue;
        }
        for (cur, dirnames, filenames) in os.walk(p) {
            kept = [
                d
                for d in sorted(dirnames)
                if not d.startswith('.') and d not in _PRUNE_DIRS
            ];
            dirnames.clear();
            dirnames.extend(kept);
            for fn in sorted(filenames) {
                if fn.endswith('.jac') {
                    files.append(os.path.join(cur, fn));
                }
            }
        }
    }
    return files;
}


impl _read_text_if_exists(path: str) -> str {
    if os.path.exists(path) {
        with open(path, 'r') as f {
            return f.read();
        }
    }
    return '';
}


impl _append_toml_entries(
    toml_path: str, header: str, entries: dict[str, str], dry_run: bool
) -> list[str] {
    import tomllib;
    text = _read_text_if_exists(toml_path);
    try {
        doc = tomllib.loads(text);
    } except Exception {
        doc = {};
    }
    section: dict[str, any] = doc;
    for part in header.strip('[]').split('.') {
        nxt_section = section.get(part, {}) if isinstance(section, dict) else {};
        section = nxt_section;
    }
    missing = {
        k: v
        for (k, v) in entries.items()
        if not (isinstance(section, dict) and k in section)
    };
    if not missing {
        return [];
    }
    added = [f'"{k}" = "{v}"' for (k, v) in sorted(missing.items())];
    if dry_run {
        return added;
    }
    lines: list[str] = text.splitlines();
    header_idx = -1;
    for (idx, ln) in enumerate(lines) {
        if ln.strip() == header {
            header_idx = idx;
            break;
        }
    }
    if header_idx >= 0 {
        insert_at = header_idx + 1;
        merged = lines[:insert_at] + added + lines[insert_at:];
        new_text = "\n".join(merged);
        if text.endswith("\n") {
            new_text += "\n";
        }
    } else {
        base = text if (not text or text.endswith("\n")) else text + "\n";
        sep = "\n" if base else "";
        new_text = base + sep + header + "\n" + "\n".join(added) + "\n";
    }
    with open(toml_path, 'w') as f {
        f.write(new_text);
    }
    return added;
}


impl _append_app_table(
    toml_path: str, name: str, table: dict[str, str], dry_run: bool
) -> list[str] {
    import tomllib;

    text = _read_text_if_exists(toml_path);
    try {
        doc = tomllib.loads(text);
    } except Exception {
        doc = {};
    }
    apps = doc.get('apps', {}) if isinstance(doc, dict) else {};
    if isinstance(apps, dict) and name in apps {
        return [];
    }
    lines: list[str] = text.split("\n");
    before = len(lines);
    _toml_append_section(lines, ('apps', name), table);
    added = [
        ln
        for ln in lines[before:]
        if ln and not ln.startswith('[')
    ];
    if dry_run {
        return added;
    }
    with open(toml_path, 'w') as f {
        f.write("\n".join(lines));
    }
    return added;
}


impl _ensure_workspace(toml_path: str, dry_run: bool) -> str {
    import tomllib;
    import from pathlib { Path }

    text = _read_text_if_exists(toml_path);
    doc = tomllib.loads(text);
    apps = doc.get('apps') if isinstance(doc, dict) else None;
    if isinstance(apps, dict) and apps {
        return '';
    }
    base = JacConfig.load(Path(toml_path));
    lines: list[str] = text.split("\n");
    base_name = migrate_implicit_app(lines, base);
    if not dry_run {
        with open(toml_path, 'w') as f {
            f.write("\n".join(lines));
        }
    }
    return base_name;
}


impl _service_file_for(
    target: str, importer: str, root_dir: str, scanned: list[str]
) -> str {
    dots = len(target) - len(target.lstrip('.'));
    parts = [
        p
        for p in target.strip('.').split('.')
        if p
    ];
    if not parts {
        return '';
    }
    importer_dir = os.path.dirname(os.path.abspath(importer));
    bases: list[str] = [];
    if dots {
        base = importer_dir;
        for _ in range(dots - 1) {
            base = os.path.dirname(base);
        }
        bases.append(base);
    } else {
        bases.append(root_dir);
        bases.append(importer_dir);
    }
    for base in bases {
        candidate = os.path.join(base, os.sep.join(parts)) + '.jac';
        if os.path.isfile(candidate) {
            return os.path.abspath(candidate);
        }
    }
    want = parts[-1] + '.jac';
    for p in scanned {
        if os.path.basename(p) == want {
            return os.path.abspath(p);
        }
    }
    return '';
}


impl _project_entry_stem(toml_path: str) -> str {
    try {
        import tomllib;
        with open(toml_path, 'rb') as f {
            proj_doc = tomllib.load(f);
        }
        entry_point = str(proj_doc.get('project', {}).get('entry-point', '') or '');
        if entry_point.endswith('.jac') {
            entry_point = entry_point[:-4];
        }
        return entry_point.rsplit('.', 1)[-1];
    } except Exception {
        return '';
    }
}


impl _parses_clean(src: str, file_path: str) -> bool {
    session = tool_session();
    def syntax -> ToolOutput {
        return session.parse(file_path);
    }
    return not session.with_text(file_path, src, syntax).errors;
}


impl _format_source(src: str, file_path: str) -> (str | None) {
    formatted = tool_session().format_text(file_path, src);
    return None if formatted.errors else formatted.text;
}


impl _client_imports(file_path: str, src: str) -> dict[tuple[int, str], bool] {
    session = tool_session();
    def placed -> list[ImportSpace] {
        return session.client_imports(file_path);
    }
    return {
        (row.line, row.target): row.client_only
        for row in session.with_text(file_path, src, placed)
    };
}


impl _verify_claims(
    file_path: str,
    claims: list[ElementSpace],
    pins: dict[str, str],
    unverified: list[str]
) {
    proj_root = find_jac_project_root(file_path);
    if not proj_root {
        unverified.append(f"{file_path} (no jac.toml found)");
        return;
    }
    if file_path.endswith('.impl.jac') or file_path.endswith('.test.jac') {
        unverified.append(f"{file_path} (annex; verify via its base module)");
        return;
    }
    session = tool_session();
    try {
        diagnostics = session.diagnostics(file_path);
        placed = session.element_spaces(file_path);
    } except KernelError as e {
        unverified.append(f"{file_path} (compile failed: {e})");
        return;
    }
    if any([diag.severity == "error" for diag in diagnostics]) {
        unverified.append(f"{file_path} (compile errors)");
        return;
    }
    stamped: dict[str, tuple[str, bool]] = {
        row.name: (row.space, row.dual) for row in placed
    };
    mod_dot = module_dot_path(file_path, proj_root);
    for claim in claims {
        got = stamped.get(claim.name);
        if got is None {
            unverified.append(
                f"{file_path}:{claim.line} '{claim.name}' (element not found)"
            );
            continue;
        }
        (space, dual) = got;
        if space != claim.space or dual {
            pins[f"{mod_dot}.{claim.name}"] = claim.space;
        }
    }
}

impl _apply_access_rewrites(
    path: str, rewrites: list[AccessRewrite]
) -> tuple[str, int] {
    import re;
    with open(path, 'r') as f {
        lines = f.read().split('\n');
    }
    changed = 0;
    for rw in rewrites {
        idx = rw.line - 1;
        if idx < 0 or idx >= len(lines) {
            continue;
        }
        keyword = 'walker' if rw.kind == 'walker' else 'def';
        pattern = re.compile(r'\b' + keyword + r'\s+' + re.escape(rw.name) + r'\b');
        new_line = pattern.sub(keyword + ':protect ' + rw.name, lines[idx], count=1);
        if new_line != lines[idx] {
            lines[idx] = new_line;
            changed += 1;
        }
    }
    return ('\n'.join(lines), changed);
}

impl _fix_access(paths: list[str], dry_run: bool) -> int {
    proj_roots: list[str] = [];
    for p in paths {
        cand = os.path.realpath(p if os.path.isdir(p) else os.path.dirname(p));
        if cand not in proj_roots {
            proj_roots.append(cand);
        }
    }
    total: list[AccessRewrite] = [];
    all_notes: list[str] = [];
    session = tool_session();
    for proj_root in proj_roots {
        plan = session.access_plan(proj_root);
        total.extend(plan.rewrites);
        all_notes.extend(plan.notes);
    }
    for note in all_notes {
        console.print(f"  note: {note}");
    }
    if not total {
        console.print(
            "Nothing to migrate: every served declaration already declares its exposure."
        );
        return 0;
    }
    by_file: dict[str, list[AccessRewrite]] = {};
    for rw in total {
        by_file.setdefault(rw.path, []).append(rw);
    }
    console.print(
        f"{'Would mark' if dry_run else 'Marking'} {len(
            total
        )} declaration(s) :protect:"
    );
    for (path, rws) in sorted(by_file.items()) {
        for rw in sorted(rws, key=lambda (r: AccessRewrite) { r.line; }) {
            console.print(
                f"  {os.path.relpath(path)}:{rw.line}  {rw.kind} {rw.name}  ({rw.reason})"
            );
        }
    }
    if dry_run {
        return 0;
    }
    written = 0;
    for (path, rws) in by_file.items() {
        (text, changed) = _apply_access_rewrites(path, rws);
        if changed == 0 {
            continue;
        }
        if not _parses_clean(text, path) {
            console.error(f"{path}: rewritten source does not parse; left untouched");
            continue;
        }
        with open(path, 'w') as f {
            f.write(text);
        }
        written += changed;
    }
    console.print(f"Rewrote {written} declaration(s). Run `jac check` to confirm.");
    return 0;
}

impl _fix_dependencies(paths: list[str], dry_run: bool) -> int {
    manifests = find_manifests(paths);
    if not manifests {
        console.error("No jac.toml found to migrate.");
        return 1;
    }
    changed = 0;
    for manifest in manifests {
        result = migrate_manifest(manifest);
        if not result.moved {
            continue;
        }
        changed += 1;
        verb = "Would move" if dry_run else "Moved";
        console.print(
            f"{verb} {len(result.moved)} Python dependenc(ies) to [*.pypi] in {manifest}",
            style="bold"
        );
        for moved_key in result.moved {
            console.print(f"  {moved_key}", style="muted");
        }
        if not result.lossless {
            console.warning(
                f"{manifest}: the file could not be edited in place, so it was "
                "rewritten; comments inside the dependency tables were dropped"
            );
        }
        if not dry_run {
            manifest.write_text(result.text, encoding="utf-8");
        }
    }
    if not changed {
        console.success(
            "Every jac.toml already keeps Python packages in [dependencies.pypi]."
        );
    }
    return 0;
}

impl _report_invalid_manifest(paths: list[str]) -> bool {
    import from pathlib { Path }
    checked: set[str] = set();
    for path in paths {
        proj = find_jac_project_root(path);
        if not proj or proj in checked {
            continue;
        }
        checked.add(proj);
        manifest = Path(proj) / "jac.toml";
        if not manifest.is_file() {
            continue;
        }
        try {
            JacConfig.load(manifest);
        } except ValueError as exc {
            console.error(f"jac.toml is invalid: {exc}", hint=f"File: {manifest}");
            return True;
        }
    }
    return False;
}
