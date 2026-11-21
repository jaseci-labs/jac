"""A version under `hub` laid out as nav.json lays out a docs tree: a page
outside every section, two sections nested in one whose pages share one
directory, a section with pages before and after a nested one, and a last
section holding a page nav.json does not name."""
def _nav_shaped(hub: DocsHub, label: str) -> DocVersion;

test "slugify matches heading anchors" {
    assert slugify("Getting Started") == "getting-started";
    assert slugify("  Spaces   Everywhere  ") == "spaces-everywhere";
    assert slugify("`code` and *stars*") == "code-and-stars";
    assert slugify("What's New?") == "whats-new";
    assert slugify("Object-Spatial") == "object-spatial";
}

test "route of strips md and a directory's own page" {
    assert route_of("latest", "index.md") == "/docs/latest";
    assert route_of("latest", "start/index.md") == "/docs/latest/start";
    assert route_of("v0.2", "language/walkers.md") == "/docs/v0.2/language/walkers";
    assert route_of("v0.2", "reference/diagnostics/e13.md")
        == "/docs/v0.2/reference/diagnostics/e13";
    assert route_of("v0.2", "skills/writing-jac/SKILL.md") == "/docs/v0.2/skills/writing-jac";
    assert page_name("SKILL.md") == "index" and page_name("walkers.md") == "walkers";
    assert page_path("start/index.md") == "start" and page_path("index.md") == "";
    assert page_path("skills/writing-jac/SKILL.md") == "skills/writing-jac";
    assert page_path("language/walkers.md") == "language/walkers";
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

test "toc of honors an explicit heading id" {
    toc = toc_of("## Your 5-minute quick win {#service}\n\n### Plain\n");
    assert toc[0].text == "Your 5-minute quick win";
    assert toc[0].anchor == "service";
    assert toc[1].anchor == "plain";
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
    assert rewrite_href("https://docs.jaseci.org/learn/", "v0.2", "")
        == "https://docs.jaseci.org/learn/";
}

test "rewrite href resolves relative markdown" {
    assert rewrite_href("walkers.md", "latest", "language") == "/docs/latest/language/walkers";
    assert rewrite_href("../start/index.md", "latest", "language") == "/docs/latest/start";
    assert rewrite_href("walkers.md#spawn", "latest", "language")
        == "/docs/latest/language/walkers#spawn";
    assert rewrite_href("../../toolchain/build.md#cache", "v0.2", "reference/diagnostics")
        == "/docs/v0.2/toolchain/build#cache";
    assert rewrite_href("../skills/writing-jac/SKILL.md", "v0.2", "start")
        == "/docs/v0.2/skills/writing-jac";
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
        "More text.",
    ];
    got = _first_prose(lines);
    assert got == "The real first paragraph with a link in it.";
    assert _first_prose(["# only a heading"]) == "";
}

test "collect tree folds sections and pages in the order they were placed" {
    ver = (root ++> DocVersion(label="t")) as DocVersion;
    ver +>:Contains():+> DocPage(path="intro", title="Intro");
    guide = (ver +>:Contains():+> DocSection(title="Guide")) as DocSection;
    guide +>:Contains():+> DocPage(path="guide/b", title="B");
    deep = (guide +>:Contains():+> DocSection(title="Deep")) as DocSection;
    deep +>:Contains():+> DocPage(path="guide/deep/z", title="Z");
    guide +>:Contains():+> DocPage(path="guide/a", title="A");
    skills = (ver +>:Contains():+> DocSection(title="Skills")) as DocSection;
    skills +>:Contains():+> DocPage(path="skills/writing-jac", title="Writing Jac code");

    tw = (ver spawn collect_tree()) as collect_tree;
    assert [(n.kind, n.title, n.path) for n in tw.tree] == [
        ("page", "Intro", "intro"),
        ("section", "Guide", ""),
        ("section", "Skills", ""),
    ];
    kids = tw.tree[1].children;
    assert [(n.kind, n.title) for n in kids] == [("page", "B"), ("section", "Deep"), ("page", "A")];
    assert kids[1].children[0].path == "guide/deep/z";
    assert tw.tree[2].children[0].path == "skills/writing-jac";
    assert [p.path for p in tw.seq] == [
        "intro",
        "guide/b",
        "guide/deep/z",
        "guide/a",
        "skills/writing-jac",
    ];
    assert sections_of(tw.seq[2]) == ["Guide", "Deep"];
    assert sections_of(tw.seq[0]) == [];

    for i in range(len(tw.seq) - 1) {
        tw.seq[i] +>:NextPage():+> tw.seq[i + 1];
    }
    after_b = [tw.seq[1] ->:NextPage:-> [?:DocPage]];
    assert after_b[0].path == "guide/deep/z";
    assert not [tw.seq[0] <-:NextPage:<- [?:DocPage]];
}

