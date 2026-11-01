impl StudioLangServer.debug(msg: str) -> None {}

impl StudioLangServer.log_error(message: str) -> None {
    self.last_error = message;
}

impl StudioLangServer.log_warning(message: str) -> None {}

impl StudioLangServer.log_info(message: str) -> None {}

impl new_server(root_dir: str) -> StudioLangServer {
    ls = StudioLangServer();
    ls.lsp._workspace = Workspace(root_uri=uris.from_fs_path(root_dir));
    return ls;
}

impl uri_of(path: str) -> str {
    return uris.from_fs_path(path) or "";
}

impl path_of(uri: str) -> str {
    return uris.to_fs_path(uri) or "";
}

impl head_of(path: str) -> str {
    base = discover_base_file(path);
    return os.path.realpath(base) if base else path;
}

impl unit_files(head: str) -> list[str] {
    files = [head];
    for suffix in [".impl.jac", ".test.jac"] {
        for f in discover_annex_files(head, suffix) {
            rp = os.path.realpath(f);
            if rp not in files {
                files.append(rp);
            }
        }
    }
    return files;
}

impl read_lines(path: str) -> list[str] {
    try {
        with open(path, "r", encoding="utf-8", errors="replace") as f {
            return f.read().split("\n");
        }
    } except OSError {
        return [];
    }
}

impl sem_style(types: list[str], mods: list[str], tok_type: int, tok_mods: int) -> str {
    name = types[tok_type] if 0 <= tok_type < len(types) else "variable";
    parts = [name];
    bit = 0;
    while tok_mods and bit < len(mods) {
        if tok_mods & (1 << bit) {
            parts.append(mods[bit]);
        }
        bit += 1;
    }
    return ".".join(parts);
}

impl decode_tokens(data: list[int]) -> list[tuple[int, int, int, str]] {
    types = JacSemTokenType.as_str_list();
    mods = JacSemTokenModifier.as_str_list();
    out: list[tuple[int, int, int, str]] = [];
    line = 0;
    col = 0;
    i = 0;
    while i + 4 < len(data) {
        if data[i] > 0 {
            line += data[i];
            col = data[i + 1];
        } else {
            col += data[i + 1];
        }
        out.append(
            (
                line,
                col,
                col + data[i + 2],
                sem_style(types, mods, data[i + 3], data[i + 4])
            )
        );
        i += 5;
    }
    return out;
}

impl symbol_info(row: TokenSymbol) -> dict[str, any] {
    info: dict[str, any] = {"name": row.name};
    if not row.kind {
        return info;
    }
    info["kind"] = row.kind;
    info["dotted"] = row.dotted;
    if row.decl_path or row.decl_line {
        info["decl_path"] = row.decl_path;
        info["decl_line"] = row.decl_line;
        info["decl_col"] = row.decl_col;
    }
    return info;
}

impl diag_tuple(diag: KernelDiagnostic) -> tuple[str, str, str, str, int, int, int, int] {
    span = diag.span;
    return (
        diag.severity,
        diag.code,
        diag.message,
        diag.help,
        max(1, span.line),
        max(0, span.col - 1),
        max(1, span.end_line),
        max(0, span.end_col - 1)
    );
}

impl new_cancel_token -> CancelToken {
    return CancelToken();
}

impl check_head(
    ls: StudioLangServer,
    head: str,
    max_apps: int = 0,
    cancel: (CancelToken | None) = None
) -> dict[str, any] {
    if max_apps > 0 {
        ls.client().set_shared_app_limit(max_apps);
    }
    files = unit_files(head);
    ls.last_error = "";
    texts = {f: read_lines(f) for f in files};
    ok = ls.type_check_file(uri_of(head), cancel_token=cancel);
    if cancel is not None and cancel.is_set() {
        return {"ok": False, "error": "cancelled", "cancelled": True, "files": {}};
    }
    result: dict[str, any] = {"ok": ok, "error": ls.last_error, "files": {}};
    for f in files {
        sem_rows = decode_tokens(list(ls.get_semantic_tokens(uri_of(f)).data))
            if ok
            else [];
        syms: list[tuple[int, int, int, dict[str, any]]] = [];
        inlays: list[tuple[int, int, str]] = [];
        if ok {
            for row in ls.client().token_symbols(f) {
                syms.append((row.line - 1, row.col, row.end_col, symbol_info(row)));
            }
            inlays += type_hints(ls, f);
            whole = lspt.Range(
                start=lspt.Position(line=0, character=0),
                end=lspt.Position(line=len(texts[f]) + 1, character=0)
            );
            for h in ls.get_inlay_hints(uri_of(f), whole) {
                lbl = h.label
                    if isinstance(h.label, str)
                    else "".join([str(part.value) for part in h.label]);
                inlays.append((int(h.position.line), int(h.position.character), lbl));
            }
        }
        result["files"][f] = {
            "lines": texts[f],
            "sem": sem_rows,
            "syms": syms,
            "diags": [diag_tuple(d) for d in ls.kernel_diagnostics.get(f, [])],
            "inlays": inlays
        };
    }
    return result;
}

impl hover_at(ls: StudioLangServer, path: str, line: int, col: int) -> (str | None) {
    h = ls.get_hover_info(uri_of(path), lspt.Position(line=line - 1, character=col));
    if h is None {
        return None;
    }
    contents: any = h.contents;
    return str(getattr(contents, "value", contents));
}

impl location_dict(loc: any, with_text: bool = False) -> dict[str, any] {
    path = path_of(loc.uri);
    line = int(loc.range.start.line) + 1;
    d: dict[str, any] = {
        "path": path,
        "line": line,
        "col": int(loc.range.start.character)
    };
    if with_text {
        lines = read_lines(path);
        d["text"] = lines[line - 1].strip() if 0 < line <= len(lines) else "";
    }
    return d;
}

impl definition_at(
    ls: StudioLangServer, path: str, line: int, col: int
) -> (dict[str, any] | None) {
    loc = ls.get_definition(uri_of(path), lspt.Position(line=line - 1, character=col));
    return location_dict(loc) if loc is not None else None;
}

impl references_at(
    ls: StudioLangServer, path: str, line: int, col: int
) -> list[dict[str, any]] {
    locs = ls.get_references(uri_of(path), lspt.Position(line=line - 1, character=col));
    out: list[dict[str, any]] = [];
    seen: set[tuple[str, int, int]] = set();
    for loc in locs {
        d = location_dict(loc, with_text=True);
        k = (d["path"], d["line"], d["col"]);
        if k not in seen {
            seen.add(k);
            out.append(d);
        }
    }
    out.sort(key=lambda (r: dict[str, any]) { (r["path"], r["line"], r["col"]); });
    return out;
}

impl invalidate_path(ls: StudioLangServer, path: str) -> list[str] {
    real = os.path.realpath(path);
    deps = [os.path.realpath(p) for p in ls.client().dependents(real)];
    if os.path.exists(real) {
        with open(real, "r", encoding="utf-8", errors="replace") as fh {
            ls.client().update(real, fh.read());
        }
        ls.client().close(real);
    } else {
        ls.client().forget(real);
    }
    return deps;
}

impl shutdown_server(ls: StudioLangServer) {
    ls.shutdown();
}

impl type_hints(ls: StudioLangServer, path: str) -> list[tuple[int, int, str]] {
    return [
        (h.line - 1, h.col - 1, h.label)
        for h in ls.client().assignment_hints(path)
    ];
}
