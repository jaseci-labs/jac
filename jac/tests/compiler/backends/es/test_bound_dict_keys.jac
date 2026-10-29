"""Bound dictionary keys must evaluate their values in client output."""

import json;
import tempfile;
import from pathlib { Path }
import from tests.compiler.backends.es.codegen_helpers {
    compile_fixture_to_js,
    run_js_module
}

test "bound dictionary keys preserve runtime values through spread updates" {
    with tempfile.TemporaryDirectory() as tmp {
        Path(tmp, "jac.toml").write_text('[placement.pins]\n"*" = "client"\n');
        source = Path(tmp, "bound_keys.jac");
        source.write_text(
            'glob shared_key: str = "global-name";\n'
            'def build(key: str, value: str) -> dict {\n'
            '    local_key = "local-name";\n'
            '    original = {"existing": "kept", key: "old"};\n'
            '    return {**original, key: value, local_key: "local", '
            'shared_key: "global", "literal": "literal", 7: "number"};\n'
            '}\n'
        );
        js_code = compile_fixture_to_js(str(source));
        result = run_js_module(
            js_code
                + '\nconsole.log(JSON.stringify(build("chosen-name", "updated")));\n'
        );
        assert result.returncode == 0 , result.stderr;
        got = json.loads(result.stdout);
        assert got
            == {
                "existing": "kept",
                "chosen-name": "updated",
                "local-name": "local",
                "global-name": "global",
                "literal": "literal",
                "7": "number"
            } , f"Dictionary keys used identifier spellings instead of values: {got}";
    }
}

test "unresolved client property names retain literal keys" {
    with tempfile.TemporaryDirectory() as tmp {
        Path(tmp, "jac.toml").write_text('[placement.pins]\n"*" = "client"\n');
        source = Path(tmp, "literal_keys.jac");
        source.write_text(
            'def config() -> dict { return {label: "Email", type: "email"}; }\n'
        );
        js_code = compile_fixture_to_js(str(source));
        result = run_js_module(js_code + '\nconsole.log(JSON.stringify(config()));\n');
        assert result.returncode == 0 , result.stderr;
        assert json.loads(result.stdout) == {"label": "Email", "type": "email"};
    }
}
