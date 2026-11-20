"""Every dev-loop client failure must name a Jac location.

A blank page in `jac run` once left only this on disk:

    {"vite": null,
     "client": {"message": "The requested module '/.vite/deps/mermaid.js?v=0926aa4f'
                            does not provide an export named 'Mermaid'",
                "file": ""}}

The cause was one `.jac` import line, and nothing in the loop named a `.jac`
file. These tests pin the contract that replaced that: the client compiler
writes column-and-name source maps, one Jac-side locator turns any compiled
artifact coordinate back into a `.jac` (or `jac.toml`) location, and the
classifier turns each raw payload into a rendered diagnostic that either
carries a Jac location or says in words why it could not.
"""

import json;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

glob MERMAID_SRC = 'import from "mermaid" { default as mermaid, Mermaid }\n'
     'def:pub diagram() -> any {\n'
     '    engine = mermaid;\n'
     '    spec = Mermaid;\n'
     '    marker = engine;\n'
     '    return <div>{marker}</div>;\n'
     '}\n',
     LEFTPAD_SRC = 'import from "left-pad" { pad }\n'
     'def:pub padded() -> any {\n'
     '    value = pad;\n'
     '    return <div>{value}</div>;\n'
     '}\n';

"""Return every process-global this file touches to its default.

Test workers are pooled, so a locator cache keyed on a deleted temp dir or a
latched rate limiter would ride into whatever runs next in the same worker.
"""
def _reset_client_globals {
    import from jaclang.client.source_mapping {
        _locator_cache,
        _mapper_cache,
        _error_rate_limiter
    }
    _locator_cache.clear();
    _mapper_cache.clear();
    _error_rate_limiter._seen = {};
    _error_rate_limiter._count = 0;
    _error_rate_limiter._window_start = 0.0;
}

"""Lay out a temp project with a real `.jac/client/compiled` tree.

The locator reads only on-disk artifacts (the compiled `.js`, its `.js.map`,
the `/* Source: */` header and `jac.toml`), so the fixture is a real client
compile rather than a hand-written map.
"""
def _make_project(proj: Path) -> Path {
    import from jaclang.client.vite_client_bundle { ViteClientBundleBuilder }
    _reset_client_globals();
    (proj / "package.json").write_text('{"name":"t","version":"0.0.0"}');
    (proj / "jac.toml").write_text(
        '[project]\n'
        'name = "t"\n'
        'version = "0.1.0"\n'
        '\n'
        '[dependencies.npm]\n'
        'mermaid = "^11.0.0"\n'
    );
    docs = proj / "docs";
    docs.mkdir(parents=True, exist_ok=True);
    (docs / "MermaidDiagram.jac").write_text(MERMAID_SRC);
    (docs / "Missing.jac").write_text(LEFTPAD_SRC);
    compiled = proj / ".jac" / "client" / "compiled";
    builder = ViteClientBundleBuilder(vite_package_json=proj / "package.json");
    compiler = builder._get_compiler().jac_client_compiler;
    compiler.compiled_dir = compiled;
    for name in ["MermaidDiagram.jac", "Missing.jac"] {
        compiler.emit_dependencies(
            docs / name,
            visited=set(),
            collected_exports=set(),
            collected_globals={},
            source_root=proj
        );
    }
    return compiled;
}

"""1-based column of `token` on `line` of `path`, or 0 when absent."""
def _col_of(path: Path, line: int, token: str) -> int {
    lines = path.read_text().splitlines();
    if line < 1 or line > len(lines) {
        return 0;
    }
    idx = lines[line - 1].find(token);
    return 0 if idx < 0 else idx + 1;
}

