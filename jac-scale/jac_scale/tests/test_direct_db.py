"""Production-grade tests for direct database operations.

Tests cover:
1. Core CRUD operations (MongoDB & Redis with appropriate semantics)
2. Connection pooling and reuse
3. Configuration fallback mechanism
4. Error handling and edge cases
5. Database-specific method validation (NotImplementedError for incompatible methods)
"""

import os
from collections.abc import Generator

import pytest
from testcontainers.mongodb import MongoDbContainer
from testcontainers.redis import RedisContainer

from jac_scale.lib import kvstore


@pytest.fixture(scope="session")
def mongodb_container():
    """Provide a MongoDB test container for the session."""
    with MongoDbContainer("mongo:7.0") as container:
        yield container


@pytest.fixture(scope="session")
def redis_container():
    """Provide a Redis test container for the session."""
    with RedisContainer("redis:7.2-alpine") as container:
        yield container


@pytest.fixture
def mongo_uri(mongodb_container: MongoDbContainer) -> str:
    """Get MongoDB connection URI from container."""
    return mongodb_container.get_connection_url()


@pytest.fixture
def redis_uri(redis_container: RedisContainer) -> str:
    """Get Redis connection URI from container."""
    host = redis_container.get_container_host_ip()
    port = redis_container.get_exposed_port(6379)
    return f"redis://{host}:{port}/0"


@pytest.fixture(autouse=True)
def cleanup_connections() -> Generator[None, None, None]:
    """Clean up all database connections after each test."""
    yield
    # Cleanup after test
    try:
        from jac_scale.db import close_all_db_connections

        close_all_db_connections()
    except Exception:
        pass


# ===== MONGODB TESTS =====


class TestMongoDBDocumentOperations:
    """Test MongoDB document operations with filters and queries."""

    def test_insert_and_find_one_with_filter(self, mongo_uri: str) -> None:
        """Test MongoDB document query with filters."""
        db = kvstore(db_name="test_db", db_type="mongodb", uri=mongo_uri)

        # Insert documents
        db.insert_one("users", {"name": "Alice", "age": 30, "role": "admin"})
        db.insert_one("users", {"name": "Bob", "age": 25, "role": "user"})

        # Query with filter
        alice = db.find_one("users", {"name": "Alice"})
        assert alice is not None
        assert alice["name"] == "Alice"
        assert alice["age"] == 30
        assert alice["role"] == "admin"

    def test_find_multiple_documents(self, mongo_uri: str) -> None:
        """Test finding multiple documents with filter."""
        db = kvstore(db_name="test_db", db_type="mongodb", uri=mongo_uri)

        # Insert multiple documents
        db.insert_one("products", {"name": "Laptop", "price": 1000, "stock": 5})
        db.insert_one("products", {"name": "Mouse", "price": 25, "stock": 50})
        db.insert_one("products", {"name": "Keyboard", "price": 75, "stock": 0})

        # Find all in-stock items
        in_stock = list(db.find("products", {"stock": {"$gt": 0}}))
        assert len(in_stock) == 2

        # Find all items
        all_products = list(db.find("products", {}))
        assert len(all_products) == 3

    def test_update_and_delete_with_filters(self, mongo_uri: str) -> None:
        """Test MongoDB update and delete operations."""
        db = kvstore(db_name="test_db", db_type="mongodb", uri=mongo_uri)

        # Insert
        result = db.insert_one("users", {"name": "Charlie", "status": "active"})
        doc_id = str(result.inserted_id)

        # Update by ID
        update_result = db.update_by_id(
            "users", doc_id, {"$set": {"status": "inactive"}}
        )
        assert update_result.modified_count == 1

        # Verify update
        found = db.find_by_id("users", doc_id)
        assert found["status"] == "inactive"

        # Delete by ID
        delete_result = db.delete_by_id("users", doc_id)
        assert delete_result.deleted_count == 1

        # Verify deletion
        assert db.find_by_id("users", doc_id) is None

    def test_bulk_operations(self, mongo_uri: str) -> None:
        """Test MongoDB bulk operations."""
        db = kvstore(db_name="test_db", db_type="mongodb", uri=mongo_uri)

        # Bulk insert
        docs = [
            {"name": "User1", "score": 100},
            {"name": "User2", "score": 200},
            {"name": "User3", "score": 300},
        ]
        result = db.insert_many("scores", docs)
        assert len(result.inserted_ids) == 3

        # Bulk update
        update_result = db.update_many(
            "scores", {"score": {"$gte": 200}}, {"$set": {"tier": "gold"}}
        )
        assert update_result.modified_count == 2

        # Bulk delete
        delete_result = db.delete_many("scores", {"tier": "gold"})
        assert delete_result.deleted_count == 2


