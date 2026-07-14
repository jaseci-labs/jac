"""Focused tests for V-01's signal self-check pure helpers + registration.

The chain logic lives in pure helpers separate from probe I/O, so these
feed them mocked probe results. Plus a registration smoke test (an
unregistered /admin/ops/* would fall to the SPA catchall and serve HTML).
"""

import from jaclang.scale.jserver.jserver { HTTPMethod }
import from jaclang.scale.jserver.jfast_api { JFastApiServer }
import from jaclang.scale.admin.ops { JacAPIServerOps }
import from jaclang.scale.admin.ops { short_circuit_chain, _traces_chain }


obj OpsHost(JacAPIServerOps) {
    has server: any = None;
}


test "short_circuit_chain: first ok:false is the diagnosis, rest skipped" {
    out = short_circuit_chain(
        [
            {"name": "a", "ok": True, "detail": ""},
            {"name": "b", "ok": False, "detail": "boom"},
            {"name": "c", "ok": True, "detail": ""}
        ]
    );
    assert out["status"] == "fail" , f"status={out['status']}";
    assert out["chain"][1]["ok"] == False and out["chain"][1]["detail"] == "boom";
    assert out["chain"][2]["ok"] == None , "rungs after the first failure are skipped";
}


test "traces chain: all green -> ok; missing tracing extra -> first rung red" {
    p = {
        "has_otel": True,
        "cfg_enabled": True,
        "active": True,
        "endpoint": "http://collector:4318",
        "tempo_ready": True,
        "recent_count": 5
    };
    assert _traces_chain(p)["status"] == "ok";

    p2 = dict(p);
    p2["has_otel"] = False;
    out = _traces_chain(p2);
    assert out["status"] == "fail" and out["chain"][0]["ok"] == False;
}


test "register adds GET /admin/ops/health" {
    host = OpsHost();
    host.server = JFastApiServer();
    host.register_ops_endpoints();
    eps = [
        e
        for e in host.server._endpoints
        if e.path == "/admin/ops/health"
    ];
    assert len(eps) == 1 and eps[0].method == HTTPMethod.GET;
}
