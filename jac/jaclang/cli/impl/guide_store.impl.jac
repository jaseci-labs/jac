"""Implementation of the shared guide store."""

import from pathlib { Path }

# Diagnostic codes that map directly to a specific guide. A code listed here
# wins over the category fallback below.
glob _CODE_GUIDE_MAP: dict[str, str] = {"W0064": "jac-fullstack-patterns",},
     # Fallback by diagnostic Category value when no exact code match is found.
     _CATEGORY_GUIDE_MAP: dict[str, str] = {"type": "jac-types",};

impl guides_dir -> Path {
    import jaclang;
    pkg_file = jaclang.__file__;
    if pkg_file is None {
        raise RuntimeError("jaclang package location is unavailable");
    }
    return Path(pkg_file).parent / "cli" / "skills";
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
    if lines and lines[0].strip() == "---" {
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
                    if key == "name" and value {
                        name = value;
                    } elif key == "description" {
                        description = value;
                    }
                }
            }
            body = "\n".join(lines[end_idx + 1:]).strip();
        }
    }
    return Guide(name=name, description=description, body=body, path=str(path));
}

impl list_guides -> list[Guide] {
    gdir = guides_dir();
    if not gdir.is_dir() {
        return [];
    }
    guides: list[Guide] = [];
    for f in sorted(gdir.glob("*.md")) {
        g = parse_guide(f);
        if g is not None {
            guides.append(g);
        }
    }
    return guides;
}

impl get_guide(name: str) -> Guide | None {
    return parse_guide(guides_dir() / f"{name}.md");
}

impl search_guides(query: str) -> list[Guide] {
    q = query.lower().strip();
    if not q {
        return list_guides();
    }
    matches: list[Guide] = [];
    for g in list_guides() {
        haystack = f"{g.name}\n{g.description}\n{g.body}".lower();
        if q in haystack {
            matches.append(g);
        }
    }
    return matches;
}

impl guide_for_diagnostic(code: str, category: str = "") -> str | None {
    name = _CODE_GUIDE_MAP.get(code);
    if name is None and category {
        name = _CATEGORY_GUIDE_MAP.get(category);
    }
    if name is None {
        return None;
    }
    if (guides_dir() / f"{name}.md").exists() {
        return name;
    }
    return None;
}
