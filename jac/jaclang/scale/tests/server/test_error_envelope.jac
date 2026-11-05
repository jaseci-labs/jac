"""A raised exception reaches the caller as a message and the server log as a stack."""

import hashlib;
import hmac;
import json;
import logging;
import time;
import uuid;
import from logging.handlers { MemoryHandler }
import from typing { Callable }
import from unittest.mock { AsyncMock, patch }

glob WATCHED_LOGGERS: tuple[str, ...] = (
         "jaclang.serve",
         "jaclang.scale.server.webhook_ext",
         "jaclang.server.serving.app"
     );

def _with_capture(send: Callable[[any], any]) -> tuple[any, list[any]] {
    client = make_client("error_paths.jac");
    watched = [logging.getLogger(name) for name in WATCHED_LOGGERS];
    saved = [(lg, lg.level, lg.disabled) for lg in watched];
    capture = MemoryHandler(10000);
    prev_global = logging.root.manager.disable;
    logging.disable(logging.NOTSET);
    for lg in watched {
        lg.setLevel(logging.ERROR);
        lg.disabled = False;
        lg.addHandler(capture);
    }
    try {
        resp = send(client);
        return (resp, list(capture.buffer));
    } finally {
        client.close();
        for (lg, level, disabled) in saved {
            lg.removeHandler(capture);
            lg.setLevel(level);
            lg.disabled = disabled;
        }
        logging.disable(prev_global);
    }
}

def _hit_with_capture(path: str) -> tuple[any, list[any]] {
    def send(client: any) -> any {
        return client.post(path, json={});
    }
    return _with_capture(send);
}

def _hit_webhook_with_capture -> tuple[any, list[any]] {
    def send(client: any) -> any {
        user = f"boomhook_{uuid.uuid4().hex[:8]}";
        client.register_user(user, "password123");
        token = client.login_user(user, "password123");
        key_resp = client.post(
            "/api-key/create",
            json={"name": "boomhook_key", "expiry_days": 30},
            headers={"Authorization": f"Bearer {token}"}
        );
        assert key_resp.status_code == 201 , key_resp.text;
        key = extract_data(key_resp.json());
        payload = json.dumps({});
        ts = str(int(time.time()));
        signature = hmac.new(
            key["signing_secret"].encode("utf-8"),
            f"{ts}.".encode("utf-8") + payload.encode("utf-8"),
            hashlib.sha256
        ).hexdigest();
        return client.post(
            "/webhook/BoomHook",
            content=payload,
            headers={
                "Content-Type": "application/json",
                "X-API-Key": key["api_key"],
                "X-Webhook-Signature": signature,
                "X-Webhook-Timestamp": ts
            }
        );
    }
    return _with_capture(send);
}

def _stacks(records: list[any]) -> list[str] {
    fmt = logging.Formatter();
    return [
        fmt.format(r)
        for r in records
        if r.exc_info
    ];
}

def _assert_message_only(resp: any, unit: str) {
    assert resp.status_code == 500 , resp.text;
    body = resp.json();
    assert body["ok"] is False , body;
    err = body["error"];
    assert err["code"] == "EXECUTION_ERROR" , err;
    assert err["message"] == "boom" , err;
    assert "details" not in err , f"{unit} put details on the wire: {err}";
    assert "Traceback" not in resp.text , resp.text;
}

def _assert_stack_logged(records: list[any], unit: str) {
    stacks = _stacks(records);
    hits = [
        s
        for s in stacks
        if f"{unit} raised ValueError: boom" in s and "ValueError: boom" in s
    ];
    assert len(hits) == 1 , (
        f"expected one ERROR record with the stack for {unit}, got "
        f"{len(hits)} of {len(records)} records: {stacks}"
    );
    assert "error_paths.jac" in hits[0] , hits[0];
}

test "walker exception: message on the wire, stack in the server log" {
    (resp, records) = _hit_with_capture("/walker/Boom");
    _assert_message_only(resp, "Boom");
    _assert_stack_logged(records, "Boom");
}

