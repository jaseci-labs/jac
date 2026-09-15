"""Tests for the bundled documentation corpus behind `jac guide`.

The corpus at jaclang/cli/docs is the canonical home of the entire Jac
documentation set -- every section the website renders (the site pulls its
content from here) and the whole thing `jac guide` serves offline next to
the curated skill guides. Docs get path-derived names, descriptions derived
from each doc's first prose paragraph, unified resolution through
`get_guide`, and grep-style search via `grep_guides`. These tests pin the
corpus's presence in the package, the nav manifest's agreement with the
files on disk, the resolution rules (exact, index collapsing, suffix
fallback, ambiguity, traversal rejection), the line-accuracy of search
hits, and the JSON surfaces agents consume.
"""

import io;
import json;
import from contextlib { redirect_stdout }
import from jaclang.cli.guide_store {
    list_guides,
    list_docs,
    get_guide,
    doc_corpora,
    grep_guides
}
import from jaclang.cli.commands.guide { guide }


glob CORPUS_NAMESPACES: list[str] = [
         "reference",
         "quick-guide",
         "build",
         "tutorials",
         "internals",
         "community"
     ];


def _capture_json(fn: any) -> any {
    buf = io.StringIO();
    with redirect_stdout(buf) {
        rc = fn();
    }
    assert rc == 0 , f"guide() exited {rc}; output={buf.getvalue()!r}";
    return json.loads(buf.getvalue());
}


test "bundled docs corpus ships namespaced, described, and non-trivial" {
    docs = list_docs();
    assert len(docs) >= 80 , f"expected the full corpus, got {len(docs)} docs";
    names = {g.name: g for g in docs};
    for expected in [
        "reference/diagnostics",
        "reference/language/foundation",
        "reference/language/syntax-cheatsheet",
        "tutorials/language/coding_primer",
        "build/ai-agents",
        "quick-guide/what-makes-jac-different",
        "community/breaking-changes",
        "community/codebase-guide",
        "community/faq",
        "community/release_notes/jaclang"
    ] {
        assert expected in names , f"'{expected}' missing from the corpus";
    }
    for g in docs {
        ns = g.name.split("/")[0];
        assert ns in CORPUS_NAMESPACES , f"unexpected namespace on {g.name}";
        assert g.description , f"{g.name} has no description";
        assert g.body , f"{g.name} has an empty body";
        assert not g.body.startswith("---") , f"{g.name} leaked frontmatter";
    }
}


test "nav manifest and corpus files agree exactly" {
    import from jaclang.cli.guide_store { docs_dir }
    nav_path = docs_dir() / "nav.json";
    assert nav_path.is_file() , "nav.json missing from the corpus";
    manifest = json.loads(nav_path.read_text(encoding="utf-8"));
    assert manifest["version"] == 1;

    pages: list[str] = [];
    def walk(items: list[dict[str, any]]) {
        for `entry in items {
            assert `entry.get("title") , f"nav entry missing a title: {`entry}";
            if "page" in `entry {
                pages.append(str(`entry["page"]));
            } elif "items" in `entry {
                walk(`entry["items"]);
            } else {
                assert "url" in `entry , f"nav entry is neither page nor section: {`entry}";
            }
        }
    }
    walk(manifest["nav"]);

    on_disk: set[str] = {
        str(f.relative_to(docs_dir())).replace("\\", "/")
        for f in docs_dir().rglob("*.md")
    };
    nav_set: set[str] = set(pages);
    assert nav_set == on_disk , (
        f"nav/corpus drift -- only in nav: {sorted(nav_set - on_disk)}; "
        f"only on disk: {sorted(on_disk - nav_set)}"
    );
    assert len(pages) == len(set(pages)) , "duplicate pages in nav.json";
}


test "nav_pages flattens the manifest in reading order with section trails" {
    import from jaclang.cli.guide_store { docs_dir, nav_manifest, nav_pages }
    manifest = nav_manifest();
    assert manifest.get("version") == 1 , "nav_manifest did not load nav.json";
    pages = nav_pages();
    assert pages , "nav_pages returned nothing";
    assert [p.order for p in pages] == list(range(len(pages)));
    for p in pages {
        assert p.title , f"{p.page} has no title";
        assert p.section , f"{p.page} has no section trail";
        assert (docs_dir() / p.page).is_file() , f"{p.page} is not in the corpus";
    }
    assert len({p.page for p in pages}) == len(pages) , "duplicate pages";
    on_disk = len(list(docs_dir().rglob("*.md")));
    assert len(pages) == on_disk , f"nav lists {len(pages)} pages, corpus has {on_disk}";
}


