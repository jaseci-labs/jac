"""The gateway's /openapi.json aggregates every healthy service's spec. The
fetches must run concurrently (one slow service must not add its latency to
every other), a dead service must not sink the aggregate, and path or schema
collisions must be resolved loudly, never silently."""

import asyncio;
import logging;
import time;
import from jaclang.scale.runtime.gateway.openapi_agg { aggregate_openapi, _agg_logger }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}


"""Serve `payload` as JSON on every GET after `delay` seconds; (server, port)."""
def _serve_spec(payload: dict, delay: float = 0.0) -> tuple {
    import http.server;
    import json;
    import threading;

    body = json.dumps(payload).encode();

    def _do_get(handler_self: any) {
        if delay {
            time.sleep(delay);
        }
        handler_self.send_response(200);
        handler_self.send_header("Content-Type", "application/json");
        handler_self.send_header("Content-Length", str(len(body)));
        handler_self.end_headers();
        handler_self.wfile.write(body);
    }

    def _log_quiet(handler_self: any, fmt: str, *args: any) { }

    handler_cls = type(
        "_SpecHandler",
        (http.server.BaseHTTPRequestHandler, ),
        {"do_GET": _do_get, "log_message": _log_quiet}
    );
    srv = http.server.ThreadingHTTPServer(("127.0.0.1", 0), handler_cls);
    t = threading.Thread(target=srv.serve_forever, daemon=True);
    t.start();
    return (srv, srv.server_address[1]);
}


def _entry(name: str, prefix: str, port: int) -> ServiceEntry {
    return ServiceEntry(
        name=name,
        file=f"{name}.jac",
        prefix=prefix,
        port=port,
        url=f"http://127.0.0.1:{port}",
        status=ServiceStatus.HEALTHY
    );
}


test "service specs are fetched concurrently, not serially" {
    spec = {"openapi": "3.0.2", "paths": {"/walker/A": {"post": {}}}};
    (srv_a, port_a) = _serve_spec(spec, delay=1.5);
    (srv_b, port_b) = _serve_spec(spec, delay=1.5);

    reg = ServiceRegistry();
    reg.register(_entry("orders", "/orders", port_a));
    reg.register(_entry("billing", "/billing", port_b));
    try {
        start = time.monotonic();
        doc = asyncio.run(aggregate_openapi(reg));
        elapsed = time.monotonic() - start;
    } finally {
        srv_a.shutdown();
        srv_b.shutdown();
    }
    assert "/orders/walker/A" in doc["paths"];
    assert "/billing/walker/A" in doc["paths"];
    assert elapsed < 2.5 , (
        f"two 1.5s fetches took {elapsed:.1f}s; serial fetching adds every "
        f"slow service's latency to the docs endpoint"
    );
}


test "a dead service does not sink the aggregate" {
    spec = {"openapi": "3.0.2", "paths": {"/walker/A": {"post": {}}}};
    (srv_a, port_a) = _serve_spec(spec);

    reg = ServiceRegistry();
    reg.register(_entry("orders", "/orders", port_a));
    reg.register(_entry("ghost", "/ghost", 1));
    try {
        doc = asyncio.run(aggregate_openapi(reg));
    } finally {
        srv_a.shutdown();
    }
    assert "/orders/walker/A" in doc["paths"];
    assert not any(["/ghost" in p for p in doc["paths"]]);
}


test "path and schema collisions are resolved loudly, keeping the first seen" {
    spec_a = {
        "openapi": "3.0.2",
        "paths": {"/walker/A": {"post": {"summary": "first"}}},
        "components": {"schemas": {"Thing": {"type": "object"}}}
    };
    spec_b = {
        "openapi": "3.0.2",
        "paths": {"/walker/A": {"post": {"summary": "second"}}},
        "components": {"schemas": {"Thing": {"type": "string"}}}
    };
    (srv_a, port_a) = _serve_spec(spec_a);
    (srv_b, port_b) = _serve_spec(spec_b);

    reg = ServiceRegistry();
    reg.register(_entry("orders", "/same", port_a));
    reg.register(_entry("billing", "/same", port_b));

    import io;
    stream = io.StringIO();
    handler = logging.StreamHandler(stream);
    _agg_logger.addHandler(handler);
    try {
        doc = asyncio.run(aggregate_openapi(reg));
    } finally {
        _agg_logger.removeHandler(handler);
        srv_a.shutdown();
        srv_b.shutdown();
    }
    assert doc["paths"]["/same/walker/A"]["post"]["summary"] == "first";
    assert doc["components"]["schemas"]["Thing"] == {"type": "object"};
    logged = stream.getvalue();
    assert "path collision" in logged;
    assert "schema collision" in logged;
}
