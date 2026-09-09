test "slugify matches heading anchors" {
    assert slugify("Getting Started") == "getting-started";
    assert slugify("  Spaces   Everywhere  ") == "spaces-everywhere";
    assert slugify("`code` and *stars*") == "code-and-stars";
    assert slugify("What's New?") == "whats-new";
    assert slugify("Object-Spatial") == "object-spatial";
}

test "route of strips md and index" {
    assert route_of("latest", "index.md") == "/docs/latest";
    assert route_of("latest", "guide/index.md") == "/docs/latest/guide";
    assert route_of("v0.33", "guide/walkers.md") == "/docs/v0.33/guide/walkers";
}

test "toc of collects h2 and h3 with anchors" {
    md = "# Title\n\n## First Section\n\ntext\n\n### Nested Bit\n\n## Second\n";
    toc = toc_of(md);
    assert len(toc) == 3;
    assert toc[0].level == 2;
    assert toc[0].text == "First Section";
    assert toc[0].anchor == "first-section";
    assert toc[1].level == 3;
    assert toc[1].anchor == "nested-bit";
    assert toc[2].text == "Second";
}

test "toc of ignores headings inside fences" {
    md = "## Real\n\n```\n## Not A Heading\n```\n\n## Also Real\n";
    toc = toc_of(md);
    assert len(toc) == 2;
    assert toc[0].text == "Real";
    assert toc[1].text == "Also Real";
}

test "rewrite href keeps anchors and externals" {
    assert rewrite_href("#section", "latest", "") == "#section";
    assert rewrite_href("mailto:a@b.c", "latest", "") == "mailto:a@b.c";
    assert rewrite_href("https://example.com", "latest", "") == "https://example.com";
}

test "rewrite href pulls docs jaseci org in site" {
    got = rewrite_href("https://docs.jaseci.org/learn/guide/", "v0.32", "");
    assert got == "/docs/v0.32/learn/guide";
}

test "rewrite href resolves relative markdown" {
    assert rewrite_href("walkers.md", "latest", "guide")
        == "/docs/latest/guide/walkers";
    assert rewrite_href("../intro.md", "latest", "guide") == "/docs/latest/intro";
    assert rewrite_href("walkers.md#spawn", "latest", "guide")
        == "/docs/latest/guide/walkers#spawn";
}

test "rewrite href maps asset images to static" {
    got = rewrite_href("assets/diagram.png", "latest", "guide");
    assert got == "/static/assets/docsmedia/diagram.png";
}

test "first prose skips headings fences and markup" {
    lines = [
        "# Title",
        "",
        "```jac",
        "prose inside a fence;",
        "```",
        "!!! note",
        "",
        "The *real* first paragraph with a [link](x.md) in it.",
        "More text."
    ];
    got = _first_prose(lines);
    assert got == "The real first paragraph with a link in it.";
    assert _first_prose(["# only a heading"]) == "";
}

test "collect tree folds orders and derives paths by walking" {
    ver = (root ++> DocVersion(label="t")) as DocVersion;
    guide = (
        ver +>:Contains():+> DocDir(name="guide", title="Guide", order=1)
    ) as DocDir;
    ver +>:Contains():+> DocPage(name="intro", title="Intro", order=0);
    guide +>:Contains():+> DocPage(name="b", title="B", order=2);
    guide +>:Contains():+> DocPage(name="a", title="A", order=1);
    deep = (
        guide +>:Contains():+> DocDir(name="deep", title="Deep", order=0)
    ) as DocDir;
    deep +>:Contains():+> DocPage(name="z", title="Z", order=5);

    tw = (ver spawn collect_tree()) as collect_tree;
    assert len(tw.tree) == 2;
    assert tw.tree[0].kind == "page" and tw.tree[0].path == "intro";
    assert tw.tree[1].kind == "dir" and tw.tree[1].name == "guide";
    assert deep.order == 5;
    kids = tw.tree[1].children;
    assert [k.name for k in kids] == ["a", "b", "deep"];
    assert kids[0].path == "guide/a";
    assert kids[2].children[0].path == "guide/deep/z";
    assert [p.name for p in tw.seq] == ["intro", "a", "b", "z"];

    for i in range(len(tw.seq) - 1) {
        tw.seq[i] +>:NextPage():+> tw.seq[i + 1];
    }
    after_a = [tw.seq[1]->:NextPage:->[?:DocPage]];
    assert after_a[0].name == "b";
    assert not [tw.seq[0]<-:NextPage:<-[?:DocPage]];
    assert _route_up(tw.seq[3]) == "guide/deep/z";
}

