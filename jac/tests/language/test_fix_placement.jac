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


test "fix placement migrates a template-shaped [project] into [apps] before adding a service" {
    import from pathlib { Path }
    import from jaclang.project.config { JacConfig }
    with tempfile.TemporaryDirectory() as tmpdir {
        root_path = Path(tmpdir);
        (root_path / "jac.toml").write_text(
            '[project]\nname = "shop"\nversion = "0.1.0"\nkind = "web-app"\n'
            'entry-point = "main"\n\n[dependencies.pypi]\nrequests = ">=2"\n'
        );
        (root_path / "main.jac").write_text(
            "sv import from analytics { Track }\n\n"
            "def:pub home -> str {\n    return \"hi\";\n}\n"
        );
        (root_path / "analytics.jac").write_text("walker:pub Track {}\n");
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
     );


test "an sv import in a client component is stripped without declaring a service app" {
    import from pathlib { Path }
    with tempfile.TemporaryDirectory() as tmpdir {
        root_path = Path(tmpdir);
        toml_text = (
            '[project]\nname = "notes"\nkind = "web-app"\nentry-point = "main"\n'
        );
        (root_path / "jac.toml").write_text(toml_text);
        (root_path / "main.jac").write_text(
            "def:pub app -> JsxElement {\n    return <div>notes</div>;\n}\n"
        );
        (root_path / "notes").mkdir();
        (root_path / "notes" / "store.jac").write_text(NOTES_STORE);
        (root_path / "notes" / "NotesShell.jac").write_text(NOTES_SHELL);
        assert fix("placement", [str(root_path)], dry_run=True) == 0;
        assert (root_path / "jac.toml").read_text() == toml_text;
        assert fix("placement", [str(root_path)]) == 0;
        assert (root_path / "jac.toml").read_text() == toml_text , (
            "a client-to-server import needs no service app: "
            + (root_path / "jac.toml").read_text()
        );
        shell = (root_path / "notes" / "NotesShell.jac").read_text();
        assert shell.startswith("import from .store { list_notes }") , shell;
    }
}


test "only a server-placed sv import declares a service app, named with its source line" {
    import io;
    import from contextlib { redirect_stdout }
    import from pathlib { Path }
    import from jaclang.project.config { JacConfig }
    with tempfile.TemporaryDirectory() as tmpdir {
        root_path = Path(tmpdir);
        (root_path / "jac.toml").write_text(
            '[project]\nname = "notes"\nkind = "web-app"\nentry-point = "main"\n'
        );
        (root_path / "main.jac").write_text(
            "sv import from analytics { Track }\n\n"
            "def:pub home -> str {\n    return \"hi\";\n}\n"
        );
        (root_path / "analytics.jac").write_text("walker:pub Track {}\n");
        (root_path / "notes").mkdir();
        (root_path / "notes" / "store.jac").write_text(NOTES_STORE);
        (root_path / "notes" / "NotesShell.jac").write_text(NOTES_SHELL);
        out = io.StringIO();
        with redirect_stdout(out) {
            rc = fix("placement", [str(root_path)]);
        }
        assert rc == 0 , rc;
        cfg = JacConfig.load(root_path / "jac.toml");
        assert list(cfg.apps.keys()) == ["notes", "analytics"] , list(cfg.apps.keys());
        assert cfg.apps["analytics"].kind == "service";
        printed = out.getvalue();
        assert "sv import at " + str(root_path / "main.jac") + ":1"
            in printed , printed;
        assert "NotesShell" not in printed , printed;
    }
}


test "a server-placed sv import is not hidden by a later client import of the same module" {
    import from pathlib { Path }
    import from jaclang.project.config { JacConfig }
    with tempfile.TemporaryDirectory() as tmpdir {
        root_path = Path(os.path.realpath(tmpdir));
        (root_path / "jac.toml").write_text(
            '[project]\nname = "notes"\nkind = "web-app"\nentry-point = "main"\n'
        );
        (root_path / "main.jac").write_text(
            "def:pub app -> JsxElement {\n    return <div>notes</div>;\n}\n"
        );
        (root_path / "notes").mkdir();
        (root_path / "notes" / "store.jac").write_text(
            NOTES_STORE
                + "\ndef:pub create_note(title: str) -> bool {\n"
                + "    root ++> Note(title=title);\n    return True;\n}\n"
        );
        (root_path / "notes" / "NotesShell.jac").write_text(
            "sv import from .store { create_note }\n"
                + NOTES_SHELL.replace("sv import from", "import from")
                + "\ndef:pub seed_note -> bool {\n    return create_note(\"first\");\n}\n"
        );
        assert fix("placement", [str(root_path)]) == 0;
        cfg = JacConfig.load(root_path / "jac.toml");
        assert "store" in cfg.apps , list(cfg.apps.keys());
        assert cfg.apps["store"].kind == "service";
    }
}


test "--dry-run classifies an sv import as the run does while its target still has markers" {
    import io;
    import from contextlib { redirect_stderr, redirect_stdout }
    import from pathlib { Path }
    with tempfile.TemporaryDirectory() as tmpdir {
        root_path = Path(tmpdir);
        toml_text = (
            '[project]\nname = "notes"\nkind = "web-app"\nentry-point = "main"\n'
        );
        (root_path / "jac.toml").write_text(toml_text);
        (root_path / "main.jac").write_text(
            "def:pub app -> JsxElement {\n    return <div>notes</div>;\n}\n"
        );
        (root_path / "notes").mkdir();
        (root_path / "notes" / "store.jac").write_text(
            "sv {\n"
                + "".join(
                    [
                        "    " + ln + "\n" if ln else "\n"
                        for ln in NOTES_STORE.splitlines()
                    ]
                )
                + "}\n"
        );
        (root_path / "notes" / "NotesShell.jac").write_text(NOTES_SHELL);
        out = io.StringIO();
        with redirect_stdout(out) {
            with redirect_stderr(out) {
                rc = fix("placement", [str(root_path)], dry_run=True);
            }
        }
        assert rc == 0 , rc;
        preview = out.getvalue();
        assert "Would migrate 2 file(s)" in preview , preview;
        assert "[apps." not in preview , preview;
        assert "unverified" not in preview , preview;
        assert fix("placement", [str(root_path)]) == 0;
        assert (root_path / "jac.toml").read_text() == toml_text;
        assert "sv {" not in (root_path / "notes" / "store.jac").read_text();
    }
}


test "a client sv import keeps its placement when another import shares its line" {
    import from pathlib { Path }
    with tempfile.TemporaryDirectory() as tmpdir {
        root_path = Path(tmpdir);
        toml_text = (
            '[project]\nname = "notes"\nkind = "web-app"\nentry-point = "main"\n'
        );
        (root_path / "jac.toml").write_text(toml_text);
        (root_path / "main.jac").write_text(
            "def:pub app -> JsxElement {\n    return <div>notes</div>;\n}\n"
        );
        (root_path / "analytics.jac").write_text("walker:pub Track {}\n");
        (root_path / "notes").mkdir();
        (root_path / "notes" / "store.jac").write_text(NOTES_STORE);
        (root_path / "notes" / "NotesShell.jac").write_text(
            NOTES_SHELL.replace(
                "sv import from .store { list_notes }\n",
                "sv import from .store { list_notes } import from analytics { Track }\n"
            )
                + "\ndef:pub ping -> bool {\n    Track();\n    return True;\n}\n"
        );
        assert fix("placement", [str(root_path)]) == 0;
        assert (root_path / "jac.toml").read_text() == toml_text , (
            (root_path / "jac.toml").read_text()
        );
    }
}
