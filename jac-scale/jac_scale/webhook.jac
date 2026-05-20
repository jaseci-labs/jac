"""Webhook support for Jac Scale.

This module provides webhook-related functionality including:
- API key generation and management
- HMAC-SHA256 signature verification for webhook security
- Webhook configuration and utilities

API keys are generated per-user (keyed by the stable user_id, never the
mutable/optional username) and can be used to authenticate webhook calls.
The API key is wrapped in a JWT for secure storage and validation.
"""
import hmac;
import hashlib;
import logging;
import secrets;
import jwt;
import from datetime { UTC, datetime, timedelta }
import from pydantic { BaseModel, Field }
import from jaclang.runtimelib.transport { TransportResponse, Meta }
import from jac_scale.config_loader { get_scale_config }
import from jac_scale.db { Db, get_mongo_client }
import from jac_scale.factories.database_factory { DatabaseType }

# JWT and webhook settings are read at call time (see webhook.impl.jac)
# so secret/expiry rotation does not require a process restart.
glob logger = logging.getLogger(__name__);

"""Pydantic model for API key creation request."""
class CreateApiKeyRequest(BaseModel) {
    has name: str = Field(..., description='A friendly name for the API key'),
        expiry_days: int | None = Field(
            None, description='Number of days until expiry (default from config)'
        );
}

"""Pydantic model for API key response."""
class ApiKeyResponse(BaseModel) {
    has api_key: str = Field(..., description='The generated API key'),
        api_key_id: str = Field(..., description='Unique identifier for the API key'),
        name: str = Field(..., description='Friendly name for the API key'),
        created_at: str = Field(..., description='ISO timestamp of creation'),
        expires_at: str | None = Field(
            None, description='ISO timestamp of expiry, or null if no expiry'
        );
}

"""Webhook utilities for signature generation and verification."""
obj WebhookUtils {
    """Generate HMAC-SHA256 signature for webhook payload."""
    static def generate_signature(payload: bytes, secret: str) -> str;

    """Verify HMAC-SHA256 signature for webhook payload."""
    static def verify_signature(payload: bytes, signature: str, secret: str) -> bool;

    """Generate a new API key."""
    static def generate_api_key -> str;

    """Create a JWT-wrapped API key token.

    The API key is embedded in a JWT for secure validation and expiry management.
    The subject (`sub`) claim holds the stable user_id."""
    static def create_api_key_token(
        api_key_id: str, user_id: str, name: str, expiry_days: int | None = None
    ) -> str;

    """Validate an API key token and extract user information.

    Returns a dict with `user_id`, `api_key_id` and `name`, or None."""
    static def validate_api_key(api_key: str) -> dict[str, str] | None;

    """Extract signature from request header value."""
    static def extract_signature(header_value: str) -> str;
}

"""Create database connection for API key storage, or None if MongoDB not configured."""
def _create_api_key_db -> Db | None {
    db_config = get_scale_config().get_database_config();
    if db_config.get('mongodb_uri') is not None {
        return Db(
            client=get_mongo_client(), db_name='jac_db', db_type=DatabaseType.MONGODB
        );
    }
    return None;
}

"""Manager for API keys associated with users."""
obj ApiKeyManager {
    has _db: Db | None = _create_api_key_db(),
        _inmemory_store: dict = {},
        _collection: str = 'webhook_api_keys',
        _rate_window: dict = {};

    """Ensure indexes (MongoDB only)."""
    def postinit -> None;

    """Index user_id for per-user key lookups."""
    def _ensure_indexes -> None;

    """Create a new API key for a user (keyed by stable user_id).

    allowed_walkers scopes the key to specific webhook walkers. An empty
    or omitted list means the key may call any webhook walker."""
    def create_api_key(
        user_id: str,
        name: str,
        expiry_days: int | None = None,
        allowed_walkers: list[str] | None = None
    ) -> TransportResponse;

    """List all API keys for a user."""
    def list_api_keys(user_id: str) -> TransportResponse;

    """Revoke an API key."""
    def revoke_api_key(user_id: str, api_key_id: str) -> TransportResponse;

    """Look up a stored key document by id (MongoDB or in-memory)."""
    def _get_key_doc(api_key_id: str) -> dict | None;

    """Resolve a valid, active api_key to its stored document.

    Decodes the JWT, loads the record, and fails closed if the record is
    missing or revoked. The returned doc carries user_id, signing_secret
    and allowed_walkers, so a caller resolves the key once and reads
    everything it needs from the result."""
    def resolve_key(api_key: str) -> dict | None;

    """Per-key fixed-window rate check. True if the call is allowed.

    Best-effort and per-process (not cluster-wide). A non-positive limit
    disables the check."""
    def check_rate_limit(api_key_id: str, limit_per_minute: int) -> bool;
}
