"""Outbox: durable deferred cross-app walker spawns (SPEC section 6).

Every test pins an explicit sqlite-backed OutboxStore in a temp dir via
use_store(), so nothing here touches the project's embedded Postgres. Delivery
is exercised two ways: by patching sv_client.spawn_walker directly (the seam
the outbox calls, independent of transport) and through
sv_client.register_test_client (the transport-level test hook)."""

import os;
import time;
import unittest.mock;
import from tempfile { TemporaryDirectory }
import from jaclang.data.store { ConnInfo, PgStore, TxnIsolation }
import from jaclang.server { sv_client }
import from jaclang.server.bridge { BridgeRejected, BridgeUnavailable }
import jaclang.server.outbox as outbox_mod;
import from jaclang.server.outbox {
    LEASE_S,
    OutboxEntry,
    PgOutboxStore,
    STATUS_DEAD,
    STATUS_DELIVERED,
    STATUS_DELIVERING,
    STATUS_PENDING,
    SqliteOutboxStore,
    backoff_seconds,
    cached_result,
    dead_letters,
    default_idempotency_key,
    deliver_pending,
    enqueue,
    prune,
    purge_dead,
    remember_idempotency_key,
    scoped_idempotency_key,
    seen_idempotency_key,
    start_worker,
    start_worker_if_bridging,
    stop_worker,
    use_store,
    worker_running
}
import from jaclang.testing.testing { JacTestClient }

def _entry(store: any, key: str) -> OutboxEntry {
    item = store.get_by_key(key);
    if item is None {
        raise AssertionError(f"no outbox entry for {key}");
    }
    return item;
}


obj _Recorder {
    has calls: list[dict] = [],
        fail_with: (Exception | None) = None;
}


def _fake_spawn(recorder: _Recorder) -> any {
    async def fake_spawn(
        app: str, `walker: str, kwargs: dict, stub_cls: any, idempotency_key: str = ""
    ) -> any {
        recorder.calls.append(
            {
                "app": app,
                "walker": `walker,
                "kwargs": kwargs,
                "idempotency_key": idempotency_key
            }
        );
        if recorder.fail_with is not None {
            raise recorder.fail_with;
        }
        return {"ok": True};
    }
    return fake_spawn;
}


def _make_due(store: SqliteOutboxStore, key: str) {
    item = _entry(store, key);
    assert item is not None;
    item.next_attempt_at = 0.0;
    store.update(item);
}


obj _StubResp {
    has payload: dict;

    def json -> any {
        return self.payload;
    }
}


obj _StubClient {
    has paths: list[str] = [],
        headers_seen: list[dict] = [];

    def post(path: str, json: any = None, headers: any = None) -> _StubResp {
        self.paths.append(path);
        self.headers_seen.append(dict(headers or {}));
        return _StubResp(payload={"ok": True, "data": {"result": {"greeting": "hi"}}});
    }
}


