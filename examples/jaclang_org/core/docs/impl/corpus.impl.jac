impl label_of(version: str) -> str {
    m = re.match(r"^v?(\d+)\.(\d+)", version.strip());
    if not m {
        return "dev";
    }
    return "v" + (m.group(1) as str) + "." + (m.group(2) as str);
}

impl reader_text(body: str) -> str {
    kept: list[str] = [];
    fenced = False;
    in_comment = False;
    for ln in body.split("\n") {
        s = ln.strip();
        if in_comment {
            in_comment = "-->" not in s;
            continue;
        }
        if s.startswith("```") {
            fenced = not fenced;
        } elif not fenced and s.startswith("<!--") {
            in_comment = "-->" not in s;
            continue;
        }
        kept.append(ln);
    }
    return "\n".join(kept);
}

impl bundle_from(ddir: Path) -> DocBundle {
    bundle = DocBundle(version=docs_version(ddir));
    digest = hashlib.sha1((BUILD_FORMAT + "\x00" + bundle.version).encode("utf-8"));
    for path in sorted(ddir.rglob("*.md"), key=lambda (p: Path) { str(p) }) {
        rel = str(path.relative_to(ddir)).replace(os.sep, "/");
        g = parse_guide(path);
        if g is None {
            continue;
        }
        body = reader_text(g.body);
        bundle.pages[rel] = body;
        bundle.descriptions[rel] = g.description;
        digest.update(rel.encode("utf-8"));
        digest.update(body.encode("utf-8"));
        digest.update(g.description.encode("utf-8"));
    }
    for np in nav_pages(ddir) {
        bundle.nav[np.page] = NavEntry(
            page=np.page, title=np.title, order=np.order, section=np.section
        );
        digest.update("\x00".join([np.page, np.title] + np.section + ["\x01"]).encode("utf-8"));
    }
    bundle.fingerprint = digest.hexdigest();
    return bundle;
}
