"""sv-to-sv calls must fall back to the stdlib transport when the scale
provider's httpx transport is unavailable - not silently return None.

The scale plugin ships with jaclang, so it always imports and the core
runtime delegates every sv-to-sv call to it; its transport, however, needs
httpx. Without a capability gate a base install swallowed every
cross-service call into `None` (callers then died on e.g. "'NoneType'
object has no attribute 'pid'") even though the core stdlib transport
right below the delegation handles the call fine."""

import sys;
import unittest.mock;
import from jaclang { JacRuntime }
import from jaclang.runtimelib { sv_client }


"""An in-process test client whose stream() yields a JSON function result."""
def _fake_client(result: any) -> any {
    resp = unittest.mock.MagicMock();
    resp.headers = {"content-type": "application/json"};
    resp.json.return_value = {"ok": True, "data": {"result": result}};
    client = unittest.mock.MagicMock();
    client.stream.return_value.__enter__.return_value = resp;
    return client;
}


test "sv_service_call falls back to stdlib transport without httpx" {
    sv_client.register_test_client("fallback_probe", _fake_client(99));
    try {
        with unittest.mock.patch.dict(sys.modules, {"httpx": None}) {
            got = JacRuntime.sv_service_call("fallback_probe", "compute", {"x": 1});
        }
        assert got == 99 , (
            f"httpx-less sv call must use the stdlib transport, got {got!r}"
        );
    } finally {
        sv_client._test_clients.pop("fallback_probe", None);
    }
}
