import time;
import asyncio;
import from jaclang.runtimelib.serving.datatypes { Request, Headers, URL }
import from jaclang.scale.runtime.middleware.rate_limit {
    InProcessRateLimiter,
    build_rate_limit_middleware,
    _parse_trusted_proxies,
    _resolve_client_ip,
    _untrusted_xff_warned,
    logger as _rl_logger
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
    mw = build_rate_limit_middleware({"enabled": False});
    assert mw is None;
}


test "middleware 429s once the per-IP bucket is empty" {
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
        import from jaclang.runtimelib.serving.datatypes { JSONResponse }
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
        import from jaclang.runtimelib.serving.datatypes { JSONResponse }
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
        import from jaclang.runtimelib.serving.datatypes { JSONResponse }
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
        import from jaclang.runtimelib.serving.datatypes { JSONResponse }
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


test "resolver called without trust config keys on the peer (audit path)" {
    r = _req(
        path="/", headers={"X-Forwarded-For": "6.6.6.6"}, client_host="203.0.113.9"
    );
    assert _resolve_client_ip(r) == "203.0.113.9";
}


test "resolver keys on the TCP peer when X-Forwarded-For is absent" {
    r = _req(path="/", client_host="9.9.9.9");
    assert _resolve_client_ip(r, []) == "9.9.9.9";
    assert (_resolve_client_ip(r, _parse_trusted_proxies(["10.0.0.0/8"])) == "9.9.9.9");
}


test "resolver ignores X-Forwarded-For when no trusted proxies are set" {
    r = _req(
        path="/", headers={"X-Forwarded-For": "6.6.6.6"}, client_host="203.0.113.9"
    );
    assert _resolve_client_ip(r, []) == "203.0.113.9";
}


test "resolver ignores X-Forwarded-For when the peer is not trusted" {
    trusted = _parse_trusted_proxies(["10.0.0.0/8"]);
    r = _req(
        path="/", headers={"X-Forwarded-For": "6.6.6.6"}, client_host="203.0.113.9"
    );
    assert _resolve_client_ip(r, trusted) == "203.0.113.9";
}


test "resolver takes the rightmost untrusted hop behind a trusted proxy" {
    trusted = _parse_trusted_proxies(["10.0.0.0/8"]);
    r = _req(
        path="/",
        headers={"X-Forwarded-For": "6.6.6.6, 198.51.100.7, 10.0.0.2"},
        client_host="10.0.0.1"
    );
    assert _resolve_client_ip(r, trusted) == "198.51.100.7";
}


test "resolver falls back to the peer when every hop is trusted" {
    trusted = _parse_trusted_proxies(["10.0.0.0/8", "127.0.0.1"]);
    r = _req(
        path="/", headers={"X-Forwarded-For": "10.9.9.9"}, client_host="127.0.0.1"
    );
    assert _resolve_client_ip(r, trusted) == "127.0.0.1";
}


test "resolver falls back to the peer on an unparseable hop" {
    trusted = _parse_trusted_proxies(["10.0.0.0/8"]);
    r = _req(path="/", headers={"X-Forwarded-For": "garbage"}, client_host="10.0.0.1");
    assert _resolve_client_ip(r, trusted) == "10.0.0.1";
}


test "resolver normalizes port and bracket forms in forwarded entries" {
    trusted = _parse_trusted_proxies(["10.0.0.0/8"]);
    r4 = _req(
        path="/",
        headers={"X-Forwarded-For": "198.51.100.7:4711"},
        client_host="10.0.0.1"
    );
    assert _resolve_client_ip(r4, trusted) == "198.51.100.7";
    r6 = _req(
        path="/",
        headers={"X-Forwarded-For": "[2001:db8::1]:443"},
        client_host="10.0.0.1"
    );
    assert _resolve_client_ip(r6, trusted) == "2001:db8::1";
}


test "invalid trusted_proxies entries are skipped without crashing" {
    trusted = _parse_trusted_proxies(["not-an-ip", "10.0.0.0/8"]);
    assert len(trusted) == 1;
}


test "forged X-Forwarded-For cannot mint fresh per-IP buckets" {
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
        import from jaclang.runtimelib.serving.datatypes { JSONResponse }
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


test "distinct clients behind a trusted proxy get distinct buckets" {
    mw = build_rate_limit_middleware(
        {
            "enabled": True,
            "per_ip_rpm": 60,
            "per_user_rpm": 0,
            "burst_multiplier": 1.0,
            "exempt_paths": [],
            "trusted_proxies": ["10.0.0.0/8"]
        }
    );
    async def next_handler(req: object) -> object {
        import from jaclang.runtimelib.serving.datatypes { JSONResponse }
        return JSONResponse({"ok": True});
    }
    req_a = _req(
        path="/api/x",
        headers={"X-Forwarded-For": "203.0.113.1, 10.0.0.2"},
        client_host="10.0.0.1"
    );
    req_b = _req(
        path="/api/x",
        headers={"X-Forwarded-For": "203.0.113.2, 10.0.0.2"},
        client_host="10.0.0.1"
    );
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


test "dropped X-Forwarded-For without trusted_proxies warns exactly once" {
    import from logging.handlers { MemoryHandler }

    mw = build_rate_limit_middleware(
        {
            "enabled": True,
            "per_ip_rpm": 600,
            "per_user_rpm": 0,
            "burst_multiplier": 1.0,
            "exempt_paths": []
        }
    );
    async def next_handler(req: object) -> object {
        import from jaclang.runtimelib.serving.datatypes { JSONResponse }
        return JSONResponse({"ok": True});
    }
    handler = MemoryHandler(capacity=100);
    _rl_logger.addHandler(handler);
    _untrusted_xff_warned.clear();
    try {
        plain = _req(path="/api/x", client_host="9.9.9.9");
        forwarded = _req(
            path="/api/x", headers={"X-Forwarded-For": "6.6.6.6"}, client_host="9.9.9.9"
        );
        async def run {
            await mw(plain, next_handler);
            await mw(forwarded, next_handler);
            await mw(forwarded, next_handler);
        }
        _run(run());
        warned = [
            rec
            for rec in handler.buffer
            if "trusted_proxies" in rec.getMessage()
        ];
        assert len(warned) == 1;
    } finally {
        _rl_logger.removeHandler(handler);
        _untrusted_xff_warned.clear();
    }
}
