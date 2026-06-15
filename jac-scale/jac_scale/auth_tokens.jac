"""One-time auth tokens for password-reset and email-verification flows.

A single token store backs both flows, distinguished by `purpose` ('reset' |
'verify'). Tokens are hashed (SHA256) at rest so a database leak doesn't
expose them. They're single-use: consume_token() deletes on success.

Persistence: MongoDB if [plugins.scale.database] mongodb_uri is set,
otherwise an in-memory dict. The collection name comes from
[plugins.scale.auth] token_collection. The in-memory store is per-worker
and non-durable across restarts; running multiple Uvicorn workers without
Mongo configured will fail verification / reset intermittently because
each worker holds its own token set (see the loud startup warning in
AuthTokenStore.postinit).
"""
import hashlib;
import logging;
import secrets;
import from datetime { UTC, datetime, timedelta }
import from typing { Any }
import from uuid { uuid4 }
import from jac_scale.config_loader { get_scale_config }
import from jac_scale.db { get_mongo_client }
import from jac_scale.mongo_db { MongoDb }

glob _auth_token_store: (AuthTokenStore | None) = None,
     logger = logging.getLogger(__name__);

"""Singleton token store with optional Mongo persistence."""
obj AuthTokenStore {
    has _collection: str = 'auth_tokens',
        _db: Any | None = None,
        _in_memory: dict[str, dict[str, Any]] = {};

    def postinit -> None;
    static def instance -> AuthTokenStore;
    """Hash a raw token for storage / lookup."""
    static def hash_token(token: str) -> str;

    """Issue a new token for (user_id, purpose), persist its hash, return raw token."""
    def create_token(
        user_id: str,
        purpose: str,
        ttl_seconds: int,
        identity_value: (str | None) = None
    ) -> str;

    """Look up a token without consuming it. Returns metadata dict or None."""
    def peek_token(token: str, purpose: str) -> (dict[str, Any] | None);

    """Consume a token (single-use). Returns metadata dict on success, None otherwise."""
    def consume_token(token: str, purpose: str) -> (dict[str, Any] | None);

    """Drop all tokens for a user with a given purpose (e.g. on password reset)."""
    def revoke_user_tokens(user_id: str, purpose: str) -> int;

    # Internal storage primitives - fall back to in-memory when Mongo is unavailable.
    def _persist(record: dict[str, Any]) -> None;
    def _find(token_hash: str, purpose: str) -> (dict[str, Any] | None);
    def _delete(token_hash: str) -> bool;
    def _delete_user(user_id: str, purpose: str) -> int;
}

"""Reset the singleton (test helper)."""
def reset_auth_token_store -> None;