test "version list orders releases desc then dev and dedupes per label" {
    h1 = (root.shared +>:HasHub():+> DocsHub(built_at="2026-01-01T00:00:00Z")) as DocsHub;
    h2 = (root.shared +>:HasHub():+> DocsHub(built_at="2026-01-02T00:00:00Z")) as DocsHub;
    h1 +>:HasVersion():+> DocVersion(
        label="dev", version="0.34.0", fetched_at="2026-01-01T00:00:00Z", pages=10
    );
    h1 +>:HasVersion():+> DocVersion(
        label="v0.33", version="0.33.0", fetched_at="2026-01-01T00:00:00Z", pages=20
    );
    h2 +>:HasVersion():+> DocVersion(
        label="dev", version="0.34.0", fetched_at="2026-01-02T00:00:00Z", pages=11
    );
    got = _version_list();
    assert [v.label for v in got] == ["v0.33", "dev"];
    assert got[1].pages == 11;
    assert got[0].version == "0.33.0";
    assert (_get_hub() as DocsHub).built_at == "2026-01-02T00:00:00Z";
    assert _version("dev")[0].pages == 11;
    assert _version("latest")[0].pages == 20;
    _sweep_stale(h2);
    assert not [root.shared --> [?:DocsHub, built_at == "2026-01-01T00:00:00Z"]];
    assert [root.shared --> [?:DocsHub, built_at == "2026-01-02T00:00:00Z"]];
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
        label="ghost", version="0.0.0", fetched_at="2026-01-03T00:00:00Z"
    );
    seen = _get_hub();
    assert seen is None or jid(seen) != jid(side_hub);
    assert not _version("ghost");
    root.shared +>:HasHub():+> side_hub;
    assert _version("ghost")[0].fetched_at == "2026-01-03T00:00:00Z";
    assert "ghost" in [v.label for v in _version_list()];
    _teardown_hub(side_hub);
}

test "teardown hub removes versions sections and pages" {
    hv = (root.shared +>:HasHub():+> DocsHub(built_at="teardown-probe")) as DocsHub;
    tv = (hv +>:HasVersion():+> DocVersion(label="tz", fetched_at="1")) as DocVersion;
    gs = (tv +>:Contains():+> DocSection(title="G")) as DocSection;
    inner = (gs +>:Contains():+> DocSection(title="H")) as DocSection;
    p2 = (inner +>:Contains():+> DocPage(path="g/p2", title="P2")) as DocPage;
    gs +>:Contains():+> DocPage(path="g/p1", title="P1");
    tv +>:Contains():+> DocPage(path="p0", title="P0");
    assert sections_of(p2) == ["G", "H"];
    _teardown_hub(hv);
    assert not [root.shared --> [?:DocsHub, built_at == "teardown-probe"]];
    assert not _version("tz");
}

test "place page finds or makes each section of its trail by walking" {
    pv = (root ++> DocVersion(label="p")) as DocVersion;
    pv spawn place_page(trail=["Language", "Basics"], path="language/variables", title="Variables");
    pv spawn place_page(trail=["Language", "Graphs"], path="language/walkers", title="Walkers");
    pv spawn place_page(trail=["Language", "Graphs"], path="language/visit", title="Visit");
    pv spawn place_page(trail=["Reference"], path="reference/grammar", title="Grammar");
    languages = [pv --> [?:DocSection, title == "Language"]];
    assert len(languages) == 1;
    assert [s.title for s in [languages[0] --> [?:DocSection]]] == ["Basics", "Graphs"];
    graphs = [languages[0] --> [?:DocSection, title == "Graphs"]];
    assert [p.path for p in [graphs[0] --> [?:DocPage]]] == ["language/walkers", "language/visit"];
    assert not [languages[0] --> [?:DocPage]];
    assert [s.title for s in [pv --> [?:DocSection]]] == ["Language", "Reference"];
}

