"""A fleet service must accept a session the gateway minted, and only that.

The gateway serves /user/register and /user/login, so users and sessions live
in its store. An app the launcher gave a store of its own has no local record
for the subject, so it provisions one. An app on the gateway's store, every
local fleet's default, already finds every real account there, so a subject it
does not know is a deleted or invented one and is refused (#10738). These drive
the real user manager against a real embedded Postgres, and the last test a
real two-process fleet over HTTP.
"""

import os;
import logging;
import uuid;
import subprocess;
import time;
import requests;
import from datetime { UTC, datetime, timedelta }
import from pathlib { Path }
import from shutil { rmtree }
import from tempfile { mkdtemp }

glob _SV_ENV: str = "JAC_SV_NAME",
     _FLEET_DIR: Path = Path(__file__).parent.parent
         / "fixtures"
         / "gateway_owned_fleet",
     _FLEET_SECRET: str = "gateway-owned-fleet-fixture-signing-secret-0123456789";


"""A session token of the shape the gateway mints, for a user no service knows."""
def _gateway_token(user_id: str) -> str {
    expires = datetime.now(UTC) + timedelta(days=1);
    return jwt_encode(
        {"sub": user_id, "exp": expires}, jwt_secret(), algorithm=jwt_algorithm()
    );
}


"""A manager built as the given process type, or None if Postgres is absent.

`own_store` is what the launcher decides for an app whose own env sets
`JAC_DB_URL`; without it a fleet app shares the gateway's store.
"""
def _manager(sv_name: str, own_store: bool = False) -> (UserManager | None) {
    previous = os.environ.get(_SV_ENV);
    previous_own = os.environ.get(OWN_STORE_ENV);
    if sv_name {
        os.environ[_SV_ENV] = sv_name;
    } elif _SV_ENV in os.environ {
        del os.environ[_SV_ENV];
    }
    if own_store {
        os.environ[OWN_STORE_ENV] = "1";
    } else {
        os.environ.pop(OWN_STORE_ENV, None);
    }
    try {
        return UserManager(
            base_path=".",
            provision_unknown_users=fleet_provisions_unknown_users(
                sv_name, own_store=own_store
            )
        );
    } except Exception as e {
        print(f"[skip] embedded postgres unavailable: {e}");
        return None;
    } finally {
        if previous is None {
            os.environ.pop(_SV_ENV, None);
        } else {
            os.environ[_SV_ENV] = previous;
        }
        if previous_own is None {
            os.environ.pop(OWN_STORE_ENV, None);
        } else {
            os.environ[OWN_STORE_ENV] = previous_own;
        }
    }
}


test "an app with its own store accepts a gateway token and provisions the user once" {
    manager = _manager("orders_app", own_store=True);
    if manager is None {
        return;
    }
    user_id = str(uuid.uuid4());
    assert manager.user_exists(user_id) is False;

    detail = manager.validate_jwt_token_detail(_gateway_token(user_id));
    assert detail["status"] == "ok" , f"expected ok, got {detail}";
    assert detail["user_id"] == user_id;
    assert manager.user_exists(user_id) is True;

    root_id = manager.get_root_id(user_id);
    assert root_id;

    again = manager.validate_jwt_token_detail(_gateway_token(user_id));
    assert again["status"] == "ok";
    assert manager.get_root_id(user_id) == root_id , "provisioning must be idempotent";
}


"""A session token minted by `issuer`, of the shape create_jwt_token makes."""
def _token_from(issuer: str, user_id: str) -> str {
    expires = datetime.now(UTC) + timedelta(days=1);
    return jwt_encode(
        {"sub": user_id, "exp": expires, "iss": issuer},
        jwt_secret(),
        algorithm=jwt_algorithm()
    );
}


