import json;
import from jaclang.server.identity.auth_tokens { AuthTokenStore }

def _app_purpose(purpose: str) -> str {
    p = purpose.strip();
    if not p {
        raise ValueError("token purpose must be a non-empty string");
    }
    return f"app:{p}";
}

def _decode(record: dict) -> dict {
    raw = record.get('identity_value');
    payload: any = {};
    if isinstance(raw, str) and raw {
        try {
            payload = json.loads(raw);
        } except ValueError {
            payload = {};
        }
    }
    return {
        "subject": record.get('user_id', ''),
        "payload": payload if isinstance(payload, dict) else {},
        "expires_at": str(record.get('expires_at', ''))
    };
}

def token_create(
    purpose: str, subject: str, ttl_seconds: int, payload: (dict | None) = None
) -> str {
    return AuthTokenStore.instance().create_token(
        user_id=subject,
        purpose=_app_purpose(purpose),
        ttl_seconds=ttl_seconds,
        identity_value=json.dumps(payload or {})
    );
}

def token_peek(purpose: str, token: str) -> (dict | None) {
    record = AuthTokenStore.instance().peek_token(token, _app_purpose(purpose));
    return _decode(record) if record is not None else None;
}

def token_consume(purpose: str, token: str) -> (dict | None) {
    record = AuthTokenStore.instance().consume_token(token, _app_purpose(purpose));
    return _decode(record) if record is not None else None;
}

def token_revoke(purpose: str, subject: str) -> int {
    return AuthTokenStore.instance().revoke_user_tokens(subject, _app_purpose(purpose));
}
