"""Per-request auth context for sv-to-sv RPC calls.

The FastAPI middleware in jfast_api.impl.jac captures the incoming
Authorization header into this ContextVar at the start of each request,
and the sv_service_call hookimpl in plugin.jac reads it back when
forwarding to a downstream service.

This avoids threading a token argument through every sv-imported
function call - propagation happens automatically.
"""

import from contextvars { ContextVar }
import from typing { Any }

# Per-request auth token. Set by middleware, read by sv_service_call hookimpl.
glob _auth_token: ContextVar[str] = ContextVar("_sv_auth_token", default="");

"""Set the current request's Authorization header value.

Returns a Token object; pass to reset_current_auth() to clean up.
Stores the full header value (e.g., 'Bearer xyz...') or empty string.
"""
def set_current_auth(token: str | None) -> Any {
    return _auth_token.set(token or "");
}

"""Reset the auth context var to its previous value."""
def reset_current_auth(token_obj: Any) {
    _auth_token.reset(token_obj);
}

"""Return the current auth token ('' when not in a request)."""
def get_current_auth -> str {
    return _auth_token.get("");
}