class TestMongoDBCommonMethods:
    """Test MongoDB using common get/set/delete methods."""

    def test_get_set_delete(self, mongo_uri: str) -> None:
        """Test MongoDB with simple key-value API."""
        db = kvstore(db_name="test_db", db_type="mongodb", uri=mongo_uri)

        # Set (upsert)
        doc_id = db.set(
            "user123", {"name": "Dave", "email": "dave@example.com"}, "users"
        )
        assert doc_id == "user123"

        # Get
        user = db.get("user123", "users")
        assert user is not None
        assert user["name"] == "Dave"

        # Exists
        assert db.exists("user123", "users") is True
        assert db.exists("nonexistent", "users") is False

        # Delete
        deleted = db.delete("user123", "users")
        assert deleted == 1

        # Verify deletion
        assert db.get("user123", "users") is None


# ===== REDIS TESTS =====


class TestRedisKeyValueOperations:
    """Test Redis pure key-value operations."""

    def test_get_set_delete(self, redis_uri: str) -> None:
        """Test Redis basic key-value operations."""
        db = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

        # Set
        key = db.set("session:abc123", {"user_id": "42", "token": "xyz"})
        assert key == "session:abc123"

        # Get
        session = db.get("session:abc123")
        assert session is not None
        assert session["user_id"] == "42"
        assert session["token"] == "xyz"

        # Exists
        assert db.exists("session:abc123") is True
        assert db.exists("nonexistent") is False

        # Delete
        deleted = db.delete("session:abc123")
        assert deleted == 1

        # Verify deletion
        assert db.get("session:abc123") is None

    def test_set_with_ttl(self, redis_uri: str) -> None:
        """Test Redis TTL functionality."""
        db = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

        # Set with TTL
        result = db.set_with_ttl("temp:token", {"value": "secret"}, ttl=3600)
        assert result is True

        # Verify it was set
        data = db.get("temp:token")
        assert data is not None
        assert data["value"] == "secret"

    def test_incr(self, redis_uri: str) -> None:
        """Test Redis atomic increment."""
        db = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

        # Increment (creates key if not exists)
        count1 = db.incr("page:views")
        assert count1 == 1

        count2 = db.incr("page:views")
        assert count2 == 2

        count3 = db.incr("page:views")
        assert count3 == 3

    def test_expire(self, redis_uri: str) -> None:
        """Test setting expiration on existing key."""
        db = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

        # Set a key
        db.set("temp:data", {"value": "test"})

        # Set expiration
        result = db.expire("temp:data", 300)
        assert result is True

        # Key should still exist
        assert db.exists("temp:data") is True

    def test_scan_keys(self, redis_uri: str) -> None:
        """Test Redis pattern-based key scanning."""
        db = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

        # Create multiple keys
        db.set("session:user1", {"id": "1"})
        db.set("session:user2", {"id": "2"})
        db.set("session:user3", {"id": "3"})
        db.set("config:app", {"theme": "dark"})

        # Scan for sessions
        session_keys = db.scan_keys("session:*")
        assert len(session_keys) == 3
        assert all(key.startswith("user") for key in session_keys)

        # Scan for config
        config_keys = db.scan_keys("config:*")
        assert len(config_keys) == 1


class TestRedisBackwardCompatibility:
    """Test Redis with legacy methods for backward compatibility."""

    def test_find_by_id_maps_to_get(self, redis_uri: str) -> None:
        """Test that find_by_id works as alias for get."""
        db = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

        # Insert using set
        db.set("item123", {"name": "Widget"})

        # Retrieve using find_by_id (backward compat)
        found = db.find_by_id("default", "item123")
        assert found is not None
        assert found["name"] == "Widget"

    def test_delete_by_id_maps_to_delete(self, redis_uri: str) -> None:
        """Test that delete_by_id works for Redis."""
        db = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

        # Set a key
        db.set("item456", {"name": "Gadget"})

        # Delete using delete_by_id
        result = db.delete_by_id("default", "item456")
        assert result.deleted_count == 1


# ===== REDIS ERROR HANDLING =====


