"""sv-to-sv calls must work on a base install with no third-party HTTP
library present at all.

Historically the scale provider's transport needed httpx, and without a
capability gate a base install swallowed every cross-service call into
`None` (callers then died on e.g. "'NoneType' object has no attribute
'pid'"). The transport is now the Jac-native client, which ships with the
runtime, so the gate is gone -- but the invariant it protected still
matters: a cross-service call must resolve on an install where httpx and
aiohttp are both absent."""

import json;
import sys;
import unittest.mock;
import from jaclang { JacRuntime }
import from jaclang.runtimelib { sv_client }
import from jaclang.runtimelib.serving.datatypes { Headers }


obj _StubResp {
    has payload: dict,
        content_type: str = "application/json";

    has text: str { getter; }
    has headers: any { getter; }

    def json -> any {
        return self.payload;
    }
}

impl _StubResp.text.getter -> str {
    return json.dumps(self.payload);
}

impl _StubResp.headers.getter -> any {
    h = Headers();
    h.set("Content-Type", self.content_type);
    return h;
}

"""An in-process test client whose post() yields a JSON function result."""
obj _StubClient {
    has result: any;

    def post(path: str, json: any = None) -> _StubResp {
        return _StubResp(payload={"ok": True, "data": {"result": self.result}});
    }
}


test "sv_service_call resolves with no third-party HTTP library installed" {
    sv_client.register_test_client("fallback_probe", _StubClient(result=99));
    try {
        no_http_libs: any = unittest.mock.patch.dict(
            sys.modules, {"httpx": None, "aiohttp": None}
        );
        with no_http_libs {
            got = JacRuntime.sv_service_call("fallback_probe", "compute", {"x": 1});
        }
        assert got == 99 , (
            f"sv call must resolve on the native transport, got {got!r}"
        );
    } finally {
        sv_client._test_clients.pop("fallback_probe", None);
    }
}
