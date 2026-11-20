impl trace_sections.leave_page with DocPage entry {
    visit [<-:Contains:<-];
}

impl trace_sections.climb with DocSection entry {
    self.titles.insert(0, here.title);
    visit [<-:Contains:<-];
}

impl sections_of(page: DocPage) -> list[str] {
    climbed = (page spawn trace_sections()) as trace_sections;
    return climbed.titles;
}

impl slugify(t: str) -> str {
    t = t.strip().lower();
    t = re.sub(r"[`*_\[\]()]", "", t);
    t = re.sub(r"[^a-z0-9\- ]", "", t);
    t = re.sub(r"\s+", "-", t).strip("-");
    return t;
}

impl _pretty(name: str) -> str {
    return name.replace("-", " ").replace("_", " ").title();
}

impl toc_of(text: str) -> list[TocEntry] {
    toc: list[TocEntry] = [];
    fenced = False;
    for ln in text.split("\n") {
        if ln.strip().startswith("```") {
            fenced = not fenced;
        } elif not fenced {
            level = 2 if ln.startswith("## ") else (3 if ln.startswith("### ") else 0);
            if level {
                t = ln[level + 1:].strip();
                anchor = "";
                m = re.search(r"\s*\{#([A-Za-z0-9_\-]+)\}\s*$", t);
                if m {
                    anchor = m.group(1) as str;
                    t = t[:m.start()].rstrip();
                }
                toc.append(TocEntry(level=level, text=t, anchor=anchor or slugify(t)));
            }
        }
    }
    return toc;
}

impl page_name(file: str) -> str {
    if file in INDEX_FILES {
        return "index";
    }
    return file[:-3] if file.endswith(".md") else file;
}

impl page_path(rel: str) -> str {
    parts = rel.split("/");
    name = page_name(parts[-1]);
    return "/".join(parts[:-1] + ([] if name == "index" else [name]));
}

impl route_of(version: str, rel: str) -> str {
    return ("/docs/" + version + "/" + page_path(rel)).rstrip("/");
}

impl rewrite_href(href: str, version: str, cur_dir: str) -> str {
    if href.startswith("#") or href.startswith("mailto:") {
        return href;
    }
    anchor = "";
    if "#" in href {
        pos = href.index("#");
        anchor = href[pos:];
        href = href[:pos];
    }
    if href.startswith("http://") or href.startswith("https://") {
        return href + anchor;
    }
    low = href.lower();
    is_img = low.endswith(".png")
        or low.endswith(".svg")
        or low.endswith(".gif")
        or low.endswith(".jpg")
        or low.endswith(".jpeg")
        or low.endswith(".webp");
    resolved = os.path.normpath(os.path.join(cur_dir, href)).replace(os.sep, "/");
    while resolved.startswith("../") {
        resolved = resolved[3:];
    }
    if is_img {
        if "assets/" in resolved {
            pos = resolved.index("assets/");
            return "/static/assets/docsmedia/" + resolved[pos + 7:];
        }
        return href + anchor;
    }
    if href.endswith(".md") or href.endswith("/") or href == "." or href == ".." {
        return route_of(version, resolved) + anchor;
    }
    return href + anchor;
}

impl _teardown_version(v: DocVersion) {
    containers: list[DocContainer] = [v];
    sections: list[DocSection] = [];
    pages: list[DocPage] = [];
    i = 0;
    while i < len(containers) {
        cur = containers[i];
        i += 1;
        for s in [cur ->:Contains:-> [?:DocSection]] {
            sections.append(s);
            containers.append(s);
        }
        for p in [cur ->:Contains:-> [?:DocPage]] {
            pages.append(p);
        }
    }
    for p in pages {
        del p;
    }
    for s in sections {
        del s;
    }
    del v;
}

impl _teardown_hub(hub: DocsHub) {
    for v in [hub ->:HasVersion:-> [?:DocVersion]] {
        _teardown_version(v);
    }
    del hub;
}

impl _sweep_stale(keep: DocsHub) {
    for h in [root.shared --> [?:DocsHub]] {
        if jid(h) != jid(keep) {
            _teardown_hub(h);
        }
    }
    best: dict[str, DocVersion] = {};
    for v in [keep ->:HasVersion:-> [?:DocVersion]] {
        cur = best.get(v.label);
        if cur is None or v.fetched_at > cur.fetched_at {
            best[v.label] = v;
        }
    }
    for v in [keep ->:HasVersion:-> [?:DocVersion]] {
        if jid(best[v.label]) != jid(v) {
            _teardown_version(v);
        }
    }
}

