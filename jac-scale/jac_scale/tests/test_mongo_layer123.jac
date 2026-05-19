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


test "MongoBackend cascade-quarantines edges when their target node is quarantined" {
    # Reproduces the schema-drift scenario from issue #5987:
    # A NodeAnchor of a removed type is quarantined; the connected EdgeAnchors
    # must also be quarantined and stripped from their source node's data.edges.
    container = MongoDbContainer("mongo:latest");
    container.start();
    try {
        uri = container.get_connection_url();
        backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
        client = MongoClient(uri);
        col = client["jac_test_l123"]["_anchors"];
        q_col = client["jac_test_l123"]["_anchors_quarantine"];

        # IDs for the three actors: a "source" node, an edge, and a "Foo" target node.
        source_id = str(uuid4());
        edge_id = str(uuid4());
        foo_id = str(uuid4());

        # Insert the source (live) NodeAnchor that owns the edge.
        col.insert_one(
            {
                '_id': source_id,
                'type': 'NodeAnchor',
                'arch_module': '__main__',
                'arch_type': '_MongoLayer123Person',
                'fingerprint': None,
                'data': {
                    '__type__': 'NodeAnchor',
                    '__module__': 'jaclang.jac0core.archetype',
                    'id': source_id,
                    'persistent': True,
                    'archetype': {
                        '__type__': '_MongoLayer123Person',
                        '__module__': '__main__',
                        'name': 'root',
                        'age': 0
                    },
                    'edges': [edge_id]
                },
                'format_version': 1,
                'updated_at': '2026-05-17T00:00:00'
            }
        );

        # Insert the EdgeAnchor pointing source -> foo (removed type).
        col.insert_one(
            {
                '_id': edge_id,
                'type': 'EdgeAnchor',
                'arch_module': 'jaclang.jac0core.archetype',
                'arch_type': 'GenericEdge',
                'fingerprint': None,
                'data': {
                    '__type__': 'EdgeAnchor',
                    '__module__': 'jaclang.jac0core.archetype',
                    'id': edge_id,
                    'persistent': True,
                    'source': source_id,
                    'target': foo_id,
                    'is_undirected': False,
                    'archetype': {
                        '__type__': 'GenericEdge',
                        '__module__': 'jaclang.jac0core.archetype'
                    }
                },
                'format_version': 1,
                'updated_at': '2026-05-17T00:00:00'
            }
        );

        # Insert the Foo NodeAnchor with an unresolvable archetype type.
        col.insert_one(
            {
                '_id': foo_id,
                'type': 'NodeAnchor',
                'arch_module': 'app',
                'arch_type': 'Foo',
                'fingerprint': None,
                'data': {
                    '__type__': 'NodeAnchor',
                    '__module__': 'jaclang.jac0core.archetype',
                    'id': foo_id,
                    'persistent': True,
                    'archetype': {'__type__': 'Foo', '__module__': 'app', 'x': 1},
                    'edges': []
                },
                'format_version': 1,
                'updated_at': '2026-05-17T00:00:00'
            }
        );

        # Attempting to load the Foo node triggers quarantine (app.Foo unresolvable).
        loaded = backend.get(UUID(foo_id));
        assert loaded is None , "unresolvable Foo must not rehydrate";

        # --- Verify the cascade ---

        # 1. Foo node is in quarantine, not in _anchors.
        assert col.find_one({'_id': foo_id}) is None , "Foo must be removed from _anchors";
        assert q_col.find_one({'_id': foo_id}) is not None , "Foo must be in quarantine";

        # 2. The edge is also in quarantine (no longer in _anchors).
        assert col.find_one({'_id': edge_id}) is None , "orphaned edge must be removed from _anchors";
        q_edge = q_col.find_one({'_id': edge_id});
        assert q_edge is not None , "orphaned edge must be in quarantine";
        assert 'cascade quarantine' in q_edge.get('error', '') , (
            f"edge quarantine error should mention cascade, got: {q_edge.get('error')}"
        );

        # 3. The source node's data.edges no longer references the orphaned edge.
        source_doc = col.find_one({'_id': source_id});
        assert source_doc is not None , "source node must still be live";
        live_edges = source_doc.get('data', {}).get('edges', []);
        assert edge_id not in live_edges , (
            f"source node data.edges should not contain orphaned edge; got: {live_edges}"
        );

        client.close();
        backend.close();
    } finally {
        container.stop();
    }
}