test "source maps carry per-segment columns and the names they map" {
    import from jaclang.client.source_mapping { _parse_mappings }

    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        compiled = _make_project(proj);
        map_path = compiled / "docs" / "MermaidDiagram.js.map";
        assert map_path.exists() , "per-file .js.map was not generated";
        data = json.loads(map_path.read_text());
        assert data["version"] == 3;
        assert "Mermaid" in data["names"] , f"names array is missing the imported identifier: {data[
            'names'
        ]}";
        parsed = _parse_mappings(data["mappings"]);
        # Line-granular maps emit at most one segment per generated line. Real
        # column maps put every mapped token on its own segment.
        assert any(len(segs) > 1 for segs in parsed) , "mappings collapsed to one segment per line (no column information)";
        # Segment columns must be real generated columns, not a constant 0.
        assert any(seg[0] > 0 for segs in parsed for seg in segs) , "every segment starts at generated column 0";
    }
}

test "the locator maps an import specifier back to its exact .jac column" {
    import from jaclang.client.source_mapping { JacLocator }

    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _make_project(proj);
        locator = JacLocator.for_base(str(proj));
        loc = locator.locate_import("mermaid", "Mermaid");
        assert loc is not None , "import specifier did not resolve to a Jac location";
        assert loc.file.endswith("docs/MermaidDiagram.jac") , loc.file;
        assert loc.line == 1 , f"expected .jac line 1, got {loc.line}";
        src_line = MERMAID_SRC.splitlines()[0];
        assert src_line[loc.column - 1:].startswith("Mermaid") , f"column {loc.column} does not point at 'Mermaid' in: {src_line}";
    }
}

test "an ESM link error names the .jac import item and suggests import type" {
    import from jaclang.client.client_diagnostics { classify_client_payload }

    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _make_project(proj);
        # The exact payload recorded by the blank-page report.
        payload = {
            "type": "SyntaxError",
            "message": "The requested module '/.vite/deps/mermaid.js?v=0926aa4f' "
            "does not provide an export named 'Mermaid'",
            "stack": None,
            "source": "",
            "line": None,
            "column": None,
            "phase": "load"
        };
        diag = classify_client_payload(str(proj), payload, channel="browser");
        assert diag.code == "E7001" , diag.code;
        assert diag.file == "docs/MermaidDiagram.jac" , diag.file;
        assert diag.line == 1 , diag.line;
        expected_col = _col_of(proj / "docs" / "MermaidDiagram.jac", 1, "Mermaid");
        assert diag.column == expected_col , f"{diag.column} != {expected_col}";
        assert "import type" in diag.help_text , diag.help_text;
        assert diag.unmapped_reason == "" , diag.unmapped_reason;
        assert diag.raw_location == "/.vite/deps/mermaid.js?v=0926aa4f" , diag.raw_location;
        rendered = diag.render();
        assert f"--> docs/MermaidDiagram.jac:1:{expected_col}" in rendered , rendered;
        assert "error[E7001]" in rendered , rendered;
        assert "help:" in rendered , rendered;
    }
}

test "an unresolved npm import points at the .jac line and at jac.toml" {
    import from jaclang.client.client_diagnostics { classify_client_payload }

    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _make_project(proj);
        payload = {
            "message": 'Failed to resolve import "left-pad" from '
            '"compiled/docs/Missing.js". Does the file exist?',
            "id": str(proj / ".jac" / "client" / "compiled" / "docs" / "Missing.js"),
            "plugin": "vite:import-analysis",
            "stack": "",
            "frame": ""
        };
        diag = classify_client_payload(str(proj), payload, channel="vite");
        assert diag.code == "E7002" , diag.code;
        assert diag.file == "docs/Missing.jac" , diag.file;
        assert diag.line == 1 , diag.line;
        # The package is undeclared, so jac.toml is the second location.
        assert diag.related , "no related location for the undeclared package";
        rel = diag.related[0];
        assert str(rel["file"]).endswith("jac.toml") , rel["file"];
        assert int(rel["line"]) > 0 , rel;
        assert "dependencies.npm" in str(rel["label"]) , rel["label"];
        # One wording for the undeclared-npm case: the registry entry that
        # already owns it, not a copy under a second code.
        import from jaclang.compiler.frontend.diagnostics { DIAGNOSTICS }
        assert diag.help_text == DIAGNOSTICS["W1106"].format_help(name="left-pad") , diag.help_text;
        assert "jac install" in diag.help_text , diag.help_text;
        assert DIAGNOSTICS["E7002"].help_text != DIAGNOSTICS["W1106"].help_text , "E7002 duplicates W1106's help text";
        rendered = diag.render();
        assert "--> docs/Missing.jac:1:" in rendered , rendered;
        assert "jac.toml" in rendered , rendered;
    }
}

