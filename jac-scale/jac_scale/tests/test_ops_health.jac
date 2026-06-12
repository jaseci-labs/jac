"""Tests for V-01's JacAPIServerOps signal self-check.

Two surfaces:
  - endpoint registration: /admin/ops/health is registered, GET, and
    tagged "Operations" (the SPA-catchall trap means a missing route would
    silently serve index.html, so we assert it exists).
  - the PURE chain-evaluation helpers (`short_circuit_chain` + the
    per-signal `_*_chain` builders), fed MOCKED probe dicts. These cover
    short-circuit (first red is the diagnosis, rest skipped), all-green,
    the config-gate "off" status, and each broken-link case for traces -
    the live backend probes are integration-tested on the real cluster.
"""

import from jac_scale.admin.ops { JacAPIServerOps }
import from jac_scale.admin.ops {
    short_circuit_chain,
    _traces_chain,
    _logs_chain,
    _metrics_chain,
    _mongo_chain,
    _redis_chain,
    _admin_api_chain
}
import from jac_scale.jserver.jfast_api { JFastApiServer }


obj OpsHost(JacAPIServerOps) {
    has server: any = None;
}


test "register_ops_endpoints adds GET /admin/ops/health tagged Operations" {
    import from jac_scale.jserver.jserver { HTTPMethod }

    host = OpsHost();
    host.server = JFastApiServer();
    host.register_ops_endpoints();

    eps = [e for e in host.server._endpoints if e.path == "/admin/ops/health"];
    assert len(eps) == 1 , f"expected one /admin/ops/health, got {len(eps)}";
    assert eps[0].method == HTTPMethod.GET , f"should be GET, got {eps[0].method}";
    assert eps[0].tags == ["Operations"] , f"should be tagged ['Operations'], got {eps[0].tags}";
}


# --- short_circuit_chain (the core pure helper) --------------------------

test "short_circuit_chain: all rungs pass -> status ok, every ok True" {
    out = short_circuit_chain([
        {"name": "a", "ok": True, "detail": "x"},
        {"name": "b", "ok": True, "detail": "y"}
    ]);
    assert out["status"] == "ok" , f"status = {out['status']}";
    assert [c["ok"] for c in out["chain"]] == [True, True];
}


test "short_circuit_chain: first false is the diagnosis, rest skipped" {
    out = short_circuit_chain([
        {"name": "a", "ok": True, "detail": "x"},
        {"name": "b", "ok": False, "detail": "boom"},
        {"name": "c", "ok": True, "detail": "z"}
    ]);
    assert out["status"] == "fail" , f"status = {out['status']}";
    chain = out["chain"];
    assert chain[0]["ok"] == True;
    assert chain[1]["ok"] == False;
    assert chain[1]["detail"] == "boom";
    # Everything after the first failure is marked skipped (ok None), even
    # though rung c's input ok was True - its probe was blocked.
    assert chain[2]["ok"] == None , f"expected skipped, got {chain[2]}";
    assert chain[2]["detail"] == "skipped";
}


test "short_circuit_chain: a failing gate yields status 'off', not 'fail'" {
    out = short_circuit_chain([
        {"name": "enabled", "ok": False, "detail": "off", "gate": True},
        {"name": "next", "ok": True, "detail": "z"}
    ]);
    assert out["status"] == "off" , f"a failing gate should be 'off', got {out['status']}";
}


# --- _traces_chain: each broken link (the O-02 count:0 incident) ---------

def _traces_all_green -> dict {
    return {
        "has_otel": True,
        "cfg_enabled": True,
        "active": True,
        "endpoint": "http://collector:4318",
        "tempo_ready": True,
        "recent_count": 7
    };
}


test "traces: all green -> status ok" {
    out = _traces_chain(_traces_all_green());
    assert out["status"] == "ok" , f"status = {out['status']}";
    assert len(out["chain"]) == 6;
    for step in out["chain"] {
        assert step["ok"] == True , f"unexpected red step: {step}";
    }
}