test "a session token names the identity store that holds the account" {
    gateway = _manager("");
    orders = _manager("orders_app");
    payments = _manager("payments_app", own_store=True);
    if gateway is None or orders is None or payments is None {
        return;
    }
    for (manager, expected) in [
        (gateway, "__gateway__"),
        (orders, "__gateway__"),
        (payments, "payments_app")
    ] {
        name = f"iss_{uuid.uuid4().hex[:10]}";
        made = manager.create_user_with_identities(
            [{"type": "username", "value": name}],
            {"type": "password", "password": f"pw-{uuid.uuid4().hex}"}
        );
        assert "error" not in made , made;
        claims = manager.get_jwt_claims(manager.create_jwt_token(str(made["user_id"])));
        assert claims is not None and claims.get("iss") == expected , claims;
        detail = manager.validate_jwt_token_detail(
            manager.create_jwt_token(str(made["user_id"]))
        );
        assert detail["status"] == "ok" and detail["iss"] == expected , detail;
    }
    name = f"iss_{uuid.uuid4().hex[:10]}";
    made = orders.create_user_with_identities(
        [{"type": "username", "value": name}],
        {"type": "password", "password": f"pw-{uuid.uuid4().hex}"}
    );
    renewed = orders.refresh_jwt_token(orders.create_jwt_token(str(made["user_id"])));
    assert renewed is not None;
    claims = orders.get_jwt_claims(renewed);
    assert claims is not None and claims.get("iss") == "__gateway__" , (
        f"a session an app on the fleet's store renews still belongs to the fleet's store: {claims}"
    );
    assert payments.issuer == "payments_app";
}


test "an app with its own store provisions only a session the gateway started" {
    manager = _manager("orders_app", own_store=True);
    if manager is None {
        return;
    }
    started = str(uuid.uuid4());
    detail = manager.validate_jwt_token_detail(_token_from("__gateway__", started));
    assert detail["status"] == "ok" , f"a gateway session must be provisioned: {detail}";
    assert manager.user_exists(started) is True;

    for issuer in ["payments_app", "orders_app"] {
        stranger = str(uuid.uuid4());
        detail = manager.validate_jwt_token_detail(_token_from(issuer, stranger));
        assert detail["status"] == "unknown_user" , f"{issuer}: {detail}";
        assert detail["iss"] == issuer;
        assert manager.user_exists(stranger) is False , (
            f"a token {issuer} minted must not provision a record"
        );
    }
}


test "the gateway process itself still rejects a subject it does not know" {
    manager = _manager("__gateway__");
    if manager is None {
        return;
    }
    detail = manager.validate_jwt_token_detail(_gateway_token(str(uuid.uuid4())));
    assert detail["status"] == "unknown_user";
    assert detail["user_id"] is None;
}


test "an app on the gateway's store refuses an unknown subject and writes no record" {
    manager = _manager("orders_app");
    if manager is None {
        return;
    }
    user_id = str(uuid.uuid4());
    detail = manager.validate_jwt_token_detail(_gateway_token(user_id));
    assert detail["status"] == "unknown_user" , f"expected unknown_user, got {detail}";
    assert manager.user_exists(user_id) is False , "the account must not be recreated";
    assert manager.provision_unknown_users is False;
}


test "only the launcher's own-store mark lets a fleet app provision" {
    assert fleet_provisions_unknown_users("orders_app") is False;
    assert fleet_provisions_unknown_users("orders_app", own_store=True) is True;
    assert fleet_provisions_unknown_users("__gateway__", own_store=True) is False;
    assert fleet_provisions_unknown_users("", own_store=True) is False;
}


test "an app owns its identity store only when its own env sets JAC_DB_URL" {
    assert owns_identity_store({}) is False;
    assert owns_identity_store({"JAC_SV_NAME": "orders_app"}) is False;
    assert owns_identity_store({"JAC_DB_URL": "  "}) is False;
    assert owns_identity_store({"JAC_DB_URL": "postgresql://db/orders"}) is True;
}


test "the local launcher marks only an app whose own env sets JAC_DB_URL" {
    reg = ServiceRegistry();
    reg.register(
        ServiceEntry(
            name="orders",
            file="orders.jac",
            prefix="/orders",
            env={"JAC_SV_NAME": "orders"}
        )
    );
    reg.register(
        ServiceEntry(
            name="billing",
            file="billing.jac",
            prefix="/billing",
            env={"JAC_SV_NAME": "billing", "JAC_DB_URL": "postgresql://db/billing"}
        )
    );
    launcher = ServiceProcessManager(registry=reg);
    fleet_env = {"JAC_DB_URL": "postgresql://db/fleet", OWN_STORE_ENV: "1"};

    shared = launcher.child_env("orders", fleet_env);
    assert OWN_STORE_ENV not in shared , "a mark in the launcher's own env must not reach the app";
    assert shared["JAC_DB_URL"] == "postgresql://db/fleet";
    assert shared["JAC_SV_SIBLING"] == "1" and shared["JAC_SV_NAME"] == "orders";

    separate = launcher.child_env("billing", fleet_env);
    assert separate[OWN_STORE_ENV] == "1";
    assert separate["JAC_DB_URL"] == "postgresql://db/billing";
}


