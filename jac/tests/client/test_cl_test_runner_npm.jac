"""npm import handling in the cl test runner.

Client tests run under bun in a sealed temp dir with no `node_modules`, so
every non-relative import spec has to be rewritten to something bun can
resolve.  These cover that rewriting for modules that are not `@jac/runtime`.
"""

import from pathlib { Path }
import from jaclang.testing.cl_test_runner { module_is_client, run_cl_test_file }

glob FIXTURES = Path(__file__).parent / "fixtures" / "cl_npm";

test "a client test importing only an npm module runs under bun" {
    fixture = str(FIXTURES / "test_npm_only.jac");
    assert module_is_client(fixture) , f"{fixture} is not in the client codespace";

    results = run_cl_test_file(fixture);
    assert results , "cl test runner discovered no client tests";
    for res in results {
        assert res.ok , f"cl test {res.name} failed: {res.error}";
    }
}

test "client harness stages side effect imports alongside named imports" {
    import tempfile;
    import from jaclang.testing.cl_test_runner { _collect_local_imports }
    with tempfile.TemporaryDirectory() as directory {
        Path(directory, "side.jac").write_text("glob ready: int = 1;\n");
        Path(directory, "named.jac").write_text("glob value: int = 2;\n");
        (files, _) = _collect_local_imports(
            'import "./side.js";\nimport { value } from "./named.js";\n',
            directory,
            str(Path(directory, "test_entry.jac"))
        );
        assert set(files) == {"side.js", "named.js"};
        assert "export { value }" in files["named.js"];
    }
}

test "client harness rewrites side effect npm imports to its shared stub" {
    import from jaclang.testing.cl_test_runner { _stub_npm_imports }
    (entry_js, files, stub, changed) = _stub_npm_imports(
        'import "npm-side-effect";\nimport { useState } from "react";\n',
        {"dependency.js": 'import "./local.js";\n'}
    );
    assert changed;
    assert 'import "./__jac_npm_stub.js";' in entry_js;
    assert 'import { useState } from "./__jac_npm_stub.js";' in entry_js;
    assert "export const useState" in stub;
    assert files["dependency.js"] == 'import "./local.js";\n';
}
