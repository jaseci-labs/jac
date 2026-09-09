test "label of maps the running jac version to a docs series" {
    assert label_of("0.37.1") == "v0.37";
    assert label_of("v1.2.0") == "v1.2";
    assert label_of("2.0.0rc1") == "v2.0";
    assert label_of("") == "dev";
    assert label_of("nightly") == "dev";
}

test "first h1 skips headings inside fences" {
    assert first_h1("```\n# Not It\n```\n# Real Title\n") == "Real Title";
    assert first_h1("plain text only\n") == "";
}

test "rewrite links routes relative docs images and legacy hosts" {
    got = rewrite_links(
        "[a](walkers.md#spawn) ![i](assets/x.png) <img src=\"assets/y.png\">"
        " https://docs.jaseci.org/learn/ [ext](https://example.com)",
        "v0.37",
        "guide/intro.md"
    );
    assert "[a](/docs/v0.37/guide/walkers#spawn)" in got;
    assert "![i](/static/assets/docsmedia/x.png)" in got;
    assert "src=\"/static/assets/docsmedia/y.png\"" in got;
    assert "/docs/v0.37/learn" in got;
    assert "(https://example.com)" in got;
}

test "corpus bundle reads the bundled docs their nav and a stable fingerprint" {
    b = corpus_bundle();
    assert len(b.pages) > 50;
    assert "quick-guide/index.md" in b.pages;
    assert b.jac_version != "";
    assert len(b.fingerprint) == 40;
    assert len(b.nav) == len(b.pages);
    for rel in b.nav.keys() {
        assert rel in b.pages;
        assert b.nav[rel].title != "";
    }
    assert corpus_bundle().fingerprint == b.fingerprint;
}

test "ingest grows one version labelled after the running jac then settles" {
    b = corpus_bundle();
    assert corpus_stale(DocBundle(fingerprint="never-ingested"));
    ingest(b);
    vers = _version("latest");
    assert len(vers) == 1;
    assert vers[0].label == label_of(b.jac_version);
    assert vers[0].jac_version == b.jac_version;
    assert vers[0].fingerprint == b.fingerprint;
    assert vers[0].pages == len(b.pages);
    assert "quick-guide" in [n.name for n in vers[0].tree()];
    assert not corpus_stale(b);
    assert corpus_stale(
        DocBundle(pages=b.pages, nav=b.nav, jac_version=b.jac_version, fingerprint="x")
    );
    order = vers[0].reading_order();
    assert len(order) == len(b.pages);
    assert [order[0]->:NextPage:->];
}