test "a single-process server rejects a subject it does not know" {
    manager = _manager("");
    if manager is None {
        return;
    }
    detail = manager.validate_jwt_token_detail(_gateway_token(str(uuid.uuid4())));
    assert detail["status"] == "unknown_user";
}


test "an expired gateway token is never provisioned into existence" {
    manager = _manager("orders_app", own_store=True);
    if manager is None {
        return;
    }
    user_id = str(uuid.uuid4());
    expired = jwt_encode(
        {"sub": user_id, "exp": datetime.now(UTC) - timedelta(days=1)},
        jwt_secret(),
        algorithm=jwt_algorithm()
    );
    detail = manager.validate_jwt_token_detail(expired);
    assert detail["status"] == "expired";
    assert manager.user_exists(user_id) is False;
}


test "a fleet service reads the assurance level the gateway put in the session" {
    import asyncio;
    import from jaclang.server.identity.assurance {
        caller_assurance_level,
        second_factor_claims
    }
    import from jaclang.server.middleware { jwt_middleware }
    import from jaclang.server.serving.datatypes { Request, Response }
    gateway = _manager("__gateway__");
    service = _manager("orders_app", own_store=True);
    if gateway is None or service is None {
        return;
    }
    user_id = str(uuid.uuid4());
    # The service's own middleware, fed the token the gateway forwards.
    def level_seen(token: str) -> str {
        request = Request();
        request.headers.set("Authorization", "Bearer " + token);
        seen: list[str] = [];
        async def next_fn(req: Request) -> Response {
            seen.append(caller_assurance_level());
            return Response();
        }
        asyncio.run(jwt_middleware(service)(request, next_fn));
        return seen[0];
    }
    strong = gateway.create_jwt_token(
        user_id, assurance=second_factor_claims(["pwd", "otp"])
    );
    assert level_seen(strong) == "aal2";
    assert level_seen(gateway.create_jwt_token(user_id)) == "aal1";
    assert level_seen("not.a.token") == "";
    assert caller_assurance_level() == "";
}


test "gateway-owned identity is on by default and can be turned off" {
    default_config = normalize_gateway_config({});
    assert default_config["identity"]["gateway_owned"] is True;

    opted_out = normalize_gateway_config({"identity": {"gateway_owned": False}});
    assert opted_out["identity"]["gateway_owned"] is False;
}


"""The data of an enveloped answer, or the answer itself."""
def _data(resp: any) -> any {
    body = resp.json();
    return body.get("data", body) if isinstance(body, dict) else body;
}


"""What a called function returned. POST runs it; GET only describes it."""
def _result(resp: any) -> any {
    data = _data(resp);
    return data.get("result", data) if isinstance(data, dict) else data;
}


"""Start the fixture fleet (`jac run main --fleet`) and wait until `orders` answers.

The gateway and `orders` are separate processes on the fixture project's one
database, as every local fleet is. Returns the process and the gateway's URL.
"""
def _start_fleet -> tuple[subprocess.Popen, str] {
    port = get_free_port();
    # The suite's fixture policy names the bootstrap admin's password and
    # relaxes the password floor; the fleet gets it the way start_server does.
    proc_env = dict(os.environ);
    apply_fixture_policy(proc_env);
    proc = subprocess.Popen(
        [jac_executable(), "run", "--fleet", "--port", str(port), "main"],
        cwd=str(_FLEET_DIR),
        env=proc_env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        start_new_session=True
    );
    base = f"http://127.0.0.1:{port}";
    deadline = time.monotonic() + 600.0;
    while time.monotonic() < deadline {
        if proc.poll() is not None {
            (out, _) = proc.communicate();
            raise RuntimeError(f"fleet exited before serving:\n{out}");
        }
        try {
            # 401 means the call reached `orders` and its auth check ran.
            if requests.post(f"{base}/orders/function/whoami", timeout=2).status_code
                == 401 {
                return (proc, base);
            }
        } except Exception {}
        time.sleep(1);
    }
    stop_server(proc);
    (out, _) = proc.communicate();
    raise RuntimeError(
        f"fleet never served /orders within 600s; last output:\n{str(out)[-4000:]}"
    );
}


