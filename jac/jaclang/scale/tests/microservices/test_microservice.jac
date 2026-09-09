import os;
import sys;
import json;
import shutil;
import glob;
import tempfile;
import from pathlib { Path }
import from jaclang { JacRuntime as Jac }
import from jaclang.compiler.frontend.constant { Constants as Con }
import from jaclang.server { sv_client as __jac_sv }
import from jaclang.testing.testkit { ServingTestClient as TestClient }
import from jaclang.server.server { JacAPIServer }

glob FIXTURES: Path = Path(__file__).parent.parent / "fixtures" / "microservice";

def build_service(mod: str, tmp: str) -> tuple[TestClient, JacAPIServer] {
    if mod in Jac.loaded_modules {
        del Jac.loaded_modules[mod];
    }
    if mod in sys.modules {
        del sys.modules[mod];
    }
    Jac.jac_import(target=mod, base_path=tmp, lng="jac");
    srv = JacAPIServer(module_name=mod, port=0, base_path=tmp, extensions=[]);
    srv.load_module();
    srv._ensure_internal_users();
    app = srv.build_app();
    client = TestClient(app, raise_server_exceptions=False);
    __jac_sv.register_test_client(mod, client);
    return (client, srv);
}

def make_server(mod: str, tmp: str) -> TestClient {
    (client, _srv) = build_service(mod, tmp);
    return client;
}

def write_service(tmp: str, name: str, src: str) {
    (Path(tmp) / f"{name}.jac").write_text(src);
}

def setup_env -> str {
    # This test builds scale API servers in-process, so the whole process is a
    # scale runtime: mark it so every execution context (this setup, each
    # server's boot identity, and the per-request contexts) resolves to the
    # shared scale tiered-memory context rather than core's local SQLite store.
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    tmp = tempfile.mkdtemp();
    for f in `glob.`glob(str(FIXTURES / "*")) {
        if Path(f).is_file() {
            shutil.copy2(f, Path(tmp) / Path(f).name);
        }
    }
    Jac.set_base_path(tmp);
    Jac.set_context(Jac.create_j_context(user_root=None));
    __jac_sv.clear_test_clients();
    return tmp;
}

def xd(resp: any) -> any {
    j = resp.json();
    if isinstance(j, dict) and j.get("ok") and j.get("data") is not None {
        return j["data"];
    }
    return j;
}

def done(tmp: str) {
    shutil.rmtree(tmp, ignore_errors=True);
}

test "sv-to-sv: sv import does not load provider into process" {
    tmp = setup_env();
    try {
        if "inventory_service" in sys.modules {
            del sys.modules["inventory_service"];
        }
        if "inventory_service" in Jac.loaded_modules {
            del Jac.loaded_modules["inventory_service"];
        }

        cons = make_server("order_service", tmp);

        assert "inventory_service" not in sys.modules;
    } finally {
        done(tmp);
    }
}

test "sv-to-sv: sv import does not load math provider into process" {
    tmp = setup_env();
    try {
        if "math_service" in sys.modules {
            del sys.modules["math_service"];
        }
        if "math_service" in Jac.loaded_modules {
            del Jac.loaded_modules["math_service"];
        }
        cons = make_server("calculator_service", tmp);
        assert "math_service" not in sys.modules;
    } finally {
        done(tmp);
    }
}

test "sv-to-sv: consumer creates order via provider" {
    tmp = setup_env();
    try {
        prov = make_server("inventory_service", tmp);
        cons = make_server("order_service", tmp);
        prov.post(
            "/function/add_product",
            json={"sku": "W", "name": "Widget", "quantity": 50, "price": 9.99}
        );
        r = xd(
            cons.post(
                "/function/create_order", json={"items": [{"sku": "W", "quantity": 2}]}
            )
        )["result"];
        assert r["success"] is True;
        assert abs(r["total"] - 19.98) < 0.01;

        ord_mod = Jac.loaded_modules["order_service"];
        inv_mod = sys.modules.get("inventory_service");
        assert inv_mod is None or ord_mod.check_stock is not inv_mod.check_stock;
    } finally {
        done(tmp);
    }
}

test "sv-to-sv: error propagates across boundary" {
    tmp = setup_env();
    try {
        prov = make_server("inventory_service", tmp);
        cons = make_server("order_service", tmp);
        r = xd(
            cons.post(
                "/function/create_order",
                json={"items": [{"sku": "NOPE", "quantity": 1}]}
            )
        )["result"];
        assert r["success"] is False;
        ord_mod = Jac.loaded_modules["order_service"];
        inv_mod = sys.modules.get("inventory_service");
        assert inv_mod is None or ord_mod.check_stock is not inv_mod.check_stock;
    } finally {
        done(tmp);
    }
}