impl _get_hub -> DocsHub | None {
    hubs = [root.shared --> [?:DocsHub]];
    if not hubs {
        return None;
    }
    best = hubs[0];
    for h in hubs {
        if h.built_at > best.built_at {
            best = h;
        }
    }
    return best;
}

impl _series_of(label: str) -> tuple[int, int] | None {
    m = re.match(r"^v(\d+)\.(\d+)$", label);
    if not m {
        return None;
    }
    return (int(m.group(1)), int(m.group(2)));
}

impl _latest_label(labels: list[str]) -> str {
    best: tuple[int, int] | None = None;
    best_label = "";
    for l in labels {
        mm = _series_of(l);
        if mm is None {
            continue;
        }
        if best is None or mm > best {
            best = mm;
            best_label = l;
        }
    }
    if best_label != "" {
        return best_label;
    }
    return "dev" if "dev" in labels else "";
}

impl _version_list -> list[VersionInfo] {
    best: dict[str, DocVersion] = {};
    for v in [root.shared --> [?:DocsHub] ->:HasVersion:-> [?:DocVersion]] {
        cur = best.get(v.label);
        if cur is None or v.fetched_at > cur.fetched_at {
            best[v.label] = v;
        }
    }
    labels = sorted(
        [l for l in best.keys() if _series_of(l) is not None],
        key=lambda (l: str) { _series_of(l) as tuple[int, int] },
        reverse=True,
    )
        + sorted([l for l in best.keys() if _series_of(l) is None]);
    return [
        VersionInfo(
            label=best[l].label,
            version=best[l].version,
            pages=best[l].pages,
            fetched_at=best[l].fetched_at,
        )
        for l in labels
    ];
}

impl place_page.place with DocContainer entry {
    if self.trail {
        nxt = self.trail[0];
        self.trail = self.trail[1:];
        visit [->:Contains:-> [?:DocSection, title == nxt]] else {
            fresh = (here +>:Contains():+> DocSection(title=nxt)) as DocSection;
            visit fresh;
        }
    } else {
        here +>:Contains():+> DocPage(
            path=self.path,
            title=self.title,
            description=self.description,
            md_lines=self.md_lines,
            toc=self.toc,
        );
    }
}

impl collect_tree.scan with DocContainer entry {
    visit [->:Contains:->];
}

impl collect_tree.fold_page with DocPage exit {
    self.folded[jid(here)] = TreeNode(kind="page", title=here.title, path=here.path);
    self.folded_seq[jid(here)] = [here];
}

impl collect_tree.fold_section with DocSection exit {
    (kids, kid_pages) = self.gather(here);
    self.folded[jid(here)] = TreeNode(kind="section", title=here.title, children=kids);
    self.folded_seq[jid(here)] = kid_pages;
}

impl collect_tree.fold_version with DocVersion exit {
    (self.tree, self.seq) = self.gather(here);
}

impl collect_tree.gather(container: DocContainer) -> tuple[list[TreeNode], list[DocPage]] {
    tree_out: list[TreeNode] = [];
    seq_out: list[DocPage] = [];
    for kid in [container ->:Contains:->] {
        tree_out.append(self.folded[jid(kid)]);
        seq_out.extend(self.folded_seq[jid(kid)]);
    }
    return (tree_out, seq_out);
}

impl DocVersion.tree -> list[TreeNode] {
    walked = (self spawn collect_tree()) as collect_tree;
    return walked.tree;
}

impl DocVersion.reading_order -> list[DocPage] {
    walked = (self spawn collect_tree()) as collect_tree;
    return walked.seq;
}

impl doc_tree(version: str = "latest") -> DocTree | None {
    vers = _version(version);
    if not vers {
        return None;
    }
    return DocTree(version=version, tree=vers[0].tree());
}

impl doc_page.start with Root entry {
    visit _version(self.version) else {
        report None;
    }
}

impl doc_page.find with DocVersion entry {
    asked = [s for s in self.path.split("/") if s];
    found = (here spawn find_page(asked=asked)) as find_page;
    page = found.page;
    if page is None {
        report None;
        return;
    }
    self.missing = found.reach < len(asked);
    visit page;
}