test "a browser stack resolves to the topmost frame that maps to Jac" {
    import from jaclang.client.client_diagnostics { classify_client_payload }

    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        compiled = _make_project(proj);
        js_lines = (compiled / "docs" / "MermaidDiagram.js").read_text().splitlines();
        target = 0;
        for (i, text) in enumerate(js_lines) {
            if "marker" in text {
                target = i + 1;
                break;
            }
        }
        assert target > 0 , "marker statement not found in compiled JS";
        stack = "TypeError: engine is not a function\n"
        "    at hot (http://localhost:5173/@vite/client:11:2)\n"
        f"    at diagram (http://localhost:5173/compiled/docs/MermaidDiagram.js:{target}:5)";
        payload = {
            "type": "TypeError",
            "message": "engine is not a function",
            "stack": stack,
            "source": "http://localhost:5173/compiled/docs/MermaidDiagram.js",
            "line": target,
            "column": 5
        };
        diag = classify_client_payload(str(proj), payload, channel="browser");
        assert diag.code == "E7003" , diag.code;
        assert diag.file == "docs/MermaidDiagram.jac" , diag.file;
        src_lines = MERMAID_SRC.splitlines();
        assert "marker" in src_lines[diag.line - 1] , f"stack mapped to .jac line {diag.line}: {src_lines[
            diag.line - 1
        ]}";
        assert diag.stack == stack , "the raw stack must be kept verbatim";
        assert diag.unmapped_reason == "" , diag.unmapped_reason;
    }
}

test "an unmappable payload still names an owner and says why it is unmapped" {
    import from jaclang.client.client_diagnostics { classify_client_payload }

    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _make_project(proj);
        payload = {
            "type": "Error",
            "message": "Script error.",
            "stack": None,
            "source": "chrome-extension://kkbfcplkddabmkflaepnmdgdnhcimbnk/inject.js",
            "line": 1,
            "column": 1
        };
        diag = classify_client_payload(str(proj), payload, channel="browser");
        assert diag.file != "" , "the file field must never be silently empty";
        assert diag.unmapped_reason != "" , "an unmapped diagnostic must say why";
        assert "chrome-extension" in diag.raw_location , diag.raw_location;
        rendered = diag.render();
        assert diag.unmapped_reason in rendered , rendered;
    }
}

test "the npm locator finds the declared key, the table, and the absent table" {
    import from jaclang.client.source_mapping { JacLocator }

    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _make_project(proj);
        locator = JacLocator.for_base(str(proj));
        # Declared key -> its own line
        found = locator.locate_npm_declaration("mermaid");
        assert found is not None;
        (loc, note) = found;
        assert loc.file.endswith("jac.toml");
        toml_lines = (proj / "jac.toml").read_text().splitlines();
        assert toml_lines[loc.line - 1].startswith("mermaid") , toml_lines[
            loc.line - 1
        ];
        assert note == "" , note;
        # Undeclared name, table present -> the table header line
        found = locator.locate_npm_declaration("left-pad");
        assert found is not None;
        (loc, note) = found;
        assert toml_lines[loc.line - 1] == "[dependencies.npm]" , toml_lines[
            loc.line - 1
        ];
        assert "not declared" in note , note;
        # Table absent -> the file, with a note
        (proj / "jac.toml").write_text('[project]\nname = "t"\n');
        locator2 = JacLocator.for_base(str(proj));
        found = locator2.locate_npm_declaration("left-pad");
        assert found is not None;
        (loc, note) = found;
        assert loc.line == 0 , loc.line;
        assert "[dependencies.npm]" in note , note;
    }
}

