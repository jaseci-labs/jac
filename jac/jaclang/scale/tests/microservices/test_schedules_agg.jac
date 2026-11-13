"""The gateway answers every /admin/* route itself, so a service's static
schedules are unreachable through it unless the gateway asks for them. It asks
every service it serves, names the service and namespace on each row, and
relays a refusal instead of hiding it behind a 404."""

import asyncio;
import json;
import os;

glob _ASKED: list[tuple[int, str]] = [],
     _PRESENTED: list[str] = [];

"""Answer every GET with `status` and `payload`; (server, port). Each request
records (port, path) in `_ASKED` and its Authorization in `_PRESENTED`. With
`only_bearer`, any other Authorization is refused with a 403, as a service whose
own user store has never seen the caller refuses a gateway admin's token."""
def _serve(
    status: int, payload: dict[str, any], only_bearer: str = ""
) -> tuple[any, ...] {
    import http.server;
    import threading;

    body = json.dumps(payload).encode();
    refusal = json.dumps({"ok": False, "error": {"code": "FORBIDDEN"}}).encode();

    def _do_get(handler_self: any) {
        _ASKED.append((handler_self.server.server_address[1], handler_self.path));
        presented = str(handler_self.headers.get("Authorization") or "");
        _PRESENTED.append(presented);
        if only_bearer and presented != f"Bearer {only_bearer}" {
            handler_self.send_response(403);
            handler_self.send_header("Content-Type", "application/json");
            handler_self.send_header("Content-Length", str(len(refusal)));
            handler_self.end_headers();
            handler_self.wfile.write(refusal);
            return;
        }
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


def _ask(reg: ServiceRegistry, authorization: str = "") -> any {
    gw = MicroserviceGateway(registry=reg);
    headers = Headers();
    if authorization {
        headers.append("authorization", authorization);
    }
    req = Request(
        method="GET",
        url=URL(path="/admin/schedules"),
        headers=headers,
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
    (srv_c, port_c) = _serve(500, {"ok": False});
    (srv_d, port_d) = _serve(200, {});
    srv_d.shutdown();
    srv_d.server_close();
    reg = ServiceRegistry();
    reg.register(_entry("orders", port_a));
    reg.register(_entry("billing", port_b));
    reg.register(_entry("ledger", port_c));
    reg.register(_entry("search", port_d));
    _ASKED.clear();
    try {
        resp = _ask(reg);
    } finally {
        srv_a.shutdown();
        srv_b.shutdown();
        srv_c.shutdown();
    }
    assert resp is not None , "the gateway answered nothing";
    assert resp.status_code == 200 , resp.status_code;
    data = json.loads(resp.body)["data"];
    assert sorted(data["services"]) == ["billing", "orders"] , data;
    unanswered = {m["service"]: m["status"] for m in data["unanswered"]};
    assert unanswered == {"ledger": 500, "search": None} , data;
    rows = {r["name"]: r for r in data["schedules"]};
    assert (rows["nightly"]["service"], rows["nightly"]["namespace"])
        == ("orders", "orders") , rows;
    assert (rows["dunning"]["service"], rows["dunning"]["namespace"])
        == ("billing", "billing") , rows;
    assert [asked[1] for asked in _ASKED] == ["/admin/schedules"] * 3 , _ASKED;
}


"""A fleet service keeps its own user store, so it refuses the gateway admin's
token. With the fleet's bridge secret set the gateway, which already checked the
caller is an admin, asks with that secret instead and the service answers; with
no secret the refusal is relayed, not hidden behind a 404."""
test "a service that refuses the admin's token answers the gateway's fleet call" {
    (srv, port) = _serve(
        200, _listing("orders", "nightly", "function"), only_bearer="fleet-secret"
    );
    reg = ServiceRegistry();
    reg.register(_entry("orders", port));
    saved = os.environ.get(BRIDGE_TOKEN_ENV);
    try {
        for (bridge, status, presented) in [
            ("", 403, "Bearer gateway-admin"),
            ("fleet-secret", 200, "Bearer fleet-secret")
        ] {
            if bridge {
                os.environ[BRIDGE_TOKEN_ENV] = bridge;
            } else {
                os.environ.pop(BRIDGE_TOKEN_ENV, None);
            }
            _PRESENTED.clear();
            resp = _ask(reg, "Bearer gateway-admin");
            assert resp is not None , "a refusal must reach the caller";
            assert resp.status_code == status , (bridge, resp.status_code, resp.body);
            assert _PRESENTED == [presented] , (bridge, _PRESENTED);
            body = json.loads(resp.body);
            if status == 403 {
                assert body["error"]["code"] == "FORBIDDEN" , resp.body;
            } else {
                assert [r["name"] for r in body["data"]["schedules"]]
                    == ["nightly"] , body;
            }
        }
    } finally {
        if saved is None {
            os.environ.pop(BRIDGE_TOKEN_ENV, None);
        } else {
            os.environ[BRIDGE_TOKEN_ENV] = saved;
        }
        srv.shutdown();
    }
}


test "a fleet where no service answers the listing gets a JSON 502, not the admin SPA" {
    (srv, port) = _serve(404, {"ok": False});
    reg = ServiceRegistry();
    reg.register(_entry("orders", port));
    try {
        resp = _ask(reg);
    } finally {
        srv.shutdown();
    }
    assert resp is not None , "nothing merged must not fall through to the admin SPA";
    assert resp.status_code == 502 , resp.status_code;
    body = json.loads(resp.body);
    assert body["ok"] is False , body;
    assert body["data"]["unanswered"] == [{"service": "orders", "status": 404}] , body;
}
