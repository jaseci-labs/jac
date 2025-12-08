"""Base memory hierachy implementation."""

from __future__ import annotations

import os
import shelve
from collections.abc import Iterable, MutableMapping
from dataclasses import dataclass, field
from pickle import dumps, loads
from threading import RLock
from typing import Any, TypeVar, cast
from uuid import UUID

import redis
from pymongo import MongoClient, UpdateOne

from jaclang.runtimelib.archetype import TANCH, Anchor
from jaclang.runtimelib.memory import Memory

ID = TypeVar("ID")


@dataclass
class MultiHierarchyMemory(Memory[UUID, Anchor]):
    def __init__(self) -> None:
        super().__init__()
        self.mem = Memory[UUID, Anchor]()
        self.redis = RedisDB()
        self.mongo = MongoDB()
        if not self.redis.redis_is_available():
            self.shelf = ShelfDB()

    # ---- DOWNSTREAM (READS) ----
    def find_by_id(self, id: UUID) -> Anchor | None:
        # print("I am using find by id", id, flush=True)
        # 1. Memory
        if anchor := self.mem.find_by_id(id):
            return anchor
        if self.redis.redis_is_available():
            # 2. Redis
            if anchor := self.redis.find_by_id(id):
                self.mem.set(anchor)
                return anchor
            # 3. MongoDB
            if anchor := self.mongo.find_by_id(id):
                self.mem.set(anchor)
                self.redis.set(anchor)
                return anchor
        else:
            if anchor := self.shelf.find_by_id(id):
                self.mem.set(anchor)
                return anchor

        return None

    # ---- UPSTREAM (WRITES) ----
    def commit(self, anchor: Anchor | None = None):
        gc = self.mem.get_gc()
        memory = self.mem.get_mem()

        if anchor:
            # print("I am commiting anchor with id", anchor.id, flush=True)
            if anchor in gc:
                self.delete(anchor)
                self.mem.remove_from_gc(anchor)
            else:
                if self.redis.redis_is_available():
                    self.redis.set(anchor)
                    self.mongo.set(anchor)
                else:
                    # print("I am using shelf storage")
                    self.shelf.set(anchor)
            return

        # print("commiting all anchors", flush=True)
        for anchor in gc:
            self.delete(anchor)
            self.mem.remove_from_gc(anchor)

        anchors = set(memory.values())
        self.sync(anchors)

    def close(self):
        self.commit()
        self.mem.close()

    def sync(self, anchors: Iterable[Anchor]) -> None:
        if self.redis.redis_is_available():
            self.redis.commit(keys=anchors)
            self.mongo.commit(keys=anchors)
        else:
            self.shelf.commit(keys=anchors)

    def delete(self, anchor: Anchor):
        self.mem.remove(anchor.id)
        if self.redis.redis_is_available():
            self.redis.remove(anchor)
            self.mongo.remove(anchor)
        else:
            self.shelf.commit(anchor)

    def set(self, anchor: TANCH):
        self.mem.set(anchor)


