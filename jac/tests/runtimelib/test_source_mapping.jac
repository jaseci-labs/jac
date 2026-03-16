"""Tests for the centralized source mapping utility."""

import json;
import os;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }
import from jaclang.runtimelib.source_mapping {
    SourceMapper,
    SourceMap,
    _decode_vlq,
    _parse_mappings,
    _scan_source_comments,
    read_source_snippet
}

# =============================================================================
# VLQ Decoding
# =============================================================================
test "vlq decodes simple values" {
    assert _decode_vlq("A") == [0];
    assert _decode_vlq("C") == [1];
    assert _decode_vlq("D") == [-1];
    assert _decode_vlq("K") == [5];
}

test "vlq decodes multi-value segment" {
    # A segment with 4 fields: gen_col, src_idx, src_line, src_col
    values = _decode_vlq("AACA");
    assert len(values) == 4;
    assert values[0] == 0;  # gen_col delta
    assert values[1] == 0;  # src_idx delta
    assert values[2] == 1;  # src_line delta
    assert values[3] == 0;  # src_col delta
}

# =============================================================================
# Source Comment Scanning
# =============================================================================
test "scan finds source comments in compiled JS" {
    with TemporaryDirectory() as tmpdir {
        compiled = Path(tmpdir) / "compiled";
        compiled.mkdir();
        (compiled / "main.js").write_text(
            "/* Source: /project/main.jac */\nvar x = 1;\n"
        );
        (compiled / "utils.js").write_text(
            "/* Source: /project/utils.jac */\nfunction f() {}\n"
        );
        # File without comment
        (compiled / "vendor.js").write_text("var y = 2;\n");
        comments = _scan_source_comments(compiled);
        assert any("/project/main.jac" in v for v in comments.values());
        assert any("/project/utils.jac" in v for v in comments.values());
        assert not any("vendor" in v for v in comments.values());
    }
}

test "scan handles subdirectories" {
    with TemporaryDirectory() as tmpdir {
        compiled = Path(tmpdir) / "compiled";
        components = compiled / "components";
        components.mkdir(parents=True);
        (components / "Button.js").write_text(
            "/* Source: /project/components/Button.cl.jac */\n"
        );
        comments = _scan_source_comments(compiled);
        assert any("Button.cl.jac" in v for v in comments.values());
    }
}

# =============================================================================
# Source Map Resolution
# =============================================================================
"""Create a minimal but realistic source map for testing."""
def _create_test_source_map(tmpdir: str) -> str {
    compiled_dir = Path(tmpdir) / ".jac" / "client" / "compiled";
    dist_dir = Path(tmpdir) / ".jac" / "client" / "dist";
    compiled_dir.mkdir(parents=True);
    dist_dir.mkdir(parents=True);

    (compiled_dir / "main.js").write_text(
        "/* Source: /project/main.jac */\nfunction app() { return 1; }\n"
    );
    (compiled_dir / "feed.js").write_text(
        "/* Source: /project/frontend/feed.jac */\nfunction feed() {}\n"
    );

    source_map = {
        "version": 3,
        "file": "client.abc123.js",
        "sources": ["../compiled/main.js", "../compiled/feed.js"],
        "names": [],
        "mappings": "AAAA;;;;ACGA"
    };
    map_path = dist_dir / "client.abc123.js.map";
    map_path.write_text(json.dumps(source_map));
    return tmpdir;
}

test "resolve to jac file" {
    with TemporaryDirectory() as tmpdir {
        _create_test_source_map(tmpdir);
        mapper = SourceMapper.from_bundle(tmpdir);
        loc = mapper.resolve(1, 0);
        assert loc is not None;
        assert "main.jac" in loc.file;
        assert loc.line == 1;
    }
}

test "resolve second source" {
    with TemporaryDirectory() as tmpdir {
        _create_test_source_map(tmpdir);
        mapper = SourceMapper.from_bundle(tmpdir);
        loc = mapper.resolve(5, 0);
        assert loc is not None;
        assert "feed.jac" in loc.file;
        assert loc.line == 4;  # src_line=3 -> 1-indexed = 4
    }
}

test "resolve returns none for invalid line" {
    with TemporaryDirectory() as tmpdir {
        _create_test_source_map(tmpdir);
        mapper = SourceMapper.from_bundle(tmpdir);
        assert mapper.resolve(9999, 0) is None;
        assert mapper.resolve(0, 0) is None;
    }
}

test "resolve without source map returns none" {
    mapper = SourceMapper();
    assert mapper.resolve(1, 0) is None;
}

# =============================================================================
# Stack Trace Resolution
# =============================================================================
"""Create a SourceMapper with a minimal source map."""
def _create_mapper_with_map(tmpdir: str) -> SourceMapper {
    compiled_dir = Path(tmpdir) / ".jac" / "client" / "compiled";
    dist_dir = Path(tmpdir) / ".jac" / "client" / "dist";
    compiled_dir.mkdir(parents=True);
    dist_dir.mkdir(parents=True);

    (compiled_dir / "main.js").write_text("/* Source: /project/main.jac */\n");

    source_map = {
        "version": 3,
        "file": "client.js",
        "sources": ["../compiled/main.js"],
        "names": [],
        "mappings": "AAAA"
    };
    (dist_dir / "client.hash.js.map").write_text(json.dumps(source_map));
    return SourceMapper.from_bundle(tmpdir);
}