test "a real fleet: an app on the gateway's store refuses a deleted or invented account" {
    (proc, base) = _start_fleet();
    try {
        name = f"fleet_{uuid.uuid4().hex[:10]}";
        password = f"Pw-{uuid.uuid4().hex}!a1";
        made = requests.post(
            f"{base}/user/register",
            json={
                "identities": [{"type": "username", "value": name}],
                "credential": {"type": "password", "password": password}
            },
            timeout=30
        );
        assert made.status_code == 201 , made.text;
        token = _data(made)["token"];
        user_id = _data(made)["user_id"];
        bearer = {"Authorization": f"Bearer {token}"};

        # A real account runs a function on the app, on its own root, without
        # any provisioning.
        mine = requests.post(
            f"{base}/orders/function/whoami", headers=bearer, timeout=30
        );
        assert mine.status_code == 200 , mine.text;
        assert _result(mine) == "orders" , mine.text;

        # A signed token for an id the store never held is refused, not created.
        ghost = jwt_encode(
            {"sub": str(uuid.uuid4()), "exp": datetime.now(UTC) + timedelta(hours=1)},
            _FLEET_SECRET,
            algorithm="HS256"
        );
        ghost_bearer = {"Authorization": f"Bearer {ghost}"};
        refused = requests.post(
            f"{base}/orders/function/whoami", headers=ghost_bearer, timeout=30
        );
        assert refused.status_code == 401 , refused.text;
        me = requests.get(f"{base}/user/me", headers=ghost_bearer, timeout=30);
        assert me.status_code == 401 , f"the invented account was created: {me.text}";

        # Delete the real account at the gateway; its token must stay dead.
        admin = requests.post(
            f"{base}/admin/login",
            json={"username": "admin", "password": ADMIN_BOOTSTRAP_PASSWORD},
            timeout=30
        );
        assert admin.status_code == 200 , admin.text;
        admin_bearer = {"Authorization": f"Bearer {_data(admin)['token']}"};
        gone = requests.delete(
            f"{base}/admin/users/{name}", headers=admin_bearer, timeout=30
        );
        assert gone.status_code == 200 , gone.text;
        after = requests.post(
            f"{base}/orders/function/whoami", headers=bearer, timeout=30
        );
        assert after.status_code == 401 , f"a deleted account reached the app: {after.text}";
        me = requests.get(f"{base}/user/me", headers=bearer, timeout=30);
        assert me.status_code == 401 , f"the deleted account {user_id} came back: {me.text}";
        renewed = requests.post(
            f"{base}/user/refresh-token", json={"token": token}, timeout=30
        );
        assert renewed.status_code != 200 , f"a deleted account renewed: {renewed.text}";

        # An app on the shared store holds the account's epoch, so it renews
        # sessions and ends them itself (a provisioning app refuses both).
        other = requests.post(
            f"{base}/user/register",
            json={
                "identities": [{"type": "username", "value": f"{name}_b"}],
                "credential": {"type": "password", "password": password}
            },
            timeout=30
        );
        assert other.status_code == 201 , other.text;
        other_token = _data(other)["token"];
        renewed_here = requests.post(
            f"{base}/orders/user/refresh-token", json={"token": other_token}, timeout=30
        );
        assert renewed_here.status_code == 200 , renewed_here.text;
        fresh = _data(renewed_here)["token"];
        ended = requests.post(
            f"{base}/orders/user/logout-all",
            headers={"Authorization": f"Bearer {fresh}"},
            timeout=30
        );
        assert ended.status_code == 200 , ended.text;
        stale = requests.post(
            f"{base}/orders/function/whoami",
            headers={"Authorization": f"Bearer {fresh}"},
            timeout=30
        );
        assert stale.status_code == 401 , f"an ended session reached the app: {stale.text}";
    } finally {
        stop_server(proc);
    }
}


