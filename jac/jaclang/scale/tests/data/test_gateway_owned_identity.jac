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
import uuid;
import subprocess;
import time;
import requests;
import from datetime { UTC, datetime, timedelta }
import from pathlib { Path }

glob _SV_ENV: str = "JAC_SV_NAME",
     _FLEET_DIR: Path = Path(__file__).parent.parent
         / "fixtures"
         / "gateway_owned_fleet",
     _FLEET_SECRET: str = "gateway-owned-fleet-fixture-signing-secret-0123456789",
     _FLEET_ADMIN_PASSWORD: str = "Fleet-fixture-admin-9";


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
    if sv_name {
        os.environ[_SV_ENV] = sv_name;
    } elif _SV_ENV in os.environ {
        del os.environ[_SV_ENV];
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


"""Start the fixture fleet (`jac run main --fleet`) and wait until `orders` answers.

The gateway and `orders` are separate processes on the fixture project's one
database, as every local fleet is. Returns the process and the gateway's URL.
"""
def _start_fleet -> tuple[subprocess.Popen, str] {
    port = get_free_port();
    proc = subprocess.Popen(
        [jac_executable(), "run", "--fleet", "--port", str(port), "main"],
        cwd=str(_FLEET_DIR),
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
            # 401 means the request reached `orders` and its auth check ran.
            if requests.get(f"{base}/orders/function/whoami", timeout=2).status_code
                == 401 {
                return (proc, base);
            }
        } except Exception {}
        time.sleep(1);
    }
    stop_server(proc);
    raise RuntimeError("fleet never served /orders within 600s");
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

        # A real account works on the app without any provisioning.
        mine = requests.get(
            f"{base}/orders/function/whoami", headers=bearer, timeout=30
        );
        assert mine.status_code == 200 , mine.text;

        # A signed token for an id the store never held is refused, not created.
        ghost = jwt_encode(
            {"sub": str(uuid.uuid4()), "exp": datetime.now(UTC) + timedelta(hours=1)},
            _FLEET_SECRET,
            algorithm="HS256"
        );
        ghost_bearer = {"Authorization": f"Bearer {ghost}"};
        refused = requests.get(
            f"{base}/orders/function/whoami", headers=ghost_bearer, timeout=30
        );
        assert refused.status_code == 401 , refused.text;
        me = requests.get(f"{base}/user/me", headers=ghost_bearer, timeout=30);
        assert me.status_code == 401 , f"the invented account was created: {me.text}";

        # Delete the real account at the gateway; its token must stay dead.
        admin = requests.post(
            f"{base}/admin/login",
            json={"username": "admin", "password": _FLEET_ADMIN_PASSWORD},
            timeout=30
        );
        assert admin.status_code == 200 , admin.text;
        admin_bearer = {"Authorization": f"Bearer {_data(admin)['token']}"};
        gone = requests.delete(
            f"{base}/admin/users/{name}", headers=admin_bearer, timeout=30
        );
        assert gone.status_code == 200 , gone.text;
        after = requests.get(
            f"{base}/orders/function/whoami", headers=bearer, timeout=30
        );
        assert after.status_code == 401 , f"a deleted account reached the app: {after.text}";
        me = requests.get(f"{base}/user/me", headers=bearer, timeout=30);
        assert me.status_code == 401 , f"the deleted account {user_id} came back: {me.text}";
        renewed = requests.post(
            f"{base}/user/refresh-token", json={"token": token}, timeout=30
        );
        assert renewed.status_code != 200 , f"a deleted account renewed: {renewed.text}";
    } finally {
        stop_server(proc);
    }
}
