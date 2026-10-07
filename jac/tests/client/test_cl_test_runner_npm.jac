"""cl test runner behaviours: npm import handling and annex resolution.

Client tests run under js_engine in a sealed temp dir with no `node_modules`, so
every non-relative import spec has to be rewritten to something js_engine can
resolve.  These cover that rewriting for modules that are not `@jac/runtime`.

They also cover which file the runner compiles (#9606): an annex resolves to its
base module, an annex with no base is its own unit, and a resolution error
propagates instead of silently falling back to the annex.
"""

import from pathlib { Path }
import from unittest.mock { patch }
import jaclang.compiler.driver.bccache as bccache;
import from jaclang.testing.cl_test_runner {
    module_entry_for,
    module_is_client,
    run_cl_test_file
}

glob FIXTURES = Path(__file__).parent / "fixtures",
     NPM = FIXTURES / "cl_npm",
     ANNEX_DIR = FIXTURES / "cl_annex",
     BASE = str(ANNEX_DIR / "widget.jac"),
     ANNEX = str(ANNEX_DIR / "widget.test.jac"),
     ORPHAN = str(ANNEX_DIR / "no_such_module.test.jac");

test "a client test importing only an npm module runs under js_engine" {
    fixture = str(NPM / "test_npm_only.jac");
    assert module_is_client(fixture) , f"{fixture} is not in the client codespace";

    results = run_cl_test_file(fixture);
    assert results , "cl test runner discovered no client tests";
    for res in results {
        assert res.ok , f"cl test {res.name} failed: {res.error}";
    }
}

test "a client test annex resolves to the module it belongs to" {
    assert module_entry_for(ANNEX) == BASE , "an annex must resolve to its module";
    assert module_entry_for(ORPHAN) == ORPHAN , "no base module means its own unit";
    assert module_is_client(ANNEX) , "an annex must inherit its module's placement";
    with patch.object(bccache, "discover_base_file", side_effect=OSError) {
        try {
            module_entry_for(ANNEX);
            assert False , "a resolution error must not fall back to the annex";
        } except OSError {}
    }

    results = run_cl_test_file(ANNEX);
    assert results , "no client tests discovered through the annex";
    for res in results {
        assert res.ok , f"cl test {res.name} failed through the annex: {res.error}";
    }
}