class TestRedisRejectsMongoDBMethods:
    """Test that Redis raises errors for MongoDB-specific methods."""

    def test_find_one_raises_error(self, redis_uri: str) -> None:
        """Verify find_one raises NotImplementedError for Redis."""
        db = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

        with pytest.raises(
            NotImplementedError, match="find_one.*not supported for Redis"
        ):
            db.find_one("users", {"name": "Alice"})

    def test_find_raises_error(self, redis_uri: str) -> None:
        """Verify find raises NotImplementedError for Redis."""
        db = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

        with pytest.raises(NotImplementedError, match="find.*not supported for Redis"):
            db.find("users", {})

    def test_insert_one_raises_error(self, redis_uri: str) -> None:
        """Verify insert_one raises NotImplementedError for Redis."""
        db = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

        with pytest.raises(
            NotImplementedError, match="insert_one.*not supported for Redis"
        ):
            db.insert_one("users", {"name": "Bob"})

    def test_update_one_raises_error(self, redis_uri: str) -> None:
        """Verify update_one raises NotImplementedError for Redis."""
        db = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

        with pytest.raises(
            NotImplementedError, match="update_one.*not supported for Redis"
        ):
            db.update_one("users", {"name": "Bob"}, {"$set": {"age": 30}})

    def test_update_many_raises_error(self, redis_uri: str) -> None:
        """Verify update_many raises NotImplementedError for Redis."""
        db = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

        with pytest.raises(
            NotImplementedError, match="update_many.*not supported for Redis"
        ):
            db.update_many("users", {}, {"$set": {"status": "active"}})

    def test_delete_many_raises_error(self, redis_uri: str) -> None:
        """Verify delete_many raises NotImplementedError for Redis."""
        db = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

        with pytest.raises(
            NotImplementedError, match="delete_many.*not supported for Redis"
        ):
            db.delete_many("users", {"status": "inactive"})

    def test_update_by_id_raises_error(self, redis_uri: str) -> None:
        """Verify update_by_id raises NotImplementedError for Redis."""
        db = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

        with pytest.raises(
            NotImplementedError, match="update_by_id.*not supported for Redis"
        ):
            db.update_by_id("users", "123", {"$set": {"age": 30}})


# ===== MONGODB ERROR HANDLING =====


class TestMongoDBRejectsRedisMethods:
    """Test that MongoDB raises errors for Redis-specific methods."""

    def test_set_with_ttl_raises_error(self, mongo_uri: str) -> None:
        """Verify set_with_ttl raises NotImplementedError for MongoDB."""
        db = kvstore(db_name="test_db", db_type="mongodb", uri=mongo_uri)

        with pytest.raises(
            NotImplementedError, match="set_with_ttl.*not supported for MongoDB"
        ):
            db.set_with_ttl("key", {"value": "data"}, ttl=3600)

    def test_incr_raises_error(self, mongo_uri: str) -> None:
        """Verify incr raises NotImplementedError for MongoDB."""
        db = kvstore(db_name="test_db", db_type="mongodb", uri=mongo_uri)

        with pytest.raises(
            NotImplementedError, match="incr.*not supported for MongoDB"
        ):
            db.incr("counter")

    def test_expire_raises_error(self, mongo_uri: str) -> None:
        """Verify expire raises NotImplementedError for MongoDB."""
        db = kvstore(db_name="test_db", db_type="mongodb", uri=mongo_uri)

        with pytest.raises(
            NotImplementedError, match="expire.*not supported for MongoDB"
        ):
            db.expire("key", 300)

    def test_scan_keys_raises_error(self, mongo_uri: str) -> None:
        """Verify scan_keys raises NotImplementedError for MongoDB."""
        db = kvstore(db_name="test_db", db_type="mongodb", uri=mongo_uri)

        with pytest.raises(
            NotImplementedError, match="scan_keys.*not supported for MongoDB"
        ):
            db.scan_keys("pattern:*")


# ===== CONNECTION POOLING =====


class TestConnectionPooling:
    """Test connection pooling and reuse."""

    def test_same_uri_reuses_connection(self, mongo_uri: str) -> None:
        """Verify same URI reuses the same connection."""
        db1 = kvstore(db_name="db1", db_type="mongodb", uri=mongo_uri)
        db2 = kvstore(db_name="db2", db_type="mongodb", uri=mongo_uri)

        # Same URI should reuse the same client
        assert db1.client is db2.client

    def test_different_uri_creates_new_connection(
        self, mongo_uri: str, redis_uri: str
    ) -> None:
        """Verify different URIs create different connections."""
        mongo_db = kvstore(db_name="mongo", db_type="mongodb", uri=mongo_uri)
        redis_db = kvstore(db_name="redis", db_type="redis", uri=redis_uri)

        # Different databases should have different clients
        assert mongo_db.client is not redis_db.client


# ===== CONFIGURATION =====


