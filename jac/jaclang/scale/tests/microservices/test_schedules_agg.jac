"""The gateway answers every /admin/* route itself, so a service's static
schedules are unreachable through it unless the gateway asks for them. It asks
every service it serves, names the service and namespace on each row, and
relays a refusal instead of hiding it behind a 404."""

import asyncio;
import json;
import from jaclang.scale.runtime.gateway.microservice_gateway { MicroserviceGateway }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jaclang.server.serving.datatypes { Headers, Request, URL }

glob _ASKED: list[tuple[int, str]] = [];

"""Answer every GET with `status` and `payload`; (server, port). Each request
records (port, path) in `_ASKED`."""
def _serve(status: int, payload: dict[str, any]) -> tuple[any, ...] {
    import http.server;
    import threading;

    body = json.dumps(payload).encode();

    def _do_get(handler_self: any) {
        _ASKED.append((handler_self.server.server_address[1], handler_self.path));
        handler_self.send_response(status);
        handler_self.send_header("Content-Type", "application/json");
        handler_self.send_header("Content-Length", str(len(body)));
        handler_self.end_headers();
        handler_self.wfile.write(body);
    }

    def _log_quiet(handler_self: any, fmt: str, *args: any) {}

    handler_cls = type(
        "_SchedulesHandler",
        (http.server.BaseHTTPRequestHandler, ),
        {"do_GET": _do_get, "log_message": _log_quiet}
    );
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler_cls);
    t = threading.Thread(target=srv.serve_forever, daemon=True);
    t.start();
    return (srv, srv.server_address[1]);
}


def _entry(name: str, port: int) -> ServiceEntry {
    return ServiceEntry(
        name=name,
        file=f"{name}.jac",
        prefix=f"/{name}",
        port=port,
        url=f"http://127.0.0.1:{port}",
        status=ServiceStatus.HEALTHY
    );
}


def _ask(reg: ServiceRegistry) -> any {
    gw = MicroserviceGateway(registry=reg);
    req = Request(
        method="GET",
        url=URL(path="/admin/schedules"),
        headers=Headers(),
        client_host="10.0.0.1"
    );
    return asyncio.run(gw.aggregate_schedules(req));
}


def _listing(namespace: str, name: str, kind: str) -> dict[str, any] {
    return {
        "ok": True,
        "data": {
            "namespace": namespace,
            "schedules": [{"name": name, "kind": kind, "last_run": None}]
        }
    };
}


test "the gateway merges every service's schedules and names each row's service" {
    (srv_a, port_a) = _serve(200, _listing("orders", "nightly", "function"));
    (srv_b, port_b) = _serve(200, _listing("billing", "dunning", "walker"));
    reg = ServiceRegistry();
    reg.register(_entry("orders", port_a));
    reg.register(_entry("billing", port_b));
    _ASKED.clear();
    try {
        resp = _ask(reg);
    } finally {
        srv_a.shutdown();
        srv_b.shutdown();
    }
    assert resp is not None , "the gateway answered nothing";
    assert resp.status_code == 200 , resp.status_code;
    data = json.loads(resp.body)["data"];
    assert sorted(data["services"]) == ["billing", "orders"] , data;
    rows = {r["name"]: r for r in data["schedules"]};
    assert (rows["nightly"]["service"], rows["nightly"]["namespace"])
        == ("orders", "orders") , rows;
    assert (rows["dunning"]["service"], rows["dunning"]["namespace"])
        == ("billing", "billing") , rows;
    assert [asked[1] for asked in _ASKED]
        == ["/admin/schedules", "/admin/schedules"] , _ASKED;
}


test "a service that refuses the listing is relayed, not hidden behind a 404" {
    (srv, port) = _serve(403, {"ok": False, "error": {"code": "FORBIDDEN"}});
    reg = ServiceRegistry();
    reg.register(_entry("orders", port));
    try {
        resp = _ask(reg);
    } finally {
        srv.shutdown();
    }
    assert resp is not None , "a refusal must reach the caller";
    assert resp.status_code == 403 , resp.status_code;
    assert json.loads(resp.body)["error"]["code"] == "FORBIDDEN" , resp.body;
}


test "a service with no listing is skipped, and nothing merged is no answer" {
    (srv, port) = _serve(404, {"ok": False});
    reg = ServiceRegistry();
    reg.register(_entry("orders", port));
    try {
        resp = _ask(reg);
    } finally {
        srv.shutdown();
    }
    assert resp is None , "nothing to merge must fall through to the admin app";
}
