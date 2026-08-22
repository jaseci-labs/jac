"""Tests for the `jac fix placement` marker-migration rewriter (#7772).

The rewriter is token-stream based so it must survive JSX, strings, and
comments, and it must keep working after the sv/cl/na keywords are gone
(the marker words then lex as plain names)."""

import os;
import tempfile;
import from jaclang.cli.commands.fix { _append_toml_entries, _strip_markers }


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