test "MongoBackend recover re-links undirected edge to both endpoints" {
    # Verifies the undirected-edge gap: when an EdgeAnchor with is_undirected=True
    # is recovered from quarantine, the edge ID must be re-added to BOTH the
    # source node's data.edges AND the target node's data.edges.
    container = MongoDbContainer("mongo:latest");
    container.start();
    try {
        uri = container.get_connection_url();
        backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
        client = MongoClient(uri);
        col = client["jac_test_l123"]["_anchors"];
        q_col = client["jac_test_l123"]["_anchors_quarantine"];

        source_id = str(uuid4());
        target_id = str(uuid4());
        edge_id = str(uuid4());

        # Two live nodes whose data.edges are empty (edge was stripped during cascade).
        for (nid, nname) in [(source_id, 'src'), (target_id, 'tgt')] {
            col.insert_one(
                {
                    '_id': nid,
                    'type': 'NodeAnchor',
                    'arch_module': '__main__',
                    'arch_type': '_MongoLayer123Person',
                    'fingerprint': None,
                    'data': {
                        '__type__': 'NodeAnchor',
                        '__module__': 'jaclang.jac0core.archetype',
                        'id': nid,
                        'persistent': True,
                        'archetype': {
                            '__type__': '_MongoLayer123Person',
                            '__module__': '__main__',
                            'name': nname,
                            'age': 0
                        },
                        'edges': []
                    },
                    'format_version': 1,
                    'updated_at': '2026-05-17T00:00:00'
                }
            );
        }

        # Insert the undirected GenericEdge directly into quarantine,
        # simulating a prior cascade-quarantine event.
        q_col.insert_one(
            {
                '_id': edge_id,
                'type': 'EdgeAnchor',
                'arch_module': 'jaclang.jac0core.archetype',
                'arch_type': 'GenericEdge',
                'fingerprint': None,
                'data': {
                    '__type__': 'EdgeAnchor',
                    '__module__': 'jaclang.jac0core.archetype',
                    'id': edge_id,
                    'persistent': True,
                    'source': source_id,
                    'target': target_id,
                    'is_undirected': True,
                    'archetype': {
                        '__type__': 'GenericEdge',
                        '__module__': 'jaclang.jac0core.archetype'
                    }
                },
                'error': 'cascade quarantine: connected node <x> was quarantined',
                'quarantined_at': '2026-05-17T00:00:00',
                'from_format_version': 1
            }
        );

        # Recover the edge — GenericEdge is always resolvable.
        (ok, reason) = backend.recover_one(edge_id);
        assert ok , f"recover_one must succeed for a GenericEdge, got: {reason}";

        # Both endpoints must have the edge ID in their data.edges.
        src_doc = col.find_one({'_id': source_id});
        tgt_doc = col.find_one({'_id': target_id});
        assert src_doc is not None , "source node must still be live";
        assert tgt_doc is not None , "target node must still be live";
        src_edges = src_doc.get('data', {}).get('edges', []);
        tgt_edges = tgt_doc.get('data', {}).get('edges', []);
        assert edge_id in src_edges , (
            f"source data.edges must contain the recovered edge; got: {src_edges}"
        );
        assert edge_id in tgt_edges , (
            f"target data.edges must contain the recovered undirected edge; got: {tgt_edges}"
        );

        client.close();
        backend.close();
    } finally {
        container.stop();
    }
}