test "enqueue defaults the idempotency key and dedupes by it" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        try {
            first = enqueue("scoring", "Greet", {"name": "ada", "n": 1});
            again = enqueue("scoring", "Greet", {"n": 1, "name": "ada"});
            other = enqueue("scoring", "Greet", {"name": "bob"});
            assert first == again;
            assert other != first;

            key = default_idempotency_key("scoring", "Greet", {"name": "ada", "n": 1});
            assert len(key) == 32;
            stored = _entry(store, key);
            assert stored is not None;
            assert stored.id == first;
            assert stored.app == "scoring";
            assert stored.`walker == "Greet";
            assert stored.kwargs == {"name": "ada", "n": 1};
            assert stored.status == STATUS_PENDING;
            assert stored.attempts == 0;
            assert stored.created_at > 0.0;

            explicit_a = enqueue("scoring", "Greet", {"name": "x"}, "req-42");
            explicit_b = enqueue("scoring", "Greet", {"name": "y"}, "req-42");
            assert explicit_a == explicit_b;
            assert len(store.list_pending(time.time() + 1.0, 100)) == 3;
        } finally {
            use_store(None);
        }
    }
}


test "backoff doubles per attempt and caps at five minutes" {
    assert backoff_seconds(0) == 1.0;
    assert backoff_seconds(1) == 1.0;
    assert backoff_seconds(2) == 2.0;
    assert backoff_seconds(3) == 4.0;
    assert backoff_seconds(8) == 128.0;
    assert backoff_seconds(9) == 256.0;
    assert backoff_seconds(10) == 300.0;
    assert backoff_seconds(40) == 300.0;
}


test "deliver_pending retries with backoff then dead-letters after max attempts" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        recorder = _Recorder(fail_with=BridgeUnavailable(app="scoring", detail="down"));
        patcher: any = unittest.mock.patch.object(
            sv_client, "spawn_walker", _fake_spawn(recorder)
        );
        try {
            with patcher {
                key = default_idempotency_key("scoring", "Greet", {"name": "ada"});
                enqueue("scoring", "Greet", {"name": "ada"});
                before = time.time();
                assert deliver_pending(max_attempts=3) == 0;
                item = _entry(store, key);
                assert item is not None;
                assert item.status == STATUS_PENDING;
                assert item.attempts == 1;
                assert item.last_error.startswith("BridgeUnavailable");
                assert item.next_attempt_at >= before + backoff_seconds(1);
                assert deliver_pending(max_attempts=3) == 0;
                assert _entry(store, key).attempts == 1;
                _make_due(store, key);
                assert deliver_pending(max_attempts=3) == 0;
                item = _entry(store, key);
                assert item.attempts == 2;
                assert item.status == STATUS_PENDING;
                assert item.next_attempt_at >= before + backoff_seconds(2);
                _make_due(store, key);
                assert deliver_pending(max_attempts=3) == 0;
                item = _entry(store, key);
                assert item.attempts == 3;
                assert item.status == STATUS_DEAD;
                dead = dead_letters();
                assert [d.id for d in dead] == [item.id];
                assert len(recorder.calls) == 3;
                _make_due(store, key);
                assert deliver_pending(max_attempts=3) == 0;
                assert len(recorder.calls) == 3;
            }
        } finally {
            use_store(None);
        }
    }
}


test "a rejected bridge call dead-letters on the first attempt" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        recorder = _Recorder(
            fail_with=BridgeRejected(
                app="scoring", name="Greet", detail="404", status=404
            )
        );
        patcher: any = unittest.mock.patch.object(
            sv_client, "spawn_walker", _fake_spawn(recorder)
        );
        try {
            with patcher {
                key = default_idempotency_key("scoring", "Greet", {});
                enqueue("scoring", "Greet", {});
                assert deliver_pending() == 0;
                item = _entry(store, key);
                assert item.status == STATUS_DEAD;
                assert item.attempts == 1;
                assert item.last_error.startswith("BridgeRejected");
            }
        } finally {
            use_store(None);
        }
    }
}


test "deliver_pending marks delivered and passes the idempotency key" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        recorder = _Recorder();
        patcher: any = unittest.mock.patch.object(
            sv_client, "spawn_walker", _fake_spawn(recorder)
        );
        try {
            with patcher {
                enqueue("scoring", "Greet", {"name": "ada"});
                enqueue("scoring", "Greet", {"name": "bob"}, "explicit-key");
                assert deliver_pending() == 2;
                assert deliver_pending() == 0;
                keys = sorted(c["idempotency_key"] for c in recorder.calls);
                assert keys
                    == sorted(
                        [
                            default_idempotency_key(
                                "scoring", "Greet", {"name": "ada"}
                            ),
                            "explicit-key"
                        ]
                    );
                for c in recorder.calls {
                    assert c["app"] == "scoring";
                    assert c["walker"] == "Greet";
                }
                done = _entry(store, "explicit-key");
                assert done.status == STATUS_DELIVERED;
                assert done.attempts == 1;
                assert done.last_error == "";
                assert dead_letters() == [];
            }
        } finally {
            use_store(None);
        }
    }
}


test "delivery reaches a provider registered via sv_client.register_test_client" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        client = _StubClient();
        sv_client.register_test_client("scoring", client);
        try {
            key = default_idempotency_key("scoring", "Greet", {"name": "ada"});
            enqueue("scoring", "Greet", {"name": "ada"});
            assert deliver_pending() == 1;
            assert client.paths == ["/walker/Greet"];
            assert len(client.headers_seen) == 1;
            assert _entry(store, key).status == STATUS_DELIVERED;
        } finally {
            sv_client._test_clients.pop("scoring", None);
            use_store(None);
        }
    }
}


test "receiver-side dedupe remembers keys with a ttl and caches the result" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        try {
            assert not seen_idempotency_key("k1");
            assert cached_result("k1") is None;

            remember_idempotency_key("k1", ttl_s=60, result='{"ok":true}');
            assert seen_idempotency_key("k1");
            assert cached_result("k1") == '{"ok":true}';

            remember_idempotency_key("k2");
            assert seen_idempotency_key("k2");
            assert cached_result("k2") == "";

            remember_idempotency_key("k3", ttl_s=0);
            assert not seen_idempotency_key("k3");

            assert not seen_idempotency_key("");
            assert store.recall_key("k1", time.time()) == '{"ok":true}';
            assert store.recall_key("k1", time.time() + 61.0) is None;
        } finally {
            use_store(None);
        }
    }
}


test "start_worker is idempotent and the daemon thread delivers on its own" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        recorder = _Recorder();
        patcher: any = unittest.mock.patch.object(
            sv_client, "spawn_walker", _fake_spawn(recorder)
        );
        try {
            with patcher {
                key = default_idempotency_key("scoring", "Greet", {"name": "ada"});
                enqueue("scoring", "Greet", {"name": "ada"});
                start_worker(interval_s=0.02);
                start_worker(interval_s=0.02);
                assert worker_running();
                deadline = time.time() + 5.0;
                while time.time() < deadline {
                    if _entry(store, key).status == STATUS_DELIVERED {
                        break;
                    }
                    time.sleep(0.02);
                }
                assert _entry(store, key).status == STATUS_DELIVERED;
                assert len(recorder.calls) == 1;
                stop_worker();
                assert not worker_running();
            }
        } finally {
            stop_worker();
            use_store(None);
        }
    }
}


test "a claimed lease blocks a second worker until it expires" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        recorder = _Recorder();
        patcher: any = unittest.mock.patch.object(
            sv_client, "spawn_walker", _fake_spawn(recorder)
        );
        try {
            with patcher {
                key = default_idempotency_key("scoring", "Greet", {"name": "ada"});
                enqueue("scoring", "Greet", {"name": "ada"});
                item = _entry(store, key);
                now = time.time();
                # A worker claims the row and crashes before finishing the delivery.
                assert store.claim(item.id, now);
                assert not store.claim(item.id, now);
                held = _entry(store, key);
                assert held.status == STATUS_DELIVERING;
                assert held.next_attempt_at >= now + LEASE_S - 0.01;
                # The lease is live: nothing is due, so nobody re-delivers it.
                assert deliver_pending() == 0;
                assert recorder.calls == [];
                assert store.list_pending(time.time(), 100) == [];
                # The lease expires: the row is due again although still 'delivering'.
                held.next_attempt_at = time.time() - 1.0;
                store.update(held);
                assert [e.id for e in store.list_pending(time.time(), 100)]
                    == [held.id];
                assert deliver_pending() == 1;
                assert len(recorder.calls) == 1;
                done = _entry(store, key);
                assert done.status == STATUS_DELIVERED;
                assert done.attempts == 1;
            }
        } finally {
            use_store(None);
        }
    }
}


test "an expired lease on a failing delivery keeps counting attempts" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        recorder = _Recorder(fail_with=BridgeUnavailable(app="scoring", detail="down"));
        patcher: any = unittest.mock.patch.object(
            sv_client, "spawn_walker", _fake_spawn(recorder)
        );
        try {
            with patcher {
                key = default_idempotency_key("scoring", "Greet", {});
                enqueue("scoring", "Greet", {});
                assert deliver_pending(max_attempts=2) == 0;
                item = _entry(store, key);
                assert item.attempts == 1;
                assert item.status == STATUS_PENDING;
                # Simulate a crash on the second attempt: claimed, never updated.
                item.next_attempt_at = 0.0;
                store.update(item);
                assert store.claim(item.id, time.time());
                stuck = _entry(store, key);
                assert stuck.status == STATUS_DELIVERING;
                stuck.next_attempt_at = time.time() - 1.0;
                store.update(stuck);
                assert deliver_pending(max_attempts=2) == 0;
                dead = _entry(store, key);
                assert dead.attempts == 2;
                assert dead.status == STATUS_DEAD;
                assert len(recorder.calls) == 2;
            }
        } finally {
            use_store(None);
        }
    }
}


def _seen_rows(store: SqliteOutboxStore) -> int {
    return int(store._exec("SELECT COUNT(*) FROM jac_outbox_seen", {})[0][0]);
}


test "an identical un-awaited spawn is deduplicated within the ttl, not after" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        recorder = _Recorder();
        patcher: any = unittest.mock.patch.object(
            sv_client, "spawn_walker", _fake_spawn(recorder)
        );
        try {
            with patcher {
                first = enqueue("scoring", "Greet", {"name": "ada"});
                assert deliver_pending() == 1;
                # Same app, walker and arguments inside the ttl: the delivered row
                # is the dedupe record, so the spawn is dropped.
                assert enqueue("scoring", "Greet", {"name": "ada"}) == first;
                assert deliver_pending() == 0;
                assert len(recorder.calls) == 1;
                # A distinct explicit key is how a caller spawns twice on purpose.
                second = enqueue("scoring", "Greet", {"name": "ada"}, "ada-again");
                assert second != first;
                assert deliver_pending() == 1;
                assert len(recorder.calls) == 2;
                # Within the default ttl nothing is pruned.
                assert prune() == 0;
                assert store.get_by_key(
                    default_idempotency_key("scoring", "Greet", {"name": "ada"})
                )
                    is not None;
                # Once the ttl has elapsed the delivered rows go away and the same
                # spawn is a new message.
                assert prune(delivered_ttl_s=0.0) == 2;
                assert store.get_by_key("ada-again") is None;
                third = enqueue("scoring", "Greet", {"name": "ada"});
                assert third != first;
                assert deliver_pending() == 1;
                assert len(recorder.calls) == 3;
            }
        } finally {
            use_store(None);
        }
    }
}


test "the worker pass prunes expired seen keys and dead letters stay for purge_dead" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        recorder = _Recorder(
            fail_with=BridgeRejected(app="scoring", name="Greet", detail="404")
        );
        patcher: any = unittest.mock.patch.object(
            sv_client, "spawn_walker", _fake_spawn(recorder)
        );
        try {
            with patcher {
                remember_idempotency_key("gone", ttl_s=0, result="x");
                remember_idempotency_key("kept", ttl_s=3600, result="y");
                assert _seen_rows(store) == 2;
                enqueue("scoring", "Greet", {"name": "ada"});
                assert deliver_pending() == 0;
                dead = dead_letters();
                assert len(dead) == 1;
                assert dead[0].status == STATUS_DEAD;
                # A worker pass never touches dead rows; it only drops the expired
                # seen key.
                assert prune(delivered_ttl_s=0.0) == 0;
                assert _seen_rows(store) == 1;
                assert store.recall_key("kept", time.time()) == "y";
                assert len(dead_letters()) == 1;
                # Dead letters are kept for inspection until purged explicitly.
                assert purge_dead(older_than_s=3600.0) == 0;
                assert len(dead_letters()) == 1;
                assert purge_dead() == 1;
                assert dead_letters() == [];
            }
        } finally {
            use_store(None);
        }
    }
}


test "scoped idempotency keys separate users, apps and targets" {
    assert scoped_idempotency_key("", "ada", "p", "W") == "";
    assert scoped_idempotency_key("  ", "ada", "p", "W") == "";
    a = scoped_idempotency_key("k1", "ada", "p", "W");
    assert a.endswith(":k1");
    assert a == scoped_idempotency_key("k1", "ada", "p", "W");
    assert a != scoped_idempotency_key("k1", "bob", "p", "W");
    assert a != scoped_idempotency_key("k1", "ada", "q", "W");
    assert a != scoped_idempotency_key("k1", "ada", "p", "X");
    assert a != scoped_idempotency_key("k2", "ada", "p", "W");
}


obj _RecordingPg(PgStore) {
    has sql: list[str] = [],
        begins: list[str] = [],
        commits: int = 0,
        _txn: bool = False;

    def rows(sql: str, params: dict) -> list[tuple] {
        self.sql.append(" ".join(sql.split()));
        return [];
    }

    def begin(isolation: TxnIsolation = TxnIsolation.SERIALIZABLE) {
        self.begins.append(str(isolation));
        self._txn = True;
    }

    def commit {
        self.commits += 1;
        self._txn = False;
    }

    def in_txn -> bool {
        return self._txn;
    }

    def txn_isolation -> (TxnIsolation | None) {
        return TxnIsolation.SERIALIZABLE if self._txn else None;
    }

    def ensure_schema_once(promotions: dict[str, list[str]]) {}
    def close {}
}


obj _FakeMemory {
    has store: any;
}


test "remember runs on the worker connection, enqueue in the request transaction" {
    primary = _RecordingPg(conninfo=ConnInfo(host="primary.invalid"));
    side = _RecordingPg(conninfo=ConnInfo(host="side.invalid"));
    mem = _FakeMemory(store=primary);
    use_store(None);

    def _mem -> any {
        return mem;
    }

    def _side(primary_store: any) -> any {
        return PgOutboxStore(store=side);
    }
    mem_patch: any = unittest.mock.patch.object(outbox_mod, "_current_memory", _mem);
    derive_patch: any = unittest.mock.patch.object(
        outbox_mod, "_derive_worker_store", _side
    );
    try {
        with mem_patch, derive_patch {
            remember_idempotency_key("k-side", ttl_s=60, result="cached");
            # The request-scoped connection is never touched: no BEGIN is left open
            # on it by a remember that happens after the walker's own scope closed.
            assert primary.begins == [];
            assert primary.sql == [];
            # The side connection wrote the row outside any transaction, i.e.
            # autocommitted.
            assert side.begins == [];
            assert not side.in_txn();
            assert [
                q
                for q in side.sql
                if "INSERT INTO jac_outbox_seen" in q
            ];
            assert cached_result("k-side") == "cached";
            enqueue("scoring", "Greet", {"name": "ada"});
            # The outbox row rides the caller's transaction on the primary.
            assert primary.begins == [str(TxnIsolation.SERIALIZABLE)];
            assert primary.in_txn();
            assert [
                q
                for q in primary.sql
                if "INSERT INTO jac_outbox (" in q
            ];
            assert not [
                q
                for q in side.sql
                if "INSERT INTO jac_outbox (" in q
            ];
        }
    } finally {
        use_store(None);
    }
}


test "start_worker_if_bridging arms the worker only for a bridging consumer" {
    with TemporaryDirectory() as tmp {
        store = SqliteOutboxStore(path=os.path.join(tmp, "outbox.sqlite"));
        use_store(store);
        saved = dict(sv_client._consumer_providers);
        sv_client.clear_consumer_providers();
        try {
            assert not start_worker_if_bridging(interval_s=0.05);
            assert not worker_running();
            sv_client._declare_consumer_provider("web", "scoring", "/api/scoring");
            assert start_worker_if_bridging(interval_s=0.05);
            assert worker_running();
        } finally {
            stop_worker();
            sv_client.clear_consumer_providers();
            sv_client._consumer_providers.update(saved);
            use_store(None);
        }
    }
}


glob _WHOAMI_SRC: str = (
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
     );


def _register_user(client: JacTestClient, name: str) -> str {
    resp = client.post(
        "/user/register",
        json={
            "identities": [{"type": "username", "value": name}],
            "credential": {"type": "password", "password": "secret123"}
        }
    );
    assert resp.ok , resp.text;
    return str(resp.data["token"]);
}


def _spawn(client: JacTestClient, token: str, key: str, name: str = "WhoAmI") -> any {
    headers = {"X-Jac-Idempotency-Key": key};
    if token {
        headers["Authorization"] = f"Bearer {token}";
    }
    return client.post(f"/walker/{name}", json={}, headers=headers);
}


test "core server: a replayed idempotency key is scoped to the caller" {
    with TemporaryDirectory() as tmp {
        src = os.path.join(tmp, "whoami.jac");
        with open(src, "w") as fh {
            fh.write(_WHOAMI_SRC);
        }
        client = JacTestClient.from_file(src, base_path=tmp);
        try {
            tok_a = _register_user(client, "ada");
            tok_b = _register_user(client, "bob");
            first_a = _spawn(client, tok_a, "same-key");
            assert first_a.status_code == 200 , first_a.text;
            root_a = first_a.json()["data"]["reports"][0];
            first_b = _spawn(client, tok_b, "same-key");
            assert first_b.status_code == 200 , first_b.text;
            root_b = first_b.json()["data"]["reports"][0];
            assert root_a != root_b;
            # A replay hands back the cached response: the nonce is the first one.
            again_a = _spawn(client, tok_a, "same-key");
            assert again_a.status_code == 200;
            assert again_a.json() == first_a.json();
            again_b = _spawn(client, tok_b, "same-key");
            assert again_b.json() == first_b.json();
            # A fresh key runs the walker again: same root, new nonce.
            fresh_a = _spawn(client, tok_a, "other-key").json()["data"]["reports"];
            assert fresh_a[0] == root_a;
            assert fresh_a[1] != first_a.json()["data"]["reports"][1];
            # The same key on another walker is not a replay of this one.
            other_walker = _spawn(client, tok_a, "same-key", "Ping");
            assert other_walker.status_code == 200 , other_walker.text;
            other_reports = other_walker.json()["data"]["reports"];
            assert other_reports[0] == root_a;
            assert other_reports[1] != first_a.json()["data"]["reports"][1];
        } finally {
            client.close();
        }
    }
}


test "core server: the bridge secret authenticates a service caller" {
    with TemporaryDirectory() as tmp {
        src = os.path.join(tmp, "whoami.jac");
        with open(src, "w") as fh {
            fh.write(_WHOAMI_SRC);
        }
        saved = os.environ.get(sv_client.BRIDGE_TOKEN_ENV);
        os.environ[sv_client.BRIDGE_TOKEN_ENV] = "fleet-secret";
        client = JacTestClient.from_file(src, base_path=tmp);
        try {
            denied = _spawn(client, "", "k-anon");
            assert denied.status_code == 401 , denied.text;
            wrong = _spawn(client, "not-the-secret", "k-wrong");
            assert wrong.status_code == 401 , wrong.text;
            ok = _spawn(client, "fleet-secret", "k-bridge");
            assert ok.status_code == 200 , ok.text;
            bridge_root = ok.json()["data"]["reports"][0];
            again = _spawn(client, "fleet-secret", "k-bridge-2");
            assert again.json()["data"]["reports"][0] == bridge_root;
            replayed = _spawn(client, "fleet-secret", "k-bridge");
            assert replayed.json() == ok.json();
            tok = _register_user(client, "ada");
            user_root = _spawn(client, tok, "k-user").json()["data"]["reports"][0];
            assert user_root != bridge_root;
        } finally {
            client.close();
            if saved is None {
                os.environ.pop(sv_client.BRIDGE_TOKEN_ENV, None);
            } else {
                os.environ[sv_client.BRIDGE_TOKEN_ENV] = saved;
            }
        }
    }
}
