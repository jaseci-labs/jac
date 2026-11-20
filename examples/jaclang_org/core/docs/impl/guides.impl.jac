impl docs_dir -> Path {
    configured = os.environ.get(DOCS_ENV, "").strip();
    if configured {
        return Path(configured).resolve();
    }
    up = os.path.abspath(__file__);
    for _ in range(5) {
        up = os.path.dirname(up);
    }
    return Path(up) / "docs";
}

impl docs_version(docs_root: Path | None = None) -> str {
    top: Path = docs_root if docs_root is not None else docs_dir();
    above = Path(os.path.dirname(str(top)));
    released = above / "VERSION";
    if released.is_file() {
        try {
            return released.read_text(encoding="utf-8").split("\n")[0].strip();
        } except OSError {
            return "";
        }
    }
    path = above / "jac.toml";
    if not path.is_file() {
        return "";
    }
    try {
        manifest: dict[str, any] = tomllib.loads(path.read_text(encoding="utf-8"));
    } except OSError {
        return "";
    } except ValueError {
        return "";
    }
    project: dict[str, any] = manifest.get("project", {});
    return str(project.get("version", "")).strip();
}

impl parse_guide(path: Path) -> Guide | None {
    if not path.exists() {
        return None;
    }
    try {
        text = path.read_text(encoding="utf-8");
    } except OSError {
        return None;
    }
    name = path.stem;
    description = "";
    body = text;
    lines = text.splitlines();
    if len(lines) > 0 and lines[0].strip() == "---" {
        end_idx = -1;
        i = 1;
        while i < len(lines) {
            if lines[i].strip() == "---" {
                end_idx = i;
                break;
            }
            i += 1;
        }
        if end_idx != -1 {
            for fm in lines[1:end_idx] {
                if ":" in fm {
                    parts = fm.split(":", 1);
                    key = parts[0].strip();
                    value = parts[1].strip();
                    if key == "name" and value != "" {
                        name = value;
                    } elif key == "description" {
                        description = value;
                    }
                }
            }
            body = "\n".join(lines[end_idx + 1:len(lines)]).strip();
        }
    }
    return Guide(name=name, description=description, body=body, path=str(path));
}

impl nav_manifest(docs_root: Path | None = None) -> dict[str, any] {
    top: Path = docs_root if docs_root is not None else docs_dir();
    path = top / "nav.json";
    if not path.is_file() {
        return {};
    }
    try {
        loaded: dict[str, any] = json.loads(path.read_text(encoding="utf-8"));
        return loaded;
    } except OSError {
        return {};
    } except ValueError {
        return {};
    }
}

impl _nav_walk(items: list[any], trail: list[str], pages: list[NavPage]) {
    for it in items {
        if not isinstance(it, dict) {
            continue;
        }
        item: dict[str, any] = it;
        title = str(item.get("title", "")).strip();
        if "page" in item {
            pages.append(
                NavPage(page=str(item["page"]), title=title, order=len(pages), section=trail)
            );
        } elif "items" in item {
            _nav_walk(item["items"], trail + [title], pages);
        }
    }
}

impl nav_pages(docs_root: Path | None = None) -> list[NavPage] {
    pages: list[NavPage] = [];
    nav: list[any] = nav_manifest(docs_root).get("nav", []);
    _nav_walk(nav, [], pages);
    return pages;
}
