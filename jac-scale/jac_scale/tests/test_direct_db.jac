"""Integration tests for direct database operations using testcontainers."""

import contextlib;
import os;
import from collections.abc { Generator }
import from testcontainers.mongodb { MongoDbContainer }
import from testcontainers.redis { RedisContainer }
import from jac_scale.db { close_all_db_connections }
import from jac_scale.lib { kvstore }

# Helper to safely close DB connections
def cleanup_connections {
    with contextlib.suppress(Exception) {
        close_all_db_connections();
    }
}

# Session-scoped containers created as globals
glob _mongo_container = MongoDbContainer(
         "mongo:7.0"
     ),
     _redis_container = RedisContainer("redis:7.2-alpine"),
     MONGO_URI: str = "",
     REDIS_URI: str = "";

with entry {
    _mongo_container.start();
    _redis_container.start();
}

glob MONGO_URI = _mongo_container.get_connection_url(),
     REDIS_URI = f"redis://{_redis_container.get_container_host_ip()}:{_redis_container.get_exposed_port(
         6379
     )}/0";

# ===== MONGODB =====
test "mongodb crud" {
    db = kvstore(db_name="test_db", db_type="mongodb", uri=MONGO_URI);

    # Insert and find
    db.insert_one("users", {"name": "Alice", "role": "admin", "age": 30});
    db.insert_one("users", {"name": "Bob", "role": "user", "age": 25});
    assert db.find_one("users", {"name": "Alice"})["age"] == 30;
    assert len(list(db.find("users", {"role": "admin"}))) == 1;
    assert len(list(db.find("users", {"age": {"$gt": 20}}))) == 2;

    # Update and delete by ID
    result = db.insert_one("users", {"name": "Charlie", "status": "active"});
    doc_id = str(result.inserted_id);
    db.update_by_id("users", doc_id, {"$set": {"status": "inactive"}});
    assert db.find_by_id("users", doc_id)["status"] == "inactive";
    db.delete_by_id("users", doc_id);
    assert db.find_by_id("users", doc_id) is None;

    # Bulk operations
    db.insert_many("scores", [{"score": 100}, {"score": 200}, {"score": 300}]);
    assert (
        db.update_many("scores", {"score": {"$gte": 200}}, {"$set": {"tier": "gold"}}).modified_count == 2
    );
    assert db.delete_many("scores", {"tier": "gold"}).deleted_count == 2;

    cleanup_connections();
}

test "mongodb kv api" {
    db = kvstore(db_name="test_db", db_type="mongodb", uri=MONGO_URI);

    assert db.set("user:123", {"name": "Dave"}, "sessions") == "user:123";
    assert db.get("user:123", "sessions")["name"] == "Dave";
    assert db.exists("user:123", "sessions") is True;
    assert db.exists("nonexistent", "sessions") is False;
    assert db.delete("user:123", "sessions") == 1;
    assert db.get("user:123", "sessions") is None;

    cleanup_connections();
}

test "mongodb rejects redis methods" {
    db = kvstore(db_name="test_db", db_type="mongodb", uri=MONGO_URI);

    raised = False;
    try {
        db.set_with_ttl("key", {"v": 1}, ttl=60);
    } except NotImplementedError {
        raised = True;
    }
    assert raised , "Expected NotImplementedError for set_with_ttl on mongodb";

    raised = False;
    try {
        db.incr("counter");
    } except NotImplementedError {
        raised = True;
    }
    assert raised , "Expected NotImplementedError for incr on mongodb";

    raised = False;
    try {
        db.expire("key", 300);
    } except NotImplementedError {
        raised = True;
    }
    assert raised , "Expected NotImplementedError for expire on mongodb";

    raised = False;
    try {
        db.scan_keys("pattern:*");
    } except NotImplementedError {
        raised = True;
    }
    assert raised , "Expected NotImplementedError for scan_keys on mongodb";

    cleanup_connections();
}

