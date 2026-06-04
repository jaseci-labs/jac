"""Integration test: the jaclang cl test runner against jac-scale's server.

jac-scale swaps in its own `JacAPIServer` (uvicorn-backed `JFastApiServer`) via
the `get_api_server_class` / `create_server` plugin hooks. This test guards that
the cl test runner boots the *active plugin's* server -- not a hard-coded base
class -- by running a real full-stack cl test (signup -> login -> walker spawn)
through bun against a jac-scale backend the runner boots on an ephemeral port.

bun is auto-installed on demand by the runner, so no toolchain setup is needed.
"""

import from pathlib { Path }
import from jaclang.runtimelib.cl_test_runner { run_cl_test_file }

glob FIXTURE = str(
         Path(__file__).parent / "fixtures" / "cl_fullstack" / "test_echo.cl.jac"
     );

test "cl runner boots jac-scale server for a full-stack client test" {
    results = run_cl_test_file(FIXTURE);
    assert results , "cl test runner discovered no client tests";
    for res in results {
        assert res.ok , f"cl test {res.name} failed: {res.error}";
    }
}
