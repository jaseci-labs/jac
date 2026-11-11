"""Ending sessions: a password change, a reset, logout-all and disabling an account.

Each account carries a session epoch, and every token carries the epoch it was
issued at. A token is accepted only while its epoch matches the account's. These
drive the real user manager against a real embedded Postgres.
"""

import asyncio;
import uuid;
import from datetime { UTC, datetime, timedelta }


"""A user manager on the real embedded Postgres; a failure to build one fails the test."""
def _manager(provision_unknown_users: bool = False) -> any {
    import from jaclang.server.identity.user_manager { UserManager }
    return UserManager(base_path=".", provision_unknown_users=provision_unknown_users);
}


"""A fresh account; returns (user_id, password)."""
def _account(manager: any) -> tuple[str, str] {
    name = f"epoch_{uuid.uuid4().hex[:10]}";
    password = f"pw-{uuid.uuid4().hex}";
    result = manager.create_user_with_identities(
        [{"type": "username", "value": name}],
        {"type": "password", "password": password}
    );
    assert "error" not in result , f"could not create the account: {result}";
    return (str(result["user_id"]), password);
}


"""A session the way /user/login opens one."""
def _sign_in(manager: any, user_id: str, password: str) -> str {
    name = manager.get_username(user_id);
    result = manager.authenticate(name, password);
    assert result is not None;
    return manager.open_session(
        user_id, session_epoch=result["session_epoch"]
    ).token;
}


def _status(manager: any, token: str) -> str {
    return str(manager.validate_jwt_token_detail(token)["status"]);
}


"""A token signed like Jac's own, with the given claims."""
def _signed(claims: dict[str, any]) -> str {
    import from jaclang.server.identity.config { signing_algorithm, signing_secret }
    import from jaclang.server.serving.authcrypt { jwt_encode }
    payload = dict(claims);
    payload["exp"] = datetime.now(UTC) + timedelta(days=1);
    return jwt_encode(payload, signing_secret(), algorithm=signing_algorithm());
}


test "a password change ends every earlier session and keeps the caller in" {
    manager = _manager();
    (user_id, password) = _account(manager);
    device_a = _sign_in(manager, user_id, password);
    device_b = _sign_in(manager, user_id, password);
    assert _status(manager, device_b) == "ok";

    claims_a = manager.validate_jwt_token_detail(device_a)["claims"];
    result = manager.update_password(user_id, password, f"new-{uuid.uuid4().hex}");
    assert "error" not in result;

    assert _status(manager, device_a) == "revoked";
    assert _status(manager, device_b) == "revoked";
    assert manager.validate_jwt_token(device_b) is None;
    assert manager.refresh_jwt_token(device_b) is None;

    replacement = manager.replacement_token(
        user_id, claims_a, result["session_epoch"]
    );
    assert replacement;
    assert _status(manager, replacement) == "ok";
}


test "a password reset ends every earlier session" {
    manager = _manager();
    (user_id, password) = _account(manager);
    token = _sign_in(manager, user_id, password);
    result = manager.reset_password_by_user_id(user_id, f"reset-{uuid.uuid4().hex}");
    assert "error" not in result;
    assert _status(manager, token) == "revoked";
}


test "end_sessions ends them all, and a later sign-in works" {
    manager = _manager();
    (user_id, password) = _account(manager);
    token = _sign_in(manager, user_id, password);
    before = manager.validate_jwt_token_detail(token)["session_epoch"];
    after = manager.end_sessions(user_id);
    assert after == before + 1;
    assert _status(manager, token) == "revoked";
    assert _status(manager, _sign_in(manager, user_id, password)) == "ok";
}


test "a disabled account's sessions stay ended after it is enabled again" {
    manager = _manager();
    (user_id, password) = _account(manager);
    token = _sign_in(manager, user_id, password);
    assert manager.update_user_fields(user_id, {"status": "disabled"});
    assert _status(manager, token) == "revoked";
    assert manager.refresh_jwt_token(token) is None;
    assert manager.update_user_fields(user_id, {"status": "active"});
    assert _status(manager, token) == "revoked";
}


