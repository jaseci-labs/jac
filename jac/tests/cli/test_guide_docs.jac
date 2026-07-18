"""Tests for the bundled documentation corpus behind `jac guide`.

The corpus at jaclang/cli/docs is the canonical markdown for the docs site's
reference/, quick-guide/, tutorials/, and internals/ sections (plus the
community breaking-changes log and codebase guide) -- the mkdocs build mounts
it from here. `jac guide` serves it next to the curated skill guides with
path-derived names, descriptions derived from each doc's first prose
paragraph, unified resolution through `get_guide`, and grep-style search via
`grep_guides`. These tests pin the corpus's presence in the package, the
resolution rules (exact, index collapsing, suffix fallback, ambiguity,
traversal rejection), the exclusion of site-only pages, the line-accuracy of
search hits, and the JSON surfaces agents consume.
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
    assert len(docs) >= 60 , f"expected a full corpus, got {len(docs)} docs";
    names = {g.name: g for g in docs};
    for expected in [
        "reference/diagnostics",
        "reference/language/foundation",
        "quick-guide/syntax-cheatsheet",
        "tutorials/language/coding_primer",
        "community/breaking-changes",
        "community/codebase-guide"
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


test "site-only pages stay out of the corpus" {
    names = {g.name for g in list_docs()};
    for hidden in [
        "reference/ninja",
        "quick-guide/what-makes-jac-different",
        "quick-guide/jac-vs-traditional-stack"
    ] {
        assert hidden not in names , f"'{hidden}' should be excluded";
        assert get_guide(hidden) is None , f"'{hidden}' should not resolve";
    }
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
    assert counts["community"] == 2 , f"community corpus changed: {counts}";
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
    kinds = {entry["kind"] for entry in payload};
    assert kinds == {"skill", "doc"} , f"kinds: {kinds}";
    assert len(payload) == len(list_guides()) + len(list_docs());
    for entry in payload {
        assert entry["name"] and entry["description"] is not None;
    }
}


test "guide <corpus> and guide <doc> JSON surfaces work" {
    listing = _capture_json(lambda { guide(topic="reference", as_json=True); });
    assert "reference/diagnostics" in {entry["name"] for entry in listing};

    doc = _capture_json(lambda { guide(topic="reference/diagnostics", as_json=True); });
    assert doc["name"] == "reference/diagnostics";
    body = str(doc["body"]);
    assert "diagnostic" in body.lower();
}


test "grep_guides falls back to doc-level matches for sentence queries" {
    hits = grep_guides("filter predicate unknown type W1051 dynamic value");
    assert hits , "sentence-length query should produce doc-level matches";
    assert all([h.line_no == 0 for h in hits]) , "fallback hits are doc-level";
    top = {h.guide for h in hits[:3]};
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


test "mcp resources index the docs corpus" {
    import from jaclang.cli.mcp.resources { ResourceProvider }
    provider = ResourceProvider();
    uris = {r["uri"] for r in provider.list_resources()};
    assert "jac://docs/reference/diagnostics" in uris , "docs corpus missing from MCP";
    assert "jac://guide/jac-types" in uris , "skill guides missing from MCP";
    content = provider.read_resource("jac://docs/reference/diagnostics");
    assert "diagnostic" in content.lower();
}
