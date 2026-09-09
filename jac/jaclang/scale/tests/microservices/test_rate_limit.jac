import time;
import asyncio;
import from jaclang.server.serving.datatypes { Request, Headers, URL }
import from jaclang.scale.runtime.middleware.rate_limit {
    InProcessRateLimiter,
    build_rate_limit_middleware
}
import from jaclang.server.serving.proxy {
    ProxyResolver,
    _untrusted_warned,
    logger as _proxy_logger
}


def _reset_state {
    import from jaclang.scale.state.factory { _backend_holder }
    _backend_holder.clear();
}


def _client(r: Request, trusted: list[str]) -> str {
    return ProxyResolver(trusted=trusted).resolve(r.client_host, r.headers).client;
}


test "token bucket allows up to capacity then denies" {
    rl = InProcessRateLimiter(rate_per_sec=0.01, capacity=3.0);
    (a1, _) = rl.consume("k");
    (a2, _) = rl.consume("k");
    (a3, _) = rl.consume("k");
    (a4, ra) = rl.consume("k");
    assert a1 and a2 and a3;
    assert not a4;
    assert ra > 0.0;
}


test "token bucket refills at the configured rate" {
    rl = InProcessRateLimiter(rate_per_sec=100.0, capacity=1.0);
    (a1, _) = rl.consume("k");
    assert a1;
    (a2, _) = rl.consume("k");
    assert not a2;
    time.sleep(0.05);
    (a3, _) = rl.consume("k");
    assert a3;
}


test "token bucket keeps per-key state isolated" {
    rl = InProcessRateLimiter(rate_per_sec=0.01, capacity=1.0);
    (a1, _) = rl.consume("alice");
    (a2, _) = rl.consume("alice");
    (a3, _) = rl.consume("bob");
    assert a1;
    assert not a2;
    assert a3;
}


def _run(coro: object) -> object {
    loop = asyncio.new_event_loop();
    try {
        return loop.run_until_complete(coro);
    } finally {
        loop.close();
    }
}


def _req(
    path: str, headers: dict[str, str] | None = None, client_host: str = "1.2.3.4"
) -> Request {
    h = Headers();
    for (k, v) in (headers or {}).items() {
        h.append(k, v);
    }
    return Request(url=URL(path=path), headers=h, client_host=client_host);
}


test "middleware returns None when disabled" {
    _reset_state();
    mw = build_rate_limit_middleware({"enabled": False});
    assert mw is None;
}


test "middleware 429s once the per-IP bucket is empty" {
    _reset_state();
    mw = build_rate_limit_middleware(
        {
            "enabled": True,
            "per_ip_rpm": 120,
            "per_user_rpm": 0,
            "burst_multiplier": 1.0,
            "exempt_paths": []
        }
    );
    assert mw is not None;

    async def next_handler(req: object) -> object {
        import from jaclang.server.serving.datatypes { JSONResponse }
        return JSONResponse({"ok": True});
    }
    r = _req(path="/api/x", client_host="9.9.9.9");
    async def run -> list {
        results = [];
        for _ in range(4) {
            resp = await mw(r, next_handler);
            results.append(getattr(resp, "status_code"));
        }
        return results;
    }
    codes = _run(run());
    assert codes[0] == 200;
    assert codes[1] == 200;
    assert 429 in codes[2:];
}


test "middleware exempts configured paths" {
    _reset_state();
    mw = build_rate_limit_middleware(
        {
            "enabled": True,
            "per_ip_rpm": 60,
            "per_user_rpm": 0,
            "burst_multiplier": 1.0,
            "exempt_paths": ["/health"]
        }
    );
    async def next_handler(req: object) -> object {
        import from jaclang.server.serving.datatypes { JSONResponse }
        return JSONResponse({"ok": True});
    }
    health = _req(path="/health", client_host="9.9.9.9");
    async def run -> list {
        out = [];
        for _ in range(5) {
            r = await mw(health, next_handler);
            out.append(getattr(r, "status_code"));
        }
        return out;
    }
    codes = _run(run());
    assert all(c == 200 for c in codes);
}


