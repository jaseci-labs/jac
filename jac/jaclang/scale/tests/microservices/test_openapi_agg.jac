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


glob _HANDLED: list[tuple[int, float, float]] = [];

"""Serve `payload` as JSON on every GET after `delay` seconds; (server, port).
Each handled request records (port, start, end) in `_HANDLED`."""
def _serve_spec(payload: dict[str, any], delay: float = 0.0) -> tuple[any, ...] {
    import http.server;
    import json;
    import threading;

    body = json.dumps(payload).encode();

    def _do_get(handler_self: any) {
        began = time.monotonic();
        if delay {
            time.sleep(delay);
        }
        _HANDLED.append(
            (handler_self.server.server_address[1], began, time.monotonic())
        );
        handler_self.send_response(200);
        handler_self.send_header("Content-Type", "application/json");
        handler_self.send_header("Content-Length", str(len(body)));
        handler_self.end_headers();
        handler_self.wfile.write(body);
    }

    def _log_quiet(handler_self: any, fmt: str, *args: any) {}

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


"""One undelayed aggregate first: the client's fetch path and the servers'
request handling each import and warm up on first use. The collector then runs
once and stays off for the timed window: a full collection of a test worker's
heap stops the process for about two seconds, which CI showed landing before
either request was sent. Neither cost is the fetch concurrency this compares."""
test "service specs are fetched concurrently, not serially" {
    spec = {"openapi": "3.0.2", "paths": {"/walker/A": {"post": {}}}};
    (srv_w, port_w) = _serve_spec(spec);
    warm = ServiceRegistry();
    warm.register(_entry("warm", "/warm", port_w));
    try {
        asyncio.run(aggregate_openapi(warm));
    } finally {
        srv_w.shutdown();
    }
    (srv_a, port_a) = _serve_spec(spec, delay=1.5);
    (srv_b, port_b) = _serve_spec(spec, delay=1.5);

    reg = ServiceRegistry();
    reg.register(_entry("orders", "/orders", port_a));
    reg.register(_entry("billing", "/billing", port_b));
    import gc;
    import selectors;
    import threading;
    _HANDLED.clear();
    gc.collect();
    gc.disable();
    try {
        start = time.monotonic();
        doc = asyncio.run(aggregate_openapi(reg));
        elapsed = time.monotonic() - start;
    } finally {
        gc.enable();
        srv_a.shutdown();
        srv_b.shutdown();
    }
    assert "/orders/walker/A" in doc["paths"];
    assert "/billing/walker/A" in doc["paths"];
    timeline = [
        f"port {port}: {began - start:.2f}s..{ended - start:.2f}s"
        for (port, began, ended) in _HANDLED
    ];
    assert elapsed < 2.5 , (
        f"two 1.5s fetches took {elapsed:.1f}s; serial fetching adds every "
        f"slow service's latency to the docs endpoint. handled: {timeline}; "
        f"selector {selectors.DefaultSelector.__name__}, "
        f"threads {[t.name for t in threading.enumerate()]}"
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
