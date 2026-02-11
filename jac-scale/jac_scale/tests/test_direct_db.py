"""Integration tests for direct database operations using testcontainers."""

import contextlib
import os
from collections.abc import Generator

import pytest
from testcontainers.mongodb import MongoDbContainer
from testcontainers.redis import RedisContainer

from jac_scale.db import close_all_db_connections
from jac_scale.lib import kvstore


@pytest.fixture(scope="session")
def mongo_uri():
    with MongoDbContainer("mongo:7.0") as container:
        yield container.get_connection_url()


@pytest.fixture(scope="session")
def redis_uri():
    with RedisContainer("redis:7.2-alpine") as container:
        host = container.get_container_host_ip()
        port = container.get_exposed_port(6379)
        yield f"redis://{host}:{port}/0"


@pytest.fixture(autouse=True)
def cleanup() -> Generator[None, None, None]:
    yield
    with contextlib.suppress(Exception):
        close_all_db_connections()


# ===== MONGODB =====


def test_mongodb_crud(mongo_uri: str) -> None:
    """Test MongoDB insert, find, update, delete operations."""
    db = kvstore(db_name="test_db", db_type="mongodb", uri=mongo_uri)

    # Insert and find
    db.insert_one("users", {"name": "Alice", "role": "admin", "age": 30})
    db.insert_one("users", {"name": "Bob", "role": "user", "age": 25})
    assert db.find_one("users", {"name": "Alice"})["age"] == 30
    assert len(list(db.find("users", {"role": "admin"}))) == 1
    assert len(list(db.find("users", {"age": {"$gt": 20}}))) == 2

    # Update and delete by ID
    result = db.insert_one("users", {"name": "Charlie", "status": "active"})
    doc_id = str(result.inserted_id)
    db.update_by_id("users", doc_id, {"$set": {"status": "inactive"}})
    assert db.find_by_id("users", doc_id)["status"] == "inactive"
    db.delete_by_id("users", doc_id)
    assert db.find_by_id("users", doc_id) is None

    # Bulk operations
    db.insert_many("scores", [{"score": 100}, {"score": 200}, {"score": 300}])
    assert (
        db.update_many(
            "scores", {"score": {"$gte": 200}}, {"$set": {"tier": "gold"}}
        ).modified_count
        == 2
    )
    assert db.delete_many("scores", {"tier": "gold"}).deleted_count == 2


def test_mongodb_kv_api(mongo_uri: str) -> None:
    """Test MongoDB with common key-value methods."""
    db = kvstore(db_name="test_db", db_type="mongodb", uri=mongo_uri)

    assert db.set("user:123", {"name": "Dave"}, "sessions") == "user:123"
    assert db.get("user:123", "sessions")["name"] == "Dave"
    assert db.exists("user:123", "sessions") is True
    assert db.exists("nonexistent", "sessions") is False
    assert db.delete("user:123", "sessions") == 1
    assert db.get("user:123", "sessions") is None


def test_mongodb_rejects_redis_methods(mongo_uri: str) -> None:
    """Test MongoDB raises NotImplementedError for Redis-specific methods."""
    db = kvstore(db_name="test_db", db_type="mongodb", uri=mongo_uri)

    with pytest.raises(NotImplementedError):
        db.set_with_ttl("key", {"v": 1}, ttl=60)
    with pytest.raises(NotImplementedError):
        db.incr("counter")
    with pytest.raises(NotImplementedError):
        db.expire("key", 300)
    with pytest.raises(NotImplementedError):
        db.scan_keys("pattern:*")


# ===== REDIS =====


