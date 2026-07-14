import from pathlib { Path }

glob _CODE_GUIDE_MAP: dict[str, str] = {
         "E0077": "jac-impl-files",
         "W0060": "jac-core-cheatsheet",
         "W0061": "jac-sv-persistence",
         "E1050": "jac-walker-patterns",
         "E1102": "jac-cl-components",
         "E1104": "jac-npm-packages",
         "E2004": "jac-has-fields",
         "E2025": "jac-npm-packages",
         "W2075": "jac-sv-persistence",
         "W3037": "jac-types",

     },
     _CATEGORY_GUIDE_MAP: dict[str, str] = {"type": "jac-types",};

glob GUIDE_GROUP_ORDER: list[str] = [
         "Start here",
         "Language",
         "Graph & OSP",
         "AI",
         "Server",
         "Client & fullstack",
         "Native",
         "Tooling & workflow",
         "Other",

     ],
     _START_HERE_ORDER: list[str] = ["jac-project-kinds", "jac-core-cheatsheet"],
     _GUIDE_GROUP_MAP: dict[str, str] = {
         "jac-project-kinds": "Start here",
         "jac-core-cheatsheet": "Start here",
         "jac-types": "Language",
         "jac-has-fields": "Language",
         "jac-impl-files": "Language",
         "jac-python-interop": "Language",
         "jac-concurrency": "Language",
         "jac-node-edge-patterns": "Graph & OSP",
         "jac-walker-patterns": "Graph & OSP",
         "jac-by-llm": "AI",
         "jac-fullstack-patterns": "Client & fullstack",
         "jac-npm-packages": "Client & fullstack",
         "jac-shadcn-components": "Client & fullstack",
         "jac-desktop-app": "Client & fullstack",
         "jac-mobile-app": "Client & fullstack",
         "jac-scaffold": "Tooling & workflow",
         "jac-config": "Tooling & workflow",
         "jac-testing": "Tooling & workflow",
         "jac-debugging": "Tooling & workflow",
         "jac-packaging": "Tooling & workflow",

     },
     _GUIDE_GROUP_PREFIXES: dict[str, str] = {
         "jac-sv-": "Server",
         "jac-cl-": "Client & fullstack",
         "jac-native": "Native",

     };

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

    for f in sorted(gdir.glob("*.md"), key=lambda (p: Path) { p.stem; }) {
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

impl guide_group(name: str) -> str {
    explicit = _GUIDE_GROUP_MAP.get(name);
    if explicit is not None {
        return explicit;
    }
    for (prefix, group) in _GUIDE_GROUP_PREFIXES.items() {
        if name.startswith(prefix) {
            return group;
        }
    }
    return "Other";
}

impl grouped_guides -> list[tuple[str, list[Guide]]] {
    buckets: dict[str, list[Guide]] = {};

    for g in list_guides() {
        buckets.setdefault(guide_group(g.name), []).append(g);
    }
    start = buckets.get("Start here");
    if start is not None {
        start.sort(
            key=lambda (g: Guide) { (
                _START_HERE_ORDER.index(g.name)
                    if g.name in _START_HERE_ORDER
                    else len(_START_HERE_ORDER)
            ); }
        );
    }
    return [
        (group, buckets[group])
        for group in GUIDE_GROUP_ORDER
        if group in buckets
    ];
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
