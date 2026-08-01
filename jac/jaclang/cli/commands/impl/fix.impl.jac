import os;
import from jaclang.cli.console { console }
import from jaclang.jac0core.parser.tokens { Token }

glob _ELEMENT_KEYWORDS: tuple = (
         'import',
         'include',
         'def',
         'obj',
         'class',
         'enum',
         'node',
         'edge',
         'walker',
         'can',
         'glob',
         'test',
         'impl',
         'sem',
         'with',
         'async',
         'let'
     ),
     _NAMED_ELEMENT_KEYWORDS: tuple = (
         'def',
         'obj',
         'class',
         'enum',
         'node',
         'edge',
         'walker',
         'can',
         'glob',
         'test',
         'impl',
         'let'
     ),
     _MARKER_SPACES: dict[str, str] = {'sv': 'server', 'cl': 'client', 'na': 'native'},
     _PRUNE_DIRS: tuple = (
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


obj MarkerClaim {
    has name: str = '',
        space: str = '',
        line: int = 0;
}


obj StripResult {
    has text: str = '',
        changed: bool = False,
        claims: list[MarkerClaim] = [],
        sv_imports: list[str] = [],
        note: str = '';
}


def _is_string_kind(kind_str: str) -> bool {
    return 'STRING' in kind_str or 'FSTR' in kind_str or 'JSX' in kind_str;
}


def _dotted_target(tokens: list[Token], start: int) -> str {
    parts: list[str] = [];
    j = start;
    while j < len(tokens) {
        val = tokens[j].value;
        if val in ('{', ';', 'as') {
            break;
        }
        parts.append(val);
        j += 1;
    }
    return ''.join(parts);
}


def _first_name_after(tokens: list[Token], start: int) -> str {
    j = start;
    while j < len(tokens) and j < start + 8 {
        tok = tokens[j];
        kind_str = str(tok.kind);
        if (
            not _is_string_kind(kind_str)
            and tok.value not in (':', 'pub', 'priv', 'protect', 'async', 'static')
            and tok.value
            and (tok.value[0].isalpha() or tok.value[0] == '_')
            and tok.value not in _ELEMENT_KEYWORDS
        ) {
            return tok.value;
        }
        j += 1;
    }
    return '';
}


def _collect_block_claims(
    tokens: list[Token], body_start: int, body_end: int, space: str, res: StripResult
) {
    depth = 0;
    j = body_start;
    while j < body_end {
        tok = tokens[j];
        if tok.value == '{' and str(tok.kind) == 'TokenKind.LBRACE' {
            depth += 1;
        } elif tok.value == '}' and str(tok.kind) == 'TokenKind.RBRACE' {
            depth -= 1;
        } elif depth == 0 and not _is_string_kind(str(tok.kind)) {
            if tok.value == 'import' and space == 'server' {
                k = j + 1;
                if k < body_end and tokens[k].value == 'from' {
                    tgt = _dotted_target(tokens, k + 1);
                    if tgt {
                        res.sv_imports.append(tgt);
                    }
                }
            } elif tok.value in _NAMED_ELEMENT_KEYWORDS {
                nm = _first_name_after(tokens, j + 1);
                if nm {
                    res.claims.append(
                        MarkerClaim(name=nm, space=space, line=tok.loc.line)
                    );
                }
                while j < body_end
                    and tokens[j].value != '{'
                    and tokens[j].value != ';' {
                    j += 1;
                }
                continue;
            }
        }
        j += 1;
    }
}


def _strip_markers(src: str, file_path: str) -> StripResult {
    import from jaclang.jac0core.parser.lexer { tokenize }
    res = StripResult(text=src);
    try {
        (tokens, err_count) = tokenize(src, file_path);
    } except Exception as e {
        res.note = f"tokenize failed: {e}";
        return res;
    }
    if err_count {
        res.note = "lex errors; skipped";
        return res;
    }
    edits: list[tuple[int, int, str]] = [];
    depth = 0;
    stmt_start = True;
    i = 0;
    n = len(tokens);
    while i < n {
        tok = tokens[i];
        kind_str = str(tok.kind);
        if tok.value == '{' and kind_str == 'TokenKind.LBRACE' {
            depth += 1;
            stmt_start = False;
            i += 1;
            continue;
        }
        if tok.value == '}' and kind_str == 'TokenKind.RBRACE' {
            depth -= 1;
            stmt_start = depth == 0;
            i += 1;
            continue;
        }
        if tok.value == ';' {
            stmt_start = depth == 0;
            i += 1;
            continue;
        }
        if depth == 0 and 'STRING' in kind_str {
            stmt_start = True;
            i += 1;
            continue;
        }
        if (
            depth == 0
            and stmt_start
            and tok.value in _MARKER_SPACES
            and not _is_string_kind(kind_str)
            and i + 1 < n
        ) {
            space = _MARKER_SPACES[tok.value];
            nxt = tokens[i + 1];
            if nxt.value == '{' and str(nxt.kind) == 'TokenKind.LBRACE' {
                d = 1;
                j = i + 2;
                close_idx = -1;
                while j < n {
                    jv = tokens[j];
                    if jv.value == '{' and str(jv.kind) == 'TokenKind.LBRACE' {
                        d += 1;
                    } elif jv.value == '}' and str(jv.kind) == 'TokenKind.RBRACE' {
                        d -= 1;
                        if d == 0 {
                            close_idx = j;
                            break;
                        }
                    }
                    j += 1;
                }
                if close_idx < 0 {
                    res.note = "unbalanced marker block; skipped";
                    return res;
                }
                edits.append((tok.loc.pos_start, nxt.loc.pos_end, ''));
                edits.append(
                    (tokens[close_idx].loc.pos_start, tokens[close_idx].loc.pos_end, '')
                );
                _collect_block_claims(tokens, i + 2, close_idx, space, res);
                depth += 1;
                i += 2;
                continue;
            }
            if nxt.value in _ELEMENT_KEYWORDS and not _is_string_kind(str(nxt.kind)) {
                edits.append((tok.loc.pos_start, nxt.loc.pos_start, ''));
                if nxt.value == 'import' {
                    if space == 'server'
                        and i + 2 < n
                        and tokens[i + 2].value == 'from' {
                        tgt = _dotted_target(tokens, i + 3);
                        if tgt {
                            res.sv_imports.append(tgt);
                        }
                    }
                } elif nxt.value in _NAMED_ELEMENT_KEYWORDS {
                    nm = _first_name_after(tokens, i + 2);
                    if nm {
                        res.claims.append(
                            MarkerClaim(name=nm, space=space, line=tok.loc.line)
                        );
                    }
                }
                i += 1;
                continue;
            }
        }
        if depth == 0 {
            stmt_start = False;
        }
        i += 1;
    }
    if not edits {
        return res;
    }
    edits.sort();
    src_bytes = src.encode('utf-8');
    out: list[bytes] = [];
    cursor = 0;
    for (start, end, repl) in edits {
        out.append(src_bytes[cursor:start]);
        out.append(repl.encode('utf-8'));
        cursor = end;
    }
    out.append(src_bytes[cursor:]);
    res.text = (b''.join(out)).decode('utf-8');
    res.changed = True;
    return res;
}


def _iter_migration_files(paths: list) -> list[str] {
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


def _read_text_if_exists(path: str) -> str {
    if os.path.exists(path) {
        with open(path, 'r') as f {
            return f.read();
        }
    }
    return '';
}


def _append_toml_entries(
    toml_path: str, header: str, entries: dict[str, str], dry_run: bool
) -> list[str] {
    import tomllib;
    text = _read_text_if_exists(toml_path);
    try {
        doc = tomllib.loads(text);
    } except Exception {
        doc = {};
    }
    section: dict = doc;
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


def _project_entry_stem(toml_path: str) -> str {
    try {
        import tomllib;
        with open(toml_path, 'rb') as f {
            proj_doc = tomllib.load(f);
        }
        entry_point = str(proj_doc.get('project', {}).get('entry-point', '') or '');
        if entry_point.endswith('.jac') {
            entry_point = entry_point[:-4];
        }
        return os.path.basename(entry_point);
    } except Exception {
        return '';
    }
}


def _parses_clean(src: str, file_path: str) -> bool {
    import from jaclang.jac0core.parser { parse as rd_parse }
    try {
        (_mod, had_error) = rd_parse(src, file_path);
        return not had_error;
    } except Exception {
        return False;
    }
}


def _format_source(src: str, file_path: str) -> (str | None) {
    import from jaclang.jac0core.program { JacProgram }
    try {
        prog = JacProgram.jac_str_formatter(
            source_str=src, file_path=file_path, auto_lint=False
        );
        if prog.errors_had {
            return None;
        }
        formatted = prog.mod.main.gen.jac;
        return formatted;
    } except Exception {
        return None;
    }
}


def _verify_claims(
    file_path: str,
    claims: list[MarkerClaim],
    pins: dict[str, str],
    unverified: list[str]
) {
    import from jaclang.jac0core.placement { element_display_name }
    import from jaclang.jac0core.placement_pins { _module_dot_path }
    import from jaclang.jac0core.modresolver { find_jac_project_root }
    import from jaclang.jac0core.program { JacProgram }
    proj_root = find_jac_project_root(file_path);
    if not proj_root {
        unverified.append(f"{file_path} (no jac.toml found)");
        return;
    }
    if file_path.endswith('.impl.jac') or file_path.endswith('.test.jac') {
        unverified.append(f"{file_path} (annex; verify via its base module)");
        return;
    }
    prog = JacProgram();
    try {
        mod = prog.compile(file_path, no_cgen=True);
    } except Exception as e {
        unverified.append(f"{file_path} (compile failed: {e})");
        return;
    }
    if prog.errors_had {
        unverified.append(f"{file_path} (compile errors)");
        return;
    }
    stamped: dict[str, tuple] = {};
    for stmt in mod.body {
        try {
            nm = element_display_name(stmt);
        } except Exception {
            continue;
        }
        space = getattr(stmt?.code_context, 'value', '');
        stamped[nm] = (space, bool(getattr(stmt, 'codespace_dual', False)));
    }
    mod_dot = _module_dot_path(file_path, proj_root);
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


impl fix(
    target: str, paths: list, dry_run: bool = False, strip_only: bool = False
) -> int {
    if target != 'placement' {
        console.error(f"Unknown fix target '{target}'. Available: placement");
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
    changed_files: list[str] = [];
    renamed: list[tuple] = [];
    claims_by_file: dict[str, list[MarkerClaim]] = {};
    sv_imports_by_file: dict[str, list[str]] = {};
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
        res = _strip_markers(src, path);
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
        }
    }

    import from jaclang.jac0core.modresolver { find_jac_project_root }
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
    routes_by_root: dict[str, dict[str, str]] = {};
    orphaned: list[str] = [];
    for (path, targets) in sv_imports_by_file.items() {
        route_root = find_jac_project_root(path);
        if not route_root {
            orphaned.append(path);
            continue;
        }
        entry_stem = _project_entry_stem(os.path.join(route_root, 'jac.toml'));
        routes = routes_by_root.setdefault(route_root, {});
        for tgt in targets {
            stem = tgt.strip('.').rsplit('.', 1)[-1];
            if stem and stem != entry_stem {
                slug = stem[:-4] if stem.endswith('_app') else stem;
                routes[stem] = f"/{slug}";
            }
        }
    }

    pins_added: list[str] = [];
    routes_added: list[str] = [];
    for (pin_root, pins) in sorted(pins_by_root.items()) {
        if pins {
            added = _append_toml_entries(
                os.path.join(pin_root, 'jac.toml'), '[placement.pins]', pins, dry_run
            );
            pins_added.extend([f"{pin_root}: {a}" for a in added]);
        }
    }
    for (route_root, routes) in sorted(routes_by_root.items()) {
        if routes {
            added = _append_toml_entries(
                os.path.join(route_root, 'jac.toml'),
                '[scale.microservices.routes]',
                routes,
                dry_run
            );
            routes_added.extend([f"{route_root}: {a}" for a in added]);
        }
    }
    if orphaned {
        console.warning(
            "No jac.toml found for service routes from: " + ", ".join(orphaned)
        );
    }

    verb = "Would migrate" if dry_run else "Migrated";
    console.print(f"{verb} {len(changed_files)} file(s).");
    for (old, new) in renamed {
        console.print(f"  rename: {old} -> {new}");
    }
    for entry in pins_added {
        console.print(f"  [placement.pins] {entry}");
    }
    for entry in routes_added {
        console.print(f"  [scale.microservices.routes] {entry}");
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