# ===== REDIS =====
test "redis kv operations" {
    db = kvstore(db_name="cache", db_type="redis", uri=REDIS_URI);

    # Basic get/set/delete/exists
    assert db.set("session:abc", {"user_id": "42"}) == "session:abc";
    assert db.get("session:abc")["user_id"] == "42";
    assert db.exists("session:abc") is True;
    assert db.delete("session:abc") == 1;
    assert db.get("session:abc") is None;

    # TTL and expire
    assert db.set_with_ttl("temp:token", {"v": "secret"}, ttl=3600) is True;
    assert db.get("temp:token")["v"] == "secret";
    db.set("temp:data", {"v": "test"});
    assert db.expire("temp:data", 300) is True;

    # Atomic increment
    assert db.incr("page:views") == 1;
    assert db.incr("page:views") == 2;
    assert db.incr("page:views") == 3;

    # Pattern scan
    db.set("session:user1", {"id": "1"});
    db.set("session:user2", {"id": "2"});
    db.set("config:app", {"theme": "dark"});
    assert len(db.scan_keys("session:*")) == 2;
    assert len(db.scan_keys("config:*")) == 1;

    cleanup_connections();
}

test "redis rejects mongodb methods" {
    db = kvstore(db_name="cache", db_type="redis", uri=REDIS_URI);

    raised = False;
    try {
        db.find_one("users", {"name": "Alice"});
    } except NotImplementedError {
        raised = True;
    }
    assert raised , "Expected NotImplementedError for find_one on redis";

    raised = False;
    try {
        db.find("users", {});
    } except NotImplementedError {
        raised = True;
    }
    assert raised , "Expected NotImplementedError for find on redis";

    raised = False;
    try {
        db.insert_one("users", {"name": "Bob"});
    } except NotImplementedError {
        raised = True;
    }
    assert raised , "Expected NotImplementedError for insert_one on redis";

    raised = False;
    try {
        db.update_one("users", {"name": "Bob"}, {"$set": {"age": 30}});
    } except NotImplementedError {
        raised = True;
    }
    assert raised , "Expected NotImplementedError for update_one on redis";

    raised = False;
    try {
        db.delete_many("users", {});
    } except NotImplementedError {
        raised = True;
    }
    assert raised , "Expected NotImplementedError for delete_many on redis";

    cleanup_connections();
}

# ===== CONNECTION POOLING & CONFIG =====
test "connection pooling" {
    db1 = kvstore(db_name="db1", db_type="mongodb", uri=MONGO_URI);
    db2 = kvstore(db_name="db2", db_type="mongodb", uri=MONGO_URI);
    assert db1.client is db2.client;

    redis_db = kvstore(db_name="cache", db_type="redis", uri=REDIS_URI);
    assert db1.client is not redis_db.client;

    cleanup_connections();
}

test "config fallback" {
    # Explicit URI overrides env var
    os.environ["MONGODB_URI"] = "mongodb://fake:27017";
    try {
        db = kvstore(db_name="test", db_type="mongodb", uri=MONGO_URI);
        assert db.insert_one("test", {"data": "ok"}).inserted_id is not None;
    } finally {
        del os.environ["MONGODB_URI"];
    }

    # Env var fallback
    os.environ["MONGODB_URI"] = MONGO_URI;
    try {
        db = kvstore(db_name="test", db_type="mongodb");
        assert db.insert_one("test", {"data": "ok"}).inserted_id is not None;
    } finally {
        del os.environ["MONGODB_URI"];
    }

    # Missing config raises error
    os.environ.pop("MONGODB_URI", None);
    raised = False;
    try {
        kvstore(db_name="test", db_type="mongodb");
    } except ValueError as e {
        raised = True;
        assert "MongoDB URI not found" in str(e);
    }
    assert raised , "Expected ValueError for missing MongoDB URI";

    cleanup_connections();
}

test "invalid db type" {
    raised = False;
    try {
        kvstore(db_name="test", db_type="invalid_db", uri=MONGO_URI);
    } except ValueError as e {
        raised = True;
        assert "is not a valid DatabaseType" in str(e);
    }
    assert raised , "Expected ValueError for invalid db_type";

    cleanup_connections();
}

