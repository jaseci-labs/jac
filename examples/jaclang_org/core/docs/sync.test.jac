import os;
import tempfile;
import from pathlib { Path }

"""A docs tree of the form jac's has, in a checkout of version 9.8.7 under
`base`: its docs/ directory."""
def _tree(base: Path) -> Path;

"""Run `body` with JAC_WEB_DOCS set to `value`, or unset for None."""
def _with_docs_env(value: str | None, body: Callable[[], None]);

test "label of maps a version to a docs series" {
    assert label_of("0.2.6") == "v0.2";
    assert label_of("v1.2.0") == "v1.2";
    assert label_of("2.0.0rc1") == "v2.0";
    assert label_of("") == "dev";
    assert label_of("nightly") == "dev";
}

test "first h1 skips headings inside fences" {
    assert first_h1("```\n# Not It\n```\n# Real Title\n") == "Real Title";
    assert first_h1("plain text only\n") == "";
}

test "rewrite links routes relative docs up-level links and images" {
    got = rewrite_links(
        "[a](walkers.md#spawn) ![i](assets/x.png) <img src=\"assets/y.png\">"
            " [up](../../apps/archwire.md) [skill](../../skills/writing-jac/SKILL.md)"
            " [ext](https://example.com) https://docs.jaseci.org/learn/",
        "v0.2",
        "reference/diagnostics/e13.md",
    );
    assert "[a](/docs/v0.2/reference/diagnostics/walkers#spawn)" in got;
    assert "![i](/static/assets/docsmedia/x.png)" in got;
    assert "src=\"/static/assets/docsmedia/y.png\"" in got;
    assert "[up](/docs/v0.2/apps/archwire)" in got;
    assert "[skill](/docs/v0.2/skills/writing-jac)" in got;
    assert "(https://example.com)" in got;
    assert "https://docs.jaseci.org/learn/" in got;
}

test "the docs tree is the checkout's docs unless JAC_WEB_DOCS names another" {
    def unset {
        ddir = docs_dir();
        assert ddir.name == "docs";
        assert (ddir / "start" / "index.md").is_file();
        assert (ddir / "language" / "walkers.md").is_file();
        assert (ddir.parent / "jac.toml").is_file();
        assert label_of(corpus_bundle().version) != "dev";
    }
    _with_docs_env(None, unset);
    with tempfile.TemporaryDirectory() as tmp {
        tree = _tree(Path(tmp));

        def named {
            assert docs_dir() == tree.resolve();
            assert corpus_bundle().version == "9.8.7";
        }
        _with_docs_env(str(tree), named);

        # A release's tree: its VERSION file says the version, a line of it.
        (Path(tmp) / "VERSION").write_text("9.9.1\n0f4f3e70\n");

        def released {
            assert corpus_bundle().version == "9.9.1";
        }
        _with_docs_env(str(tree), released);
        (Path(tmp) / "VERSION").unlink();

        def missing {
            try {
                corpus_bundle();
                assert False, "a directory with no docs tree must not read as an empty one";
            } except FileNotFoundError as e {
                assert DOCS_ENV in str(e);
            }
        }
        _with_docs_env(str(Path(tmp) / "nowhere"), missing);
    }
}

test "the checkout's corpus has every page as a reader sees it and a stable fingerprint" {
    def body {
        b = corpus_bundle();
        for rel in [
            "start/index.md",
            "language/walkers.md",
            "reference/grammar.md",
            "reference/commands.md",
        ] {
            assert rel in b.pages, rel;
            assert b.descriptions[rel] != "", rel;
        }
        assert label_of(b.version) != "dev";
        assert len(b.fingerprint) == 40;
        for rel in b.nav.keys() {
            assert rel in b.pages, rel;
        }
        # Each page is in a section, as nav.json nests them: a language page
        # in one of the sections nested in the language's.
        for rel in ["start/index.md", "reference/grammar.md", "reference/commands.md"] {
            assert b.nav[rel].section, rel;
        }
        assert len(b.nav["language/walkers.md"].section) == 2;
        for (rel, text) in b.pages.items() {
            assert not text.startswith("---"), rel;
            fenced = False;
            for ln in text.split("\n") {
                if ln.strip().startswith("```") {
                    fenced = not fenced;
                }
                assert fenced or not ln.strip().startswith("<!--"), rel;
            }
        }
        assert corpus_bundle().fingerprint == b.fingerprint;
    }
    _with_docs_env(None, body);
}