test "the locator is cached per compiled dir and invalidated by a touched map" {
    import os;
    import from jaclang.client.source_mapping { JacLocator }
    import from jaclang.client.client_diagnostics { classify_client_payload }

    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        compiled = _make_project(proj);
        payload = {
            "type": "SyntaxError",
            "message": "The requested module '/.vite/deps/mermaid.js?v=1' "
            "does not provide an export named 'Mermaid'",
            "source": "",
            "phase": "load"
        };
        # Two classifications against an unchanged compiled dir share one
        # locator: no re-scan and no re-parse of the maps per payload.
        classify_client_payload(str(proj), payload, channel="browser");
        first = JacLocator.for_base(str(proj));
        classify_client_payload(str(proj), payload, channel="browser");
        assert JacLocator.for_base(str(proj)) is first , "locator was rebuilt";
        # A map is loaded and parsed on first use only.
        assert "docs/MermaidDiagram.js" in first._maps , "the map the payload needed was never loaded";
        assert "docs/Missing.js" not in first._maps , "an unrelated map was parsed eagerly";
        # Touching a map invalidates the cache.
        touched = compiled / "docs" / "MermaidDiagram.js.map";
        stamp = os.path.getmtime(touched) + 10;
        os.utime(touched, (stamp, stamp));
        assert JacLocator.for_base(str(proj)) is not first , "a rebuilt map did not invalidate the locator";
    }
}

test "the locator scans no compiled headers until something asks for them" {
    import from jaclang.client.source_mapping { JacLocator }

    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _make_project(proj);
        locator = JacLocator.for_base(str(proj));
        assert locator._sources == {} , "for_base scanned the compiled headers";
        assert locator._maps == {} , "for_base parsed maps eagerly";
        assert locator._bundle_mapper is None , "for_base built the bundle mapper";
        # A compiled coordinate resolves through exactly one map.
        loc = locator.locate_compiled("compiled/docs/MermaidDiagram.js", 3, 18);
        assert loc is not None;
        assert loc.file.endswith("docs/MermaidDiagram.jac") , loc.file;
        assert list(locator._maps.keys()) == ["docs/MermaidDiagram.js"] , list(
            locator._maps.keys()
        );
        assert locator._sources == {} , "resolving a direct hit forced a header scan";
    }
}

test "a module id may not escape the compiled directory" {
    import from jaclang.client.source_mapping { JacLocator, _module_rel }
    import from jaclang.client.client_diagnostics { classify_client_payload }

    # `/cl/__error__` is reachable in production, so the module id in a browser
    # payload is attacker-influenced input that reaches the filesystem.
    for escape in [
        "http://host/compiled/../../../../etc/passwd",
        "compiled/../../secrets.js",
        "/compiled/a/../../../b.js",
        "..%2f..%2fx.js/../../../y.js"
    ] {
        assert _module_rel(escape) == "" , f"{escape} escaped to {_module_rel(escape)}";
    }
    # An ordinary nested module id still resolves.
    assert _module_rel("http://host:5173/compiled/docs/X.js?v=1") == "docs/X.js";
    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _make_project(proj);
        locator = JacLocator.for_base(str(proj));
        assert locator.locate_compiled("compiled/../../../etc/passwd", 1, 0) is None;
        assert locator.owner_for("compiled/../../../etc/passwd") == "";
        diag = classify_client_payload(
            str(proj),
            {
                "type": "Error",
                "message": "boom",
                "source": "http://host/compiled/../../../../etc/passwd",
                "line": 1,
                "column": 1
            },
            channel="browser"
        );
        assert diag.code == "E7006" , diag.code;
        assert "etc/passwd" not in diag.file , diag.file;
    }
}

test "the suite leaves no dev-loop global behind" {
    import from jaclang.client.source_mapping { _locator_cache, _mapper_cache }
    _reset_client_globals();
    # A pooled worker runs later suites in this same process.
    assert _locator_cache == {};
    assert _mapper_cache == {};
}

