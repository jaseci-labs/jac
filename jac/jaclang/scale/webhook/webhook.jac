import hmac;
import hashlib;
import json;
import logging;
import secrets;
import from typing { Any }
import from jaclang.runtimelib.serving.authcrypt {
    JWTError,
    JWTExpiredError,
    jwt_decode,
    jwt_encode
}
import from datetime { UTC, datetime, timedelta }
import from jaclang.runtimelib.transport { TransportResponse, Meta }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.persistence.pg { open_docs_store }

glob logger = logging.getLogger(__name__);

obj WebhookUtils {
    static def generate_signature(payload: bytes, secret: str) -> str;
    static def verify_signature(payload: bytes, signature: str, secret: str) -> bool;
    static def generate_api_key -> str;
    static def create_api_key_token(
        api_key_id: str, user_id: str, name: str, expiry_days: int | None = None
    ) -> str;

    static def validate_api_key(api_key: str) -> dict[str, str] | None;
    static def extract_signature(header_value: str) -> str;
}

def _create_api_key_db -> Any | None {
    try {
        return open_docs_store();
    } except Exception as e {
        logger.warning(f"webhook api-key store unavailable: {e}");
        return None;
    }
}

obj ApiKeyManager {
    has _db: Any | None = _create_api_key_db(),
        _inmemory_store: dict = {},
        _collection: str = 'webhook_api_keys',
        _rate_window: dict = {};

    def postinit -> None;
    def _ensure_indexes -> None;
    def create_api_key(
        user_id: str,
        name: str,
        expiry_days: int | None = None,
        allowed_walkers: list[str] | None = None
    ) -> TransportResponse;

    def list_api_keys(user_id: str) -> TransportResponse;
    def revoke_api_key(user_id: str, api_key_id: str) -> TransportResponse;
    def _get_key_doc(api_key_id: str) -> dict | None;
    def resolve_key(api_key: str) -> dict | None;
    def check_rate_limit(api_key_id: str, limit_per_minute: int) -> bool;
}