class TestConfigurationFallback:
    """Test configuration fallback mechanism."""

    def test_explicit_uri_overrides_config(self, mongo_uri: str) -> None:
        """Verify explicit URI parameter takes precedence."""
        os.environ["MONGODB_URI"] = "mongodb://fake:27017"

        try:
            db = kvstore(db_name="test", db_type="mongodb", uri=mongo_uri)
            result = db.insert_one("test", {"test": "data"})
            assert result.inserted_id is not None
        finally:
            del os.environ["MONGODB_URI"]

    def test_env_var_fallback(self, mongo_uri: str) -> None:
        """Verify environment variable is used when URI not provided."""
        os.environ["MONGODB_URI"] = mongo_uri

        try:
            db = kvstore(db_name="test", db_type="mongodb")
            result = db.insert_one("test", {"test": "data"})
            assert result.inserted_id is not None
        finally:
            del os.environ["MONGODB_URI"]

    def test_missing_config_raises_error(self) -> None:
        """Verify missing configuration raises ValueError."""
        os.environ.pop("MONGODB_URI", None)
        os.environ.pop("REDIS_URL", None)

        with pytest.raises(ValueError, match="MongoDB URI not found"):
            kvstore(db_name="test", db_type="mongodb")


# ===== ERROR HANDLING =====


class TestErrorHandling:
    """Test error handling and edge cases."""

    def test_invalid_db_type(self, mongo_uri: str) -> None:
        """Verify invalid database type raises error."""
        with pytest.raises(ValueError, match="is not a valid DatabaseType"):
            kvstore(db_name="test", db_type="invalid_db", uri=mongo_uri)

    def test_connection_cleanup(self, mongo_uri: str) -> None:
        """Verify connections can be cleaned up."""
        from jac_scale.db import close_all_db_connections

        # Create connection
        db1 = kvstore(db_name="db1", db_type="mongodb", uri=mongo_uri)
        db1.insert_one("test", {"data": "test"})

        # Cleanup
        close_all_db_connections()

        # New connection should work
        db2 = kvstore(db_name="db2", db_type="mongodb", uri=mongo_uri)
        result = db2.insert_one("test", {"data": "test2"})
        assert result.inserted_id is not None


# ===== REAL-WORLD USAGE =====


class TestRealWorldUsage:
    """Test realistic usage patterns."""

    def test_user_session_workflow(self, mongo_uri: str, redis_uri: str) -> None:
        """Simulate real user session workflow with appropriate methods."""
        # MongoDB for persistent data (use document queries)
        user_db = kvstore(db_name="app", db_type="mongodb", uri=mongo_uri)

        # Redis for session cache (use key-value)
        cache_db = kvstore(db_name="app", db_type="redis", uri=redis_uri)

        # 1. Create user in MongoDB (document operation)
        user = {"email": "user@example.com", "name": "Test User"}
        user_result = user_db.insert_one("users", user)
        user_id = str(user_result.inserted_id)

        # 2. Create session in Redis (key-value with TTL)
        session_key = f"session:{user_id}"
        cache_db.set_with_ttl(
            session_key, {"user_id": user_id, "token": "abc123"}, ttl=3600
        )

        # 3. Retrieve session from Redis
        cached_session = cache_db.get(session_key)
        assert cached_session is not None
        assert cached_session["user_id"] == user_id

        # 4. Query user from MongoDB (document query)
        found_user = user_db.find_one("users", {"email": "user@example.com"})
        assert found_user["name"] == "Test User"

        # 5. Update user in MongoDB
        user_db.update_by_id("users", user_id, {"$set": {"status": "active"}})

        # 6. Increment page views in Redis
        cache_db.incr("page:views")

        # 7. Cleanup
        cache_db.delete(session_key)
        user_db.delete_by_id("users", user_id)

    def test_caching_pattern(self, mongo_uri: str, redis_uri: str) -> None:
        """Test cache-aside pattern."""
        mongo = kvstore(db_name="app", db_type="mongodb", uri=mongo_uri)
        redis = kvstore(db_name="cache", db_type="redis", uri=redis_uri)

        # 1. Insert into MongoDB
        doc = {"product_id": "prod123", "name": "Widget", "price": 99.99}
        mongo.insert_one("products", doc)

        # 2. Cache in Redis with TTL
        redis.set_with_ttl("product:prod123", doc, ttl=300)

        # 3. Read from cache first
        cached = redis.get("product:prod123")
        assert cached is not None
        assert cached["name"] == "Widget"

        # 4. On cache miss, read from MongoDB
        redis.delete("product:prod123")
        assert redis.get("product:prod123") is None

        # Fallback to MongoDB
        from_db = mongo.find_one("products", {"product_id": "prod123"})
        assert from_db["name"] == "Widget"
