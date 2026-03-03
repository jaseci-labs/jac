"""Test serialization and persistence of social graph nodes."""
import contextlib;
import os;
import from jaclang.runtimelib.serializer { Serializer }
import from jac_scale.tests.fixtures.social_graph { User, Post, BuildGraph, QueryGraph }
import from jac_scale.lib { kvstore }
import from jac_scale.db { close_all_db_connections }
import from jac_scale.config_loader { reset_scale_config }
import from testcontainers.mongodb { MongoDbContainer }
import from uuid { uuid4 }
import from jaclang.jac0core.archetype { NodeAnchor, EdgeAnchor }

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

test "_id_to_stub creates valid stubs" {
    # NodeAnchor stub
    node_id = uuid4();
    node_stub = Serializer._id_to_stub(NodeAnchor, str(node_id));
    assert node_stub.id == node_id and not node_stub.is_populated();

    # EdgeAnchor stub
    edge_id = uuid4();
    edge_stub = Serializer._id_to_stub(EdgeAnchor, str(edge_id));
    assert edge_stub.id == edge_id and not edge_stub.is_populated();

    # Invalid UUID returns None
    assert Serializer._id_to_stub(NodeAnchor, "bad-uuid") is None;
}

test "NodeAnchor edges restored as lazy stubs" {
    edge_ids = [uuid4(), uuid4(), uuid4()];
    anchor = Serializer._deserialize_anchor(
        {
            '__type__': 'NodeAnchor',
            'id': str(uuid4()),
            'root': str(uuid4()),
            'edges': [str(e) for e in edge_ids]
        }
    );
    assert len(anchor.edges) == 3;
    for (i, edge) in enumerate(anchor.edges) {
        assert edge.id == edge_ids[i] and not edge.is_populated();
    }
}

test "EdgeAnchor source/target restored as lazy stubs" {
    src_id = uuid4();
    tgt_id = uuid4();
    anchor = Serializer._deserialize_anchor(
        {
            '__type__': 'EdgeAnchor',
            'id': str(uuid4()),
            'source': str(src_id),
            'target': str(tgt_id)
        }
    );
    assert anchor.source.id == src_id and not anchor.source.is_populated();
    assert anchor.target.id == tgt_id and not anchor.target.is_populated();
}
