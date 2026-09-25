import json;
import os;
import tempfile;
import from pathlib { Path }
import from unittest.mock { patch }

def _entry(version: str, yanked: bool = False, role: str = "lib") -> IndexEntry {
    return IndexEntry(
        name="acme/kit",
        version=version,
        sha256="0" * 64,
        role=role,
        yanked=yanked,
        description="Geometry kit",
        exports=["geo"],
        source="https://github.com/acme/kit"
    );
}

def _registry(entries: list[IndexEntry], api: dict[str, any]) -> Path {
    base = Path(tempfile.mkdtemp(prefix="site-packages-"));
    (base / "config.json").write_text(
        json.dumps({"protocol": 1, "blob_base": "blobs/", "repo": "t/i"})
    );
    index = base / "index" / "acme";
    index.mkdir(parents=True);
    (index / "kit.json").write_text("\n".join([e.to_line() for e in entries]) + "\n");
    for e in entries {
        target = base / "api" / "acme" / "kit" / f"{e.version}.json";
        target.parent.mkdir(parents=True, exist_ok=True);
        target.write_text(json.dumps(api));
    }
    return base;
}

glob API: dict[str, any] = {
         "format": 1,
         "module_docs": {"geo": "Rectangle helpers."},
         "modules": {
             "geo": {
                 "area": {
                     "kind": "function",
                     "doc": "Area of a rectangle.",
                     "params": [
                         {
                             "name": "w",
                             "kind": "normal",
                             "type": "int",
                             "default": False
                         },
                         {
                             "name": "h",
                             "kind": "normal",
                             "type": "int",
                             "default": True,
                             "value": "1"
                         }
                     ],
                     "returns": "int"
                 },
                 "Box": {
                     "kind": "node",
                     "bases": [],
                     "members": {
                         "w": {
                             "kind": "field",
                             "type": "int",
                             "default": True,
                             "value": "0"
                         }
                     }
                 }
             }
         }
     };

test "the latest version skips yanked releases and prefers stable ones" {
    entries = [_entry("1.0.0"), _entry("1.1.0", yanked=True), _entry("2.0.0-rc.1")];
    best = latest_entry(entries);
    assert best is not None and best.version == "1.0.0";
    only_rc = latest_entry([_entry("2.0.0-rc.1")]);
    assert only_rc is not None and only_rc.version == "2.0.0-rc.1";
    assert latest_entry([_entry("1.0.0", yanked=True)]) is None;
}

test "install commands differ for libraries and templates" {
    assert install_command("acme/kit", "lib") == "jac install acme/kit";
    assert install_command("acme/app", "template")
        == "jac create my-app --use acme/app";
}

test "API files become typed modules with docs and defaults" {
    modules = api_modules(API);
    assert [m.name for m in modules] == ["geo"];
    assert modules[0].doc == "Rectangle helpers.";
    syms = {s.name: s for s in modules[0].symbols};
    assert syms["area"].doc == "Area of a rectangle.";
    assert syms["area"].params[1].value == "1";
    assert syms["Box"].members[0].value == "0";
}

test "READMEs lose raw HTML and unsafe links but keep images and relative links" {
    text = "\n".join(
        [
            "# Kit",
            "<p align=\"center\"><img src=\"docs/logo.png\"></p>",
            "<script>alert(1)</script>",
            "See [the guide](docs/guide.md) and [evil](javascript:alert(1)).",
            "[![badge](https://img.shields.io/x.svg)](javascript:alert(2))",
            "![shot](./shot.png) [top](#kit) [mail](mailto:a@b.c)",
            "```html",
            "<div>kept in a fence</div>",
            "```",
            "> <iframe src=\"https://x\"></iframe>"
        ]
    );
    lines = safe_readme(text, "acme", "kit", "main");
    joined = "\n".join(lines);
    assert "<script" not in joined and "<p " not in joined and "<iframe" not in joined;
    assert "![](https://raw.githubusercontent.com/acme/kit/main/docs/logo.png)"
        in lines;
    assert "(https://github.com/acme/kit/blob/main/docs/guide.md)" in joined;
    assert "javascript:" not in joined , joined;
    assert "![shot](https://raw.githubusercontent.com/acme/kit/main/shot.png)"
        in joined;
    assert "[top](#kit)" in joined and "[mail](mailto:a@b.c)" in joined;
    assert "<div>kept in a fence</div>" in lines;
}

test "the catalog and a package page read the index without downloading artifacts" {
    base = _registry([_entry("1.0.0"), _entry("1.1.0")], API);
    _CACHE.clear();
    with patch.dict(os.environ, {"JAC_REGISTRY": str(base)}), patch(
        package_catalog.__module__ + ".repo_readme",
        return_value=RepoReadme(lines=["# Kit"], stars=3)
    ), patch(
        "jaclang.packages.index.Registry.fetch_blob",
        side_effect=AssertionError("the site must not download artifacts")
    ) {
        catalog = package_catalog();
        assert catalog.ready and not catalog.error , catalog.error;
        assert [p.name for p in catalog.packages] == ["acme/kit"];
        kit = catalog.packages[0];
        assert kit.latest == "1.1.0" and kit.description == "Geometry kit";
        assert "area" in kit.symbols and kit.install == "jac install acme/kit";
        page = package_detail(name="acme/kit");
        assert page.found and page.version == "1.1.0";
        assert [v.version for v in page.versions] == ["1.1.0", "1.0.0"];
        assert page.readme_lines == ["# Kit"] and page.stars == 3;
        assert page.modules[0].name == "geo";
        older = package_detail(name="acme/kit", version="1.0.0");
        assert older.found and older.version == "1.0.0";
        missing = package_detail(name="acme/kit", version="9.0.0");
        assert not missing.found and "9.0.0" in missing.error;
        assert not package_detail(name="not a name").found;
    }
    _CACHE.clear();
}
