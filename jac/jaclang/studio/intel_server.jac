import os;
import sys;

import from jaclang.lsp.protocol { uris }

obj StudioLangServer(JacLangServer) {
    has last_error: str = "";

    def debug(msg: str) -> None;
    def log_error(message: str) -> None;
    def log_warning(message: str) -> None;
    def log_info(message: str) -> None;
}

impl StudioLangServer.debug(msg: str) -> None {}

impl StudioLangServer.log_error(message: str) -> None {
    self.last_error = message;
}

impl StudioLangServer.log_warning(message: str) -> None {}

impl StudioLangServer.log_info(message: str) -> None {}

def new_server(root_dir: str) -> StudioLangServer;

def uri_of(path: str) -> str;

def path_of(uri: str) -> str;

def head_of(path: str) -> str;

def unit_files(head: str) -> list[str];

def read_lines(path: str) -> list[str];

def sem_style(types: list[str], mods: list[str], tok_type: int, tok_mods: int) -> str;

def decode_tokens(data: list[int]) -> list[tuple[int, int, int, str]];

def defining_symbol(sym: any) -> any;

def symbol_info(nd: any) -> dict[str, any];

def alert_tuple(
    alert: any, severity: str
) -> tuple[str, str, str, str, int, int, int, int];

def new_cancel_token -> CancelToken;

def check_head(
    ls: StudioLangServer,
    head: str,
    max_apps: int = 0,
    cancel: (CancelToken | None) = None
) -> dict[str, any];

def hover_at(ls: StudioLangServer, path: str, line: int, col: int) -> (str | None);

def location_dict(loc: any, with_text: bool = False) -> dict[str, any];

def definition_at(
    ls: StudioLangServer, path: str, line: int, col: int
) -> (dict[str, any] | None);

def references_at(
    ls: StudioLangServer, path: str, line: int, col: int
) -> list[dict[str, any]];

def invalidate_path(ls: StudioLangServer, path: str) -> list[str];

def shutdown_server(ls: StudioLangServer);

def type_hints(ls: StudioLangServer, path: str) -> list[tuple[int, int, str]];

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

impl defining_symbol(sym: any) -> any {
    cur = sym;
    seen: set[int] = set();
    while cur is not None and cur.provider is not None and id(cur) not in seen {
        seen.add(id(cur));
        target = cur.provider.definition();
        if target is None or target is cur {
            break;
        }
        cur = target;
    }
    return cur;
}

impl symbol_info(nd: any) -> dict[str, any] {
    info: dict[str, any] = {"name": str(getattr(nd, "value", "") or "")};
    sym = nd?.sym;
    if sym is None {
        return info;
    }
    try {
        d = defining_symbol(sym) or sym;
        info["name"] = d.sym_name;
        info["kind"] = d.sym_type.value;
        info["dotted"] = d.sym_dotted_name;
        decl = d.decl;
        if decl is not None and decl.loc is not None {
            info["decl_path"] = str(decl.loc.mod_path or "");
            info["decl_line"] = int(decl.loc.first_line);
            info["decl_col"] = max(0, int(decl.loc.col_start) - 1);
        }
    } except Exception {}
    return info;
}

impl alert_tuple(
    alert: any, severity: str
) -> tuple[str, str, str, str, int, int, int, int] {
    code = alert.code.code if alert.code else "";
    hint = alert.help_text or (alert.code.help_text if alert.code else "") or "";
    loc = alert.loc;
    return (
        severity,
        str(code),
        str(alert.msg),
        str(hint),
        max(1, int(loc.first_line)),
        max(0, int(loc.col_start) - 1),
        max(1, int(loc.last_line)),
        max(0, int(loc.col_end) - 1)
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
    engine_mod = sys.modules.get(JacLangServer.__module__);
    if max_apps > 0 and engine_mod is not None {
        engine_mod.LSP_SHARED_APP_LIMIT = max_apps;
    }
    files = unit_files(head);
    ls.last_error = "";
    texts = {f: read_lines(f) for f in files};
    ok = ls.type_check_file(uri_of(head), cancel_token=cancel);
    if cancel is not None and cancel.is_set() {
        return {"ok": False, "error": "cancelled", "cancelled": True, "files": {}};
    }
    result: dict[str, any] = {"ok": ok, "error": ls.last_error, "files": {}};
    errors = list(ls.program.errors_had);
    warnings = list(ls.program.warnings_had);
    for f in files {
        sem_rows = decode_tokens(list(ls.get_semantic_tokens(uri_of(f)).data))
            if ok
            else [];
        syms: list[tuple[int, int, int, dict[str, any]]] = [];
        mgr = ls.sem_managers.get(f) if ok else None;
        if mgr is not None {
            for (pos, col_end, length, nd) in mgr.static_sem_tokens {
                syms.append(
                    (pos.line, pos.character, pos.character + length, symbol_info(nd))
                );
            }
        }
        diags = [
            alert_tuple(e, "error")
            for e in errors
            if e.loc.mod_path == f
        ]
            + [
                alert_tuple(w, "warning")
                for w in warnings
                if w.loc.mod_path == f
            ];
        inlays: list[tuple[int, int, str]] = [];
        if ok {
            try {
                inlays += type_hints(ls, f);
            } except Exception {}
            try {
                whole = lspt.Range(
                    start=lspt.Position(line=0, character=0),
                    end=lspt.Position(line=len(texts[f]) + 1, character=0)
                );
                for h in ls.get_inlay_hints(uri_of(f), whole) {
                    lbl = h.label
                        if isinstance(h.label, str)
                        else "".join([str(getattr(p, "value", p)) for p in h.label]);
                    inlays.append(
                        (int(h.position.line), int(h.position.character), lbl)
                    );
                }
            } except Exception {}
        }
        result["files"][f] = {
            "lines": texts[f],
            "sem": sem_rows,
            "syms": syms,
            "diags": diags,
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
    try {
        ls.program.invalidate_module(path);
        return [os.path.realpath(p) for p in ls.program.transitive_dependents(path)];
    } except Exception {
        return [];
    }
}

impl shutdown_server(ls: StudioLangServer) {
    try {
        ls.shutdown();
    } except Exception {}
}

impl type_hints(ls: StudioLangServer, path: str) -> list[tuple[int, int, str]] {
    mod = ls.program.mod.hub.get(path);
    out: list[tuple[int, int, str]] = [];
    if mod is None {
        return out;
    }
    seen: set[int] = set();
    for asg in mod.get_all_sub_nodes(uni.Assignment) {
        if asg.type_tag is not None
            or len(asg.target) != 1
            or not isinstance(asg.target[0], uni.Name) {
            continue;
        }
        tgt = asg.target[0];
        sym = tgt.sym;
        if sym is None or id(sym) in seen {
            continue;
        }
        seen.add(id(sym));
        ty = tgt?.type;
        txt = str(ty) if ty is not None else "";
        if not txt or "Unknown" in txt or len(txt) > 48 {
            continue;
        }
        loc = tgt.loc;
        out.append((loc.first_line - 1, loc.col_end - 1, f": {txt}"));
    }
    return out;
}