test "resolve stack trace to jac files" {
    with TemporaryDirectory() as tmpdir {
        mapper = _create_mapper_with_map(tmpdir);
        stack = "TypeError: Cannot read property\n" + "    at MyComponent (http://localhost:8001/static/client.js:1:0)\n" + "    at React.render (http://localhost:8001/static/client.js:1:100)";
        resolved = mapper.resolve_stack_trace(stack);
        assert "main.jac" in resolved;
        assert "TypeError: Cannot read property" in resolved;
    }
}

test "node modules not resolved" {
    mapper = SourceMapper();
    stack = "    at React.createElement (node_modules/react/index.js:1:0)";
    assert mapper.resolve_stack_trace(stack) == stack;
}

test "no source map returns original stack" {
    mapper = SourceMapper();
    stack = "    at foo (client.js:1:0)";
    assert mapper.resolve_stack_trace(stack) == stack;
}

# =============================================================================
# Source Snippet Reader
# =============================================================================
test "read source snippet around target line" {
    with TemporaryDirectory() as tmpdir {
        f = Path(tmpdir) / "test.jac";
        f.write_text("line1\nline2\nline3\nline4\nline5\n");
        snippet = read_source_snippet(str(f), 3, context_lines=1);
        assert "line2" in snippet;
        assert "line3" in snippet;
        assert "line4" in snippet;
        assert " -> " in snippet;
    }
}

test "read source snippet returns empty for missing file" {
    assert read_source_snippet("/nonexistent/file.jac", 1) == "";
}

test "read source snippet handles edge case" {
    with TemporaryDirectory() as tmpdir {
        f = Path(tmpdir) / "test.jac";
        f.write_text("one line\n");
        snippet = read_source_snippet(str(f), 1);
        assert "one line" in snippet;
    }
}

# =============================================================================
# Line Mapping Precision (end-to-end through ES compiler)
# =============================================================================
"""Compile a .jac file through the ES compiler and verify that each
generated JS line maps back to the exact .jac source line."""
test "es compiler produces exact line mapping for function body statements" {
    import from jaclang.jac0core.runtime { JacRuntime as Jac }

    with TemporaryDirectory() as tmpdir {
        # Write a .jac file with distinct statements on known lines
        jac_file = Path(tmpdir) / "test_precision.jac";
        jac_source = (
            'cl {\n'  # line 1
            '    def:pub app() -> Any {\n'  # line 2
            '        has x: int = 1;\n'  # line 3
            '        has y: int = 2;\n'  # line 4
            '        has z: str = "hello";\n'  # line 5
            '        has w: bool = True;\n'  # line 6
            '        return <div>{x + y}</div>;\n'  # line 7
            '    }\n'  # line 8
            '}\n'  # line 9
        );
        jac_file.write_text(jac_source);
        # Compile
        program = Jac.get_program();
        mod = program.compile(str(jac_file));
        assert mod is not None , "Compilation failed";
        assert mod.gen.es_ast is not None , "No ES AST generated";
        # Get JS code and line map
        import from jaclang.compiler.passes.ecmascript.es_unparse { es_to_js_with_map }
        (js_code, line_map) = es_to_js_with_map(mod.gen.es_ast);
        assert len(line_map) > 0 , "No line mappings generated";
        # Build a lookup: output_line -> jac_line
        out_to_jac: dict[int, int] = {};
        for (out_line, src_line, src_col) in line_map {
            out_to_jac[out_line] = src_line;
        }
        # Find the JS output lines that contain our known statements
        js_lines = js_code.split('\n');
        for (i, js_line) in enumerate(js_lines) {
            out_line = i + 1;
            stripped = js_line.strip();
            if out_line in out_to_jac {
                jac_line = out_to_jac[out_line];
                # Verify: has x: int = 1 -> should map to .jac line 3
                if 'let x = 1' in stripped or 'useState(1)' in stripped {
                    assert jac_line == 3 , f"'x = 1' on JS line {out_line} mapped to .jac:{jac_line}, expected 3";
                }
                # has y: int = 2 -> .jac line 4
                if 'let y = 2' in stripped or 'useState(2)' in stripped {
                    assert jac_line == 4 , f"'y = 2' on JS line {out_line} mapped to .jac:{jac_line}, expected 4";
                }
                # has z: str = "hello" -> .jac line 5
                if '"hello"' in stripped
                and ('let z' in stripped or 'useState' in stripped) {
                    assert jac_line == 5 , f"'z = hello' on JS line {out_line} mapped to .jac:{jac_line}, expected 5";
                }
            }
        }
    }
}

