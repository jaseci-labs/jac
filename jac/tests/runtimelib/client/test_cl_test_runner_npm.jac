"""npm import handling in the cl test runner.

Client tests run under bun in a sealed temp dir with no `node_modules`, so
every non-relative import spec has to be rewritten to something bun can
resolve.  These cover that rewriting for modules that are not `@jac/runtime`.
"""

import from pathlib { Path }
import from jaclang.runtimelib.cl_test_runner { module_is_client, run_cl_test_file }

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
