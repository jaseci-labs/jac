impl tokens_of(text: str) -> list[str] {
    return [
        w
        for w in re.findall(r"[a-z0-9_]+", text.lower())
        if len(w) > 1 and w not in STOP_WORDS
    ];
}

impl index_doc(kind: str, key: str, title: str, href: str, text: str) -> IndexDoc {
    terms: dict[str, int] = {};
    for w in tokens_of(text) {
        terms[w] = terms.get(w, 0) + 1;
    }
    for w in tokens_of(title) {
        terms[w] = terms.get(w, 0) + TITLE_WEIGHT;
    }
    return IndexDoc(
        kind=kind,
        key=key,
        title=title,
        href=href,
        text=text,
        terms=terms,
        length=sum(terms.values())
    );
}

impl docs_route(rel: str) -> str {
    p = rel[:-3] if rel.endswith(".md") else rel;
    if p.endswith("/index") {
        p = p[:-6];
    }
    if p == "index" {
        p = "";
    }
    return ("/docs/latest/" + p).rstrip("/");
}

impl heading_anchor(heading: str) -> tuple[str, str] {
    text = heading.strip();
    m = re.search(r"\s*\{#([A-Za-z0-9_\-]+)\}\s*$", text);
    if m {
        return (text[:m.start()].rstrip(), m.group(1) as str);
    }
    slug = text.lower();
    slug = re.sub(r"[`*_\[\]()]", "", slug);
    slug = re.sub(r"[^a-z0-9\- ]", "", slug);
    slug = re.sub(r"\s+", "-", slug).strip("-");
    return (text, slug);
}

impl page_sections(text: str) -> list[tuple[str, str, str]] {
    sections: list[tuple[str, str, str]] = [];
    heading = "";
    anchor = "";
    body: list[str] = [];
    fenced = False;
    for ln in text.split("\n") {
        if ln.strip().startswith("```") {
            fenced = not fenced;
        }
        if not fenced and ln.startswith("## ") {
            sections.append((heading, anchor, "\n".join(body)));
            (heading, anchor) = heading_anchor(ln[3:]);
            body = [];
            continue;
        }
        body.append(ln);
    }
    sections.append((heading, anchor, "\n".join(body)));
    return [
        sec
        for sec in sections
        if sec[2].strip()
    ];
}

impl docs_from_tree(ddir: Path) -> list[IndexDoc] {
    found: list[IndexDoc] = [];
    if not ddir.is_dir() {
        return found;
    }
    for path in sorted(ddir.rglob("*.md")) {
        rel = str(path.relative_to(ddir)).replace(os.sep, "/");
        try {
            text = path.read_text(encoding="utf-8");
        } except Exception {
            continue;
        }
        if text.startswith("---") {
            end = text.find("\n---", 3);
            if end > 0 {
                text = text[end + 4:];
            }
        }
        title = "";
        m = re.search(r"^# (.+)$", text, re.MULTILINE);
        if m {
            title = (m.group(1) as str).strip();
        }
        page_title = title or rel;
        route = docs_route(rel);
        for (heading, anchor, body) in page_sections(text) {
            if heading {
                found.append(
                    index_doc(
                        "docs",
                        rel + "#" + anchor,
                        page_title + " › " + heading,
                        route + "#" + anchor,
                        body
                    )
                );
            } else {
                found.append(index_doc("docs", rel, page_title, route, body));
            }
        }
    }
    return found;
}

impl search(docs: list[IndexDoc], query: str, limit: int = 8) -> list[IndexHit] {
    wanted = list(dict.fromkeys(tokens_of(query)));
    if not wanted or not docs {
        return [];
    }
    total = len(docs);
    avg = sum([d.length for d in docs]) / total or 1.0;
    df: dict[str, int] = {};
    for w in wanted {
        df[w] = len(
            [
                d
                for d in docs
                if w in d.terms
            ]
        );
    }
    hits: list[IndexHit] = [];
    for d in docs {
        score = 0.0;
        for w in wanted {
            tf = d.terms.get(w, 0);
            if not tf {
                continue;
            }
            idf = math.log(1.0 + (total - df[w] + 0.5) / (df[w] + 0.5));
            norm = tf + BM25_K1 * (1.0 - BM25_B + BM25_B * d.length / avg);
            score += idf * tf * (BM25_K1 + 1.0) / norm;
        }
        if score > 0.0 {
            hits.append(IndexHit(doc=d, score=score));
        }
    }
    hits.sort(key=lambda (h: IndexHit) { -h.score; });
    return hits[:limit];
}

impl excerpt(doc: IndexDoc, query: str, size: int = 700) -> str {
    text = doc.text;
    lowered = text.lower();
    start = 0;
    for w in tokens_of(query) {
        at = lowered.find(w);
        if at >= 0 {
            start = max(0, at - size // 4);
            break;
        }
    }
    return text[start:start + size].strip();
}