def test_redis_kv_operations(redis_uri: str) -> None:
    """Test Redis key-value, TTL, incr, expire, and scan_keys."""
    db = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

    # Basic get/set/delete/exists
    assert db.set("session:abc", {"user_id": "42"}) == "session:abc"
    assert db.get("session:abc")["user_id"] == "42"
    assert db.exists("session:abc") is True
    assert db.delete("session:abc") == 1
    assert db.get("session:abc") is None

    # TTL and expire
    assert db.set_with_ttl("temp:token", {"v": "secret"}, ttl=3600) is True
    assert db.get("temp:token")["v"] == "secret"
    db.set("temp:data", {"v": "test"})
    assert db.expire("temp:data", 300) is True

    # Atomic increment
    assert db.incr("page:views") == 1
    assert db.incr("page:views") == 2
    assert db.incr("page:views") == 3

    # Pattern scan
    db.set("session:user1", {"id": "1"})
    db.set("session:user2", {"id": "2"})
    db.set("config:app", {"theme": "dark"})
    assert len(db.scan_keys("session:*")) == 2
    assert len(db.scan_keys("config:*")) == 1


def test_redis_rejects_mongodb_methods(redis_uri: str) -> None:
    """Test Redis raises NotImplementedError for MongoDB-specific methods."""
    db = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

    with pytest.raises(NotImplementedError):
        db.find_one("users", {"name": "Alice"})
    with pytest.raises(NotImplementedError):
        db.find("users", {})
    with pytest.raises(NotImplementedError):
        db.insert_one("users", {"name": "Bob"})
    with pytest.raises(NotImplementedError):
        db.update_one("users", {"name": "Bob"}, {"$set": {"age": 30}})
    with pytest.raises(NotImplementedError):
        db.delete_many("users", {})


# ===== CONNECTION POOLING & CONFIG =====


def test_connection_pooling(mongo_uri: str, redis_uri: str) -> None:
    """Test same URI reuses connection, different URIs create separate ones."""
    db1 = kvstore(db_name="db1", db_type="mongodb", uri=mongo_uri)
    db2 = kvstore(db_name="db2", db_type="mongodb", uri=mongo_uri)
    assert db1.client is db2.client

    redis_db = kvstore(db_name="cache", db_type="redis", uri=redis_uri)
    assert db1.client is not redis_db.client


def test_config_fallback(mongo_uri: str) -> None:
    """Test URI resolution: explicit > env var > raises ValueError."""
    # Explicit URI overrides env var
    os.environ["MONGODB_URI"] = "mongodb://fake:27017"
    try:
        db = kvstore(db_name="test", db_type="mongodb", uri=mongo_uri)
        assert db.insert_one("test", {"data": "ok"}).inserted_id is not None
    finally:
        del os.environ["MONGODB_URI"]

    # Env var fallback
    os.environ["MONGODB_URI"] = mongo_uri
    try:
        db = kvstore(db_name="test", db_type="mongodb")
        assert db.insert_one("test", {"data": "ok"}).inserted_id is not None
    finally:
        del os.environ["MONGODB_URI"]

    # Missing config raises error
    os.environ.pop("MONGODB_URI", None)
    with pytest.raises(ValueError, match="MongoDB URI not found"):
        kvstore(db_name="test", db_type="mongodb")


def test_invalid_db_type(mongo_uri: str) -> None:
    """Test invalid db_type raises ValueError."""
    with pytest.raises(ValueError, match="is not a valid DatabaseType"):
        kvstore(db_name="test", db_type="invalid_db", uri=mongo_uri)


# ===== REAL-WORLD PATTERN =====


def test_cache_aside_pattern(mongo_uri: str, redis_uri: str) -> None:
    """Test typical MongoDB (persistent) + Redis (cache) usage pattern."""
    mongo = kvstore(db_name="app", db_type="mongodb", uri=mongo_uri)
    cache = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

    # Persist user in MongoDB, cache session in Redis
    user_id = str(
        mongo.insert_one(
            "users", {"email": "u@example.com", "name": "User"}
        ).inserted_id
    )
    cache.set_with_ttl(
        f"session:{user_id}", {"user_id": user_id, "token": "abc"}, ttl=3600
    )

    assert cache.get(f"session:{user_id}")["user_id"] == user_id
    assert mongo.find_one("users", {"email": "u@example.com"})["name"] == "User"

    mongo.update_by_id("users", user_id, {"$set": {"status": "active"}})
    cache.incr("stats:logins")

    # Cleanup
    cache.delete(f"session:{user_id}")
    mongo.delete_by_id("users", user_id)
    assert cache.get(f"session:{user_id}") is None
    assert mongo.find_by_id("users", user_id) is None