test "refresh keeps the epoch it validated, never a newer one" {
    manager = _manager();
    (user_id, password) = _account(manager);
    token = _sign_in(manager, user_id, password);
    validate = manager.validate_jwt_token_detail;
    # A password change lands between the refresh's check and its new token.
    def racing(t: (str | None), check_existence: bool = True) -> dict[str, any] {
        detail = validate(t, check_existence);
        manager.end_sessions(user_id);
        return detail;
    }
    manager.validate_jwt_token_detail = racing;
    try {
        refreshed = manager.refresh_jwt_token(token);
    } finally {
        manager.validate_jwt_token_detail = validate;
    }
    assert refreshed;
    assert _status(manager, refreshed) == "revoked";
}


test "a sign-in that read the old password cannot outlive a concurrent change" {
    manager = _manager();
    (user_id, password) = _account(manager);
    checked = manager.authenticate(manager.get_username(user_id), password);
    manager.end_sessions(user_id);
    token = manager.open_session(
        user_id, session_epoch=checked["session_epoch"]
    ).token;
    assert _status(manager, token) == "revoked";
}


"""The manager's second-factor manager, made to require and accept a code."""
def _with_second_factor(manager: any) -> any {
    factors = manager.second_factors();
    def required(user_id: str) -> bool {
        return True;
    }
    def prove(user_id: str, code: str, recovery_code: str) -> dict[str, any] {
        return {"ok": True, "method": "otp"};
    }
    def same_factors -> any {
        return factors;
    }
    factors.required_for = required;
    factors.prove = prove;
    manager.second_factors = same_factors;
    return factors;
}


test "a second-factor challenge cannot finish into a session that has ended" {
    import from jaclang.server.identity.assurance { second_factor_claims }
    manager = _manager();
    (user_id, _) = _account(manager);
    factors = _with_second_factor(manager);
    # Opened the way SSO opens it: no epoch from a credential check.
    grant = manager.open_session(user_id, "fed");
    assert grant.challenge;
    manager.end_sessions(user_id);
    done = factors.complete_login(grant.challenge["challenge_token"], "123456", "");
    assert done["ok"];
    token = manager.create_jwt_token(
        user_id,
        assurance=second_factor_claims(["fed", "otp"]),
        session_epoch=done["session_epoch"]
    );
    assert _status(manager, token) == "revoked";
}


test "a challenge recorded without an epoch is refused" {
    import from jaclang.server.identity.auth_tokens { AuthTokenStore }
    import from jaclang.server.identity.second_factor { LOGIN_CHALLENGE_PURPOSE }
    manager = _manager();
    (user_id, _) = _account(manager);
    factors = _with_second_factor(manager);
    legacy = AuthTokenStore.instance().create_token(
        user_id, LOGIN_CHALLENGE_PURPOSE, 60, "pwd"
    );
    done = factors.complete_login(legacy, "123456", "");
    assert not done.get("ok");
    assert done.get("code") == "INVALID_CHALLENGE";
}


test "a password change checked before a reset cannot overwrite it" {
    manager = _manager();
    (user_id, password) = _account(manager);
    storage = manager._identity_storage;
    read_state = storage.credential_state;
    reset_to = f"reset-{uuid.uuid4().hex}";
    # The reset lands after the change has read and checked the old password.
    def racing(uid: str) -> tuple[list[dict[str, any]], any] {
        state = read_state(uid);
        storage.credential_state = read_state;
        manager.reset_password_by_user_id(uid, reset_to);
        return state;
    }
    storage.credential_state = racing;
    try {
        changed = manager.update_password(
            user_id, password, f"stale-{uuid.uuid4().hex}"
        );
    } finally {
        storage.credential_state = read_state;
    }
    assert "error" in changed , f"the stale change must fail, got {changed}";
    assert manager.authenticate(manager.get_username(user_id), reset_to) is not None;
}


