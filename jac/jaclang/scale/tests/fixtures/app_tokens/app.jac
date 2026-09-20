"""Fixture for app-facing token tests: an invitation flow over app_tokens."""

import from jaclang.server.identity.app_tokens {
    token_create,
    token_peek,
    token_consume,
    token_revoke
}

def:protect invite(role: str, ttl: int) -> dict[str, any] {
    tok = token_create(
        "invite", subject=jid(root), ttl_seconds=ttl, payload={"role": role}
    );
    return {"token": tok};
}

def:protect peek(token: str) -> dict[str, any] {
    got = token_peek("invite", token);
    return {"found": got is not None};
}

def:protect accept(token: str) -> dict[str, any] {
    got = token_consume("invite", token);
    if got is None {
        return {"ok": False};
    }
    return {"ok": True, "role": got["payload"].get("role", "")};
}

def:protect accept_other_purpose(token: str) -> dict[str, any] {
    got = token_consume("other", token);
    return {"ok": got is not None};
}

def:protect cancel_all -> dict[str, any] {
    return {"revoked": token_revoke("invite", jid(root))};
}