test "function exception: message on the wire, stack in the server log" {
    (resp, records) = _hit_with_capture("/function/boom_fn");
    _assert_message_only(resp, "boom_fn");
    _assert_stack_logged(records, "boom_fn");
}

test "a bad target node is the caller's error and leaves no stack in the log" {
    unknown = "00000000-0000-4000-8000-000000000001";
    for (path, body, status, code, message) in (
        ("/walker/Boom/zzz", {}, 400, "INVALID_NODE_ID", "Invalid node id"),
        (f"/walker/Boom/{unknown}", {}, 404, "NOT_FOUND", "Target node not found")
    ) {
        def send(client: any) -> any {
            return client.post(path, json=body);
        }
        (resp, records) = _with_capture(send);
        assert resp.status_code == status , f"{path}: {resp.text}";
        err = resp.json()["error"];
        assert (err["code"], err["message"]) == (code, message) , f"{path}: {err}";
        assert not _stacks(records) , f"{path}: {_stacks(records)}";
    }
}

test "an unhandled server failure stays in the log, off the wire" {
    def send(client: any) -> any {
        token = client.register_and_login(
            f"member_{uuid.uuid4().hex[:8]}", "password123"
        );
        with patch.object(
            client._server.user_manager,
            "aget_root_id",
            new=AsyncMock(return_value="00000000-0000-4000-8000-000000000001")
        ) {
            return client.post(
                "/walker/Boom", json={}, headers={"Authorization": f"Bearer {token}"}
            );
        }
    }
    (resp, records) = _with_capture(send);
    assert resp.status_code == 500 , resp.text;
    assert resp.json() == {"error": "Internal Server Error"} , resp.text;
    logged = [r.getMessage() for r in records];
    assert any("Traceback" in m and "Root anchor" in m for m in logged) , logged;
}

test "webhook exception: opaque failure on the wire, one ERROR record in the log" {
    (resp, records) = _hit_webhook_with_capture();
    assert resp.status_code == 500 , resp.text;
    err = resp.json()["error"];
    assert err["code"] == "EXECUTION_ERROR" , err;
    assert err["message"] == "Webhook processing failed" , err;
    assert "boom" not in resp.text and "Traceback" not in resp.text , resp.text;
    _assert_stack_logged(records, "BoomHook");
    rendered = [logging.Formatter().format(r) for r in records];
    assert len(records) == 1 , (
        f"expected the catch-site record alone, got {len(records)}: {rendered}"
    );
}

test "only a caller with no root answers 401, whatever a program's error says" {
    client = make_client("error_paths.jac");
    try {
        member = client.register_and_login(
            f"member_{uuid.uuid4().hex[:8]}", "password123"
        );
        server: any = client._server;
        ghost = server.user_manager.create_jwt_token("ghost");
        for (token, status, code, message) in (
            (member, 500, "EXECUTION_ERROR", "User not found"),
            (ghost, 401, "UNAUTHORIZED", "Unauthorized: unknown user")
        ) {
            for path in ("/walker/NamesMissingUser", "/function/names_missing_user") {
                resp = client.post(
                    path, json={}, headers={"Authorization": f"Bearer {token}"}
                );
                assert resp.status_code == status , f"{path}: {resp.text}";
                err = resp.json()["error"];
                assert (err["code"], err["message"]) == (code, message) , f"{path}: {err}";
            }
        }

        users = server.user_manager;
        with patch.object(
            users,
            "aget_root_id",
            new=AsyncMock(return_value="00000000-0000-4000-8000-000000000001")
        ) {
            with patch.object(users, "reset_root", return_value=None) {
                resp = client.post("/walker/Boom", json={});
            }
        }
        assert resp.status_code == 401 , f"guest with no root: {resp.text}";
        err = resp.json()["error"];
        assert (err["code"], err["message"])
            == ("UNAUTHORIZED", "Unauthorized: unknown user") , err;
    } finally {
        client.close();
    }
}
