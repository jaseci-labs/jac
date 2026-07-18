import hmac;
import hashlib;
import logging;
import secrets;
import jwt;
import from datetime { UTC, datetime, timedelta }
import from pydantic { BaseModel, Field }
import from jaclang.runtimelib.transport { TransportResponse, Meta }
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.persistence.db { Db, get_mongo_client }
import from jaclang.scale.persistence.mongo_db { MongoDb }

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

def _create_api_key_db -> Db | None {
    db_config = get_scale_config().get_database_config();
    if db_config.get('mongodb_uri') is not None {
        return MongoDb(client=get_mongo_client(), db_name='jac_db');
    }
    return None;
}

obj ApiKeyManager {
    has _db: Db | None = _create_api_key_db(),
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
