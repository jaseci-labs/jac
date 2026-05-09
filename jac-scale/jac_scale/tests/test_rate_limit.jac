"""Tests for the gateway rate limiter (ROADMAP P17)."""

import time;
import asyncio;
import from jac_scale.microservices._rate_limit {
    InProcessRateLimiter,
    build_rate_limit_middleware
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
    time.sleep(0.05);  # 0.05s * 100 tok/s = 5 tokens refilled
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


obj _URL {
    has path: str = "/";
}


obj _Headers {
    has _d: dict[str, str] = {};

    def get(key: str, `default: object = None) -> object {
        v = self._d.get(key);
        if v is not None {
            return v;
        }
        # Case-insensitive fallback
        for (kk, vv) in self._d.items() {
            if kk.lower() == key.lower() {
                return vv;
            }
        }
        return `default;
    }
}


obj _Client {
    has host: str = "1.2.3.4";
}


obj _FakeReq {
    has url: _URL = _URL(),
        headers: _Headers = _Headers(),
        client: _Client = _Client();
}


def _req(
    path: str, headers: dict[str, str] | None = None, client_host: str = "1.2.3.4"
) -> _FakeReq {
    return _FakeReq(
        url=_URL(path=path),
        headers=_Headers(_d=headers or {}),
        client=_Client(host=client_host)
    );
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
        import from fastapi.responses { JSONResponse }
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
        import from fastapi.responses { JSONResponse }
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
        import from fastapi.responses { JSONResponse }
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
        import from fastapi.responses { JSONResponse }
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


test "X-Forwarded-For takes precedence over client.host for bucket key" {
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
        import from fastapi.responses { JSONResponse }
        return JSONResponse({"ok": True});
    }
    req_a = _req(
        path="/api/x",
        headers={"X-Forwarded-For": "203.0.113.1, 10.0.0.1"},
        client_host="10.0.0.1"
    );
    req_b = _req(
        path="/api/x",
        headers={"X-Forwarded-For": "203.0.113.2, 10.0.0.1"},
        client_host="10.0.0.1"
    );
    async def run -> list {
        r1 = await mw(req_a, next_handler);
        r2 = await mw(req_b, next_handler);
        return [getattr(r1, "status_code"), getattr(r2, "status_code")];
    }
    codes = _run(run());
    assert codes[0] == 200;
    assert codes[1] == 200;
}