test "guide --nav prints the tree and --nav --json emits the manifest" {
    payload = _capture_json(lambda { guide(nav=True, as_json=True); });
    assert payload["version"] == 1;
    assert payload["nav"] , "manifest has no nav sections";

    buf = io.StringIO();
    with redirect_stdout(buf) {
        rc = guide(nav=True);
    }
    out = buf.getvalue();
    assert rc == 0;
    assert "Bundled docs navigation" in out , "nav header missing";
    assert "[quick-guide/index]" in out , "nav tree lacks the quick-guide index";
}


test "no bundled doc depends on mkdocs snippet includes" {
    # A doc using `--8<--` renders on the site but would print a hole where
    # the include belongs when served by `jac guide`.
    offenders = [
        g.name
        for g in list_docs()
        if "--8<--" in g.body
    ];
    assert not offenders , f"docs use mkdocs snippet includes: {offenders}";
}


test "doc_corpora groups every doc by namespace in canonical order" {
    corpora = doc_corpora();
    assert [ns for (ns, _) in corpora] == CORPUS_NAMESPACES;
    counts = {ns: len(members) for (ns, members) in corpora};
    assert counts["reference"] >= 25 , f"reference corpus too small: {counts}";
    assert counts["tutorials"] >= 20 , f"tutorials corpus too small: {counts}";
    assert counts["build"] >= 5 , f"build corpus too small: {counts}";
    assert counts["community"] >= 5 , f"community corpus too small: {counts}";
    assert sum(counts.values()) == len(list_docs());
}


test "get_guide resolves exact names, dir indexes, suffixes, and skills first" {
    doc = get_guide("reference/diagnostics");
    assert doc is not None and doc.name == "reference/diagnostics";

    # reference/cli/index.md collapses to reference/cli, and resolving that
    # name finds the index file.
    by_index = get_guide("reference/cli");
    assert by_index is not None and by_index.name == "reference/cli";
    assert by_index.name in {g.name for g in list_docs()};

    by_suffix = get_guide("breaking-changes");
    assert by_suffix is not None , "unique suffix did not resolve";
    assert by_suffix.name == "community/breaking-changes";

    skill = get_guide("jac-types");
    assert skill is not None and skill.name == "jac-types" , "skill lookup broke";

    assert get_guide("osp") is None , "ambiguous suffix must not resolve";
    assert get_guide("no-such-doc-anywhere") is None;
}


test "get_guide rejects path traversal and junk names" {
    for bad in ["../skills/jac-types", "reference/../../secrets", "..", "", "/"] {
        assert get_guide(bad) is None , f"'{bad}' should not resolve";
    }
}


test "grep_guides hits are line-accurate against the printed body" {
    bodies = {g.name: g.body for g in (list_guides() + list_docs())};
    hits = grep_guides("nearest enclosing binding");
    assert hits , "expected hits for a known docs phrase";
    guides_hit = {h.guide for h in hits};
    assert "community/breaking-changes" in guides_hit , f"hit guides: {guides_hit}";
    for h in hits {
        if h.line_no == 0 {
            continue;
        }
        line = bodies[h.guide].splitlines()[h.line_no - 1].lower();
        for term in ["nearest", "enclosing", "binding"] {
            assert term in line , f"{h.guide}:{h.line_no} does not contain '{term}'";
        }
    }
}


test "grep_guides honors per-guide and total caps" {
    hits = grep_guides("jac", max_per_guide=2, max_total=10);
    assert len(hits) <= 10;
    body_hits: dict[str, int] = {};
    for h in hits {
        if h.line_no > 0 {
            body_hits[h.guide] = body_hits.get(h.guide, 0) + 1;
        }
    }
    for (name, count) in body_hits.items() {
        assert count <= 2 , f"{name} exceeded max_per_guide: {count}";
    }
    assert grep_guides("") == [];
}


