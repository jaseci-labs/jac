import json;
import re;
import from pathlib { Path }

glob _CODE_GUIDE_MAP: dict[str, str] = {
         "E0077": "jac-impl-files",
         "E0033": "jac-comptime",
         "E0108": "jac-comptime",
         "E0109": "jac-comptime",
         "W0060": "jac-core-cheatsheet",
         "E1042": "jac-sv-microservices",
         "E1050": "jac-walker-patterns",
         "E1102": "jac-cl-components",
         "E1104": "jac-npm-packages",
         "E1105": "jac-mobui",
         "E1301": "jac-native-memory",
         "E1302": "jac-native-memory",
         "E1303": "jac-native-memory",
         "E1304": "jac-native-memory",
         "E1306": "jac-native-memory",
         "E1307": "jac-native-memory",
         "E1308": "jac-native-memory",
         "E1309": "jac-native-memory",
         "E1311": "jac-native-memory",
         "W1312": "jac-native-memory",
         "E1313": "jac-native-memory",
         "E1314": "jac-native-memory",
         "E1401": "jac-native-memory",
         "E1402": "jac-native-memory",
         "E1403": "jac-native-memory",
         "E1404": "jac-native-memory",
         "E1405": "jac-native-memory",
         "E1406": "jac-native-memory",
         "W1310": "jac-native-memory",
         "E2004": "jac-has-fields",
         "E2025": "jac-npm-packages",
         "E2039": "jac-apps",
         "E2040": "jac-apps",
         "W2039": "jac-apps",
         "W2040": "jac-apps",
         "W2075": "jac-sv-persistence",
         "W3037": "jac-types",
         "E5104": "jac-apps",
         "E5105": "jac-apps",
         "E5106": "jac-apps",
         "E5107": "jac-apps",
         "E5108": "jac-apps",

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
     _START_HERE_ORDER: list[str] = [
         "jac-essentials",
         "jac-project-kinds",
         "jac-apps",
         "jac-core-cheatsheet"
     ],
     _GUIDE_GROUP_MAP: dict[str, str] = {
         "jac-project-kinds": "Start here",
         "jac-essentials": "Start here",
         "jac-core-cheatsheet": "Start here",
         "jac-types": "Language",
         "jac-comptime": "Language",
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
         "jac-mobui": "Client & fullstack",
         "jac-scaffold": "Tooling & workflow",
         "jac-config": "Tooling & workflow",
         "jac-apps": "Start here",
         "jac-testing": "Tooling & workflow",
         "jac-debugging": "Tooling & workflow",
         "jac-packaging": "Tooling & workflow",

     },
     _GUIDE_GROUP_PREFIXES: dict[str, str] = {
         "jac-sv-": "Server",
         "jac-cl-": "Client & fullstack",
         "jac-native": "Native",

     };

glob DOC_CORPUS_ORDER: list[str] = [
         "reference",
         "quick-guide",
         "build",
         "tutorials",
         "internals",
         "community",

     ],
     _DOC_CORPUS_BLURBS: dict[str, str] = {
         "reference": (
             "Exhaustive reference: language semantics, CLI, config, "
             "diagnostics, persistence, plugins"
         ),
         "quick-guide": (
             "Getting started: what Jac is and why, install, vocabulary, "
             "project kinds"
         ),
         "build": (
             "Task-oriented entry points: what to build with Jac and "
             "which pathway fits"
         ),
         "tutorials": (
             "End-to-end worked tutorials: full-stack, AI, native, "
             "production deployment"
         ),
         "internals": ("Compiler architecture and contributor orientation"),
         "community": (
             "Contributing, codebase guide, research, FAQ, breaking "
             "changes, release notes"
         ),

     };

glob _DOC_DESCRIPTION_MAX: int = 180;

impl guides_dir -> Path {
    import jaclang;
    pkg_file = jaclang.__file__;
    if pkg_file is None {
        raise RuntimeError("jaclang package location is unavailable");
    }
    return Path(pkg_file).parent / "cli" / "skills";
}

impl docs_dir -> Path {
    import jaclang;
    pkg_file = jaclang.__file__;
    if pkg_file is None {
        raise RuntimeError("jaclang package location is unavailable");
    }
    return Path(pkg_file).parent / "cli" / "docs";
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

    for f in sorted(gdir.`glob("*.md"), key=lambda (p: Path) { p.stem; }) {
        g = parse_guide(f);
        if g is not None {
            guides.append(g);
        }
    }
    return guides;
}

def _clean_markdown(text: str) -> str {
    text = re.sub(r"!\[[^\]]*\]\([^)]*\)", "", text);
    text = re.sub(r"\[([^\]]*)\]\([^)]*\)", r"\1", text);
    text = re.sub(r"[*_`]", "", text);
    text = re.sub(r"\s*\{#[^}]*\}", "", text);
    return " ".join(text.split());
}

def _derive_description(body: str) -> str {
    title = "";
    para: list[str] = [];
    in_fence = False;

    for raw in body.splitlines() {
        stripped = raw.strip();
        if stripped.startswith("```") {
            if para {
                break;
            }
            in_fence = not in_fence;
            continue;
        }
        if in_fence {
            continue;
        }
        if not stripped {
            if para {
                break;
            }
            continue;
        }
        if stripped.startswith("#") {
            if para {
                break;
            }
            if not title {
                title = stripped.lstrip("#").strip();
            }
            continue;
        }

        if stripped.startswith(("!!!", "???", "===", "<", "|", "---", "- ", "* ")) {
            if para {
                break;
            }
            continue;
        }
        if re.`match(r"^\d+\. ", stripped) or raw.startswith(("    ", "\t")) {
            if para {
                break;
            }
            continue;
        }
        para.append(stripped);
    }
    text = _clean_markdown(" ".join(para)) or _clean_markdown(title);
    if len(text) > _DOC_DESCRIPTION_MAX {
        cut = text[:_DOC_DESCRIPTION_MAX + 1];
        text = cut[:cut.rfind(" ")].rstrip(" ,;:") + " ...";
    }
    return text;
}

def _doc_name(rel: Path) -> str {
    parts = list(rel.parts);
    parts[-1] = rel.stem;

    if parts[-1] == "index" and len(parts) > 2 {
        parts.pop();
    }
    return "/".join(parts);
}

def _load_doc(path: Path, name: str) -> Guide | None {
    g = parse_guide(path);
    if g is None {
        return None;
    }
    description = g.description or _derive_description(g.body);
    return Guide(name=name, description=description, body=g.body, path=g.path);
}

impl list_docs -> list[Guide] {
    ddir = docs_dir();
    if not ddir.is_dir() {
        return [];
    }
    docs: list[Guide] = [];

    for f in sorted(ddir.rglob("*.md"), key=lambda (p: Path) { str(p); }) {
        name = _doc_name(f.relative_to(ddir));
        g = _load_doc(f, name);
        if g is not None {
            docs.append(g);
        }
    }
    return docs;
}

impl doc_corpora -> list[tuple[str, list[Guide]]] {
    buckets: dict[str, list[Guide]] = {};

    for g in list_docs() {
        buckets.setdefault(g.name.split("/")[0], []).append(g);
    }
    ordered = [
        ns
        for ns in DOC_CORPUS_ORDER
        if ns in buckets
    ];
    ordered += [
        ns
        for ns in sorted(buckets)
        if ns not in DOC_CORPUS_ORDER
    ];
    return [(ns, buckets[ns]) for ns in ordered];
}

impl corpus_blurb(ns: str) -> str {
    return _DOC_CORPUS_BLURBS.get(ns, "");
}

impl nav_manifest -> dict {
    path = docs_dir() / "nav.json";
    if not path.is_file() {
        return {};
    }
    try {
        loaded = json.loads(path.read_text(encoding="utf-8"));
    } except (OSError, ValueError) {
        return {};
    }
    return loaded if isinstance(loaded, dict) else {};
}

impl nav_pages -> list[NavPage] {
    pages: list[NavPage] = [];

    def walk(items: list, trail: list[str]) {
        for item in items {
            if not isinstance(item, dict) {
                continue;
            }
            title = str(item.get("title", "")).strip();
            if "page" in item {
                pages.append(
                    NavPage(
                        page=str(item["page"]),
                        title=title,
                        order=len(pages),
                        section=trail
                    )
                );
            } elif "items" in item {
                walk(item["items"] as list, trail + [title]);
            }
        }
    }
    walk(nav_manifest().get("nav", []) as list, []);
    return pages;
}

def _resolve_by_suffix(clean: str) -> Guide | None {
    matches = [
        g
        for g in (list_guides() + list_docs())
        if g.name == clean or g.name.endswith("/" + clean)
    ];
    if len(matches) == 1 {
        return matches[0];
    }
    return None;
}

impl get_guide(name: str) -> Guide | None {
    clean = name.strip().strip("/");
    if not clean or ".." in clean.split("/") {
        return None;
    }
    if "/" not in clean {
        skill = parse_guide(guides_dir() / f"{clean}.md");
        if skill is not None {
            return skill;
        }
    }
    ddir = docs_dir();
    candidates = [ddir / f"{clean}.md"];
    if "/" in clean {
        candidates.append(ddir / clean / "index.md");
    }
    for candidate in candidates {
        if candidate.is_file() {
            return _load_doc(candidate, clean);
        }
    }
    return _resolve_by_suffix(clean);
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

impl grep_guides(
    query: str, max_per_guide: int = 8, max_total: int = 200
) -> list[GrepHit] {
    terms = [
        t
        for t in query.lower().split()
        if t
    ];
    hits: list[GrepHit] = [];

    if not terms {
        return hits;
    }
    for g in (list_guides() + list_docs()) {
        if len(hits) >= max_total {
            break;
        }
        meta = f"{g.name} {g.description}".lower();
        if all([(t in meta) for t in terms]) {
            hits.append(GrepHit(guide=g.name, line_no=0, text=g.description));
        }
        per_guide = 0;
        line_no = 0;
        for line in g.body.splitlines() {
            line_no += 1;
            low = line.lower();
            if all([(t in low) for t in terms]) {
                hits.append(GrepHit(guide=g.name, line_no=line_no, text=line.strip()));
                per_guide += 1;
                if per_guide >= max_per_guide or len(hits) >= max_total {
                    break;
                }
            }
        }
    }
    if hits {
        return hits[:max_total];
    }
    return _doc_level_hits(terms);
}

def _doc_level_hits(terms: list[str]) -> list[GrepHit] {
    if len(terms) < 2 {
        return [];
    }
    scored: list[tuple[int, float, str]] = [];

    for g in (list_guides() + list_docs()) {
        text = f"{g.name}\n{g.description}\n{g.body}".lower();
        matched = len(
            [
                t
                for t in terms
                if t in text
            ]
        );
        if matched >= 2 {
            density = sum([text.count(t) for t in terms]) / max(len(text), 1);
            scored.append((-matched, -density, g.name));
        }
    }
    scored.sort();
    out: list[GrepHit] = [];

    for (neg, _density, name) in scored[:10] {
        matched = -neg;
        if matched == len(terms) {
            detail = (
                f"all {matched} terms appear in this doc "
                f"(no single line has them all) -- open: jac guide {name}"
            );
        } else {
            detail = (
                f"{matched}/{len(terms)} terms appear in this doc -- "
                f"open: jac guide {name}"
            );
        }
        out.append(GrepHit(guide=name, line_no=0, text=detail));
    }
    return out;
}

impl guide_for_diagnostic(code: str, category: str = "") -> str | None {
    name = _CODE_GUIDE_MAP.get(code);
    if name is None and category {
        name = _CATEGORY_GUIDE_MAP.get(category);
    }
    if name is not None and (guides_dir() / f"{name}.md").exists() {
        return name;
    }
    if (docs_dir() / "reference" / "diagnostics.md").is_file() {
        return "reference/diagnostics";
    }
    return None;
}


impl guide_sections(g: Guide) -> list[GuideSection] {
    lines = g.body.splitlines();
    headings: list[tuple[int, int, str, str]] = [];
    counts: dict[str, int] = {};
    fence_char = "";
    fence_length = 0;
    for (i, line) in enumerate(lines) {
        fence = re.match(r"^ {0,3}(`{3,}|~{3,})(.*)$", line);
        if fence is not None {
            marker = fence.group(1);
            if not fence_char {
                fence_char = marker[0];
                fence_length = len(marker);
            } elif marker[0] == fence_char
                and len(marker) >= fence_length
                and not fence.group(2).strip() {
                fence_char = "";
            }
            continue;
        }
        if fence_char {
            continue;
        }
        heading = re.match(r"^ {0,3}(#{1,6})[ \t]+(.+?)\s*$", line);
        if heading is None {
            continue;
        }
        title = re.sub(r"\s+#+\s*$", "", heading.group(2));
        custom = re.search(r"\s+\{:?\s*#([^\s}]+)[^}]*\}\s*$", title);
        if custom is not None {
            title = title[:custom.start()];
        }
        title = _clean_markdown(title);
        base = custom.group(1)
            if custom is not None
            else re.sub(r"[^\w\s-]", "", title.lower());
        base = re.sub(r"[\s-]+", "-", base).strip("-") or "section";
        ordinal = counts.get(base, 0) + 1;
        slug = base if ordinal == 1 else f"{base}-{ordinal}";
        # A literal heading can collide with a generated duplicate suffix.
        while slug in [h[3] for h in headings] {
            ordinal += 1;
            slug = f"{base}-{ordinal}";
        }
        counts[base] = ordinal;
        headings.append((i, len(heading.group(1)), title, slug));
    }
    sections: list[GuideSection] = [];
    for (index, h) in enumerate(headings) {
        end = len(lines);
        for following in headings[index + 1:] {
            if following[1] <= h[1] {
                end = following[0];
                break;
            }
        }
        sections.append(
            GuideSection(
                title=h[2],
                slug=h[3],
                level=h[1],
                line_no=h[0] + 1,
                body="\n".join(lines[h[0]:end]).strip()
            )
        );
    }
    return sections;
}