test "sv-to-sv: typed objects serialize across boundary" {
    tmp = setup_env();
    try {
        prov = make_server("math_service", tmp);
        cons = make_server("calculator_service", tmp);
        r = xd(cons.post("/function/safe_divide", json={"a": 10.0, "b": 0.0}))[
            "result"
        ];
        assert r["error"] == "division by zero";
        assert r["result"] is None;
        calc_mod = Jac.loaded_modules["calculator_service"];
        math_mod = sys.modules.get("math_service");
        assert math_mod is None or calc_mod.add is not math_mod.add;
    } finally {
        done(tmp);
    }
}

test "sv-to-sv: typed archetype return rehydrates for attribute access" {
    tmp = setup_env();
    try {
        cons = make_server("calculator_service", tmp);
        prov = make_server("math_service", tmp);
        r = xd(cons.post("/function/describe_divide", json={"a": 6.0, "b": 2.0}))[
            "result"
        ];

        assert r["value"] == 3.0;
        assert r["error"] == "";
        calc_mod = Jac.loaded_modules["calculator_service"];
        math_mod = sys.modules.get("math_service");
        assert math_mod is None or calc_mod.add is not math_mod.add;
    } finally {
        done(tmp);
    }
}

test "sv-to-sv: walker routes through provider" {
    tmp = setup_env();
    try {
        prov = make_server("inventory_service", tmp);
        cons = make_server("order_service", tmp);
        prov.post(
            "/function/add_product",
            json={"sku": "B", "name": "Bolt", "quantity": 500, "price": 0.1}
        );
        rpt = xd(
            cons.post(
                "/walker/CheckOrderFeasibility", json={"sku": "B", "quantity": 100}
            )
        )["reports"][0];
        assert rpt["feasible"] is True;
        assert rpt["available"] == 500;
        ord_mod = Jac.loaded_modules["order_service"];
        inv_mod = sys.modules.get("inventory_service");
        assert inv_mod is None or ord_mod.check_stock is not inv_mod.check_stock;
    } finally {
        done(tmp);
    }
}

test "sv-to-sv: sv-imported walker round-trips report and fields" {
    tmp = setup_env();
    try {
        prov = make_server("notify_service", tmp);
        cons = make_server("dispatcher_service", tmp);
        rpt = xd(cons.post("/walker/TriggerGreet", json={"who": "world"}))["reports"][
            0
        ];
        assert rpt == "hello, world";

        rpt2 = xd(cons.post("/function/greet_via_walker", json={"who": "ada"}))[
            "result"
        ];
        assert rpt2 == "hello, ada";
    } finally {
        done(tmp);
    }
}

test "sv-to-sv: sv-imported walker preserves boundary type in reports" {
    tmp = setup_env();
    try {
        prov = make_server("notify_service", tmp);
        cons = make_server("dispatcher_service", tmp);
        rpt = xd(
            cons.post("/walker/Announce", json={"channel": "ops", "subject": "rollout"})
        )["reports"][0];
        assert rpt["channel"] == "ops";
        assert rpt["delivered"] is True;
        assert rpt["message"] == "[ops] rollout";
    } finally {
        done(tmp);
    }
}

test "sv-to-sv: sv-imported walker does not load provider in-process" {
    tmp = setup_env();
    try {
        if "notify_service" in sys.modules {
            del sys.modules["notify_service"];
        }
        if "notify_service" in Jac.loaded_modules {
            del Jac.loaded_modules["notify_service"];
        }
        cons = make_server("dispatcher_service", tmp);

        disp_mod = Jac.loaded_modules["dispatcher_service"];
        notify_mod = sys.modules.get("notify_service");
        assert notify_mod is None or disp_mod.Greet is not notify_mod.Greet;
    } finally {
        done(tmp);
    }
}

glob _SECURE_PROVIDER_SRC: str = '"""Secure downstream provider fixture.\n\n`report_status` (function) and `PrivateAudit` (walker) carry NO :pub marker,\nso the scale serve layer treats them as auth-required. A cross-service caller\nthat reaches these endpoints without a valid token is rejected by the real\ndownstream enforcement in serve.endpoints (requires_auth).\n"""\n\nobj AuditEntry {\n    has actor: str = "",\n        action: str = "",\n        allowed: bool = False;\n}\n\ndef report_status(actor: str) -> AuditEntry {\n    return AuditEntry(actor=actor, action="status", allowed=True);\n}\n\nwalker PrivateAudit {\n    has action: str;\n\n    can run with Root entry {\n        report AuditEntry(actor="downstream", action=self.action, allowed=True);\n    }\n}\n',
     _SECURE_CONSUMER_SRC: str = '"""Consumer that imports the private downstream function report_status."""\n\nimport from secure_service { report_status, AuditEntry }\n\nasync def:pub proxy_status(actor: str) -> AuditEntry {\n    return await report_status(actor);\n}\n';

