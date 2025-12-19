"""Base memory hierachy implementation."""
import os;
import shelve;
import from collections.abc { Iterable, MutableMapping }
import from pickle { dumps, loads }
import from threading { RLock }
import from typing { Any, TypeVar, cast }
import from uuid { UUID }
import redis;
import from pymongo { MongoClient, UpdateOne }
import from jaclang.runtimelib.archetype { TANCH, Anchor }
import from jaclang.runtimelib.memory { Memory }

glob ID = TypeVar('ID');

obj MultiHierarchyMemory(Memory[(UUID, Anchor)]) {
    def init -> None;
    def find_by_id(id: UUID) -> (Anchor | None);
    def commit(anchor: (Anchor | None) = None);
    def close;
    def sync(anchors: Iterable[Anchor]) -> None;
    def delete(anchor: Anchor);
    def <>set(anchor: TANCH);
}

"""MongoDB handler."""
obj MongoDB {
    has client: (MongoClient | None) = None,
        db_name: str = 'jac_db',
        collection_name: str = 'anchors',
        mongo_url: str = os.environ.get(
            'MONGODB_URI', 'mongodb://root:rootpassword123@localhost:27017/'
        );

    def postinit -> None;
    def _to_uuid(id: (UUID | str)) -> UUID;
    def _load_anchor(raw: dict[(str, Any)]) -> (TANCH | None);
    def <>set(anchor: Anchor) -> None;
    def remove(anchor: TANCH) -> None;
    def find_by_id(id: UUID) -> (Anchor | None);
    def commit_bulk(anchors: Iterable[Anchor]) -> None;
    def commit(anchor: (TANCH | None) = None, keys: Iterable[Anchor] = []) -> None;
}

"""Redis-based Memory Handler."""
obj RedisDB {
    has redis_url: str = os.environ.get(
        'REDIS_URL', 'redis://:mypassword123@localhost:6379/0'
    ),
        redis_client: (redis.Redis | None) = None;

    def postinit -> None;
    def redis_is_available -> bool;
    def _redis_key(id: UUID) -> str;
    def _to_uuid(id: (UUID | str)) -> UUID;
    def _load_anchor_from_redis(id: UUID) -> (Anchor | None);
    def <>set(anchor: Anchor) -> None;
    def remove(anchor: Anchor) -> None;
    def find_by_id(id: UUID) -> (Anchor | None);
    def commit(anchor: (Anchor | None) = None, keys: Iterable[Anchor] = []) -> None;
}

"""
Shelf-based Memory Handler — file-backed key/value storage.
Uses dbm.dumb on all platforms to avoid gdbm locking issues in Linux.
"""
obj ShelfDB {
    has shelf_path: str = os.environ.get('SHELF_DB_PATH', 'anchor_store.db'),
        _shelf: shelve.Shelf | None = None,
        _lock: RLock | None = None;

    def postinit;
    def _open_shelf -> shelve.Shelf;
    def _ensure_shelf -> shelve.Shelf;
    def close;
    def _redis_key(id: UUID) -> str;
    def _to_uuid(id: (UUID | str)) -> UUID;
    def _load_anchor_from_shelf(id: UUID) -> (Anchor | None);
    def <>set(anchor: Anchor) -> None;
    def remove(anchor: Anchor) -> None;
    def find_by_id(id: UUID) -> (Anchor | None);
    def commit(anchor: (Anchor | None) = None, keys: Iterable[Anchor] = []) -> None;
}