test "per-user bucket applies on top of per-IP when Authorization is set" {
    _reset_state();
    mw = build_rate_limit_middleware(
        {
            "enabled": True,
            "per_ip_rpm": 600,
            "per_user_rpm": 60,
            "burst_multiplier": 1.0,
            "exempt_paths": []
        }
    );
    async def next_handler(req: object) -> object {
        import from jaclang.server.serving.datatypes { JSONResponse }
        return JSONResponse({"ok": True});
    }
    r = _req(
        path="/api/x", headers={"Authorization": "Bearer abc"}, client_host="9.9.9.9"
    );
    async def run -> list {
        out = [];
        for _ in range(3) {
            resp = await mw(r, next_handler);
            out.append(getattr(resp, "status_code"));
        }
        return out;
    }
    codes = _run(run());
    assert codes[0] == 200;
    assert 429 in codes[1:];
}


test "429 envelope carries RATE_LIMITED code + Retry-After header" {
    _reset_state();
    mw = build_rate_limit_middleware(
        {
            "enabled": True,
            "per_ip_rpm": 60,
            "per_user_rpm": 0,
            "burst_multiplier": 1.0,
            "exempt_paths": []
        }
    );
    import json;
    async def next_handler(req: object) -> object {
        import from jaclang.server.serving.datatypes { JSONResponse }
        return JSONResponse({"ok": True});
    }
    r = _req(path="/api/x", client_host="8.8.8.8");
    async def run -> object {
        await mw(r, next_handler);
        return await mw(r, next_handler);
    }
    resp = _run(run());
    assert getattr(resp, "status_code") == 429;
    headers = getattr(resp, "headers");
    assert headers.get("Retry-After") is not None;
    body: dict = json.loads(bytes(getattr(resp, "body")).decode());
    assert body["ok"] == False;
    assert body["error"]["code"] == "RATE_LIMITED";
}


test "resolver keys on the TCP peer when X-Forwarded-For is absent" {
    r = _req(path="/", client_host="9.9.9.9");
    assert _client(r, []) == "9.9.9.9";
    assert _client(r, ["10.0.0.0/8"]) == "9.9.9.9";
}


test "resolver ignores X-Forwarded-For when no trusted proxies are set" {
    r = _req(
        path="/", headers={"X-Forwarded-For": "6.6.6.6"}, client_host="203.0.113.9"
    );
    assert _client(r, []) == "203.0.113.9";
}


test "resolver ignores X-Forwarded-For when the peer is not trusted" {
    r = _req(
        path="/", headers={"X-Forwarded-For": "6.6.6.6"}, client_host="203.0.113.9"
    );
    assert _client(r, ["10.0.0.0/8"]) == "203.0.113.9";
}


test "resolver takes the rightmost untrusted hop behind a trusted proxy" {
    r = _req(
        path="/",
        headers={"X-Forwarded-For": "6.6.6.6, 198.51.100.7, 10.0.0.2"},
        client_host="10.0.0.1"
    );
    assert _client(r, ["10.0.0.0/8"]) == "198.51.100.7";
}


test "resolver falls back to the peer when every hop is trusted" {
    r = _req(
        path="/", headers={"X-Forwarded-For": "10.9.9.9"}, client_host="127.0.0.1"
    );
    assert _client(r, ["10.0.0.0/8", "127.0.0.1"]) == "127.0.0.1";
}


test "resolver ignores empty entries in the forwarded chain" {
    trusted = ["10.0.0.0/8"];
    trailing = _req(
        path="/", headers={"X-Forwarded-For": "198.51.100.7,"}, client_host="10.0.0.1"
    );
    assert _client(trailing, trusted) == "198.51.100.7";
    leading = _req(
        path="/", headers={"X-Forwarded-For": ",198.51.100.7"}, client_host="10.0.0.1"
    );
    assert _client(leading, trusted) == "198.51.100.7";
    interior = _req(
        path="/",
        headers={"X-Forwarded-For": "198.51.100.7, , 10.0.0.2"},
        client_host="10.0.0.1"
    );
    assert _client(interior, trusted) == "198.51.100.7";
}


test "resolver falls back to the peer on an unparseable hop" {
    r = _req(path="/", headers={"X-Forwarded-For": "garbage"}, client_host="10.0.0.1");
    assert _client(r, ["10.0.0.0/8"]) == "10.0.0.1";
}


