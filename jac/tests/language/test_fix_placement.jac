"""Tests for the `jac fix placement` marker-migration rewriter (#7772).

The rewriter is token-stream based so it must survive JSX, strings, and
comments, and it must keep working after the sv/cl/na keywords are gone
(the marker words then lex as plain names)."""

import os;
import tempfile;
import from jaclang.cli.commands.fix {
    _append_app_table,
    _append_toml_entries,
    _strip_markers,
    fix
}


test "prefix markers strip and record claims" {
    src = (
        "sv def helper(x: int) -> int {\n    return x;\n}\n\n"
        "cl def widget -> str {\n    return \"w\";\n}\n"
    );
    res = _strip_markers(src, "mod.jac");
    assert res.changed;
    assert "sv def" not in res.text and "cl def" not in res.text;
    assert "def helper" in res.text and "def widget" in res.text;
    claimed = {c.name: c.space for c in res.claims};
    assert claimed == {"helper": "server", "widget": "client"};
}


test "sv import strips and records the service target" {
    src = "sv import from analytics { track }\n";
    res = _strip_markers(src, "mod.jac");
    assert res.changed;
    assert res.text.startswith("import from analytics");
    assert [(i.target, i.line) for i in res.sv_imports] == [("analytics", 1)];
    for header in [
        "sv\n{\nimport from .store { list_notes }\n}\n",
        "sv\nimport from .store { list_notes }\n"
    ] {
        res = _strip_markers(header, "mod.jac");
        assert [i.target for i in res.sv_imports] == [".store"] , header;
        line = res.text.splitlines()[res.sv_imports[0].line - 1];
        assert line.strip().startswith("import from .store") , f"{header!r}: {line!r}";
    }
}


test "block markers unwrap and claim every element" {
    src = (
        "sv {\ndef:pub track(x: int) -> None {\n    print(x);\n}\n\n"
        "def helper(y: int) -> int {\n    return y;\n}\n}\n"
    );
    res = _strip_markers(src, "mod.jac");
    assert res.changed;
    assert "sv {" not in res.text;
    claimed = {c.name: c.space for c in res.claims};
    assert claimed == {"track": "server", "helper": "server"};
}


test "markers inside strings and JSX text are untouched" {
    src = (
        "def note -> str {\n    return \"use sv { } blocks\";\n}\n\n"
        "glob msg: str = 'na import from x';\n"
    );
    res = _strip_markers(src, "mod.jac");
    assert not res.changed , "marker words inside strings must not rewrite";
}


test "sv as a plain name is not a marker" {
    src = "def f -> int {\n    sv = 1;\n    return sv;\n}\n";
    res = _strip_markers(src, "mod.jac");
    assert not res.changed , "identifier 'sv' in a body is not a marker";
}


test "toml append is idempotent and respects existing entries" {
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = os.path.join(tmpdir, "jac.toml");
        with open(toml_path, "w") as f {
            f.write("[project]\nname = \"x\"\n");
        }
        added = _append_toml_entries(
            toml_path, "[placement.pins]", {"m.f": "server"}, False
        );
        assert added == ['"m.f" = "server"'];
        again = _append_toml_entries(
            toml_path, "[placement.pins]", {"m.f": "server"}, False
        );
        assert again == [] , "existing entries must not duplicate";
        more = _append_toml_entries(
            toml_path, "[placement.pins]", {"m.g": "client"}, False
        );
        assert more == ['"m.g" = "client"'];
    }
}


test "app table append declares the service once and keeps the file intact" {
    with tempfile.TemporaryDirectory() as tmpdir {
        toml_path = os.path.join(tmpdir, "jac.toml");
        with open(toml_path, "w") as f {
            f.write("[project]\nname = \"x\"\n");
        }
        table = {
            "kind": "service",
            "entry-point": "svc.analytics",
            "route": "/analytics"
        };
        added = _append_app_table(toml_path, "analytics", table, False);
        assert added
            == [
                'kind = "service"',
                'entry-point = "svc.analytics"',
                'route = "/analytics"'
            ] , added;
        with open(toml_path) as f {
            text = f.read();
        }
        assert text.startswith("[project]\nname = \"x\"\n") , text;
        assert '\n[apps.analytics]\nkind = "service"\nentry-point = "svc.analytics"\n'
            in text , text;
        again = _append_app_table(toml_path, "analytics", table, False);
        assert again == [] , "an app already declared must not be appended twice";
        preview = _append_app_table(toml_path, "billing", {"kind": "service"}, True);
        assert preview == ['kind = "service"'] , preview;
        with open(toml_path) as f {
            assert "[apps.billing]" not in f.read() , "dry-run must not write";
        }
    }
}