def _mint_user_token(srv: JacAPIServer, username: str) -> tuple[str, str] {
    user_manager = srv.user_manager;
    assert user_manager is not None;
    user = user_manager.create_internal_user(username, "pw-secret-123");
    uid = user.get("user_id", username);
    return (uid, user_manager.create_jwt_token(uid));
}

def _secure_provider(tmp: str) -> tuple[TestClient, JacAPIServer] {
    write_service(tmp, "secure_service", _SECURE_PROVIDER_SRC);
    return build_service("secure_service", tmp);
}

test "sv boundary: private function rejects call with NO token (401)" {
    tmp = setup_env();
    try {
        (prov, _srv) = _secure_provider(tmp);
        resp = prov.post("/function/report_status", json={"actor": "attacker"});
        assert resp.status_code == 401;
        body = resp.json();
        assert body["ok"] is False;
        assert body["error"]["code"] == "UNAUTHORIZED";
    } finally {
        done(tmp);
    }
}

test "sv boundary: private function rejects malformed token (401)" {
    tmp = setup_env();
    try {
        (prov, _srv) = _secure_provider(tmp);
        resp = prov.post(
            "/function/report_status",
            json={"actor": "attacker"},
            headers={"Authorization": "Bearer not.a.real.jwt"}
        );
        assert resp.status_code == 401;
        assert resp.json()["error"]["code"] == "UNAUTHORIZED";
    } finally {
        done(tmp);
    }
}

test "sv boundary: private function rejects expired token (401)" {
    import from datetime { datetime, UTC, timedelta }
    import from jaclang.server.serving.authcrypt { jwt_encode }
    import from jaclang.server.identity.config {
        signing_algorithm as jwt_algorithm,
        signing_secret as jwt_secret
    }

    tmp = setup_env();
    try {
        (prov, srv) = _secure_provider(tmp);
        (uid, _valid) = _mint_user_token(srv, "expired_user_fn");
        past = datetime.now(UTC) - timedelta(days=2);
        expired = jwt_encode(
            {
                "sub": uid,
                "user_id": uid,
                "exp": past,
                "iat": (past - timedelta(minutes=1)).timestamp()
            },
            jwt_secret(),
            algorithm=jwt_algorithm()
        );
        resp = prov.post(
            "/function/report_status",
            json={"actor": "attacker"},
            headers={"Authorization": f"Bearer {expired}"}
        );
        assert resp.status_code == 401;
        assert resp.json()["error"]["code"] == "UNAUTHORIZED";
    } finally {
        done(tmp);
    }
}

