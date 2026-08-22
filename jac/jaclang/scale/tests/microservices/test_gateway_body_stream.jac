"""The gateway forwards an upload without holding it.

A proxied request now carries an unread body stream, and forward_to hands that
stream straight to the upstream connection, so the gateway's footprint no
longer tracks the size of the upload. Builtin passthrough is the exception: it
replays the same body across services until one accepts it, so it still asks
for the bytes up front.
"""

import asyncio;
import from jaclang.runtimelib.serving.app { ServingApp }
import from jaclang.runtimelib.serving.datatypes {
    Headers,
    HTTPError,
    Request,
    Response,
    URL
}
import from jaclang.runtimelib.serving.endpoint { HTTPMethod, JEndPoint }
import from jaclang.runtimelib.serving.server { ServingServer }
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}
import from jaclang.scale.runtime.gateway.microservice_gateway { MicroserviceGateway }


glob _PART: bytes = b"u" * 1024,
     _PARTS: int = 4;


def _spawn_upstream(status: int) -> tuple[object, str] {
    def sink(request: Request) -> Response {
        return Response(
            content=str(len(request.body)), status_code=status, media_type="text/plain"
        );
    }
    app = ServingApp();
    app.add_endpoint(
        JEndPoint(method=HTTPMethod.POST, path="/walker/sink", callback=sink)
    );
    server = ServingServer(app=app, host="127.0.0.1", port=0);
    stop = server.serve_background();
    return (stop, f"http://127.0.0.1:{server.bound_port}");
}


def _register(reg: ServiceRegistry, name: str, prefix: str, url: str) {
    reg.register(
        ServiceEntry(
            name=name,
            file=f"{name}.jac",
            prefix=prefix,
            port=0,
            url=url,
            status=ServiceStatus.HEALTHY
        )
    );
}


async def _parts(request: Request) -> any {
    for _ in range(_PARTS) {
        yield _PART;
    }
    request.stream = None;
}


def _streaming_request(path: str, declare_length: bool) -> Request {
    raw: list[tuple[str, str]] = [("Content-Type", "application/octet-stream")];
    if declare_length {
        raw.append(("Content-Length", str(len(_PART) * _PARTS)));
    }
    request = Request(
        method="POST",
        url=URL(path=path),
        headers=Headers(raw=raw),
        client_host="10.0.0.7"
    );
    request.stream = _parts(request);
    return request;
}


async def _truncated -> any {
    yield _PART;
    raise HTTPError(status_code=400, detail="Bad Request");
}


async def _drain(response: Response) -> str {
    body = b"";
    async for chunk in response.body_iterator {
        body += chunk if isinstance(chunk, bytes) else chunk.encode("utf-8");
    }
    return body.decode("utf-8");
}


def _run(coro: object) -> object {
    loop = asyncio.new_event_loop();
    try {
        return loop.run_until_complete(coro);
    } finally {
        loop.close();
    }
}


test "forward_to streams a declared-length body through to the service" {
    async def scenario -> dict {
        (stop, base) = _spawn_upstream(200);
        try {
            reg = ServiceRegistry();
            _register(reg, "orders", "/api/orders", base);
            gw = MicroserviceGateway(registry=reg);
            request = _streaming_request("/api/orders/walker/sink", True);
            resp = await gw.forward_to(
                request, reg.entries["orders"], f"{base}/walker/sink"
            );
            return {
                "seen": await _drain(resp),
                "buffered": len(request.body),
                "pending": request.stream is not None
            };
        } finally {
            stop();
        }
    }
    result = _run(scenario());
    assert result["seen"] == str(len(_PART) * _PARTS) , result;
    assert result["buffered"] == 0 , "the gateway kept a copy of the upload";
    assert not result["pending"];
}


test "forward_to chunk-frames a body whose length the client never declared" {
    async def scenario -> str {
        (stop, base) = _spawn_upstream(200);
        try {
            reg = ServiceRegistry();
            _register(reg, "orders", "/api/orders", base);
            gw = MicroserviceGateway(registry=reg);
            resp = await gw.forward_to(
                _streaming_request("/api/orders/walker/sink", False),
                reg.entries["orders"],
                f"{base}/walker/sink"
            );
            return await _drain(resp);
        } finally {
            stop();
        }
    }
    assert _run(scenario()) == str(len(_PART) * _PARTS);
}


test "a body that fails part way is not reported as an upstream failure" {
    async def scenario -> int {
        (stop, base) = _spawn_upstream(200);
        try {
            reg = ServiceRegistry();
            _register(reg, "orders", "/api/orders", base);
            gw = MicroserviceGateway(registry=reg);
            request = _streaming_request("/api/orders/walker/sink", True);
            request.stream = _truncated();
            try {
                await gw.forward_to(
                    request, reg.entries["orders"], f"{base}/walker/sink"
                );
            } except HTTPError as he {
                return he.status_code;
            }
            return 0;
        } finally {
            stop();
        }
    }
    assert _run(scenario()) == 400;
}


test "builtin passthrough still replays the body past a service that declines" {
    async def scenario -> dict {
        (stop_a, base_a) = _spawn_upstream(404);
        (stop_b, base_b) = _spawn_upstream(200);
        try {
            reg = ServiceRegistry();
            _register(reg, "alpha", "/api/alpha", base_a);
            _register(reg, "beta", "/api/beta", base_b);
            gw = MicroserviceGateway(registry=reg);
            request = _streaming_request("/walker/sink", True);
            resp = await gw.handle_builtin_passthrough(request, "/walker/sink");
            return {
                "status": resp.status_code,
                "seen": await _drain(resp),
                "buffered": len(request.body)
            };
        } finally {
            stop_a();
            stop_b();
        }
    }
    result = _run(scenario());
    assert result["status"] == 200 , result;
    assert result["seen"] == str(len(_PART) * _PARTS);
    assert result["buffered"] == len(_PART) * _PARTS;
}