test "fix placement waits for fix dependencies, then migrates a template-shaped [project] into [apps]" {
    import from pathlib { Path }
    import from jaclang.project.config { JacConfig }
    with tempfile.TemporaryDirectory() as tmpdir {
        root_path = Path(tmpdir);
        (root_path / "jac.toml").write_text(
            '[project]\nname = "shop"\nversion = "0.1.0"\nkind = "web-app"\n'
            'entry-point = "main"\n\n[dependencies]\nrequests = ">=2"\n'
        );
        (root_path / "main.jac").write_text(
            "sv import from analytics { Track }\n\n"
            "def:pub home -> str {\n    return \"hi\";\n}\n"
        );
        (root_path / "analytics.jac").write_text("walker:pub Track {}\n");
        source = (root_path / "main.jac").read_text();
        assert fix("placement", [str(root_path)]) == 2;
        assert (root_path / "main.jac").read_text() == source , (
            "an invalid jac.toml must stop placement before it rewrites a marker"
        );
        assert fix("dependencies", [str(root_path)]) == 0;
        rc = fix("placement", [str(root_path)]);
        assert rc == 0 , rc;
        text = (root_path / "jac.toml").read_text();
        assert "kind = \"web-app\"" not in text.split("[apps.")[0] , (
            "[project] kind must move onto the app table: " + text
        );
        assert "[dependencies.pypi]\nrequests = \">=2\"" in text , text;
        cfg = JacConfig.load(root_path / "jac.toml");
        assert cfg.is_workspace;
        assert cfg.default_app == "shop" , cfg.default_app;
        assert cfg.project.kind == "" , "[project] kind is gone";
        base = cfg.apps["shop"];
        assert base.kind == "web-app" , base.kind;
        assert base.entry_point == "main" , base.entry_point;
        svc = cfg.apps["analytics"];
        assert svc.kind == "service" , svc.kind;
        assert svc.entry_point == "analytics" , svc.entry_point;
        assert svc.effective_route() == "/analytics" , svc.effective_route();
        assert cfg.resolve_app("").name == "shop";
        assert "sv import" not in (root_path / "main.jac").read_text();
        (root_path / "billing.jac").write_text("walker:pub Bill {}\n");
        (root_path / "pages.jac").write_text("sv import from billing { Bill }\n");
        again = fix("placement", [str(root_path)]);
        assert again == 0;
        text = (root_path / "jac.toml").read_text();
        assert text.count("[apps.shop]") == 1 , "a workspace is migrated once: " + text;
        cfg = JacConfig.load(root_path / "jac.toml");
        assert cfg.default_app == "shop";
        assert list(cfg.apps.keys()) == ["shop", "analytics", "billing"] , (
            list(cfg.apps.keys())
        );
    }
}


test "fix placement --dry-run leaves a template-shaped jac.toml untouched" {
    import from pathlib { Path }
    with tempfile.TemporaryDirectory() as tmpdir {
        root_path = Path(tmpdir);
        toml_text = (
            '[project]\nname = "shop"\nkind = "web-app"\nentry-point = "main"\n'
        );
        (root_path / "jac.toml").write_text(toml_text);
        (root_path / "main.jac").write_text("sv import from analytics { Track }\n");
        (root_path / "analytics.jac").write_text("walker:pub Track {}\n");
        rc = fix("placement", [str(root_path)], dry_run=True);
        assert rc == 0 , rc;
        assert (root_path / "jac.toml").read_text() == toml_text , "dry-run must not write";
        assert "sv import" in (root_path / "main.jac").read_text();
    }
}


test "fix placement verifies element markers and pins a claim that differs" {
    import from pathlib { Path }
    with tempfile.TemporaryDirectory() as tmpdir {
        root_path = Path(tmpdir);
        (root_path / "jac.toml").write_text('[project]\nname = "x"\n');
        (root_path / "mod.jac").write_text(
            "cl def helper(x: int) -> int {\n    return x;\n}\n"
        );
        rc = fix("placement", [str(root_path)]);
        assert rc == 0 , rc;
        assert "cl def" not in (root_path / "mod.jac").read_text();
        toml = (root_path / "jac.toml").read_text();
        assert '"mod.helper" = "client"' in toml , toml;
    }
}