test "a malformed stored epoch refuses sessions and is never reset" {
    manager = _manager();
    (user_id, password) = _account(manager);
    manager.end_sessions(user_id);
    token = _sign_in(manager, user_id, password);
    manager._identity_storage.store.rows(
        """
        UPDATE identity_users SET doc = jsonb_set(doc, '{session_epoch}', '"1"')
        WHERE user_id = :u
        """,
        {"u": user_id}
    );
    assert _status(manager, token) == "revoked";
    assert manager.end_sessions(user_id) is None;
    assert manager._identity_storage.session_state(user_id)["session_epoch"] == "1";
    assert _status(manager, token) == "revoked";
}


test "a fleet service never extends a gateway token" {
    gateway = _manager();
    (user_id, password) = _account(gateway);
    token = _sign_in(gateway, user_id, password);
    service = _manager(provision_unknown_users=True);
    assert _status(service, token) == "ok";
    assert service.refresh_jwt_token(token) is None;
    assert service.end_sessions(user_id) is None;
}


test "a token without an epoch claim works until the first bump" {
    manager = _manager();
    (user_id, _) = _account(manager);
    legacy = _signed({"sub": user_id, "user_id": user_id});
    assert _status(manager, legacy) == "ok";
    manager.end_sessions(user_id);
    assert _status(manager, legacy) == "revoked";
}


test "a malformed epoch claim is refused, not read as zero" {
    manager = _manager();
    (user_id, _) = _account(manager);
    for bad in ["0", True, -1, 1.5, None, {"n": 0}] {
        claims: dict[str, any] = {"sub": user_id, "sep": bad};
        assert _status(manager, _signed(claims)) == "invalid" , f"sep={bad!r}";
    }
}


test "the request middleware signs out a revoked token completely" {
    import from jaclang.server.middleware { jwt_middleware }
    import from jaclang.server.serving.datatypes { Request, Response }
    manager = _manager();
    (user_id, password) = _account(manager);
    token = _sign_in(manager, user_id, password);
    def seen_by_request(t: str) -> dict[str, any] {
        request = Request();
        request.headers.set("Authorization", "Bearer " + t);
        seen: list[dict[str, any]] = [];
        async def next_fn(req: Request) -> Response {
            seen.append(
                {
                    "username": req.state.username,
                    "root": req.state.user_root_id,
                    "epoch": req.state.session_epoch
                }
            );
            return Response();
        }
        asyncio.run(jwt_middleware(manager)(request, next_fn));
        return seen[0];
    }
    live = seen_by_request(token);
    assert live["username"] == user_id;
    assert live["root"];
    manager.end_sessions(user_id);
    gone = seen_by_request(token);
    assert gone == {"username": None, "root": None, "epoch": None};
}


test "an open websocket is closed once its session ends" {
    import from jaclang.scale.websocket.protocol { ws_heartbeat_loop }
    import from jaclang.scale.websocket.websocket { ConnectionContext }
    manager = _manager();
    (user_id, password) = _account(manager);
    detail = manager.validate_jwt_token_detail(_sign_in(manager, user_id, password));

    obj FakeSocket {
        has closed_with: list[str] = [];
        async def close(code: int, reason: str) {
            self.closed_with.append(reason);
        }
    }
    socket = FakeSocket();
    ctx = ConnectionContext(
        websocket=socket,
        target_kind="function",
        target_name="f",
        user_id=user_id,
        session_epoch=detail["session_epoch"]
    );
    assert manager.session_current(user_id, ctx.session_epoch);
    manager.end_sessions(user_id);
    asyncio.run(ws_heartbeat_loop(ctx, 0.01, 1000, manager.session_current));
    assert ctx.closed;
    assert socket.closed_with == ["revoked"];
}
