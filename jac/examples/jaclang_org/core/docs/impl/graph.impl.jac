impl trace_route.name_page with DocPage entry {
    if here.name != "index" {
        self.segs.insert(0, here.name);
    }
    visit [<-:Contains:<-];
}

impl trace_route.climb_dir with DocDir entry {
    self.segs.insert(0, here.name);
    visit [<-:Contains:<-];
}

impl _route_up(target: object) -> str {
    climbed = (target spawn trace_route()) as trace_route;
    return "/".join(climbed.segs);
}

impl slugify(t: str) -> str {
    t = t.strip().lower();
    t = re.sub(r"[`*_\[\]()]", "", t);
    t = re.sub(r"[^a-z0-9\- ]", "", t);
    t = re.sub(r"\s+", "-", t).strip("-");
    return t;
}

impl _pretty(name: str) -> str {
    if name in DIR_TITLES {
        return DIR_TITLES[name];
    }
    return name.replace("-", " ").replace("_", " ").title();
}

impl toc_of(text: str) -> list[TocEntry] {
    toc: list[TocEntry] = [];
    fenced = False;
    for ln in text.split("\n") {
        if ln.strip().startswith("```") {
            fenced = not fenced;
        } elif not fenced {
            if ln.startswith("## ") {
                t = ln[3:].strip();
                toc.append(TocEntry(level=2, text=t, anchor=slugify(t)));
            } elif ln.startswith("### ") {
                t = ln[4:].strip();
                toc.append(TocEntry(level=3, text=t, anchor=slugify(t)));
            }
        }
    }
    return toc;
}

impl route_of(version: str, rel: str) -> str {
    p = rel;
    if p.endswith(".md") {
        p = p[:-3];
    }
    if p.endswith("/index") {
        p = p[:-6];
    }
    if p == "index" {
        p = "";
    }
    return ("/docs/" + version + "/" + p).rstrip("/");
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
        m = re.`match(r"https?://docs\.jaseci\.org/?(.*)", href);
        if m {
            tail = (m.group(1) as str).strip("/");
            return ("/docs/" + version + "/" + tail).rstrip("/") + anchor;
        }
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
    containers: list = [v];
    dirs: list[DocDir] = [];
    pages: list[DocPage] = [];
    i = 0;
    while i < len(containers) {
        cur = containers[i];
        i += 1;
        for d in [cur-->[?:DocDir]] {
            dirs.append(d);
            containers.append(d);
        }
        for p in [cur-->[?:DocPage]] {
            pages.append(p);
        }
    }
    for p in pages {
        del p;
    }
    for d in dirs {
        del d;
    }
    del v;
}

impl _teardown_hub(hub: DocsHub) {
    for v in [hub->:HasVersion:->[?:DocVersion]] {
        _teardown_version(v);
    }
    del hub;
}

impl _sweep_stale(keep: DocsHub) {
    for h in [root.shared-->[?:DocsHub]] {
        if jid(h) != jid(keep) {
            _teardown_hub(h);
        }
    }
    best: dict[str, DocVersion] = {};
    for v in [keep->:HasVersion:->[?:DocVersion]] {
        cur = best.get(v.label);
        if cur is None or v.fetched_at > cur.fetched_at {
            best[v.label] = v;
        }
    }
    for v in [keep->:HasVersion:->[?:DocVersion]] {
        if jid(best[v.label]) != jid(v) {
            _teardown_version(v);
        }
    }
}

impl _get_hub -> DocsHub | None {
    hubs = [root.shared-->[?:DocsHub]];
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
    m = re.`match(r"^v(\d+)\.(\d+)$", label);
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
    for v in [root.shared-->[?:DocsHub]->:HasVersion:->[?:DocVersion]] {
        cur = best.get(v.label);
        if cur is None or v.fetched_at > cur.fetched_at {
            best[v.label] = v;
        }
    }
    labels = sorted(
        [
            l
            for l in best.keys()
            if _series_of(l) is not None
        ],
        key=lambda (l: str) { _series_of(l) as tuple[int, int]; },
        reverse=True
    )
        + sorted(
            [
                l
                for l in best.keys()
                if _series_of(l) is None
            ]
        );
    return [
        VersionInfo(
            label=best[l].label,
            jac_version=best[l].jac_version,
            pages=best[l].pages,
            fetched_at=best[l].fetched_at
        ) for l in labels
    ];
}

impl place_page.place with DocContainer entry {
    if self.segs {
        nxt = self.segs[0];
        self.segs = self.segs[1:];
        visit [-->[?:DocDir, name==nxt]] else {
            fresh = (
                here +>:Contains():+> DocDir(name=nxt, title=_pretty(nxt))
            ) as DocDir;
            visit fresh;
        }
    } else {
        here +>:Contains():+> DocPage(
            name=self.name,
            title=self.title,
            order=self.order,
            md_lines=self.md_lines,
            toc=self.toc
        );
    }
}

