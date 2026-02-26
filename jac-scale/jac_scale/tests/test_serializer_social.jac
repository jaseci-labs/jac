"""Test serialization and persistence of social graph nodes."""
import contextlib;
import os;
import from jaclang.runtimelib.serializer { Serializer }
import from jac_scale.tests.fixtures.social_graph { User, Post, BuildGraph, QueryGraph }
import from jac_scale.lib { kvstore }
import from jac_scale.db { close_all_db_connections }
import from jac_scale.config_loader { reset_scale_config }
import from testcontainers.mongodb { MongoDbContainer }

def cleanup_connections {
    with contextlib.suppress(Exception) {
        close_all_db_connections();
    }
}

glob _mongo_container = MongoDbContainer("mongo:7.0"),
     MONGO_URI: str = "";

with entry {
    _mongo_container.start();
}

glob MONGO_URI = _mongo_container.get_connection_url();

# Set environment variable so ScaleTieredMemory uses the testcontainer's MongoDB
with entry {
    os.environ['MONGODB_URI'] = MONGO_URI;
    reset_scale_config();  # Reset config cache to pick up the new env var
}

test "serialize user node" {
    u = User(name="Alice", role="admin", age=30);
    serialized = Serializer.serialize(u, include_type=True);
    deserialized = Serializer.deserialize(serialized);
    assert deserialized.name == "Alice"
    and deserialized.role == "admin"
    and deserialized.age == 30;
    assert type(deserialized) == User;
}

test "serialize post node" {
    p = Post(title="Hello", content="World");
    serialized = Serializer.serialize(p, include_type=True);
    deserialized = Serializer.deserialize(serialized);
    assert deserialized.title == "Hello" and deserialized.content == "World";
    assert type(deserialized) == Post;
}

test "find_nodes queries persisted graph with BuildGraph" {
    # Clean up any leftover connections from previous tests
    cleanup_connections();

    db = kvstore(db_name='jac_db', db_type='mongodb', uri=MONGO_URI);

    # Drop collection to ensure clean state before test
    db._get_mongo_collection('_anchors').drop();

    graph = BuildGraph() spawn root;

    # Query using the QueryGraph walker
    result = QueryGraph(mongo_uri=MONGO_URI) spawn root;
    report_data = result.reports[0];

    young = report_data['young'];
    admins = report_data['admins'];
    posts = report_data['posts'];

    # Verify counts and data
    assert len(young) == 1 and young[0].name == 'Bob' and young[0].age == 25;
    assert len(admins) == 1 and admins[0].name == 'Alice' and admins[0].role == 'admin';
    assert len(posts) == 3;

    # Cleanup
    db._get_mongo_collection('_anchors').drop();
    cleanup_connections();
}