impl doc_page.deliver with DocPage entry {
    prevs = [here <-:NextPage:<- [?:DocPage]];
    nexts = [here ->:NextPage:-> [?:DocPage]];
    report DocPageView(
        version=self.version,
        path=here.path,
        title=here.title,
        md_lines=here.md_lines,
        toc=here.toc,
        sections=sections_of(here),
        missing=self.missing,
        prev_page=PageRef(title=prevs[0].title, path=prevs[0].path) if prevs else None,
        next_page=PageRef(title=nexts[0].title, path=nexts[0].path) if nexts else None,
    );
}

impl find_page.enter with DocContainer entry {
    visit :0: [->:Contains:->];
}

impl find_page.weigh with DocPage entry {
    held = [s for s in here.path.split("/") if s];
    reach = 0;
    while reach < len(self.asked) and reach < len(held) and self.asked[reach] == held[reach] {
        reach += 1;
    }
    if reach == len(self.asked) == len(held) {
        self.page = here;
        self.reach = reach;
        disengage;
    }
    if reach > self.reach {
        self.page = here;
        self.reach = reach;
    }
}

impl _first_prose(md_lines: list[str]) -> str {
    fenced = False;
    for ln in md_lines {
        s: str = ln.strip();
        if s.startswith("```") {
            fenced = not fenced;
            continue;
        }
        if fenced or not s {
            continue;
        }
        if s.startswith(("#", "!", "|", "<", ">", "-", "*", "=", "?")) {
            continue;
        }
        s = re.sub(r"\[([^\]]*)\]\(([^)]*)\)", r"\1", s);
        s = re.sub(r"[*_`]", "", s);
        s = " ".join(s.split());
        if len(s) > 160 {
            s = s[:160].rsplit(" ", 1)[0].rstrip(" ,;:") + " ...";
        }
        return s;
    }
    return "";
}

impl llms_txt -> str {
    vers = _version("latest");
    if not vers {
        return "# jac\n\nThe docs index is still syncing; try again shortly.\n";
    }
    walked = (vers[0] spawn collect_tree()) as collect_tree;
    by_path: dict[str, DocPage] = {};
    for p in walked.seq {
        by_path[p.path] = p;
    }
    lines: list[str] = [LLMS_HEADER];
    _llms_sections(walked.tree, [], by_path, lines);
    return "\n".join(lines);
}

impl _llms_sections(
    nodes: list[TreeNode], trail: list[str], by_path: dict[str, DocPage], lines: list[str]
) {
    if trail {
        pages = [n for n in nodes if n.kind == "page"];
        if pages {
            lines.extend(["## " + ": ".join(trail), ""]);
            lines.extend([_llms_entry(pg, by_path) for pg in pages]);
            lines.append("");
        }
    }
    for n in nodes {
        if n.kind == "section" {
            _llms_sections(n.children, trail + [n.title], by_path, lines);
        } elif not trail {
            # A page nav.json names outside every section heads itself.
            lines.extend(["## " + n.title, "", _llms_entry(n, by_path), ""]);
        }
    }
}

impl _llms_entry(pg: TreeNode, by_path: dict[str, DocPage]) -> str {
    page = by_path.get(pg.path);
    desc = (page.description or _first_prose(page.md_lines)) if page is not None else "";
    url = SITE_ORIGIN + "/docs/latest/" + pg.path;
    return "- [" + pg.title + "](" + url + ")" + ((": " + desc) if desc else "");
}

impl _version(wanted: str) -> list[DocVersion] {
    all_vers = [root.shared --> [?:DocsHub] ->:HasVersion:-> [?:DocVersion]];
    if wanted == "latest" {
        lab = _latest_label([v.label for v in all_vers]);
        if lab != "" {
            wanted = lab;
        }
    }
    vers = [v for v in all_vers if v.label == wanted];
    if not vers {
        return [];
    }
    best = vers[0];
    for v in vers {
        if v.fetched_at > best.fetched_at {
            best = v;
        }
    }
    return [best];
}

impl docs_status -> DocsStatus {
    hub = _get_hub();
    if hub is None {
        return DocsStatus();
    }
    infos = _version_list();
    return DocsStatus(
        ready=True,
        built_at=hub.built_at,
        latest_label=_latest_label([v.label for v in infos]),
        versions=infos,
    );
}
