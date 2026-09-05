impl _ancestors_of(d: str) -> list[str] {
    if d == "" {
        return [];
    }
    parts = d.split("/");
    out: list[str] = [];
    acc = "";
    for p in parts {
        acc = p if acc == "" else acc + "/" + p;
        out.append(acc);
    }
    return out;
}

impl _dir_paths(rows: list[dict]) -> list[str] {
    out: list[str] = [];
    for r in rows {
        if r["kind"] == "dir" {
            out.append(r["path"] as str);
        }
    }
    return out;
}

impl _build_rows(tree: list[SourceFile]) -> list[dict] {
    rows: list[dict] = [];
    seen: list[str] = [];
    for f in tree {
        chain = _ancestors_of(f.dir);
        for (di, d) in enumerate(chain) {
            if d not in seen {
                seen.append(d);
                rows.append(
                    {
                        "kind": "dir",
                        "path": d,
                        "name": d.split("/")[-1],
                        "depth": di,
                        "ancestors": chain[0:di],

                    }
                );
            }
        }
        rows.append(
            {
                "kind": "file",
                "path": f.path,
                "name": f.name,
                "depth": len(chain),
                "ancestors": chain,
                "lang": f.language,
                "lines": f.lines,

            }
        );
    }
    return rows;
}

impl SourceBrowser.open_path(path: str) {
    busy = True;
    view = await source_file(path);
    busy = False;
}

impl SourceBrowser.toggle_dir(d: str) {
    if d in closed {
        closed = [
            x
            for x in closed
            if x != d
        ];
    } else {
        closed = closed + [d];
    }
}

impl SourceBrowser.is_visible(row: dict) -> bool {
    for a in (row["ancestors"] as list[str]) {
        if a in closed {
            return False;
        }
    }
    return True;
}