test "sv boundary: private function accepts valid token (200)" {
    tmp = setup_env();
    try {
        (prov, srv) = _secure_provider(tmp);
        (_uid, token) = _mint_user_token(srv, "valid_user_fn");
        resp = prov.post(
            "/function/report_status",
            json={"actor": "svc-a"},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert resp.status_code == 200;
        body = resp.json();
        assert body["ok"] is True;
        assert body["data"]["result"]["actor"] == "svc-a";
        assert body["data"]["result"]["allowed"] is True;
    } finally {
        done(tmp);
    }
}

test "sv boundary: private walker rejects call with NO token (401)" {
    tmp = setup_env();
    try {
        (prov, _srv) = _secure_provider(tmp);
        resp = prov.post("/walker/PrivateAudit", json={"action": "login"});
        assert resp.status_code == 401;
        assert resp.json()["error"]["code"] == "UNAUTHORIZED";
    } finally {
        done(tmp);
    }
}

test "sv boundary: private walker accepts valid token (200)" {
    tmp = setup_env();
    try {
        (prov, srv) = _secure_provider(tmp);
        (_uid, token) = _mint_user_token(srv, "valid_user_wlk");
        resp = prov.post(
            "/walker/PrivateAudit",
            json={"action": "login"},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert resp.status_code == 200;
        body = resp.json();
        assert body["ok"] is True;
        rpt = body["data"]["reports"][0];
        assert rpt["action"] == "login";
        assert rpt["allowed"] is True;
    } finally {
        done(tmp);
    }
}

test "sv boundary: unauthenticated cross-service call is rejected downstream" {
    tmp = setup_env();
    try {
        write_service(tmp, "secure_service", _SECURE_PROVIDER_SRC);
        write_service(tmp, "secure_consumer", _SECURE_CONSUMER_SRC);
        # Declare both sides as file-rooted service apps so the import lowers to a
        # typed-async RPC stub (#7772, #8823), making the call cross-service and
        # subject to the real downstream auth enforcement.
        toml_path = Path(tmp) / "jac.toml";
        toml_path.write_text(
            toml_path.read_text()
                + '\n[apps.secure_service]\nkind = "service"\n'
                + 'entry-point = "secure_service.jac"\nroute = "/secure"\n'
                + '\n[apps.secure_consumer]\nkind = "service"\n'
                + 'entry-point = "secure_consumer.jac"\nroute = "/secure-consumer"\n'
        );
        prov = make_server("secure_service", tmp);
        cons = make_server("secure_consumer", tmp);

        resp = cons.post("/function/proxy_status", json={"actor": "anon"});
        body = resp.json();
        assert body["ok"] is False;
        assert "Unauthorized" in json.dumps(body.get("error") or {});
    } finally {
        done(tmp);
    }
}

test "sv-to-sv over the wire: a sibling peer's JAC_APP url is used as given" {
    import from jaclang.server.serving.server { ServingServer }
    tmp = setup_env();
    url_key = __jac_sv.peer_url_env_key("notify_service");
    route_key = __jac_sv.peer_route_env_key("notify_service");
    saved_url = os.environ.get(url_key);
    saved_route = os.environ.get(route_key);
    os.environ.pop(route_key, None);
    stop_provider: any = None;
    try {
        # The provider is a real HTTP server on a loopback port, mounted at its
        # root the way a fleet member or a deployed pod is (JAC_SV_SIBLING).
        (_prov_client, prov_srv) = build_service("notify_service", tmp);
        __jac_sv._test_clients.pop("notify_service", None);
        __jac_sv.unregister("notify_service");
        wire = ServingServer(app=prov_srv.require_app(), host="127.0.0.1", port=0);
        stop_provider = wire.serve_background();
        base = f"http://127.0.0.1:{wire.bound_port}";
        os.environ[url_key] = base;

        cons = make_server("dispatcher_service", tmp);
        # The compiled consumer declared the provider's public route; that route
        # belongs to the gateway, not to the peer URL.
        assert __jac_sv.provider_route("notify_service") == "/notify";
        rpt = xd(cons.post("/walker/TriggerGreet", json={"who": "wire"}))["reports"][0];
        assert rpt == "hello, wire";
        assert __jac_sv.resolve_url("notify_service") == base;
        assert __jac_sv.registered_route("notify_service") == "";
    } finally {
        if stop_provider is not None {
            stop_provider();
        }
        __jac_sv.unregister("notify_service");
        for (k, v) in [(url_key, saved_url), (route_key, saved_route)] {
            if v is None {
                os.environ.pop(k, None);
            } else {
                os.environ[k] = v;
            }
        }
        done(tmp);
    }
}


test "sv-to-sv: a bridged streaming call is awaited and forwarded frame by frame" {
    # #8982 follow-up to the jac-sv-streaming skill: the bridge stub for a
    # generator-returning def:pub is a coroutine; awaiting it yields the live
    # generator, and the consumer's own stream re-yields it as SSE.
    tmp = setup_env();
    try {
        prov = make_server("narrator_service", tmp);
        assert "text/event-stream"
            in prov.post("/function/narrate", json={"n": 2}).headers.get(
                "Content-Type", ""
            );
        cons = make_server("story_service", tmp);
        resp = cons.post("/function/story", json={"n": 3});
        assert resp.status_code == 200 , f"status {resp.status_code}: {resp.text}";
        assert "text/event-stream" in resp.headers.get("Content-Type", "") , resp.text;
        for i in range(3) {
            assert f'data: "CHUNK {i}"' in resp.text , resp.text;
        }
        assert "event: end" in resp.text;
    } finally {
        done(tmp);
    }
}


test "sv-to-sv: a colocated streaming provider streams exactly like a remote one" {
    tmp = setup_env();
    try {
        make_server("narrator_service", tmp);
        provider_mod = sys.modules["narrator_service"];
        __jac_sv.clear_test_clients();
        __jac_sv.register_local("narrator_service", provider_mod);
        try {
            cons = make_server("story_service", tmp);
            resp = cons.post("/function/story", json={"n": 2});
            assert resp.status_code == 200 , f"status {resp.status_code}: {resp.text}";
            assert "text/event-stream" in resp.headers.get("Content-Type", "") , resp.text;
            assert 'data: "CHUNK 0"' in resp.text and 'data: "CHUNK 1"' in resp.text , resp.text;
        } finally {
            __jac_sv.unregister_local("narrator_service");
        }
    } finally {
        done(tmp);
    }
}