test "a startup bundle failure resolves every error it can place to a .jac line" {
    import from jaclang.client.client_diagnostics { classify_build_output }

    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        compiled = _make_project(proj);
        # What rollup actually prints when the bundle build fails at startup:
        # two unresolved imports in one blob, wrapped in framing noise.
        output = "error during build:\n"
        f'[vite]: Rollup failed to resolve import "left-pad" from "{compiled}/docs/Missing.js".\n'
        "This is most likely unintended because it can break your "
        "application at runtime.\n"
        'Failed to resolve import "mermaid" from "compiled/docs/MermaidDiagram.js". '
        "Does the file exist?\n"
        "    at viteWarn (file:///opt/vite/dist/node/chunks/dep.js:1:1)\n";
        diags = classify_build_output(str(proj), output);
        codes = [d.code for d in diags];
        assert codes == ["E7002", "E7002"] , codes;
        files = sorted([d.file for d in diags]);
        assert files == ["docs/MermaidDiagram.jac", "docs/Missing.jac"] , files;
        for d in diags {
            assert d.line == 1 , f"{d.file} lost its Jac line: {d.line}";
            assert d.channel == "vite" , d.channel;
        }
        rendered = "\n\n".join(d.render() for d in diags);
        assert "error[E7002]" in rendered , rendered;
        assert "--> docs/Missing.jac:1:" in rendered , rendered;
        assert "--> docs/MermaidDiagram.jac:1:" in rendered , rendered;
        # The undeclared package still gets the one npm wording, from W1106.
        missing = [
            d
            for d in diags
            if d.file == "docs/Missing.jac"
        ][0];
        assert "jac install" in missing.help_text , missing.help_text;
        assert missing.related , "no jac.toml location for the undeclared package";
    }
}

test "a Jac compile failure in the bundle output keeps its file, line and column" {
    import from jaclang.client.client_diagnostics { classify_build_output }

    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _make_project(proj);
        target = proj / "docs" / "MermaidDiagram.jac";
        output = f"Failed to compile '{target}', line 3, col 5: unexpected token";
        diags = classify_build_output(str(proj), output);
        assert len(diags) == 1 , [d.code for d in diags];
        diag = diags[0];
        assert diag.code == "E7005" , diag.code;
        assert diag.file == "docs/MermaidDiagram.jac" , diag.file;
        assert diag.line == 3 , diag.line;
        assert diag.column == 5 , diag.column;
        assert "unexpected token" in diag.message , diag.message;
        rendered = diag.render();
        assert "error[E7005]" in rendered , rendered;
        assert "--> docs/MermaidDiagram.jac:3:5" in rendered , rendered;
    }
}

test "a bundle failure that names nothing still renders and says why" {
    import from jaclang.client.client_diagnostics { classify_build_output }

    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        _make_project(proj);
        diags = classify_build_output(str(proj), "error during build:\nboom");
        assert len(diags) == 1 , [d.code for d in diags];
        diag = diags[0];
        assert diag.code == "E7004" , diag.code;
        assert diag.file != "" , "the file field must never be silently empty";
        assert diag.unmapped_reason != "" , "an unmapped diagnostic must say why";
        assert "error[E7004]" in diag.render() , diag.render();
    }
}

test "the startup renderer keeps the raw output only in debug mode" {
    import os;
    import from jaclang.client.client_diagnostics { format_build_diagnostics }

    with TemporaryDirectory() as tmp {
        proj = Path(tmp);
        compiled = _make_project(proj);
        output = f'Failed to resolve import "left-pad" from "{compiled}/docs/Missing.js".';
        prior = os.environ.get("JAC_DEBUG");
        try {
            os.environ["JAC_DEBUG"] = "0";
            quiet = format_build_diagnostics(str(proj), output);
            assert "error[E7002]" in quiet , quiet;
            assert "--> docs/Missing.jac:1:" in quiet , quiet;
            assert "Raw Error" not in quiet , quiet;
            os.environ["JAC_DEBUG"] = "1";
            loud = format_build_diagnostics(str(proj), output);
            assert "error[E7002]" in loud , loud;
            assert "Raw Error" in loud , loud;
            assert output in loud , loud;
        } finally {
            if prior is None {
                os.environ.pop("JAC_DEBUG", None);
            } else {
                os.environ["JAC_DEBUG"] = prior;
            }
        }
    }
}
