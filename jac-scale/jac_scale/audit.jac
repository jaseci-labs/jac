"""Structured audit events for security-sensitive auth flows.

Emits go to the dedicated `jac_scale.audit` logger so ops can route them
independently of regular application logs (file, syslog, ELK, Loki, etc.).
Fields land on the log record's `audit` extra so a JSON formatter picks
them up as first-class columns.

Callers MUST NOT include raw passwords, raw tokens, or full Authorization
headers. Identity values should be the normalized form (lowercase, trimmed).
"""
import logging;
import from datetime { UTC, datetime }
import from typing { Any }

glob _audit_logger = logging.getLogger('jac_scale.audit');

"""Emit a structured audit event.

`event` is the action label (e.g. 'password_reset.completed').
`fields` are caller-supplied attributes (user_id, identity_value, source_ip,
outcome, reason). A UTC timestamp is added automatically.
"""
def emit(event: str, **fields: Any) {
    payload: dict[str, Any] = {
        'event': event,
        'timestamp': datetime.now(UTC).isoformat()
    };
    payload.update(fields);
    _audit_logger.info(event, extra={'audit': payload});
}

"""Resolve the originating client IP from a FastAPI / Starlette Request.

Honours X-Forwarded-For when behind a load balancer; falls back to the
direct socket peer. Returns 'unknown' when neither is available so audit
fields stay non-null.
"""
def client_ip(request: Any) -> str {
    xff = request.headers.get('X-Forwarded-For');
    if xff {
        return xff.split(',')[0].strip();
    }
    client = request?.client;
    return getattr(client, 'host', 'unknown') if client else 'unknown';
}