test "traces: missing tracing extra (the canonical incident) -> first red" {
    p = _traces_all_green();
    p["has_otel"] = False;
    out = _traces_chain(p);
    assert out["status"] == "fail";
    assert out["chain"][0]["ok"] == False , "HAS_OTEL rung should be the red one";
    # The diagnosis text names the actual fix.
    assert "tracing" in out["chain"][0]["detail"].lower();
    # Downstream rungs are skipped, not falsely green/red.
    assert out["chain"][5]["ok"] == None;
}


test "traces: config disabled -> status off (gate), amber not red" {
    p = _traces_all_green();
    p["cfg_enabled"] = False;
    out = _traces_chain(p);
    assert out["status"] == "off" , f"disabled-by-config should be 'off', got {out['status']}";
    assert out["chain"][1]["ok"] == False;
}


test "traces: endpoint env unset -> the OTEL endpoint rung is the diagnosis" {
    p = _traces_all_green();
    p["endpoint"] = "";
    out = _traces_chain(p);
    assert out["status"] == "fail";
    assert out["chain"][3]["ok"] == False , "endpoint rung should be red";
    assert out["chain"][2]["ok"] == True , "earlier rungs stay green";
}


test "traces: Tempo unreachable -> tempo /ready rung is the diagnosis" {
    p = _traces_all_green();
    p["tempo_ready"] = False;
    out = _traces_chain(p);
    assert out["status"] == "fail";
    assert out["chain"][4]["ok"] == False;
    assert out["chain"][5]["ok"] == None , "count rung skipped when Tempo down";
}


test "traces: everything up but zero spans in 5m -> count rung red" {
    p = _traces_all_green();
    p["recent_count"] = 0;
    out = _traces_chain(p);
    assert out["status"] == "fail";
    assert out["chain"][5]["ok"] == False , "count>0 rung should be red";
    assert "count = 0" in out["chain"][5]["detail"];
}


# --- logs / metrics / mongo / redis / admin-api --------------------------

test "logs: enabled + Loki ready + lines -> ok; disabled -> off" {
    ok = _logs_chain({"cfg_enabled": True, "loki_ready": True, "recent_count": 3});
    assert ok["status"] == "ok";

    off = _logs_chain({"cfg_enabled": False, "loki_ready": False, "recent_count": 0});
    assert off["status"] == "off" , f"logs disabled should be 'off', got {off['status']}";
}


test "metrics: client present + Prometheus reachable -> ok; no client -> fail" {
    ok = _metrics_chain({"has_client": True, "prom_ready": True});
    assert ok["status"] == "ok";

    none = _metrics_chain({"has_client": False, "prom_ready": False});
    assert none["status"] == "fail";
    assert none["chain"][0]["ok"] == False;
    assert none["chain"][1]["ok"] == None , "Prometheus rung skipped when no client";
}


test "mongo: unreachable ping is the admin-login-HTML incident's red row" {
    ok = _mongo_chain({"configured": True, "detail": "mongodb://***@m:27017", "ping": True});
    assert ok["status"] == "ok";

    down = _mongo_chain({"configured": True, "detail": "mongodb://***@m:27017", "ping": False});
    assert down["status"] == "fail";
    assert down["chain"][1]["ok"] == False , "ping rung should be red";

    unset = _mongo_chain({"configured": False, "detail": "no MONGODB_URI", "ping": False});
    assert unset["status"] == "fail";
    assert unset["chain"][0]["ok"] == False , "configured rung should be red";
}


test "redis: configured + ping -> ok; ping fail -> fail" {
    ok = _redis_chain({"configured": True, "detail": "redis://r:6379", "ping": True});
    assert ok["status"] == "ok";

    down = _redis_chain({"configured": True, "detail": "redis://r:6379", "ping": False});
    assert down["status"] == "fail";
    assert down["chain"][1]["ok"] == False;
}


test "admin_api: registered -> ok; None server -> fail (catchall trap)" {
    assert _admin_api_chain(True)["status"] == "ok";

    down = _admin_api_chain(False);
    assert down["status"] == "fail";
    assert down["chain"][0]["ok"] == False;
    # The detail must name the actual failure mode so an operator can act.
    assert "catchall" in down["chain"][0]["detail"].lower();
}
