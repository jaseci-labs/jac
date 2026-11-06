"""Execute default client sorting with values that distinguish text order."""

import json;
import tempfile;
import from pathlib { Path }
import from tests.compiler.backends.es.codegen_helpers {
    compile_fixture_to_js,
    run_js_module
}

test "default list sort orders numeric values and retains string order" {
    with tempfile.TemporaryDirectory() as tmp {
        Path(tmp, "jac.toml").write_text('[placement.pins]\n"*" = "client"\n');
        source = Path(tmp, "sort_values.jac");
        source.write_text(
            'def numeric(values: list[float]) -> list[float] { values.sort(); return values; }\n'
            'def words(values: list[str]) -> list[str] { values.sort(); return values; }\n'
        );
        emitted = compile_fixture_to_js(str(source));
        result = run_js_module(
            emitted
                + '\nconsole.log(JSON.stringify({numbers: numeric([1036, 28, 532, 10, 2, -1.5]), strings: words(["b", "10", "a", "2"])}));\n'
        );
        assert result.returncode == 0 , result.stderr;
        got = json.loads(result.stdout);
        assert got["numbers"] == [-1.5, 2, 10, 28, 532, 1036] , (
            f"Default sort used numeric spellings instead of values: {got['numbers']}"
        );
        assert got["strings"] == ["10", "2", "a", "b"];
    }
}
