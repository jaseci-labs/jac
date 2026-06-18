"""Redis-backed database implementation."""
import from jac_scale.db { Db, DeleteResult }
import from jac_scale._optdeps.redis { Redis }

obj RedisDb(Db) {
    has client: Redis;

    """Get namespaced Redis key."""
    def _get_redis_key(col_name: str, key: str) -> str;

    def get(key: str, col_name: str = 'default') -> dict | None;
    def set(key: str, value: dict, col_name: str = 'default') -> str;
    def delete(key: str, col_name: str = 'default') -> int;
    def exists(key: str, col_name: str = 'default') -> bool;
    def set_with_ttl(
        key: str, value: dict, ttl: int, col_name: str = 'default'
    ) -> bool;

    def incr(key: str, col_name: str = 'default') -> int;
    def expire(key: str, seconds: int, col_name: str = 'default') -> bool;
    def scan_keys(pattern: str, col_name: str = 'default') -> list[str];
    def set_nx_with_ttl(
        key: str, value: dict, ttl: int, col_name: str = 'default'
    ) -> bool;

    def delete_if_equals(
        key: str, expected_value: dict, col_name: str = 'default'
    ) -> bool;

    def find_by_id(col_name: str, id: str) -> dict | None;
    def delete_by_id(col_name: str, id: str) -> DeleteResult;
}
