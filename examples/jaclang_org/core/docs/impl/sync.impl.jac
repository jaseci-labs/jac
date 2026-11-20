impl corpus_bundle -> DocBundle {
    ddir = docs_dir();
    if not (ddir / "nav.json").is_file() {
        raise FileNotFoundError(
            "no docs tree at " + str(ddir) + ": " + DOCS_ENV + " names jac's docs/"
        );
    }
    return bundle_from(ddir);
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

    def md_repl(m: re.Match) -> str {
        g1 = (m.group(1) or "") as str;
        g2 = (m.group(2) or "") as str;
        return "[" + g1 + "](" + rewrite_href(g2, version, cur_dir) + ")";
    }
    def img_repl(m: re.Match) -> str {
        g1 = (m.group(1) or "") as str;
        g2 = (m.group(2) or "") as str;
        return "![" + g1 + "](" + rewrite_href(g2, version, cur_dir) + ")";
    }
    def src_repl(m: re.Match) -> str {
        g1 = (m.group(1) or "") as str;
        g2 = (m.group(2) or "") as str;
        g3 = (m.group(3) or "") as str;
        return g1 + rewrite_href(g2, version, cur_dir) + g3;
    }
    text = re.sub(r"!\[([^\]]*)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)", img_repl, text);
    text = re.sub(r"(?<!\!)\[([^\]]+)\]\(([^)\s]+)(?:\s+\"[^\"]*\")?\)", md_repl, text);
    text = re.sub(r"(src=[\"'])([^\"']+)([\"'])", src_repl, text);
    return text;
}

impl build_version(bundle: DocBundle) -> DocVersion {
    label = label_of(bundle.version);
    files = bundle.pages;
    log.info("docs sync: growing " + label + " · " + str(len(files)) + " pages");

    ver = DocVersion(
        label=label,
        version=bundle.version,
        fetched_at=now_iso(),
        fingerprint=bundle.fingerprint,
        pages=len(files),
    );

    # nav.json's pages in its order, then the pages it does not name, by path:
    # each is placed after the one before it, which is the order of the tree.
    named = sorted(
        [rel for rel in files.keys() if rel in bundle.nav],
        key=lambda (rel: str) { bundle.nav[rel].order },
    );
    unnamed = sorted([rel for rel in files.keys() if rel not in bundle.nav]);
    for rel in named + unnamed {
        raw = rewrite_links(files[rel], label, rel);
        meta = bundle.nav.get(rel);
        title = meta.title if meta is not None else "";
        if not title {
            title = first_h1(raw) or _pretty(page_name(rel.split("/")[-1]));
        }
        ver spawn place_page(
            trail=meta.section if meta is not None else [UNNAMED_SECTION],
            path=page_path(rel),
            title=title,
            description=bundle.descriptions.get(rel, ""),
            md_lines=raw.split("\n"),
            toc=toc_of(raw),
        );
    }

    reading = ver.reading_order();
    for i in range(len(reading) - 1) {
        reading[i] +>:NextPage():+> reading[i + 1];
    }
    return ver;
}

impl corpus_stale(bundle: DocBundle) -> bool {
    vers = _version(label_of(bundle.version));
    if not vers {
        return True;
    }
    return vers[0].fingerprint != bundle.fingerprint;
}

impl ingest(bundle: DocBundle) {
    label = label_of(bundle.version);
    log.info(
        "docs sync: ingesting "
            + label
            + " · jac "
            + bundle.version
            + " · "
            + str(len(bundle.pages))
            + " pages",
    );
    hub = _get_hub();
    if hub is None {
        hub = DocsHub(built_at=now_iso());
        root.shared +>:HasHub():+> hub;
    }
    fresh = build_version(bundle);
    hub +>:HasVersion():+> fresh;
    for v in [hub ->:HasVersion:-> [?:DocVersion]] {
        if v.label == label and jid(v) != jid(fresh) {
            _teardown_version(v);
        }
    }
    hub.built_at = now_iso();
    _sweep_stale(hub);
    log.info("docs sync: " + label + " ready");
}

impl retire_versions(keep: list[str]) {
    hub = _get_hub();
    if hub is None {
        return;
    }
    for v in [hub ->:HasVersion:-> [?:DocVersion]] {
        if v.label not in keep {
            log.info("docs sync: retiring " + v.label);
            _teardown_version(v);
        }
    }
}

impl docs_sync_tick {
    now = time.monotonic();
    if now < SYNC_STATE.get("next_at", 0.0) {
        return;
    }
    try {
        bundle = corpus_bundle();
        if corpus_stale(bundle) {
            ingest(bundle);
        }
        retire_versions([label_of(bundle.version)]);
        SYNC_STATE["next_at"] = now + RECHECK_S;
    } except Exception as e {
        log.error("docs sync: failed: " + str(e));
    }
}
