import hashlib;
import logging;
import secrets;
import from datetime { UTC, datetime, timedelta }
import from typing { Any }
import from uuid { uuid4 }
import from jac_scale.config.config_loader { get_scale_config }
import from jac_scale.persistence.db { get_mongo_client }
import from jac_scale.persistence.mongo_db { MongoDb }

glob _auth_token_store: (AuthTokenStore | None) = None,
     logger = logging.getLogger(__name__);

obj AuthTokenStore {
    has _collection: str = 'auth_tokens',
        _db: Any | None = None,
        _in_memory: dict[str, dict[str, Any]] = {};

    def postinit -> None;
    static def instance -> AuthTokenStore;
    static def hash_token(token: str) -> str;
    def create_token(
        user_id: str,
        purpose: str,
        ttl_seconds: int,
        identity_value: (str | None) = None
    ) -> str;

    def peek_token(token: str, purpose: str) -> (dict[str, Any] | None);
    def consume_token(token: str, purpose: str) -> (dict[str, Any] | None);
    def revoke_user_tokens(user_id: str, purpose: str) -> int;
    def _persist(record: dict[str, Any]) -> None;
    def _find(token_hash: str, purpose: str) -> (dict[str, Any] | None);
    def _delete(token_hash: str) -> bool;
    def _delete_user(user_id: str, purpose: str) -> int;
}

def reset_auth_token_store -> None;