"""A gateway manager whose identity store is a fresh embedded Postgres, so a
bulk clean-up sees only this test's records. None if Postgres is absent."""
def _isolated_gateway -> (tuple[any, any, any, any, str] | None) {
    manager = _manager("__gateway__");
    if manager is None {
        return None;
    }
    base = mkdtemp(prefix='jacprov_');
    rt = PgRuntime(data_dir=base + '/data');
    try {
        store = PgStore(conninfo=rt.ensure());
    } except Exception as e {
        print(f"[skip] embedded postgres unavailable: {e}");
        _close_isolated(None, rt, base);
        return None;
    }
    storage = PgIdentityStorage(store=store);
    manager._identity_storage = storage;
    return (manager, storage, store, rt, base);
}


# Stop the private Postgres and remove its files, so a run leaves none behind.
def _close_isolated(store: any, rt: any, base: str) {
    try {
        if store is not None {
            store.close();
        }
        rt.stop();
    } finally {
        rmtree(base, ignore_errors=True);
    }
}


test "the gateway's clean-up removes provisioned records, so a deleted account's old token dies" {
    made = _isolated_gateway();
    if made is None {
        return;
    }
    (gw, storage, store, rt, base) = made;
    try {
        pw = f"Pw-{uuid.uuid4().hex}!a1";
        real = storage.create_user(
            identities=[{"type": "username", "value": f"real_{uuid.uuid4().hex[:8]}"}],
            credential={"type": "password", "password": pw}
        );

        # A deleted account whose record a fleet app recreated before #10738's fix.
        gone = storage.create_user(
            identities=[{"type": "username", "value": f"gone_{uuid.uuid4().hex[:8]}"}],
            credential={"type": "password", "password": pw}
        )["user_id"];
        token = gw.create_jwt_token(gone, session_epoch=gw.current_epoch(gone));
        storage.delete_user(gone);
        storage.ensure_user_by_id(gone);
        assert gw.validate_jwt_token_detail(token)["status"] == "ok";

        # Another recreated record, with data written under its root since.
        used = str(uuid.uuid4());
        used_root = storage.ensure_user_by_id(used);
        store.ensure_schema({});
        store.rows(
            "INSERT INTO anchors (id, kind, root_id) VALUES (CAST(:i AS uuid), 'node', CAST(:r AS uuid))",
            {"i": str(uuid.uuid4()), "r": used_root}
        );

        # A blank record linked to an SSO account is a real account, not provisioned.
        linked = str(uuid.uuid4());
        storage.ensure_user_by_id(linked);
        store.rows(
            "INSERT INTO sso_lookups (provider, external_id, user_id) VALUES ('google', :e, :u)",
            {"e": uuid.uuid4().hex, "u": linked}
        );

        listed = gw.list_provisioned_users();
        by_id = {r["user_id"]: r for r in listed["users"]};
        assert set(by_id) == {gone, used} , f"listed {sorted(by_id)}";
        assert by_id[gone]["holds_data"] is False;
        assert by_id[used]["holds_data"] is True;
        assert gw.count_provisioned_users() == 2;

        result = gw.delete_provisioned_users();
        assert result == {"deleted": [gone], "kept_with_data": [used]} , str(result);
        assert gw.validate_jwt_token_detail(token)["status"] == "unknown_user";
        assert gw.refresh_jwt_token(token) is None;
        assert storage.get_user_by_id(used) is not None;
        assert storage.get_user_by_id(linked) is not None;
        assert storage.get_user_by_id(real["user_id"]) is not None;
        assert gw.list_provisioned_users()["users"] == [by_id[used]];
        assert gw.count_provisioned_users() == 1;
    } finally {
        _close_isolated(store, rt, base);
    }
}


