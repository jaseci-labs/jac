"""Fixture for app-facing token tests: an invitation flow over app_tokens."""

import from jaclang.server.identity.app_tokens {
    token_create,
    token_peek,
    token_consume,
    token_revoke
}

def invite(role: str, ttl: int) -> dict {
    tok = token_create(
        "invite", subject=jid(root), ttl_seconds=ttl, payload={"role": role}
    );
    return {"token": tok};
}

def peek(token: str) -> dict {
    got = token_peek("invite", token);
    return {"found": got is not None};
}

def accept(token: str) -> dict {
    got = token_consume("invite", token);
    if got is None {
        return {"ok": False};
    }
    return {"ok": True, "role": got["payload"].get("role", "")};
}

def accept_other_purpose(token: str) -> dict {
    got = token_consume("other", token);
    return {"ok": got is not None};
}

def cancel_all -> dict {
    return {"revoked": token_revoke("invite", jid(root))};
}
