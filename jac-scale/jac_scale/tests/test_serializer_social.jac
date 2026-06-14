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
import from jaclang.jac0core.archetype { NodeAnchor, EdgeAnchor, ObjectAnchor }

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

# ref_mode tests
obj City {
    has name: str;
}

obj Person {
    has name: str,
        city: City,
        friend: (Person | None) = None;
}

test "ref_mode: shared refs deduplicated, circular graphs terminate, $ref round-trips to live objects" {
    city = City(name="Metropolis");
    alice = Person(name="Alice", city=city);
    bob = Person(name="Bob", city=city);

    # ref_mode=False on non-circular shared refs: both cities fully inlined, no $ref
    off = Serializer.serialize([alice, bob], ref_mode=False);
    assert off[0]["city"]["name"] == "Metropolis"
    and off[1]["city"]["name"] == "Metropolis"
    and "$ref" not in str(off);

    # Now create the cycle
    bob.friend = alice;
    alice.friend = bob;
    city_id = jid(city);
    alice_id = jid(alice);

    # ref_mode=True: shared city → first inline, second $ref; circular friends → $ref breaks cycle
    data = Serializer.serialize(alice, ref_mode=True);
    assert data["name"] == "Alice" and data["city"]["name"] == "Metropolis";
    assert data["friend"]["name"] == "Bob";
    assert data["friend"]["city"] == {"$ref": city_id, "$type": "object"};
    assert data["friend"]["friend"] == {"$ref": alice_id, "$type": "object"};

    # $ref round-trips to live archetype via context memory
    resolved_city = Serializer._deserialize_value(data["friend"]["city"]);
    resolved_alice = Serializer._deserialize_value(data["friend"]["friend"]);
    assert resolved_city.name == "Metropolis" and resolved_alice.name == "Alice";
}

test "ref_mode: mutations reflect inline, identity and $ref stay stable across lifecycle" {
    city = City(name="Metropolis");
    alice = Person(name="Alice", city=city);
    bob = Person(name="Bob", city=city);
    alice.friend = bob;
    bob.friend = alice;
    city_id = jid(city);
    alice_id = jid(alice);

    # Mutate city — inline shows new value, $ref UUID unchanged
    city.name = "Gotham";
    data = Serializer.serialize(alice, ref_mode=True);
    assert data["city"]["name"] == "Gotham"
    and data["friend"]["city"]["$ref"] == city_id;

    # Break cycle — None serializes cleanly
    alice.friend = None;
    data2 = Serializer.serialize(alice, ref_mode=True);
    assert data2["friend"] is None and data2["city"]["name"] == "Gotham";

    # Reassign friend — new object fully inlined with its own city
    alice.friend = Person(name="Carol", city=City(name="Star City"));
    data3 = Serializer.serialize(alice, ref_mode=True);
    assert data3["friend"]["name"] == "Carol"
    and data3["friend"]["city"]["name"] == "Star City";

    # jid() stable through all mutations
    assert jid(city) == city_id and jid(alice) == alice_id;
}

test "ref_mode: unknown $ref falls back to typed anchor stub" {
    ref_id = uuid4();
    # Default type → ObjectAnchor stub
    stub = Serializer._deserialize_value({"$ref": ref_id.hex});
    assert isinstance(stub, ObjectAnchor)
    and stub.id == ref_id
    and not stub.is_populated();
    # $type selects correct anchor class
    assert isinstance(
        Serializer._deserialize_value({"$ref": ref_id.hex, "$type": "node"}), NodeAnchor
    );
    assert isinstance(
        Serializer._deserialize_value({"$ref": ref_id.hex, "$type": "edge"}), EdgeAnchor
    );
    # Invalid $ref → None
    assert Serializer._deserialize_value({"$ref": "not-a-uuid"}) is None;
    # User dict with $ref key + extra keys is NOT treated as a Jac ref
    user_dict = {"$ref": "some-value", "name": "Alice", "count": 42};
    result = Serializer._deserialize_value(user_dict);
    assert isinstance(result, dict)
    and result["$ref"] == "some-value"
    and result["name"] == "Alice"
    and result["count"] == 42;
}