impl collect_tree.fold_dir with DocDir exit {
    (kids, kid_pages) = self.fold_children(here);
    d_order = kids[0].order if kids else 9000;

    if here.order != d_order {
        here.order = d_order;
    }
    self.folded[jid(here)] = TreeNode(
        kind="dir",
        name=here.name,
        title=here.title,
        path=_route_up(here),
        order=d_order,
        children=kids
    );
    self.folded_seq[jid(here)] = kid_pages;
}

impl collect_tree.fold_children(
    container: object
) -> tuple[list[TreeNode], list[DocPage]] {
    dirs = [container-->[?:DocDir]];
    pages = [container-->[?:DocPage]];
    dirs.sort(key=lambda (d: DocDir) { d.order; });
    pages.sort(key=lambda (p: DocPage) { p.order; });
    tree_out: list[TreeNode] = [];
    seq_out: list[DocPage] = [];
    (di, pi) = (0, 0);
    while di < len(dirs) or pi < len(pages) {
        take_dir = di < len(dirs)
            and (pi >= len(pages) or dirs[di].order <= pages[pi].order);
        if take_dir {
            tree_out.append(self.folded[jid(dirs[di])]);
            seq_out.extend(self.folded_seq[jid(dirs[di])]);
            di += 1;
        } else {
            p = pages[pi];
            tree_out.append(
                TreeNode(
                    kind="page",
                    name=p.name,
                    title=p.title,
                    path=_route_up(p),
                    order=p.order
                )
            );
            seq_out.append(p);
            pi += 1;
        }
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
    self.segs = [
        s
        for s in self.path.split("/")
        if s
    ];
    visit _version(self.version) else {
        report None;
    }
}

impl doc_page.descend with DocContainer entry {
    if self.segs {
        nxt = self.segs[0];
        self.segs = self.segs[1:];
        visit [-->[?:DocDir, name==nxt]] else {
            visit [-->[?:DocPage, name==nxt]] else {
                self.missing = True;
                self.segs = [];
                self.settle(here);
            }
        }
        return;
    }
    self.settle(here);
}

impl doc_page.note_dir with DocDir entry {
    self.route.append(here.name);
    self.crumbs.append(Crumb(title=here.title, path="/".join(self.route)));
}

impl doc_page.deliver with DocPage entry {
    landed = self.route + ([here.name] if here.name != "index" else []);
    prevs = [here<-:NextPage:<-[?:DocPage]];
    nexts = [here->:NextPage:->[?:DocPage]];
    report DocPageView(
        version=self.version,
        path="/".join(landed),
        title=here.title,
        md_lines=here.md_lines,
        toc=here.toc,
        crumbs=self.crumbs,
        missing=self.missing,
        prev_page=PageRef(title=prevs[0].title, path=_route_up(prevs[0]))
            if prevs
            else None,
        next_page=PageRef(title=nexts[0].title, path=_route_up(nexts[0]))
            if nexts
            else None
    );
}

impl doc_page.settle(container: object) {
    visit [container-->[?:DocPage, name=="index"]] else {
        best_page: DocPage | None = None;
        bp_order = 999999;
        for p in [container-->[?:DocPage]] {
            if p.order < bp_order {
                best_page = p;
                bp_order = p.order;
            }
        }
        best_dir: DocDir | None = None;
        bd_order = 999999;
        for d in [container-->[?:DocDir]] {
            if d.order < bd_order {
                best_dir = d;
                bd_order = d.order;
            }
        }
        if best_page is not None and bp_order <= bd_order {
            visit best_page as DocPage;
        } elif best_dir is not None {
            visit best_dir as DocDir;
        } else {
            report None;
        }
    }
}

impl _flatten_tree_pages(nodes: list[TreeNode]) -> list[TreeNode] {
    out: list[TreeNode] = [];
    for n in nodes {
        if n.kind == "page" {
            out.append(n);
        } else {
            out.extend(_flatten_tree_pages(n.children));
        }
    }
    return out;
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
        return "# Jac\n\nThe docs index is still syncing; try again shortly.\n";
    }
    walked = (vers[0] spawn collect_tree()) as collect_tree;
    by_route: dict[str, DocPage] = {};
    for p in walked.seq {
        by_route[_route_up(p)] = p;
    }
    lines: list[str] = [LLMS_HEADER];
    for section in walked.tree {
        entries = _flatten_tree_pages(section.children)
            if section.kind == "dir"
            else [section];
        if not entries {
            continue;
        }
        lines.append("## " + section.title);
        lines.append("");
        for pg in entries {
            page = by_route.get(pg.path);
            desc = _first_prose(page.md_lines) if page is not None else "";
            url = SITE_ORIGIN + "/docs/latest/" + pg.path;
            lines.append(
                "- [" + pg.title + "](" + url + ")" + ((": " + desc) if desc else "")
            );
        }
        lines.append("");
    }
    return "\n".join(lines);
}