test "a page's view names its sections and the nearest page stands in for a missing one" {
    hub = (root.shared +>:HasHub():+> DocsHub(built_at="view-probe")) as DocsHub;
    _nav_shaped(hub, "v98.0");

    def view(path: str) -> DocPageView {
        walked = root spawn doc_page(version="v98.0", path=path);
        return walked.reports[0] as DocPageView;
    }
    walkers = view("language/walkers");
    assert (walkers.path, walkers.title, walkers.missing) == ("language/walkers", "Walkers", False);
    assert walkers.sections == ["Language", "Object-spatial programming"];
    assert view("language/variables").sections == ["Language", "Basics"];
    assert view("reference/diagnostics/e13").sections == ["Reference", "Diagnostics"];
    assert view("reference/commands").sections == ["Reference"];
    assert view("language/scratch").sections == ["Other pages"];
    assert view("about").sections == [];
    # A path that names a directory shows its first page in reading order; one
    # that names nothing shows the nearest page, said to be missing.
    front = view("");
    assert (front.path, front.missing) == ("about", False);
    within = view("language/");
    assert (within.path, within.missing) == ("language/variables", False);
    # A directory's own page is its path's page, though a page in it comes first.
    assert view("reference").title == "Overview";
    near = view("reference/diagnostics/e99");
    assert (near.path, near.missing) == ("reference/diagnostics/e13", True);
    far = view("nowhere/at/all");
    assert (far.path, far.missing) == ("about", True);
    assert not (root spawn doc_page(version="v0.0", path="about")).reports[0];
    _teardown_hub(hub);
}

test "llms txt describes jac and lists the latest version's pages by section" {
    hub = (root.shared +>:HasHub():+> DocsHub(built_at="llms-probe")) as DocsHub;
    _nav_shaped(hub, "v99.0");
    got = llms_txt();
    assert got.startswith("# jac\n");
    assert "native-first implementation of the Jac language" in got;
    assert "`jac docs <word>`" in got and "`jac docs search <text>`" in got;
    assert "`jac skills`" in got;
    assert "jac guide" not in got and "jac mcp" not in got;
    # A nested section's heading says the titles of the sections it is in,
    # and a section's own pages come before the sections nested in it.
    assert [ln for ln in got.split("\n") if ln.startswith("## ")] == [
        "## About",
        "## Language: Basics",
        "## Language: Object-spatial programming",
        "## Reference",
        "## Reference: Diagnostics",
        "## Other pages",
    ];
    osp = got.split("## Language: Object-spatial programming\n\n", 1)[1].split("\n\n", 1)[0];
    assert osp
        == "- [Walkers]("
            + SITE_ORIGIN
            + "/docs/latest/language/walkers): What a walker is.\n"
            + "- [Visit]("
            + SITE_ORIGIN
            + "/docs/latest/language/visit): visit queues nodes.";
    reference = got.split("## Reference\n\n", 1)[1].split("\n\n", 1)[0];
    assert [ln.split("](")[0] for ln in reference.split("\n")] == [
        "- [Grammar",
        "- [Overview",
        "- [Commands",
    ];
    _teardown_hub(hub);
}

impl _nav_shaped(hub: DocsHub, label: str) -> DocVersion {
    ver = (hub +>:HasVersion():+> DocVersion(label=label, fetched_at="1")) as DocVersion;
    for (trail, path, title, desc, body) in [
        ([], "about", "About", "What this is.", ""),
        (["Language", "Basics"], "language/variables", "Variables", "Names.", ""),
        (
            ["Language", "Object-spatial programming"],
            "language/walkers",
            "Walkers",
            "What a walker is.",
            "",
        ),
        (
            ["Language", "Object-spatial programming"],
            "language/visit",
            "Visit",
            "",
            "`visit` queues nodes.",
        ),
        (["Reference"], "reference/grammar", "Grammar", "The grammar.", ""),
        (["Reference"], "reference", "Overview", "What is here.", ""),
        (["Reference", "Diagnostics"], "reference/diagnostics/e13", "E13", "E13 codes.", ""),
        (["Reference"], "reference/commands", "Commands", "The commands.", ""),
        (["Other pages"], "language/scratch", "Scratch", "Not named.", ""),
    ] {
        ver spawn place_page(
            trail=trail, path=path, title=title, description=desc, md_lines=["# " + title, "", body]
        );
    }
    return ver;
}