test "resolver normalizes port and bracket forms in forwarded entries" {
    r4 = _req(
        path="/",
        headers={"X-Forwarded-For": "198.51.100.7:4711"},
        client_host="10.0.0.1"
    );
    assert _client(r4, ["10.0.0.0/8"]) == "198.51.100.7";
    r6 = _req(
        path="/",
        headers={"X-Forwarded-For": "[2001:db8::1]:443"},
        client_host="10.0.0.1"
    );
    assert _client(r6, ["10.0.0.0/8"]) == "2001:db8::1";
}


test "resolver reads RFC 7239 Forwarded when X-Forwarded-For is absent" {
    r = _req(
        path="/",
        headers={"Forwarded": "for=198.51.100.7;proto=https;host=app.example"},
        client_host="10.0.0.1"
    );
    info = ProxyResolver(trusted=["10.0.0.0/8"]).resolve(r.client_host, r.headers);
    assert info.client == "198.51.100.7";
    assert info.scheme == "https";
    assert info.host == "app.example";
}


test "invalid trusted entries are skipped without crashing" {
    resolver = ProxyResolver(trusted=["not-an-ip", "10.0.0.0/8"]);
    assert len(resolver._networks) == 1;
}


test "forged X-Forwarded-For cannot mint fresh per-IP buckets" {
    _reset_state();
    mw = build_rate_limit_middleware(
        {
            "enabled": True,
            "per_ip_rpm": 60,
            "per_user_rpm": 0,
            "burst_multiplier": 1.0,
            "exempt_paths": []
        }
    );
    async def next_handler(req: object) -> object {
        import from jaclang.server.serving.datatypes { JSONResponse }
        return JSONResponse({"ok": True});
    }
    req_a = _req(
        path="/api/x", headers={"X-Forwarded-For": "203.0.113.1"}, client_host="9.9.9.9"
    );
    req_b = _req(
        path="/api/x", headers={"X-Forwarded-For": "203.0.113.2"}, client_host="9.9.9.9"
    );
    async def run -> list {
        r1 = await mw(req_a, next_handler);
        r2 = await mw(req_b, next_handler);
        return [getattr(r1, "status_code"), getattr(r2, "status_code")];
    }
    codes = _run(run());
    assert codes[0] == 200;
    assert codes[1] == 429;
}


test "distinct resolved clients get distinct buckets" {
    _reset_state();
    mw = build_rate_limit_middleware(
        {
            "enabled": True,
            "per_ip_rpm": 60,
            "per_user_rpm": 0,
            "burst_multiplier": 1.0,
            "exempt_paths": []
        }
    );
    async def next_handler(req: object) -> object {
        import from jaclang.server.serving.datatypes { JSONResponse }
        return JSONResponse({"ok": True});
    }
    req_a = _req(path="/api/x", client_host="203.0.113.1");
    req_b = _req(path="/api/x", client_host="203.0.113.2");
    async def run -> list {
        r1 = await mw(req_a, next_handler);
        r2 = await mw(req_b, next_handler);
        r3 = await mw(req_a, next_handler);
        return [
            getattr(r1, "status_code"),
            getattr(r2, "status_code"),
            getattr(r3, "status_code")
        ];
    }
    codes = _run(run());
    assert codes[0] == 200;
    assert codes[1] == 200;
    assert codes[2] == 429;
}


test "dropped X-Forwarded-For without trusted proxies warns exactly once" {
    import from logging.handlers { MemoryHandler }

    handler = MemoryHandler(capacity=100);
    _proxy_logger.addHandler(handler);
    _untrusted_warned.clear();
    try {
        resolver = ProxyResolver(trusted=[]);
        plain = _req(path="/api/x", client_host="9.9.9.9");
        forwarded = _req(
            path="/api/x", headers={"X-Forwarded-For": "6.6.6.6"}, client_host="9.9.9.9"
        );
        resolver.resolve(plain.client_host, plain.headers);
        resolver.resolve(forwarded.client_host, forwarded.headers);
        resolver.resolve(forwarded.client_host, forwarded.headers);
        warned = [
            rec
            for rec in handler.buffer
            if "trusted" in rec.getMessage()
        ];
        assert len(warned) == 1;
    } finally {
        _proxy_logger.removeHandler(handler);
        _untrusted_warned.clear();
    }
}
