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
    assert res.sv_imports == ["analytics"];
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
            "entry-point": "svc/analytics.jac",
            "route": "/analytics"
        };
        added = _append_app_table(toml_path, "analytics", table, False);
        assert added
            == [
                'kind = "service"',
                'entry-point = "svc/analytics.jac"',
                'route = "/analytics"'
            ] , added;
        with open(toml_path) as f {
            text = f.read();
        }
        assert text.startswith("[project]\nname = \"x\"\n") , text;
        assert "\n[apps.analytics]\nkind = \"service\"\n" in text , text;
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
            'entry-point = "main.jac"\n\n[dependencies]\nrequests = ">=2"\n'
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
        assert "[dependencies]\nrequests = \">=2\"" in text , text;
        cfg = JacConfig.load(root_path / "jac.toml");
        assert cfg.is_workspace;
        assert cfg.default_app == "shop" , cfg.default_app;
        assert cfg.project.kind == "" , "[project] kind is gone";
        base = cfg.apps["shop"];
        assert base.kind == "web-app" , base.kind;
        assert base.entry_point == "main.jac" , base.entry_point;
        svc = cfg.apps["analytics"];
        assert svc.kind == "service" , svc.kind;
        assert svc.entry_point == "analytics.jac" , svc.entry_point;
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
            '[project]\nname = "shop"\nkind = "web-app"\nentry-point = "main.jac"\n'
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