test "the admin endpoints list and delete provisioned records, admin only" {
    made = _isolated_gateway();
    if made is None {
        return;
    }
    (gw, storage, store, rt, base) = made;
    try {
        admin_id = storage.create_user(
            identities=[{"type": "username", "value": f"ops_{uuid.uuid4().hex[:8]}"}],
            credential={"type": "password", "password": f"Pw-{uuid.uuid4().hex}!a1"}
        )["user_id"];
        storage.set_user_role(admin_id, "admin");
        bearer = f"Bearer {gw.create_jwt_token(admin_id, session_epoch=0)}";
        stray = str(uuid.uuid4());
        storage.ensure_user_by_id(stray);
        portal = JacAPIServerAdmin(user_manager=gw);

        # The start-up warning reports the count, from a count-only query.
        seen: list[str] = [];
        class _Seen(logging.Handler) {
            def emit(self: any, record: logging.LogRecord) {
                seen.append(record.getMessage());
            }
        }
        handler = _Seen(level=logging.WARNING);
        logging.getLogger().addHandler(handler);
        previous = os.environ.pop(_SV_ENV, None);
        try {
            portal.warn_provisioned_users();
        } finally {
            logging.getLogger().removeHandler(handler);
            if previous is not None {
                os.environ[_SV_ENV] = previous;
            }
        }
        assert any(m.startswith("1 blank account record(s)") for m in seen) , str(seen);

        refused = portal.admin_delete_provisioned_users(Authorization=None);
        assert refused.ok is False;
        assert storage.get_user_by_id(stray) is not None;

        listed = portal.admin_list_provisioned_users(Authorization=bearer);
        assert listed.ok , str(listed.error);
        assert [r["user_id"] for r in listed.data["users"]] == [stray];

        removed = portal.admin_delete_provisioned_users(Authorization=bearer);
        assert removed.ok , str(removed.error);
        assert removed.data["deleted"] == [stray];
        assert storage.get_user_by_id(stray) is None;
    } finally {
        _close_isolated(store, rt, base);
    }
}


test "the clean-up leaves a record that gained an identity or data after it was listed" {
    made = _isolated_gateway();
    if made is None {
        return;
    }
    (gw, storage, store, rt, base) = made;
    try {
        named = str(uuid.uuid4());
        storage.ensure_user_by_id(named);
        filled = str(uuid.uuid4());
        filled_root = storage.ensure_user_by_id(filled);
        listed = storage.list_provisioned_users();
        assert sorted(r["user_id"] for r in listed) == sorted([named, filled]);

        # Between the listing and the delete, one token holder attaches an
        # identity (/user/add-identity accepts a blank record's token) and an
        # app writes data under the other's root.
        value = f"late_{uuid.uuid4().hex[:8]}@example.com";
        assert storage._add_identity(
            named,
            {
                "type": "email",
                "value_raw": value,
                "value_normalized": value,
                "verified": False,
                "is_recovery": False
            }
        );
        store.ensure_schema({});
        store.rows(
            "INSERT INTO anchors (id, kind, root_id) VALUES (CAST(:i AS uuid), 'node', CAST(:r AS uuid))",
            {"i": str(uuid.uuid4()), "r": filled_root}
        );

        # The clean-up works from that earlier listing.
        storage.list_provisioned_users = lambda { return listed; };
        result = gw.delete_provisioned_users();
        assert result == {"deleted": [], "kept_with_data": []} , str(result);
        assert storage.get_user_by_id(named) is not None;
        assert storage.find_user_by_identity(value) is not None;
        assert storage.get_user_by_id(filled) is not None;
    } finally {
        _close_isolated(store, rt, base);
    }
}


test "an app that provisions on its own store refuses the clean-up" {
    manager = _manager("orders_app", own_store=True);
    if manager is None {
        return;
    }
    assert "error" in manager.list_provisioned_users();
    assert "error" in manager.delete_provisioned_users();
    assert manager.count_provisioned_users() == 0;
    admin = manager.create_internal_user(
        f"ops_{uuid.uuid4().hex[:8]}", f"Pw-{uuid.uuid4().hex}!a1", role="admin"
    );
    bearer = f"Bearer {manager.create_jwt_token(admin['user_id'], session_epoch=0)}";
    refused = JacAPIServerAdmin(user_manager=manager).admin_delete_provisioned_users(
        Authorization=bearer
    );
    assert refused.ok is False;
    assert refused.meta.extra["http_status"] == 409;
}
