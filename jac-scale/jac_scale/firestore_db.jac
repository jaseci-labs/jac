"""Firestore-backed database implementation (future extension point).

Implement the methods below and register FirestoreDb in kvstore() when
adding Firestore support. See MongoDb / RedisDb for the pattern to follow.
"""
import from jac_scale.db { Db }

obj FirestoreDb(Db) {
    def get(key: str, col_name: str = 'default') -> dict | None;
    def set(key: str, value: dict, col_name: str = 'default') -> str;
    def delete(key: str, col_name: str = 'default') -> int;
    def exists(key: str, col_name: str = 'default') -> bool;
}