@dataclass
class MongoDB:  # Memory[UUID, Anchor]):
    """MongoDB handler."""

    client: MongoClient | None = field(default=None)
    db_name: str = "jac_db"
    collection_name: str = "anchors"
    mongo_url = os.environ.get(
        "MONGODB_URI", "mongodb://root:rootpassword123@localhost:27017/"
    )

    def __post_init__(self) -> None:
        """Initialize Mongodb."""
        if self.client is None:
            self.client = MongoClient(self.mongo_url)

        self.db = self.client[self.db_name]
        self.collection = self.db[self.collection_name]

    def _to_uuid(self, id: UUID | str) -> UUID:
        if not isinstance(id, UUID):
            return UUID(str(id))
        return id

    def _load_anchor(self, raw: dict[str, Any]) -> TANCH | None:
        try:
            return loads(raw["data"])
        except Exception:
            return None

    def set(self, anchor: Anchor) -> None:
        """
        Save anchor to MongoDB, exactly like ShelfStorage:
        - Save all anchors (no empty NodeAnchor skipping)
        - Update NodeAnchor edges
        - Respect write and connect access
        """
        from jaclang.runtimelib.archetype import NodeAnchor
        from jaclang.runtimelib.runtime import JacRuntimeInterface as Jac

        _id = self._to_uuid(anchor.id)
        try:
            current_hash = hash(dumps(anchor))

        except Exception:
            return

        if getattr(anchor, "hash", None) == current_hash:
            return

        # fetch existing
        db_doc = self.collection.find_one({"_id": str(_id)})
        stored_anchor = self._load_anchor(db_doc) if db_doc else None
        # update edges if NodeAnchor
        if (
            stored_anchor
            and isinstance(stored_anchor, NodeAnchor)
            and isinstance(anchor, NodeAnchor)
            and getattr(stored_anchor, "edges", None) != getattr(anchor, "edges", None)
            and Jac.check_connect_access(anchor)
        ):
            stored_anchor.edges = anchor.edges
            base_anchor = stored_anchor
        else:
            base_anchor = anchor

        # update access/archetype if allowed
        if stored_anchor and Jac.check_write_access(anchor):
            try:
                if hash(dumps(stored_anchor.access)) != hash(dumps(anchor.access)):
                    stored_anchor.access = anchor.access
                if hash(dumps(stored_anchor.archetype)) != hash(
                    dumps(anchor.archetype)
                ):
                    stored_anchor.archetype = anchor.archetype
                final_anchor = stored_anchor
            except Exception:
                final_anchor = anchor
        else:
            final_anchor = base_anchor

        # save to MongoDB
        try:
            data_blob = dumps(final_anchor)
        except Exception:
            return

        self.collection.update_one(
            {"_id": str(_id)},
            {"$set": {"data": data_blob, "type": type(final_anchor).__name__}},
            upsert=True,
        )

    def remove(self, anchor: TANCH) -> None:
        _id = self._to_uuid(anchor.id)
        self.collection.delete_one({"_id": str(_id)})

    def find_by_id(self, id: UUID) -> Anchor | None:
        _id = self._to_uuid(id)
        db_obj = self.collection.find_one({"_id": str(_id)})
        if db_obj:
            anchor = self._load_anchor(db_obj)
            if anchor:
                return anchor
        return None

    def commit_bulk(self, anchors: Iterable[Anchor]) -> None:
        """
        Faster bulk commit:
        - Deletes anchors in GC
        - Saves only updated anchors
        - Uses MongoDB bulk_write for speed
        """
        from jaclang.runtimelib.archetype import NodeAnchor
        from jaclang.runtimelib.runtime import JacRuntimeInterface as Jac

        ops: list = []

        for anc in anchors:
            _id = self._to_uuid(anc.id)

            try:
                current_hash = hash(dumps(anc))
            except Exception:
                continue
            # Skip if hash unchanged → no need to save
            if getattr(anc, "hash", None) == current_hash:
                continue

            # Need to fetch stored anchor only once
            db_doc = self.collection.find_one({"_id": str(_id)})
            stored_anchor = self._load_anchor(db_doc) if db_doc else None

            # ---- Edge merging logic ----
            if (
                stored_anchor
                and isinstance(stored_anchor, NodeAnchor)
                and isinstance(anc, NodeAnchor)
                and getattr(stored_anchor, "edges", None) != getattr(anc, "edges", None)
                and Jac.check_connect_access(anc)
            ):
                stored_anchor.edges = anc.edges
                working_anchor = stored_anchor
            else:
                working_anchor = anc

            # ---- Access + archetype update logic ----
            if stored_anchor and Jac.check_write_access(anc):
                try:
                    if hash(dumps(stored_anchor.access)) != hash(dumps(anc.access)):
                        stored_anchor.access = anc.access
                    if hash(dumps(stored_anchor.archetype)) != hash(
                        dumps(anc.archetype)
                    ):
                        stored_anchor.archetype = anc.archetype
                    working_anchor = stored_anchor
                except Exception:
                    working_anchor = anc
            # ---- Serialize ----
            try:
                blob = dumps(working_anchor)
            except Exception:
                continue

            ops.append(
                UpdateOne(
                    {"_id": str(_id)},
                    {"$set": {"data": blob, "type": type(working_anchor).__name__}},
                    upsert=True,
                )
            )

        if ops:
            self.collection.bulk_write(ops)

    def commit(self, anchor: TANCH | None = None, keys: Iterable[Anchor] = []) -> None:
        if anchor:
            self.set(anchor)
            return
        if keys:
            self.commit_bulk(keys)


