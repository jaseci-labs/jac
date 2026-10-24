impl corpus_bundle -> DocBundle {
    return bundle_from(docs_dir(), resolve_cli_version());
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
    vers = _version(label_of(bundle.jac_version));
    if not vers {
        return True;
    }
    return vers[0].fingerprint != bundle.fingerprint;
}

impl ingest(bundle: DocBundle) {
    label = label_of(bundle.jac_version);
    log.info(
        "docs sync: ingesting "
            + label
            + " · jac "
            + bundle.jac_version
            + " · "
            + str(len(bundle.pages))
            + " pages"
    );
    hub = _get_hub();
    if hub is None {
        hub = DocsHub(built_at=now_iso());
        root.shared +>:HasHub():+> hub;
    }
    fresh = build_version(bundle);
    hub +>:HasVersion():+> fresh;
    for v in [hub->:HasVersion:->[?:DocVersion]] {
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
    for v in [hub->:HasVersion:->[?:DocVersion]] {
        if v.label not in keep {
            log.info("docs sync: retiring " + v.label);
            _teardown_version(v);
        }
    }
}

impl sync_release_lines(serving_label: str) -> bool {
    try {
        offered = await release_doc_lines();
    } except BridgeError as e {
        log.info("docs sync: release lines unavailable: " + str(e));
        return False;
    }
    if not offered.ready {
        return False;
    }
    keep = [serving_label];
    for info in offered.lines {
        if info.label == serving_label {
            continue;
        }
        keep.append(info.label);
        have = _version(info.label);
        if have and have[0].fingerprint == info.fingerprint {
            continue;
        }
        bundle = await release_docs(info.tag);
        if bundle is not None {
            ingest(bundle);
        }
    }
    retire_versions(keep);
    return True;
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
        settled = await sync_release_lines(label_of(bundle.jac_version));
        SYNC_STATE["next_at"] = now + (RECHECK_S if settled else SYNC_TICK_S);
    } except Exception as e {
        log.error("docs sync: failed: " + str(e));
    }
}
