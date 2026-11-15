impl agent_catalog(repo_root: Path) -> list[IndexDoc] {
    found: list[IndexDoc] = [];
    for d in docs_from_tree(repo_root / DOCS_DIR) {
        found.append(d);
    }
    guides = repo_root / GUIDES_DIR;
    if guides.is_dir() {
        for path in sorted(guides.glob("*.md")) {
            text = path.read_text(encoding="utf-8");
            found.append(
                index_doc(
                    "guide",
                    path.stem,
                    "guide " + path.stem,
                    "jac guide " + path.stem,
                    text
                )
            );
        }
    }
    examples = repo_root / EXAMPLES_DIR;
    if examples.is_dir() {
        for path in sorted(examples.rglob("*.jac")) {
            rel = str(path.relative_to(repo_root)).replace(os.sep, "/");
            if any([rel.startswith(prefix) for prefix in SKIP_EXAMPLES]) {
                continue;
            }
            try {
                text = path.read_text(encoding="utf-8");
            } except Exception {
                continue;
            }
            found.append(index_doc("example", rel, "example " + rel, rel, text[:6000]));
        }
    }
    return found;
}

impl open_toolbox(repo_root: Path, catalog: list[IndexDoc], note: Callable) -> None {
    TOOLBOX["root"] = repo_root;
    TOOLBOX["catalog"] = catalog;
    TOOLBOX["note"] = note;
}

impl _toolbox_note(text: str) -> None {
    note = TOOLBOX.get("note");
    if note is not None {
        note("read", text);
    }
}

impl _repo_path(doc: IndexDoc) -> str {
    if doc.kind == "docs" {
        return DOCS_DIR + "/" + doc.key;
    }
    if doc.kind == "guide" {
        return GUIDES_DIR + "/" + doc.key + ".md";
    }
    return doc.key;
}

impl search_jac(query: str) -> list[str] {
    catalog: list[IndexDoc] = TOOLBOX.get("catalog") or [];
    hits = search(catalog, query, 6);
    _toolbox_note("searched: " + query);
    return [
        _repo_path(h.doc) + ": " + h.doc.title + ": " + excerpt(h.doc, query, 400)
        for h in hits
    ];
}

impl read_jac_file(path: str) -> str {
    repo_root: Path | None = TOOLBOX.get("root");
    if repo_root is None {
        return "the repository is not available";
    }
    clean = path.split("#")[0].strip().lstrip("/");
    if ".." in clean.split("/") {
        return "paths may not leave the repository";
    }
    if not any(
        [clean.startswith(prefix) for prefix in [DOCS_DIR, GUIDES_DIR, EXAMPLES_DIR]]
    ) {
        return "only the docs, the guides and the examples can be read";
    }
    target = repo_root / clean;
    if not target.is_file() {
        return "no such file: " + clean;
    }
    _toolbox_note("read " + clean);
    return target.read_text(encoding="utf-8")[:READ_LIMIT];
}

impl read_jac_guide(name: str) -> str {
    return read_jac_file(GUIDES_DIR + "/" + name.strip().removesuffix(".md") + ".md");
}

impl list_jac_guides -> list[str] {
    repo_root: Path | None = TOOLBOX.get("root");
    if repo_root is None {
        return [];
    }
    return [p.stem for p in sorted((repo_root / GUIDES_DIR).glob("*.md"))];
}
