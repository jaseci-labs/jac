"""Outbox receipt on the server: scoped replay, the bridge secret, the worker
armed for a bridging consumer, and the Postgres-backed OutboxStore on the
embedded store. Servers are built in-process the way test_microservice does."""

import os;
import sys;
import shutil;
import tempfile;
import time;
import unittest.mock;
import from pathlib { Path }
import from jaclang { JacRuntime as Jac }
import from jaclang.server { sv_client }
import from jaclang.server.outbox {
    LEASE_S,
    OutboxEntry,
    PgOutboxStore,
    STATUS_DELIVERED,
    STATUS_DELIVERING,
    STATUS_PENDING,
    SqliteOutboxStore,
    stop_worker,
    use_store,
    worker_running
}
import from jaclang.testing.testkit { ServingTestClient as TestClient }
import from jaclang.server.endpoints.colocated { register_colocated_endpoints }
import from jaclang.server.server { JacAPIServer }
import from jaclang.server.serving.server { ServingServer }

glob _PROVIDER_SRC: str = (
         "import uuid;\n"
         "\n"
         "walker WhoAmI {\n"
         "    can run with Root entry {\n"
         "        report str(here.__jac__.id);\n"
         "        report uuid.uuid4().hex;\n"
         "    }\n"
         "}\n"
         "\n"
         "walker:pub Ping {\n"
         "    can run with Root entry {\n"
         "        report str(here.__jac__.id);\n"
         "        report uuid.uuid4().hex;\n"
         "    }\n"
         "}\n"
         "\n"
         "def:pub nonce() -> str {\n"
         "    return uuid.uuid4().hex;\n"
         "}\n"
     );


def setup_env -> str {
    os.environ["JAC_SCALE_RUNTIME"] = "1";
    tmp = tempfile.mkdtemp();
    Jac.set_base_path(tmp);
    Jac.set_context(Jac.create_j_context(user_root=None));
    sv_client.clear_test_clients();
    return tmp;
}


def done(tmp: str) {
    shutil.rmtree(tmp, ignore_errors=True);
}


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
    sv_client.register_test_client(mod, client);
    return (client, srv);
}


def _provider(tmp: str, name: str) -> tuple[TestClient, JacAPIServer] {
    (Path(tmp) / f"{name}.jac").write_text(_PROVIDER_SRC);
    return build_service(name, tmp);
}


def _mint_user_token(srv: JacAPIServer, username: str) -> str {
    user_manager = srv.user_manager;
    assert user_manager is not None;
    user = user_manager.create_internal_user(username, "pw-secret-123");
    uid = user.get("user_id", username);
    return user_manager.create_jwt_token(uid);
}


def _post(
    client: TestClient, path: str, token: str, key: str, body: (dict | None) = None
) -> any {
    headers = {"X-Jac-Idempotency-Key": key};
    if token {
        headers["Authorization"] = f"Bearer {token}";
    }
    return client.post(path, json=body or {}, headers=headers);
}


def _reports(resp: any) -> list {
    body = resp.json();
    assert body.get("ok") is True , resp.text;
    return body["data"]["reports"];
}


def _set_env(key: str, value: (str | None)) {
    if value is None {
        os.environ.pop(key, None);
    } else {
        os.environ[key] = value;
    }
}


