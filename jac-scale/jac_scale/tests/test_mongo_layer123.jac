"""Integration tests for MongoBackend Layer 1+2+3 parity.

These tests start a real MongoDB container (via testcontainers) and
exercise the same fingerprint / quarantine / alias / recover surface
that SqliteMemory exposes, via the abstract PersistentMemory interface.

Locally they require Docker; in CI they run against a throwaway Mongo
instance. Skipped automatically if Docker is unavailable.
"""

import os;
import from typing { cast }
import from uuid { uuid4, UUID }
import from pymongo { MongoClient }
import from testcontainers.mongodb { MongoDbContainer }

import from jaclang.jac0core.archetype { Anchor, NodeAnchor, Root, NodeArchetype }
import from jaclang.runtimelib.serializer { Serializer }
import from jaclang.runtimelib.topology_index { TopologyIndex }
import from jac_scale.memory_hierarchy { MongoBackend }


obj _MongoLayer123Person(Root) {
    has name: str = "",
        age: int = 0;
}


test "MongoBackend stamps fingerprint + archetype identity on put" {
    container = MongoDbContainer("mongo:latest");
    container.start();
    try {
        uri = container.get_connection_url();
        backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
        p = _MongoLayer123Person(name="alice", age=30);
        anchor = p.__jac__;
        anchor.persistent = True;
        backend.put(anchor);
        # Read the raw doc and verify it carries the Layer 1+2 metadata.
        client = MongoClient(uri);
        doc = client["jac_test_l123"]["_anchors"].find_one({'_id': str(anchor.id)});
        assert doc is not None;
        assert doc.get('arch_module');
        assert doc.get('arch_type') == '_MongoLayer123Person';
        assert doc.get('fingerprint');
        assert doc.get('format_version') == 1;
        assert doc.get('updated_at');
        client.close();
        backend.close();
    } finally {
        container.stop();
    }
}


test "MongoBackend quarantines un-deserializable documents instead of dropping" {
    container = MongoDbContainer("mongo:latest");
    container.start();
    try {
        uri = container.get_connection_url();
        backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
        # Insert a corrupt doc directly — data refers to an unregistered class.
        bad_id = str(uuid4());
        backend.collection.insert_one(
            {
                '_id': bad_id,
                'type': 'NodeAnchor',
                'arch_module': 'nowhere',
                'arch_type': 'Missing',
                'fingerprint': 'deadbeef01234567',
                'data': {
                    '__type__': 'NodeAnchor',
                    '__module__': 'jaclang.jac0core.archetype',
                    'id': bad_id,
                    'persistent': True,
                    'archetype': {'__type__': 'Missing', '__module__': 'nowhere'},
                    'edges': []
                },
                'format_version': 1,
                'updated_at': '2026-04-14T00:00:00'
            }
        );
        loaded = backend.get(UUID(bad_id));
        assert loaded is None , "unresolvable class must not rehydrate";
        # Moved to quarantine, removed from main collection.
        client = MongoClient(uri);
        q = client["jac_test_l123"]["_anchors_quarantine"];
        quarantined_doc = q.find_one({'_id': bad_id});
        assert quarantined_doc is not None;
        assert quarantined_doc.get('arch_type') == 'Missing';
        assert quarantined_doc.get('error');
        main = client["jac_test_l123"]["_anchors"];
        assert main.find_one({'_id': bad_id}) is None;
        client.close();
        backend.close();
    } finally {
        container.stop();
    }
}


test "MongoBackend alias add/list/remove round-trip + recover_all works" {
    container = MongoDbContainer("mongo:latest");
    container.start();
    try {
        uri = container.get_connection_url();
        backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
        # Seed the quarantine with one row that references a fake legacy class.
        seed_id = str(uuid4());
        backend.collection.insert_one(
            {
                '_id': seed_id,
                'type': 'NodeAnchor',
                'arch_module': '__main__',
                'arch_type': 'LegacyPerson',
                'fingerprint': '5c76fe17abcdef01',
                'data': {
                    '__type__': 'NodeAnchor',
                    '__module__': 'jaclang.jac0core.archetype',
                    'id': seed_id,
                    'persistent': True,
                    'archetype': {
                        '__type__': 'LegacyPerson',
                        '__module__': '__main__',
                        'name': 'alice',
                        'age': 30
                    },
                    'edges': []
                },
                'format_version': 1,
                'updated_at': '2026-04-14T00:00:00'
            }
        );
        # Loading moves it to quarantine (LegacyPerson isn't registered).
        assert backend.get(UUID(seed_id)) is None;
        # Before alias: still un-recoverable.
        (raw_rec, raw_still) = backend.recover_all();
        recovered = cast(int, raw_rec);
        still = cast(list, raw_still);
        assert recovered == 0;
        assert len(still) == 1;
        # alias list empty.
        assert backend.list_aliases() == [];
        # Register a rescue alias that points LegacyPerson at our test class,
        # whose fields match the stored payload.
        live_mod = getattr(_MongoLayer123Person, '__module__');
        live_name = getattr(_MongoLayer123Person, '__name__');
        live_key = f"{live_mod}.{live_name}";
        backend.add_alias("__main__.LegacyPerson", live_key);
        aliases = backend.list_aliases();
        assert len(aliases) == 1;
        assert aliases[0].get('old_name') == '__main__.LegacyPerson';
        # Now recovery should succeed.
        (raw_rec, raw_still) = backend.recover_all();
        recovered = cast(int, raw_rec);
        still = cast(list, raw_still);
        assert recovered == 1 , f"expected 1 recovered, got {recovered}, {still}";
        assert still == [];
        # Inspect shows the recovered row, now stamped as the live class.
        summary = backend.inspect_summary();
        assert summary.get('quarantine_total') == 0;
        assert summary.get('anchors_total') >= 1;
        # Remove alias round-trip.
        removed = backend.remove_alias("__main__.LegacyPerson");
        assert removed is True;
        assert backend.list_aliases() == [];
        backend.close();
    } finally {
        container.stop();
    }
}