glob NOTES_STORE: str = (
         "node Note {\n    has title: str;\n}\n\n"
         "def:pub list_notes -> list[str] {\n"
         "    return [n.title for n in [root --> [?:Note]]];\n}\n"
     ),
     NOTES_SHELL: str = (
         "sv import from .store { list_notes }\n\n"
         "def:pub NotesShell -> JsxElement {\n"
         "    has notes: list[str] = [];\n\n"
         "    async def load -> None {\n        notes = await list_notes();\n    }\n\n"
         "    can with entry {\n        load();\n    }\n\n"
         "    return <ul>{[<li key={n}>{n}</li> for n in notes]}</ul>;\n}\n"
     ),
     NOTES_HELPER: str = (
         "sv import from .store { list_notes }\n\n"
         "cl def count_notes -> int {\n    return len(list_notes());\n}\n"
     );


def _fix_placement_output(project_dir: str, dry_run: bool) -> tuple[int, str] {
    import io;
    import from contextlib { redirect_stderr, redirect_stdout }
    out = io.StringIO();
    with redirect_stdout(out) {
        with redirect_stderr(out) {
            rc = fix("placement", [project_dir], dry_run=dry_run);
        }
    }
    return (rc, out.getvalue());
}


test "fix placement declares a service app only for a server-placed sv import" {
    import tomllib;
    import from pathlib { Path }
    toml_text = '[project]\nname = "notes"\nkind = "web-app"\nentry-point = "main"\n';
    pin = '"notes.helper.count_notes" = "client"';
    analytics = {"analytics.jac": "walker:pub Track {}\n"};
    rows: list[dict[str, any]] = [
        {
            "label": "a client component's sv import (#9132)",
            "files": {"notes/NotesShell.jac": NOTES_SHELL},
            "services": [],
            "preview_lacks": ["[apps.", "unverified"]
        },
        {
            "label": "a server-placed sv import, named with its source line",
            "files": analytics
                | {
                    "main.jac": "sv import from analytics { Track }\n\n"
                    "def:pub home -> str {\n    return \"hi\";\n}\n",
                    "notes/NotesShell.jac": NOTES_SHELL
                },
            "services": ["analytics"],
            "out_has": ["sv import at {root}/main.jac:1"],
            "out_lacks": ["NotesShell"]
        },
        {
            "label": "a later client import of the same module",
            "files": {
                "notes/store.jac": NOTES_STORE
                    + "\ndef:pub create_note(title: str) -> bool {\n"
                    + "    root ++> Note(title=title);\n    return True;\n}\n",
                "notes/NotesShell.jac": "sv import from .store { create_note }\n"
                    + NOTES_SHELL.replace("sv import from", "import from")
                    + "\ndef:pub seed_note -> bool {\n    return create_note(\"first\");\n}\n"
            },
            "services": ["store"]
        },
        {
            "label": "used only by an element the run pins to client",
            "files": {"notes/helper.jac": NOTES_HELPER},
            "services": [],
            "pins": [pin],
            "preview_has": ["unverified", "notes/helper.jac:1"]
        },
        {
            "label": "read by server code too",
            "files": {
                "notes/helper.jac": NOTES_HELPER
                    + "\ndef:pub note_total -> int {\n    return len(list_notes());\n}\n"
            },
            "services": ["store"]
        },
        {
            "label": "a client local sharing the import's name",
            "files": analytics
                | {
                    "main.jac": "sv import from analytics { Track }\n\n"
                    "def:pub home -> str {\n    return \"hi\";\n}\n\n"
                    "def:pub Panel -> JsxElement {\n"
                    "    Track = 3;\n    return <div>{Track}</div>;\n}\n"
                },
            "services": ["analytics"]
        },
        {
            "label": "an alias when another alias imports the same name",
            "files": {
                "notes/helper.jac": "sv import from .store { list_notes as client_list }\n"
                "import from .store { list_notes as server_list }\n\n"
                "cl def count_notes -> int {\n    return len(client_list());\n}\n\n"
                "def:pub note_total -> int {\n    return len(server_list());\n}\n"
            },
            "services": [],
            "pins": [pin]
        },
        {
            "label": "--dry-run while the target still has markers",
            "files": {
                "notes/store.jac": "sv {\n"
                    + "".join(
                        [
                            "    " + ln + "\n" if ln else "\n"
                            for ln in NOTES_STORE.splitlines()
                        ]
                    )
                    + "}\n",
                "notes/NotesShell.jac": NOTES_SHELL
            },
            "services": [],
            "preview_has": ["Would migrate 2 file(s)"],
            "preview_lacks": ["[apps.", "unverified"]
        },
        {
            "label": "another import on the sv import's line",
            "files": analytics
                | {
                    "notes/NotesShell.jac": NOTES_SHELL.replace(
                        "sv import from .store { list_notes }\n",
                        "sv import from .store { list_notes } import from analytics { Track }\n"
                    )
                        + "\ndef:pub ping -> bool {\n    Track();\n    return True;\n}\n"
                },
            "services": []
        },
        {
            "label": "a block marker spanning lines",
            "files": {
                "notes/NotesShell.jac": NOTES_SHELL.replace(
                    "sv import from .store { list_notes }\n",
                    "sv\n{\nimport from .store { list_notes }\n}\n"
                )
            },
            "services": []
        },
        {
            "label": "a prefix marker on its own line",
            "files": {
                "notes/NotesShell.jac": NOTES_SHELL.replace(
                    "sv import from .store { list_notes }\n",
                    "sv\nimport from .store { list_notes }\n"
                )
            },
            "services": []
        },
        {
            "label": "an annex import on the line of a client sv import",
            "files": {
                "notes/store.jac": NOTES_STORE
                    + "\ndef:pub create_note(title: str) -> bool {\n"
                    + "    root ++> Note(title=title);\n    return True;\n}\n",
                "notes/NotesShell.jac": NOTES_SHELL + "\ndef:pub seed_note -> bool;\n",
                "notes/NotesShell.impl.jac": "import from .store { create_note }\n\n"
                "impl seed_note -> bool {\n    return create_note(\"first\");\n}\n"
            },
            "services": []
        },
        {
            "label": "an sv import read by server code in the annex",
            "files": {
                "notes/store.jac": NOTES_STORE
                    + "\ndef:pub create_note(title: str) -> bool {\n"
                    + "    root ++> Note(title=title);\n    return True;\n}\n",
                "notes/NotesShell.jac": "sv import from .store { create_note }\n\n"
                "def:pub seed_note -> bool;\n",
                "notes/NotesShell.impl.jac": "impl seed_note -> bool {\n"
                "    return create_note(\"first\");\n}\n"
            },
            "services": ["store"]
        }
    ];
    for row in rows {
        label = row["label"];
        with tempfile.TemporaryDirectory() as tmpdir {
            root_path = Path(os.path.realpath(tmpdir));
            files = {
                "jac.toml": toml_text,
                "main.jac": "def:pub app -> JsxElement {\n    return <div>notes</div>;\n}\n",
                "notes/store.jac": NOTES_STORE
            }
                | row["files"];
            for (rel, src) in files.items() {
                (root_path / rel).parent.mkdir(parents=True, exist_ok=True);
                (root_path / rel).write_text(src);
            }
            (rc, preview) = _fix_placement_output(str(root_path), True);
            assert rc == 0 , f"{label}: {preview}";
            for (rel, src) in files.items() {
                assert (root_path / rel).read_text() == src , f"{label}: --dry-run wrote {rel}";
            }
            for s in row.get("preview_has", []) {
                assert s in preview , f"{label}: {preview}";
            }
            for s in row.get("preview_lacks", []) {
                assert s not in preview , f"{label}: {preview}";
            }
            (rc, out) = _fix_placement_output(str(root_path), False);
            assert rc == 0 , f"{label}: {out}";
            toml = (root_path / "jac.toml").read_text();
            services = sorted(
                [
                    name
                    for (name, app) in tomllib.loads(toml).get("apps", {}).items()
                    if app.get("kind") == "service"
                ]
            );
            assert services == row["services"] , f"{label}: {toml}";
            for p in row.get("pins", []) {
                assert p in toml , f"{label}: {toml}";
            }
            if not services and not row.get("pins") {
                assert toml == toml_text , f"{label}: jac.toml was rewritten: {toml}";
            }
            for s in row.get("out_has", []) {
                assert s.replace("{root}", str(root_path)) in out , f"{label}: {out}";
            }
            for s in row.get("out_lacks", []) {
                assert s not in out , f"{label}: {out}";
            }
            for rel in files {
                if rel.endswith(".jac") {
                    text = (root_path / rel).read_text();
                    assert "sv import" not in text and not text.startswith("sv") , f"{label}: {rel} kept a marker: {text}";
                }
            }
        }
    }
}