# ===== REAL-WORLD PATTERN =====
test "cache aside pattern" {
    mongo = kvstore(db_name="app", db_type="mongodb", uri=MONGO_URI);
    cache = kvstore(db_name="cache", db_type="redis", uri=REDIS_URI);

    # Persist user in MongoDB, cache session in Redis
    user_id = str(
        mongo.insert_one("users", {"email": "u@example.com", "name": "User"}).inserted_id
    );
    cache.set_with_ttl(
        f"session:{user_id}", {"user_id": user_id, "token": "abc"}, ttl=3600
    );

    assert cache.get(f"session:{user_id}")["user_id"] == user_id;
    assert mongo.find_one("users", {"email": "u@example.com"})["name"] == "User";

    mongo.update_by_id("users", user_id, {"$set": {"status": "active"}});
    cache.incr("stats:logins");

    # Cleanup
    cache.delete(f"session:{user_id}");
    mongo.delete_by_id("users", user_id);
    assert cache.get(f"session:{user_id}") is None;
    assert mongo.find_by_id("users", user_id) is None;

    cleanup_connections();
}

# ===== FIND_NODES =====
test "find_nodes basic" {
    import from jaclang.runtimelib.serializer { Serializer }

    # Test node for find_nodes test
    node TestNode {
        has name: str,
            age: int,
            status: str = "active";
    }
    db = kvstore(db_name="test_find_nodes", db_type="mongodb", uri=MONGO_URI);

    # Create test nodes manually
    alice = TestNode(name="Alice", age=30, status="active");
    bob = TestNode(name="Bob", age=25, status="inactive");
    charlie = TestNode(name="Charlie", age=35, status="active");

    test_nodes = [alice, bob, charlie];

    # Store nodes in _anchors collection
    for node in test_nodes {
        data = Serializer.serialize(node.__jac__, include_type=True);
        db._get_mongo_collection('_anchors').insert_one(
            {'_id': str(node.__jac__.id), 'data': data, 'type': 'NodeAnchor'}
        );
    }

    # Test find_nodes - find all TestNode instances
    results = db.find_nodes('TestNode');
    assert len(results) == 3 , f"Expected 3 nodes, got {len(results)}";

    # Test with filter - find only active nodes
    active_results = db.find_nodes('TestNode', {'status': 'active'});
    assert len(active_results) == 2 , f"Expected 2 active nodes, got {len(
        active_results
    )}";
    for node in active_results {
        assert node.status == 'active';
    }

    # Test with filter - find by name
    alice_results = db.find_nodes('TestNode', {'name': 'Alice'});
    assert len(alice_results) == 1;
    assert alice_results[0].name == 'Alice';
    assert alice_results[0].age == 30;

    # Clean up
    db._get_mongo_collection('_anchors').drop();
    cleanup_connections();
}

test "_anchors collection is read-only" {
    db = kvstore(db_name="test_db", db_type="mongodb", uri=MONGO_URI);

    # Test that write operations on _anchors are blocked
    raised = False;
    try {
        db.set("test_key", {"data": "value"}, "_anchors");
    } except PermissionError as e {
        raised = True;
        assert "read-only" in str(e);
    }
    assert raised , "Expected PermissionError for set() on _anchors";

    raised = False;
    try {
        db.insert_one("_anchors", {"data": "value"});
    } except PermissionError as e {
        raised = True;
        assert "read-only" in str(e);
    }
    assert raised , "Expected PermissionError for insert_one() on _anchors";

    raised = False;
    try {
        db.update_one("_anchors", {"_id": "test"}, {"$set": {"data": "new"}});
    } except PermissionError as e {
        raised = True;
        assert "read-only" in str(e);
    }
    assert raised , "Expected PermissionError for update_one() on _anchors";

    raised = False;
    try {
        db.delete_one("_anchors", {"_id": "test"});
    } except PermissionError as e {
        raised = True;
        assert "read-only" in str(e);
    }
    assert raised , "Expected PermissionError for delete_one() on _anchors";

    raised = False;
    try {
        db.delete("test_key", "_anchors");
    } except PermissionError as e {
        raised = True;
        assert "read-only" in str(e);
    }
    assert raised , "Expected PermissionError for delete() on _anchors";

    results = db.find_nodes('SomeNodeType');
    assert isinstance(results, list);

    cleanup_connections();
}
