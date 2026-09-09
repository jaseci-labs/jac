impl label_of(version: str) -> str {
    m = re.`match(r"^v?(\d+)\.(\d+)", version.strip());
    if not m {
        return "dev";
    }
    return "v" + (m.group(1) as str) + "." + (m.group(2) as str);
}

impl corpus_bundle -> DocBundle {
    bundle = DocBundle(jac_version=resolve_cli_version());
    ddir = docs_dir();
    digest = hashlib.sha1(bundle.jac_version.encode("utf-8"));
    for path in sorted(ddir.rglob("*.md"), key=lambda (p: Path) { str(p); }) {
        rel = str(path.relative_to(ddir)).replace(os.sep, "/");
        g = parse_guide(path);
        if g is None {
            continue;
        }
        bundle.pages[rel] = g.body;
        digest.update(rel.encode("utf-8"));
        digest.update(g.body.encode("utf-8"));
    }
    for np in nav_pages() {
        bundle.nav[np.page] = np;
        digest.update((np.page + "\x00" + np.title).encode("utf-8"));
    }
    bundle.fingerprint = digest.hexdigest();
    return bundle;
}

impl first_h1(text: str) -> str {
    fenced = False;
    for ln in text.split("\n") {
        if ln.strip().startswith("```") {
            fenced = not fenced;
        } elif not fenced and ln.startswith("# ") {
            return ln[2:].strip();
        }
    }
    return "";
}

impl rewrite_links(text: str, version: str, rel: str) -> str {
    cur_dir = os.path.dirname(rel);

    def md_repl(m: re.Match[str]) -> str {
        g1 = (m.group(1) or "") as str;
        g2 = (m.group(2) or "") as str;
        return "[" + g1 + "](" + rewrite_href(g2, version, cur_dir) + ")";
    }
    def img_repl(m: re.Match[str]) -> str {
        g1 = (m.group(1) or "") as str;
        g2 = (m.group(2) or "") as str;
        return "![" + g1 + "](" + rewrite_href(g2, version, cur_dir) + ")";
    }
    def src_repl(m: re.Match[str]) -> str {
        g1 = (m.group(1) or "") as str;
        g2 = (m.group(2) or "") as str;
        g3 = (m.group(3) or "") as str;
        return g1 + rewrite_href(g2, version, cur_dir) + g3;
    }
    def bare_repl(m: re.Match[str]) -> str {
        tail = ((m.group(1) or "") as str).strip("/");
        return ("/docs/" + version + "/" + tail).rstrip("/");
    }
    text = re.sub(r"!\[([^\]]*)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)", img_repl, text);
    text = re.sub(r"(?<!\!)\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)", md_repl, text);
    text = re.sub(r"(src=[\"'])([^\"']+)([\"'])", src_repl, text);
    text = re.sub(r"https?://docs\.jaseci\.org(/[\w\-/#\.]*)?", bare_repl, text);
    return text;
}

impl build_version(bundle: DocBundle) -> DocVersion {
    label = label_of(bundle.jac_version);
    files = bundle.pages;
    log.info("docs sync: growing " + label + " · " + str(len(files)) + " pages");

    ver = DocVersion(
        label=label,
        jac_version=bundle.jac_version,
        fetched_at=now_iso(),
        fingerprint=bundle.fingerprint,
        pages=len(files)
    );

    names = sorted([k for k in files.keys()]);
    fallback = 9000;
    for rel in names {
        parts = rel.split("/");
        raw = rewrite_links(files[rel], label, rel);
        meta = bundle.nav.get(rel);
        title = meta.title if meta is not None else "";
        if not title {
            title = first_h1(raw) or _pretty(parts[-1][:-3]);
        }
        order = meta.order if meta is not None else fallback;
        fallback += 1;
        ver spawn place_page(
            segs=parts[:-1],
            name=parts[-1][:-3],
            title=title,
            order=order,
            md_lines=raw.split("\n"),
            toc=toc_of(raw)
        );
    }

    reading = ver.reading_order();
    for i in range(len(reading) - 1) {
        reading[i] +>:NextPage():+> reading[i + 1];
    }
    return ver;
}

impl corpus_stale(bundle: DocBundle) -> bool {
    vers = _version("latest");
    if not vers {
        return True;
    }
    return vers[0].fingerprint != bundle.fingerprint;
}

impl ingest(bundle: DocBundle) {
    log.info(
        "docs sync: ingesting the bundled docs · jac "
            + bundle.jac_version
            + " · "
            + str(len(bundle.pages))
            + " pages"
    );
    hub = DocsHub(built_at=now_iso());
    hub +>:HasVersion():+> build_version(bundle);
    root.shared +>:HasHub():+> hub;
    _sweep_stale(hub);
    log.info("docs sync: graph ready");
}

impl docs_sync_tick{
    if SYNC_STATE.get("settled", False) {
        return;
    }
    try {
        bundle = corpus_bundle();
        if corpus_stale(bundle) {
            ingest(bundle);
        } else {
            log.info(
                "docs sync: graph already holds jac "
                    + bundle.jac_version
                    + " docs — nothing to do"
            );
        }
        SYNC_STATE["settled"] = True;
    } except Exception as e {
        log.error("docs sync: failed — " + str(e));
    }
}