test "version list orders releases desc then dev and dedupes per label" {
    h1 = (root +>:HasHub():+> DocsHub(built_at="2026-01-01T00:00:00Z")) as DocsHub;
    h2 = (root +>:HasHub():+> DocsHub(built_at="2026-01-02T00:00:00Z")) as DocsHub;
    h1 +>:HasVersion():+> DocVersion(
        label="dev", jac_version="0.34.0", fetched_at="2026-01-01T00:00:00Z", pages=10
    );
    h1 +>:HasVersion():+> DocVersion(
        label="v0.33", jac_version="0.33.0", fetched_at="2026-01-01T00:00:00Z", pages=20
    );
    h2 +>:HasVersion():+> DocVersion(
        label="dev", jac_version="0.34.0", fetched_at="2026-01-02T00:00:00Z", pages=11
    );
    got = _version_list();
    assert [v.label for v in got] == ["v0.33", "dev"];
    assert got[1].pages == 11;
    assert got[0].jac_version == "0.33.0";
    assert (_get_hub() as DocsHub).built_at == "2026-01-02T00:00:00Z";
    assert _version("dev")[0].pages == 11;
    assert _version("latest")[0].pages == 20;
    _sweep_stale(h2);
    assert not [root-->[?:DocsHub, built_at=="2026-01-01T00:00:00Z"]];
    assert [root-->[?:DocsHub, built_at=="2026-01-02T00:00:00Z"]];
    assert not _version("v0.33");
    assert _version("latest")[0].pages == 11;
}

test "latest alias resolves to newest release label" {
    assert _latest_label(["dev", "v0.33", "v0.35", "v0.34"]) == "v0.35";
    assert _latest_label(["v0.9", "v0.35"]) == "v0.35";
    assert _latest_label(["dev"]) == "dev";
    assert _latest_label([]) == "";
    assert _series_of("v0.35") == (0, 35);
    assert _series_of("dev") is None;
    assert _series_of("v0.35.1") is None;
}

test "detached hubs stay invisible until attached" {
    side_hub = DocsHub(built_at="2026-01-03T00:00:00Z");
    side_hub +>:HasVersion():+> DocVersion(
        label="ghost", jac_version="0.0.0", fetched_at="2026-01-03T00:00:00Z"
    );
    seen = _get_hub();
    assert seen is None or jid(seen) != jid(side_hub);
    assert not _version("ghost");
    root +>:HasHub():+> side_hub;
    assert _version("ghost")[0].fetched_at == "2026-01-03T00:00:00Z";
    assert "ghost" in [v.label for v in _version_list()];
    _teardown_hub(side_hub);
}

test "teardown hub removes versions dirs and pages" {
    hv = (root +>:HasHub():+> DocsHub(built_at="teardown-probe")) as DocsHub;
    tv = (hv +>:HasVersion():+> DocVersion(label="tz", fetched_at="1")) as DocVersion;
    gd = (tv +>:Contains():+> DocDir(name="g", title="G")) as DocDir;
    gd +>:Contains():+> DocPage(name="p1", title="P1");
    tv +>:Contains():+> DocPage(name="p0", title="P0");
    _teardown_hub(hv);
    assert not [root-->[?:DocsHub, built_at=="teardown-probe"]];
    assert not _version("tz");
}

test "place page builds missing dirs by walking" {
    pv = (root ++> DocVersion(label="p")) as DocVersion;
    pv spawn place_page(segs=["guide", "deep"], name="one", title="One", order=1);
    pv spawn place_page(segs=["guide"], name="two", title="Two", order=2);
    guides = [pv-->[?:DocDir, name=="guide"]];
    assert len(guides) == 1;
    deeps = [guides[0]-->[?:DocDir, name=="deep"]];
    assert len(deeps) == 1;
    assert [p.name for p in [deeps[0]-->[?:DocPage]]] == ["one"];
    assert [p.name for p in [guides[0]-->[?:DocPage]]] == ["two"];
}
