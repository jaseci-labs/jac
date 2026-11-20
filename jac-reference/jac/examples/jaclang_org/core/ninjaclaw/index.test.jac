test "search ranks the page whose title and body match the question" {
    docs = [
        index_doc(
            "docs",
            "a.md",
            "Walkers",
            "/docs/latest/a",
            "Walkers visit nodes and report results."
        ),
        index_doc(
            "docs",
            "b.md",
            "Persistence",
            "/docs/latest/b",
            "Nodes attached to root persist across requests."
        ),
        index_doc(
            "tutorial",
            "spawn",
            "Spawning a walker",
            "/jacyac/tutorials/spawn",
            "spawn a walker on root to visit nodes"
        )
    ];
    hits = search(docs, "How do I spawn a walker to visit nodes?", 3);
    assert hits[0].doc.key == "spawn";
    assert "a.md" in [h.doc.key for h in hits];
    assert search(docs, "the and of", 3) == [];
}

test "docs routes match the docs reader's paths" {
    assert docs_route("quick-guide/index.md") == "/docs/latest/quick-guide";
    assert docs_route("index.md") == "/docs/latest";
    assert docs_route("build/backend-apis.md") == "/docs/latest/build/backend-apis";
}

test "an excerpt starts near the first matching term" {
    doc = index_doc(
        "docs", "x.md", "X", "/x", ("filler " * 200) + "the persistence rules apply"
    );
    assert "persistence" in excerpt(doc, "persistence", 120);
}

test "pages split into sections that link to their anchors" {
    secs = page_sections(
        "# Title\n\nintro text\n\n## Default values {#defaults}\n\nhas x: int = 0;\n\n## Lists\n\n```\n## not a heading\n```\nlist body\n"
    );
    assert [s[0] for s in secs] == ["", "Default values", "Lists"];
    assert secs[1][1] == "defaults";
    assert secs[2][1] == "lists";
    assert "## not a heading" in secs[2][2];
}