test "scale server: a replayed idempotency key is scoped to the caller" {
    tmp = setup_env();
    try {
        (prov, srv) = _provider(tmp, "replay_service");
        tok_a = _mint_user_token(srv, "replay_ada");
        tok_b = _mint_user_token(srv, "replay_bob");

        first_a = _post(prov, "/walker/WhoAmI", tok_a, "same-key");
        assert first_a.status_code == 200 , first_a.text;
        (root_a, nonce_a) = _reports(first_a);
        first_b = _post(prov, "/walker/WhoAmI", tok_b, "same-key");
        assert first_b.status_code == 200 , first_b.text;
        (root_b, _nonce_b) = _reports(first_b);
        # user B never sees A's cached response for the same client-supplied key
        assert root_a != root_b;

        again_a = _post(prov, "/walker/WhoAmI", tok_a, "same-key");
        assert again_a.json() == first_a.json();
        again_b = _post(prov, "/walker/WhoAmI", tok_b, "same-key");
        assert again_b.json() == first_b.json();

        fresh = _reports(_post(prov, "/walker/WhoAmI", tok_a, "fresh-key"));
        assert fresh[0] == root_a;
        assert fresh[1] != nonce_a;

        # the same key on another target is a different scope
        ping = _reports(_post(prov, "/walker/Ping", tok_a, "same-key"));
        assert ping[0] == root_a;
        assert ping[1] != nonce_a;

        # functions replay under the same rule
        n1 = _post(prov, "/function/nonce", tok_a, "fn-key").json();
        n2 = _post(prov, "/function/nonce", tok_a, "fn-key").json();
        n3 = _post(prov, "/function/nonce", tok_b, "fn-key").json();
        assert n1 == n2;
        assert n1["data"]["result"] != n3["data"]["result"];
    } finally {
        done(tmp);
    }
}


test "scale server: the colocated mount scopes replay per user and provider" {
    tmp = setup_env();
    try {
        (_prov, _srv) = _provider(tmp, "mounted_service");
        (host, host_srv) = _provider(tmp, "host_service");
        sv_client.register_local(
            "mounted_service", Jac.loaded_modules["mounted_service"]
        );
        try {
            register_colocated_endpoints(host_srv);
        } finally {
            sv_client.unregister_local("mounted_service");
        }
        tok_a = _mint_user_token(host_srv, "mount_ada");
        tok_b = _mint_user_token(host_srv, "mount_bob");
        path = "/api/mounted_service/walker/WhoAmI";

        first_a = _post(host, path, tok_a, "same-key");
        assert first_a.status_code == 200 , first_a.text;
        (root_a, nonce_a) = _reports(first_a);
        first_b = _post(host, path, tok_b, "same-key");
        (root_b, _nonce_b) = _reports(first_b);
        assert root_a != root_b;
        assert _post(host, path, tok_a, "same-key").json() == first_a.json();
        assert _post(host, path, tok_b, "same-key").json() == first_b.json();

        # the host's own walker with the same key is another scope again
        host_reports = _reports(_post(host, "/walker/WhoAmI", tok_a, "same-key"));
        assert host_reports[0] == root_a;
        assert host_reports[1] != nonce_a;

        fn_path = "/api/mounted_service/function/nonce";
        f1 = _post(host, fn_path, tok_a, "fn-key").json();
        assert f1.get("ok") is True , f1;
        assert _post(host, fn_path, tok_a, "fn-key").json() == f1;
        f3 = _post(host, fn_path, tok_b, "fn-key").json();
        assert f3["data"]["result"] != f1["data"]["result"];
    } finally {
        done(tmp);
    }
}


test "scale server: the bridge secret authenticates a service caller" {
    tmp = setup_env();
    saved = os.environ.get(sv_client.BRIDGE_TOKEN_ENV);
    os.environ[sv_client.BRIDGE_TOKEN_ENV] = "fleet-secret";
    try {
        (prov, srv) = _provider(tmp, "bridge_service");
        denied = _post(prov, "/walker/WhoAmI", "", "k-anon");
        assert denied.status_code == 401 , denied.text;
        wrong = _post(prov, "/walker/WhoAmI", "not-the-secret", "k-wrong");
        assert wrong.status_code == 401 , wrong.text;

        ok = _post(prov, "/walker/WhoAmI", "fleet-secret", "k-bridge");
        assert ok.status_code == 200 , ok.text;
        (bridge_root, _nonce) = _reports(ok);
        (again_root, _again_nonce) = _reports(
            _post(prov, "/walker/WhoAmI", "fleet-secret", "k-bridge-2")
        );
        assert again_root == bridge_root;
        replayed = _post(prov, "/walker/WhoAmI", "fleet-secret", "k-bridge");
        assert replayed.json() == ok.json();

        tok = _mint_user_token(srv, "bridge_ada");
        (user_root, _n) = _reports(_post(prov, "/walker/WhoAmI", tok, "k-user"));
        assert user_root != bridge_root;

        # the secret is only honored while the provider has it configured
        os.environ.pop(sv_client.BRIDGE_TOKEN_ENV, None);
        off = _post(prov, "/walker/WhoAmI", "fleet-secret", "k-off");
        assert off.status_code == 401 , off.text;
    } finally {
        _set_env(sv_client.BRIDGE_TOKEN_ENV, saved);
        done(tmp);
    }
}


