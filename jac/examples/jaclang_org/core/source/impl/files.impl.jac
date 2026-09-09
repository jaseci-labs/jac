import os;
import from pathlib { Path }

impl _project_root -> str {
    cur = os.path.dirname(os.path.abspath(__file__));
    while True {
        if os.path.isfile(os.path.join(cur, "jac.toml")) {
            return cur;
        }
        parent = os.path.dirname(cur);
        if parent == cur {
            return os.getcwd();
        }
        cur = parent;
    }
}

impl _language_of(name: str) -> str {
    ext = os.path.splitext(name)[1].lower();
    table = {".jac": "jac", ".toml": "toml", ".css": "css", ".md": "markdown"};
    return table.get(ext, "text");
}

impl _tree_order(f: SourceFile) -> tuple {
    return (0 if f.dir == "" else 1, f.dir, 0 if f.name == "main.jac" else 1, f.name, );
}

impl _walk_sources -> list[SourceFile] {
    proj_root = _project_root();
    found: list[SourceFile] = [];
    for (cur, dirnames, filenames) in os.walk(proj_root) {
        kept = [
            d
            for d in sorted(dirnames)
            if not d.startswith(".") and d not in EXCLUDE_DIRS
        ];
        dirnames.clear();
        dirnames.extend(kept);
        for fname in sorted(filenames) {
            ext = os.path.splitext(fname)[1].lower();
            if ext not in ALLOW_EXT {
                continue;
            }
            full = str(os.path.join(cur, fname));
            rel = str(os.path.relpath(full, proj_root));
            try {
                text = Path(full).read_text(encoding="utf-8");
            } except Exception {
                continue;
            }
            found.append(
                SourceFile(
                    path=rel.replace(os.sep, "/"),
                    dir=os.path.dirname(rel).replace(os.sep, "/"),
                    name=fname,
                    language=_language_of(fname),
                    lines=text.count("\n") + 1,
                )
            );
        }
    }
    return sorted(found, key=_tree_order);
}

impl source_tree -> list[SourceFile] {
    return _walk_sources();
}

impl source_file(path: str) -> SourceView | None {
    allowed = {f.path: f for f in _walk_sources()};
    found = allowed.get(path);
    if found is None {
        return None;
    }
    full = os.path.join(_project_root(), path);
    try {
        text = Path(full).read_text(encoding="utf-8");
    } except Exception {
        return None;
    }
    return SourceView(
        path=path,
        language=found.language,
        size_bytes=os.path.getsize(full),
        lines=found.lines,
        raw_lines=text.split("\n"),
    );
}

impl source_span(
    path: str, needle: str, hl_lines: int = 1, before: int = 3, after: int = 12
) -> SourceSpan | None {
    view = source_file(path);
    if view is None {
        return None;
    }
    hit = -1;
    for (i, ln) in enumerate(view.raw_lines) {
        if needle in ln {
            hit = i;
            break;
        }
    }
    found = hit >= 0;
    anchor = hit if found else 0;
    lo = anchor - before;
    if lo < 0 {
        lo = 0;
    }
    hi = anchor + hl_lines - 1 + after;
    if hi > len(view.raw_lines) - 1 {
        hi = len(view.raw_lines) - 1;
    }
    return SourceSpan(
        path=path,
        language=view.language,
        total_lines=view.lines,
        start=lo + 1,
        hl_from=(anchor + 1) if found else 0,
        hl_to=(anchor + hl_lines) if found else -1,
        found=found,
        raw_lines=view.raw_lines[lo:hi + 1],
    );
}

impl example_sources -> list[SourceView] {
    out: list[SourceView] = [];
    for f in _walk_sources() {
        if f.dir == EXAMPLES_DIR {
            view = source_file(f.path);
            if view is not None {
                out.append(view);
            }
        }
    }
    return out;
}
