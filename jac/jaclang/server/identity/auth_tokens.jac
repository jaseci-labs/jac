import hashlib;
import logging;
import secrets;
import from datetime { UTC, datetime, timedelta }
import from uuid { uuid4 }

glob _auth_token_store: (AuthTokenStore | None) = None,
     logger = logging.getLogger(__name__);

obj AuthTokenStore {
    has _collection: str = 'auth_tokens',
        _db: any | None = None,
        _in_memory: dict[str, dict[str, any]] = {};

    def postinit -> None;
    static def instance -> AuthTokenStore;
    static def hash_token(token: str) -> str;
    def create_token(
        user_id: str,
        purpose: str,
        ttl_seconds: int,
        identity_value: (str | None) = None
    ) -> str;

    def peek_token(token: str, purpose: str) -> (dict[str, any] | None);
    def consume_token(token: str, purpose: str) -> (dict[str, any] | None);
    def revoke_user_tokens(user_id: str, purpose: str) -> int;
    def _persist(record: dict[str, any]) -> None;
    def _find(token_hash: str, purpose: str) -> (dict[str, any] | None);
    def _delete(token_hash: str) -> bool;
    def _delete_user(user_id: str, purpose: str) -> int;
}

def reset_auth_token_store -> None;
