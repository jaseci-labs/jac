import json;

def _app_purpose(purpose: str) -> str;

def _decode(record: dict[str, any]) -> dict[str, any];

def token_create(
    purpose: str,
    subject: str,
    ttl_seconds: int,
    payload: (dict[str, any] | None) = None
) -> str;

def token_peek(purpose: str, token: str) -> (dict[str, any] | None);

def token_consume(purpose: str, token: str) -> (dict[str, any] | None);

def token_revoke(purpose: str, subject: str) -> int;