def _noop(*args: any, **kwargs: any) {}


def _fake_run(self: ServingServer, on_ready: any = None, port_retries: int = 0) -> int {
    if on_ready is not None {
        on_ready(self.port or 0);
    }
    return 0;
}


test "scale server: a worker arms the outbox worker for a bridging consumer" {
    tmp = setup_env();
    stop_worker();
    store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
    use_store(store);
    saved_consumers = dict(sv_client._consumer_providers);
    sv_client.clear_consumer_providers();
    patches: list = [
        unittest.mock.patch.object(JacAPIServer, "_ensure_client_bundle", _noop),
        unittest.mock.patch.object(ServingServer, "run", _fake_run)
    ];
    try {
        (prov, _prov_srv) = _provider(tmp, "armed_provider");
        (_cons, cons_srv) = _provider(tmp, "armed_consumer");
        for p in patches {
            p.start();
        }
        armed: list[bool] = [];

        def _on_ready(port: int) {
            armed.append(worker_running());
        }
        # Without a bridging consumer nothing is armed while the worker serves.
        cons_srv.start(no_client=True, on_ready=_on_ready);
        assert armed == [False] , "start() never reached the transport";

        sv_client._declare_consumer_provider(
            "armed_consumer", "armed_provider", "/api/armed_provider"
        );
        cons_srv.start(no_client=True, on_ready=_on_ready);
        assert armed == [False, True];
        # and the worker is released again once the transport returns
        assert not worker_running();
    } finally {
        for p in patches {
            p.stop();
        }
        stop_worker();
        sv_client.clear_consumer_providers();
        sv_client._consumer_providers.update(saved_consumers);
        use_store(None);
        done(tmp);
    }
}


test "PgOutboxStore: lease, expired-lease re-listing and prune on the embedded store" {
    import from jaclang.server.session { Session }
    tmp = setup_env();
    session = Session(base_path=tmp);
    try {
        pg = session.store;
        assert pg is not None;
        store = PgOutboxStore(store=pg);
        store.ensure_tables();
        now = time.time();
        item = OutboxEntry(
            id="pg-1",
            app="peer",
            `walker="Greet",
            kwargs={"name": "ada"},
            idempotency_key="pg-key-1",
            created_at=now - 10.0,
            status=STATUS_PENDING,
            next_attempt_at=now - 10.0
        );
        store.put(item);
        store.put(item);
        assert [e.id for e in store.list_pending(now, 100)] == ["pg-1"];

        assert store.claim("pg-1", now);
        assert not store.claim("pg-1", now);
        held = store.get_by_key("pg-key-1");
        assert held is not None;
        assert held.status == STATUS_DELIVERING;
        assert held.next_attempt_at >= now + LEASE_S - 0.01;
        assert store.list_pending(now, 100) == [];

        held.next_attempt_at = now - 1.0;
        store.update(held);
        assert [e.id for e in store.list_pending(now, 100)] == ["pg-1"];
        assert store.claim("pg-1", now);

        held.status = STATUS_DELIVERED;
        store.update(held);
        assert store.prune_status(STATUS_DELIVERED, now - 3600.0) == 0;
        assert store.prune_status(STATUS_DELIVERED, now) == 1;
        assert store.get_by_key("pg-key-1") is None;

        store.remember_key("seen-live", 3600, "live", now);
        store.remember_key("seen-gone", 0, "gone", now);
        assert store.recall_key("seen-live", now) == "live";
        assert store.prune_seen(now) == 1;
        assert store.recall_key("seen-live", now) == "live";
        assert store.recall_key("seen-gone", now) is None;
        store.prune_seen(now + 7200.0);
    } finally {
        session.close();
        done(tmp);
    }
}
