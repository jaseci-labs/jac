"""Per-file source map generation during client compilation.

When the client compiler writes `compiled/<mod>.js` it must also write a
`compiled/<mod>.js.map` mapping the generated JS lines back to the original
`.jac` source lines. Without it, a client-side JS error stack resolves only to
the compiled-JS line (with the `.jac` filename swapped in by the `/* Source */`
header), so the server log points at a line that does not exist in the `.jac`
file.

Regression guard: map generation must use the compiled module the bundler
already holds, NOT a re-fetch from the global `Jac.program.mod.hub`. A real
fullstack/interop build leaves the client modules out of that hub (they are
compiled into a separate codespace), so a hub lookup silently misses and skips
the map. These tests reproduce that condition by clearing the hub right after
each module is compiled.
"""

import json;
import from pathlib { Path }
import from tempfile { TemporaryDirectory }

# Holds the real `compile_module` while the wrapper below stands in for it.
glob _orig_compile_module: any = None;

"""Compile as usual, then empty the module hub -- mimicking the fullstack/interop
build where client modules never land in `Jac.program.mod.hub`. The returned
module (with its `gen.es_ast`) is exactly what map generation must rely on."""
def _compile_then_clear_hub(module_path: any) -> any {
    import from jaclang { JacRuntime as Jac }
    result = _orig_compile_module(module_path);
    Jac.program.mod.hub.clear();
    return result;
}

"""Build the shared client compile engine (JacClientCompiler) over a fresh
temp project containing `app.cl.jac`, with `compile_module` wrapped to clear
the hub after each compile. Returns the compiler and the compiled-output
directory."""
def _make_compiler(proj: Path) -> tuple[any, Path] {
    import from jaclang.runtimelib.client.vite_client_bundle { ViteClientBundleBuilder }
    (proj / "package.json").write_text('{"name":"t","version":"0.0.0"}');
    # A multi-statement component: `marker` is assigned on .jac line 6, but lands
    # several lines deep in the generated JS (after the runtime-import prefix and
    # the function wrapper) -- so a "report the JS line" bug resolves to a clearly
    # wrong line, while a correct map resolves it back to line 6.
    (proj / "app.cl.jac").write_text(
        'def:pub app() -> any {\n'  # 1
        '    alpha = 1;\n'  # 2
        '    beta = 2;\n'  # 3
        '    gamma = 3;\n'  # 4
        '    delta = 4;\n'  # 5
        '    marker = alpha + beta + gamma + delta;\n'  # 6  <-- target statement
        '    return <div>{marker}</div>;\n'  # 7
        '}\n'  # 8
    );
    builder = ViteClientBundleBuilder(vite_package_json=proj / "package.json");
    compiler = builder._get_compiler().jac_client_compiler;
    out_dir = proj / "out";
    compiler.compiled_dir = out_dir;
    global _orig_compile_module;
    _orig_compile_module = compiler.jac_compiler.compile_module;
    compiler.jac_compiler.compile_module = _compile_then_clear_hub;
    return (compiler, out_dir);
}

test "client compile writes a per-file source map even when the hub is empty" {
    with TemporaryDirectory() as tmp {
        (compiler, out_dir) = _make_compiler(Path(tmp));
        compiler.compile_dependencies_recursively(
            Path(tmp) / "app.cl.jac",
            visited=set(),
            collected_exports=set(),
            collected_globals={}
        );
        js_path = out_dir / "app.js";
        map_path = out_dir / "app.js.map";
        assert js_path.exists() , "compiled JS was not written";
        assert map_path.exists() , "per-file .js.map was not generated";
        # The compiled JS must chain to its map so Vite can compose it.
        assert "sourceMappingURL=app.js.map" in js_path.read_text();
    }
}

test "per-file source map resolves a deep JS line to the exact .jac line" {
    import from jaclang.runtimelib.source_mapping { SourceMap, _parse_mappings }

    with TemporaryDirectory() as tmp {
        (compiler, out_dir) = _make_compiler(Path(tmp));
        compiler.compile_dependencies_recursively(
            Path(tmp) / "app.cl.jac",
            visited=set(),
            collected_exports=set(),
            collected_globals={}
        );
        map_path = out_dir / "app.js.map";
        assert map_path.exists() , "per-file .js.map was not generated";
        data = json.loads(map_path.read_text());
        sm = SourceMap(
            sources=data["sources"],
            source_comments={},
            _index=_parse_mappings(data["mappings"])
        );
        # Find the generated JS line carrying the `marker` assignment.
        js_lines = (out_dir / "app.js").read_text().splitlines();
        marker_js_line = 0;
        for (i, line) in enumerate(js_lines) {
            if "marker" in line {
                marker_js_line = i + 1;
                break;
            }
        }
        assert marker_js_line > 0 , "marker statement not found in compiled JS";
        loc = sm.resolve(marker_js_line, 0);
        assert loc is not None , "JS line did not resolve to a source location";
        assert loc.file.endswith("app.cl.jac");
        assert loc.line == 6 , f"marker mapped to .jac:{loc.line}, expected 6";
    }
}