@dataclass
class RedisDB:  # Memory[UUID, Anchor]):
    """Redis-based Memory Handler."""

    redis_url: str = os.environ.get(
        "REDIS_URL", "redis://:mypassword123@localhost:6379/0"
    )
    redis_client: redis.Redis | None = field(default=None)

    def __post_init__(self) -> None:
        """Initialize Redis."""

        if self.redis_client is None:
            self.redis_client = redis.from_url(self.redis_url)

    def redis_is_available(self) -> bool:
        """Check whether Redis connection is alive and reachable."""
        try:
            if self.redis_client is None:
                return False
            return self.redis_client.ping()
        except Exception:
            return False

    def _redis_key(self, id: UUID) -> str:
        return f"anchor:{str(id)}"

    def _to_uuid(self, id: UUID | str) -> UUID:
        if not isinstance(id, UUID):
            return UUID(str(id))
        return id

    def _load_anchor_from_redis(self, id: UUID) -> Anchor | None:
        if self.redis_client is None:
            return None
        key = self._redis_key(id)
        raw = self.redis_client.get(key)
        if not raw:
            return None
        try:
            return loads(raw)
        except Exception:
            return None

    def set(self, anchor: Anchor) -> None:
        """Save to MongoDB AND Redis."""
        if self.redis_client is None:
            return
        self.redis_client.set(self._redis_key(anchor.id), dumps(anchor))

    def remove(self, anchor: Anchor) -> None:
        """Delete from MongoDB AND Redis."""
        if self.redis_client is None:
            return None
        self.redis_client.delete(self._redis_key(anchor.id))

    def find_by_id(self, id: UUID) -> Anchor | None:
        _id = self._to_uuid(id)
        data = self._load_anchor_from_redis(_id)
        return data

    def commit(self, anchor: Anchor | None = None, keys: Iterable[Anchor] = []) -> None:
        """Commit behaves like MongoDB but also syncs Redis."""

        if anchor:
            self.set(anchor)
            return
        if keys:
            for anc in keys:
                self.set(anc)


@dataclass
class ShelfDB:
    """Shelf-based Memory Handler — file-backed key/value storage.
    Uses dbm.dumb on all platforms to avoid gdbm locking issues in Linux.
    """

    shelf_path: str = field(default=os.environ.get("SHELF_DB_PATH", "anchor_store.db"))

    _shelf: shelve.Shelf | None = field(init=False, default=None)
    _lock: RLock = field(default_factory=RLock, init=False)

    def __post_init__(self):
        """Initialize shelf DB on startup."""
        self._open_shelf()

    def _open_shelf(self) -> shelve.Shelf:
        """Always use dbm.dumb backend to avoid Linux gdbm locking."""
        import dbm.dumb

        if self._shelf is None:
            # dbm.dumb creates two files: .dat and .dir
            # Note: Can't use context manager - db must stay open for Shelf lifecycle
            raw_db = dbm.dumb.open(self.shelf_path, "c")  # noqa: SIM115
            db_as_mapping = cast(MutableMapping[bytes, bytes], raw_db)
            self._shelf = shelve.Shelf(db_as_mapping, writeback=False)
        return self._shelf

    def _ensure_shelf(self) -> shelve.Shelf:
        if self._shelf is None:
            self._shelf = self._open_shelf()
        return self._shelf

    def close(self):
        """Cleanly close shelf storage."""
        self._shelf = self._ensure_shelf()
        if self._shelf is not None:
            self._shelf.close()
            self._shelf = None

    def _redis_key(self, id: UUID) -> str:
        """Match key format used by Redis for consistency."""
        return f"anchor:{str(id)}"

    def _to_uuid(self, id: UUID | str) -> UUID:
        if not isinstance(id, UUID):
            return UUID(str(id))
        return id

    def _load_anchor_from_shelf(self, id: UUID) -> Anchor | None:
        key = self._redis_key(id)
        shelf = self._ensure_shelf()

        with self._lock:
            if key not in shelf:
                return None
            return shelf[key]

    def set(self, anchor: Anchor) -> None:
        """Save anchor to shelf."""
        key = self._redis_key(anchor.id)
        shelf = self._ensure_shelf()

        with self._lock:
            shelf[key] = anchor
            shelf.sync()  # flush changes to disk

    def remove(self, anchor: Anchor) -> None:
        """Remove anchor from shelf."""
        key = self._redis_key(anchor.id)
        shelf = self._ensure_shelf()

        with self._lock:
            if key in shelf:
                del shelf[key]
                shelf.sync()

    def find_by_id(self, id: UUID) -> Anchor | None:
        _id = self._to_uuid(id)
        return self._load_anchor_from_shelf(_id)

    def commit(self, anchor: Anchor | None = None, keys: Iterable[Anchor] = []) -> None:
        """Commit one or many anchors."""
        if anchor:
            self.set(anchor)
            return

        for anc in keys:
            self.set(anc)