test "ingest grows one version labelled with jac's version then settles" {
    with tempfile.TemporaryDirectory() as tmp {
        tree = _tree(Path(tmp));

        def body {
            b = corpus_bundle();
            assert b.version == "9.8.7";
            assert b.nav["language/walkers.md"].section == [
                "Language",
                "Object-spatial programming",
            ];
            assert b.nav["reference/diagnostics/e13.md"].section == ["Reference", "Diagnostics"];
            assert "language/scratch.md" not in b.nav;
            assert corpus_stale(DocBundle(fingerprint="never-ingested"));
            ingest(b);
            vers = _version("v9.8");
            assert len(vers) == 1;
            assert vers[0].version == "9.8.7";
            assert vers[0].fingerprint == b.fingerprint;
            assert vers[0].pages == len(b.pages) == 10;
            # nav.json's tree: two sections whose pages share language/, a
            # section with pages before and after a nested one, a skill's page
            # as itself, and last the page nav.json does not name.
            top = vers[0].tree();
            assert [(n.kind, n.title) for n in top] == [
                ("section", "Start here"),
                ("section", "Language"),
                ("section", "Reference"),
                ("section", "Skills"),
                ("section", UNNAMED_SECTION),
            ];
            assert [n.path for n in top[0].children] == ["start", "start/install"];
            language = top[1].children;
            assert [(n.kind, n.title) for n in language] == [
                ("section", "Basics"),
                ("section", "Object-spatial programming"),
            ];
            assert [n.path for n in language[0].children] == ["language/variables"];
            assert [n.path for n in language[1].children] == ["language/walkers", "language/visit"];
            reference = top[2].children;
            assert [(n.kind, n.title, n.path) for n in reference] == [
                ("page", "Grammar", "reference/grammar"),
                ("section", "Diagnostics", ""),
                ("page", "Commands", "reference/commands"),
            ];
            assert [n.path for n in reference[1].children] == ["reference/diagnostics/e13"];
            skill = top[3].children[0];
            assert (skill.kind, skill.title, skill.path)
                == ("page", "Writing Jac", "skills/writing-jac");
            assert [n.path for n in top[4].children] == ["language/scratch"];
            assert not corpus_stale(b);
            order = vers[0].reading_order();
            assert [p.title for p in order] == [
                "What jac is",
                "Install",
                "Variables",
                "Walkers",
                "Visit",
                "Grammar",
                "E13",
                "Commands",
                "Writing Jac",
                "Scratch",
            ];
            assert [order[0] ->:NextPage:->];
            # From the last page of a section to the first of the next.
            assert order[5].path == "reference/grammar";
            assert jid([order[4] ->:NextPage:->][0]) == jid(order[5]);
            e13 = order[6];
            assert e13.description == "E13 codes.";
            md = "\n".join(e13.md_lines);
            assert "not checked" not in md and "spread over" not in md;
            assert "-->\n```jac" not in md and "```jac\n<!-- the code's -->" in md;
            assert "After." in md;
            assert "[walkers](/docs/v9.8/language/walkers#spawn)" in md;
            assert order[8].path == "skills/writing-jac";

            hub = _get_hub() as DocsHub;
            hub +>:HasVersion():+> DocVersion(label="v0.39", version="0.39.1", fetched_at="1");
            retire_versions([label_of(b.version)]);
            assert not _version("v0.39");
            assert _version("latest")[0].label == "v9.8";
            assert [v.label for v in [hub ->:HasVersion:-> [?:DocVersion]]] == ["v9.8"];
        }
        _with_docs_env(str(tree), body);
    }
}

impl _tree(base: Path) -> Path {
    (base / "jac.toml").write_text('[project]\nname = "jac"\nversion = "9.8.7"\n');
    docs = base / "docs";
    pages: dict[str, str] = {
        "start/index.md": "---\ndescription: What it is.\n---\n# What jac is\n\nProse.\n",
        "start/install.md": "---\ndescription: Install it.\n---\n# Install\n\nRun it.\n",
        "reference/grammar.md": "---\ndescription: The grammar.\n---\n# Grammar\n\n```ebnf\nx ::= y\n```\n",
        "reference/diagnostics/e13.md": "---\ndescription: E13 codes.\n---\n# E13\n\n"
            "See [walkers](../../language/walkers.md#spawn).\n\n"
            "<!-- example: not checked: needs a file beside it -->\n```jac\n<!-- the code's -->\n```\n"
            "<!--\nspread over\nlines -->\nAfter.\n",
        "skills/writing-jac/SKILL.md": "---\nname: writing-jac\ndescription: Write Jac.\n---\n"
            "# Writing Jac\n\nSteps.\n",
        "language/variables.md": "---\ndescription: Name a value.\n---\n# Variables\n",
        "language/walkers.md": "---\ndescription: Walk.\n---\n# Walkers\n",
        "language/visit.md": "---\ndescription: Queue a node.\n---\n# Visit\n",
        "reference/commands.md": "---\ndescription: The commands.\n---\n# Commands\n",
        "language/scratch.md": "---\ndescription: Not in nav.json.\n---\n# Scratch\n",
    };
    for (rel, text) in pages.items() {
        path = docs / rel;
        path.parent.mkdir(parents=True, exist_ok=True);
        path.write_text(text);
    }
    (docs / "nav.json").write_text(
        '{"version": 1, "site_name": "jac", "nav": ['
            '{"title": "Start here", "items": ['
            '{"title": "What jac is", "page": "start/index.md"},'
            '{"title": "Install", "page": "start/install.md"}]},'
            '{"title": "Language", "items": ['
            '{"title": "Basics", "items": ['
            '{"title": "Variables", "page": "language/variables.md"}]},'
            '{"title": "Object-spatial programming", "items": ['
            '{"title": "Walkers", "page": "language/walkers.md"},'
            '{"title": "Visit", "page": "language/visit.md"}]}]},'
            '{"title": "Reference", "items": ['
            '{"title": "Grammar", "page": "reference/grammar.md"},'
            '{"title": "Diagnostics", "items": ['
            '{"title": "E13", "page": "reference/diagnostics/e13.md"}]},'
            '{"title": "Commands", "page": "reference/commands.md"}]},'
            '{"title": "Skills", "items": ['
            '{"title": "Writing Jac", "page": "skills/writing-jac/SKILL.md"}]}]}',
    );
    return docs;
}

impl _with_docs_env(value: str | None, body: Callable[[], None]) {
    saved = os.environ.get(DOCS_ENV);
    if value is None {
        os.environ.pop(DOCS_ENV, None);
    } else {
        os.environ[DOCS_ENV] = value;
    }
    try {
        body();
    } finally {
        if saved is None {
            os.environ.pop(DOCS_ENV, None);
        } else {
            os.environ[DOCS_ENV] = saved;
        }
    }
}