test "guide --json emits the full skill + doc index" {
    payload = _capture_json(lambda { guide(as_json=True); });
    kinds = {`entry["kind"] for `entry in payload};
    assert kinds == {"skill", "doc"} , f"kinds: {kinds}";
    assert len(payload) == len(list_guides()) + len(list_docs());
    for `entry in payload {
        assert `entry["name"] and `entry["description"] is not None;
    }
}


test "guide <corpus> and guide <doc> JSON surfaces work" {
    listing = _capture_json(lambda { guide(topic="reference", as_json=True); });
    assert "reference/diagnostics" in {`entry["name"] for `entry in listing};

    doc = _capture_json(lambda { guide(topic="reference/diagnostics", as_json=True); });
    assert doc["name"] == "reference/diagnostics";
    body = str(doc["body"]);
    assert "diagnostic" in body.lower();
}


test "grep_guides falls back to doc-level matches for sentence queries" {
    hits = grep_guides("filter predicate unknown type W1051 dynamic value");
    assert hits , "sentence-length query should produce doc-level matches";
    assert all([h.line_no == 0 for h in hits]) , "fallback hits are doc-level";
    # The subject here is the doc-level fallback, not an exact ranking: the
    # score is a function of the whole corpus, so any page that gains matching
    # prose shifts neighbours by a place or two. Pin that the diagnostics
    # reference stays findable near the top, not that it holds one slot.
    top = {h.guide for h in hits[:5]};
    assert "reference/diagnostics" in top , f"top hits: {top}";
    assert "open: jac guide" in hits[0].text;
}

test "guide_for_diagnostic routes unmapped codes to the diagnostics reference" {
    import from jaclang.cli.guide_store { guide_for_diagnostic }
    assert guide_for_diagnostic("W3037") == "jac-types" , "mapped code broke";
    assert guide_for_diagnostic("W9999") == "reference/diagnostics";
}

test "guide --search JSON emits grep hits" {
    hits = _capture_json(lambda { guide(search="walker", as_json=True); });
    assert hits , "expected search hits for 'walker'";
    for h in hits {
        assert set(h.keys()) == {"guide", "line", "text"};
    }
}


test "guide CLI listing, body, search lines, and unknown-topic exit" {
    buf = io.StringIO();
    with redirect_stdout(buf) {
        rc = guide();
    }
    listing = buf.getvalue();
    assert rc == 0;
    assert "Jac reference guides" in listing , "guide listing header missing";
    assert "jac-types" in listing;
    assert "jac-core-cheatsheet" in listing;

    buf = io.StringIO();
    with redirect_stdout(buf) {
        rc = guide(topic="jac-types");
    }
    body = buf.getvalue();
    assert rc == 0;
    assert len(body) > 200 , f"jac-types body is too short ({len(body)} chars)";
    assert not body.lstrip().startswith("---") , "jac-types leaked raw frontmatter";

    buf = io.StringIO();
    with redirect_stdout(buf) {
        rc = guide(topic="reference/diagnostics");
    }
    assert rc == 0;
    assert len(buf.getvalue()) > 500 , "reference/diagnostics body is too short";

    buf = io.StringIO();
    with redirect_stdout(buf) {
        rc = guide(topic="community");
    }
    assert rc == 0;
    assert "community/breaking-changes" in buf.getvalue();

    import re;
    buf = io.StringIO();
    with redirect_stdout(buf) {
        rc = guide(search="walker");
    }
    assert rc == 0;
    hit = re.compile(r"^[A-Za-z0-9_/.-]+:[0-9]+: ");
    assert any(hit.`match(line) for line in buf.getvalue().splitlines()) , "guide --search produced no grep-style hits";

    buf = io.StringIO();
    with redirect_stdout(buf) {
        rc = guide(topic="does-not-exist");
    }
    assert rc != 0 , "guide on an unknown topic must exit non-zero";
}


test "mcp resources index the docs corpus" {
    import from jaclang.cli.mcp.resources { ResourceProvider }
    provider = ResourceProvider();
    uris = {r["uri"] for r in provider.list_resources()};
    assert "jac://docs/reference/diagnostics" in uris , "docs corpus missing from MCP";
    assert "jac://guide/jac-types" in uris , "skill guides missing from MCP";
    content = provider.read_resource("jac://docs/reference/diagnostics");
    assert "diagnostic" in content.lower();
    assert "jac://docs/nav" in uris , "nav manifest missing from MCP";
    nav = json.loads(provider.read_resource("jac://docs/nav"));
    assert nav["version"] == 1 and nav["nav"];
}