test "MongoBackend inspect_summary shape matches SqliteMemory's" {
    container = MongoDbContainer("mongo:latest");
    container.start();
    try {
        uri = container.get_connection_url();
        backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
        s = backend.inspect_summary();
        for key in [
            'format_version',
            'anchors_total',
            'anchors_by_type',
            'quarantine_total',
            'quarantine_by_type',
            'aliases_total',
            'location'
        ] {
            assert key in s , f"missing key in summary: {key}";
        }
        backend.close();
    } finally {
        container.stop();
    }
}


test "MongoBackend topology-only update persisted when hash unchanged" {
    container = MongoDbContainer("mongo:latest");
    container.start();
    try {
        uri = container.get_connection_url();
        backend = MongoBackend(mongo_url=uri, db_name="jac_topo_test");

        r = Root();
        root_anchor = r.__jac__;
        root_anchor.persistent = True;
        idx1 = TopologyIndex();
        idx1.add_node(root_anchor.id, "Root");
        n1 = uuid4();
        idx1.add_node(n1, "UserProfile");
        idx1.add_edge(root_anchor.id, n1, "default");
        root_anchor.set_topology_index(idx1);
        root_anchor.is_topology_dirty = False;
        backend._write_to_db(root_anchor);

        idx2 = root_anchor.get_topology_index();
        n2 = uuid4();
        idx2.add_node(n2, "Project");
        idx2.add_edge(root_anchor.id, n2, "default");
        root_anchor.set_topology_index(idx2);
        assert root_anchor.is_topology_dirty is True , "set_topology_index must raise flag";

        current_hash = Serializer._compute_hash(root_anchor);
        assert current_hash == root_anchor.hash , (
            "precondition: hash must be unchanged after topology-only update"
        );

        would_skip = (current_hash == root_anchor.hash)
        and not root_anchor.is_topology_dirty;
        assert not would_skip , "topology_dirty=True must prevent the hash early-out skip";

        backend._write_to_db(root_anchor);
        assert root_anchor.is_topology_dirty is False , "flag must clear after _write_to_db";

        final = backend.get(root_anchor.id);
        assert final is not None and isinstance(final, NodeAnchor);
        final_node: NodeAnchor = final;
        final_idx = final_node.get_topology_index();
        type_names = set(final_idx.type_table);
        assert "Project" in type_names , f"Project type lost — only found: {type_names}";
        assert "UserProfile" in type_names , "UserProfile type unexpectedly missing";

        backend.close();
    } finally {
        container.stop();
    }
}


test "MongoBackend _put_node_atomic resets is_topology_dirty on success" {
    container = MongoDbContainer("mongo:latest");
    container.start();
    try {
        uri = container.get_connection_url();
        backend = MongoBackend(mongo_url=uri, db_name="jac_topo_atomic_test");

        r = Root();
        root_anchor = r.__jac__;
        root_anchor.persistent = True;

        backend._write_to_db(root_anchor);

        idx = TopologyIndex();
        idx.add_node(root_anchor.id, "Root");
        root_anchor.set_topology_index(idx);
        assert root_anchor.is_topology_dirty is True;

        backend._put_node_atomic(root_anchor, [], []);
        assert root_anchor.is_topology_dirty is False , (
            "is_topology_dirty must be cleared inside _put_node_atomic on success"
        );

        loaded = backend.get(root_anchor.id);
        assert loaded is not None and isinstance(loaded, NodeAnchor);
        loaded_node: NodeAnchor = loaded;
        loaded_idx = loaded_node.get_topology_index();
        assert "Root" in set(loaded_idx.type_table) , "topology not persisted by _put_node_atomic";

        backend.close();
    } finally {
        container.stop();
    }
}