# =============================================================================
# SourceMapper Caching
# =============================================================================
test "source mapper caches results" {
    with TemporaryDirectory() as tmpdir {
        _create_test_source_map(tmpdir);
        mapper1 = SourceMapper.from_bundle(tmpdir);
        mapper2 = SourceMapper.from_bundle(tmpdir);
        # Same base_path should return cached mapper (same object references)
        assert mapper1._source_map is mapper2._source_map;
    }
}

test "source mapper invalidates on file change" {
    import time;
    with TemporaryDirectory() as tmpdir {
        _create_test_source_map(tmpdir);
        mapper1 = SourceMapper.from_bundle(tmpdir);
        # Modify a .map file to invalidate cache
        time.sleep(0.1);
        dist_dir = Path(tmpdir) / ".jac" / "client" / "dist";
        for f in dist_dir.glob("*.js.map") {
            f.write_text(f.read_text());  # touch to change mtime
        }
        mapper2 = SourceMapper.from_bundle(tmpdir);
        # Should have reloaded (different object)
        assert mapper1._source_map is not mapper2._source_map;
    }
}

# =============================================================================
# Rate Limiter
# =============================================================================
test "rate limiter allows first error" {
    import from jaclang.runtimelib.source_mapping { ErrorRateLimiter }
    limiter = ErrorRateLimiter();
    assert limiter.should_log("first error") == True;
}

test "rate limiter deduplicates same message" {
    import from jaclang.runtimelib.source_mapping { ErrorRateLimiter }
    limiter = ErrorRateLimiter(dedup_seconds=10.0);
    assert limiter.should_log("same error") == True;
    assert limiter.should_log("same error") == False;  # deduped
    assert limiter.should_log("different error") == True;  # different message ok
}

test "rate limiter enforces window cap" {
    import from jaclang.runtimelib.source_mapping { ErrorRateLimiter }
    limiter = ErrorRateLimiter(max_per_window=3, dedup_seconds=0.0);
    assert limiter.should_log("error 1") == True;
    assert limiter.should_log("error 2") == True;
    assert limiter.should_log("error 3") == True;
    assert limiter.should_log("error 4") == False;  # over limit
}

# =============================================================================
# Source Map Generation
# =============================================================================
test "generate source map json produces valid map" {
    import from jaclang.runtimelib.source_mapping { generate_source_map_json }
    map_json = generate_source_map_json(
        source_file="test.jac",
        output_file="test.js",
        line_map=[(1, 5, 0), (2, 6, 4), (3, 10, 0)]
    );
    data = json.loads(map_json);
    assert data["version"] == 3;
    assert data["sources"] == ["test.jac"];
    assert len(data["mappings"]) > 0;
    # Verify round-trip resolution
    index = _parse_mappings(data["mappings"], len(data["sources"]));
    sm = SourceMap(sources=data["sources"], source_comments={}, _index=index);
    loc = sm.resolve(1, 0);
    assert loc is not None;
    assert loc.line == 5;
}

test "generate source map json handles empty line map" {
    import from jaclang.runtimelib.source_mapping { generate_source_map_json }
    map_json = generate_source_map_json("test.jac", "test.js", []);
    data = json.loads(map_json);
    assert data["mappings"] == "";
    assert data["sources"] == [];
}

# =============================================================================
# Two-layer Resolution
# =============================================================================
test "two-layer resolution chains bundle and per-file maps" {
    with TemporaryDirectory() as tmpdir {
        compiled_dir = Path(tmpdir) / ".jac" / "client" / "compiled";
        dist_dir = Path(tmpdir) / ".jac" / "client" / "dist";
        compiled_dir.mkdir(parents=True);
        dist_dir.mkdir(parents=True);
        # Create compiled JS with source comment
        (compiled_dir / "app.js").write_text(
            "/* Source: /project/app.jac */\nline1\nline2\nline3\n"
        );
        # Create per-file .map: app.js line 3 -> app.jac line 42
        import from jaclang.runtimelib.source_mapping { generate_source_map_json }
        per_file_map = generate_source_map_json(
            source_file="/project/app.jac",
            output_file="app.js",
            line_map=[(1, 10, 0), (2, 20, 5), (3, 42, 8)]
        );
        (compiled_dir / "app.js.map").write_text(per_file_map);
        # Create bundle .map: bundle line 1 -> app.js line 3
        # AAEA = gen_col=0, src_idx=0, src_line=2 (0-indexed), src_col=0
        bundle_map = {
            "version": 3,
            "file": "client.js",
            "sources": ["../compiled/app.js"],
            "names": [],
            "mappings": ";;AAEA"
        };
        (dist_dir / "client.hash.js.map").write_text(json.dumps(bundle_map));
        mapper = SourceMapper.from_bundle(tmpdir);
        # Bundle line 3 -> app.js line 3 -> app.jac line 42
        loc = mapper.resolve(3, 0);
        assert loc is not None;
        assert loc.file == "/project/app.jac";
        assert loc.line == 42;
    }
}
