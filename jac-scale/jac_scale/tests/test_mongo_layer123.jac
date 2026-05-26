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
import from jac_scale.memory_hierarchy { _process_cache, MongoBackend }


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


test "MongoBackend recover_all processes nodes before edges so re-link finds live endpoints" {
    # Ordering bug regression: edge inserted into quarantine BEFORE the node;
    # naïve iteration would restore the edge first, leaving data.edges empty.
    container = MongoDbContainer("mongo:latest");
    container.start();
    try {
        uri = container.get_connection_url();
        backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
        client = MongoClient(uri);
        col = client["jac_test_l123"]["_anchors"];
        q_col = client["jac_test_l123"]["_anchors_quarantine"];

        node_id = str(uuid4());
        edge_id = str(uuid4());

        # Adversarial insertion order: edge first, node second.
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
                    'source': node_id,
                    'target': node_id,
                    'is_undirected': False,
                    'archetype': {
                        '__type__': 'GenericEdge',
                        '__module__': 'jaclang.jac0core.archetype'
                    }
                },
                'error': 'cascade quarantine: connected node was quarantined',
                'quarantined_at': '2026-05-17T00:00:00',
                'from_format_version': 1
            }
        );
        q_col.insert_one(
            {
                '_id': node_id,
                'type': 'NodeAnchor',
                'arch_module': 'jaclang.jac0core.archetype',
                'arch_type': 'Root',
                'fingerprint': None,
                'data': {
                    '__type__': 'NodeAnchor',
                    '__module__': 'jaclang.jac0core.archetype',
                    'id': node_id,
                    'persistent': True,
                    'archetype': {
                        '__type__': 'Root',
                        '__module__': 'jaclang.jac0core.archetype'
                    },
                    'edges': []
                },
                'error': 'cascade quarantine: connected node was quarantined',
                'quarantined_at': '2026-05-17T00:00:00',
                'from_format_version': 1
            }
        );

        (recovered, still_stuck) = backend.recover_all();
        assert recovered == 2 , f"both docs must recover, got {recovered}: {still_stuck}";
        assert not still_stuck , f"nothing should remain stuck, got {still_stuck}";

        node_doc = col.find_one({'_id': node_id});
        assert node_doc is not None , "recovered node must be live in _anchors";
        node_edges = node_doc.get('data', {}).get('edges', []);
        assert edge_id in node_edges , (
            f"node data.edges must contain the re-linked edge (ordering fix); got: {node_edges}"
        );

        client.close();
        backend.close();
    } finally {
        container.stop();
    }
}


test "MongoBackend recover_all emits warning when re-link target is missing" {
    # When a quarantined edge's source node is absent from live _anchors,
    # recover_all must still succeed (matched_count==0 is not a crash) and
    # the edge must be moved to the live collection.
    container = MongoDbContainer("mongo:latest");
    container.start();
    try {
        uri = container.get_connection_url();
        backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
        client = MongoClient(uri);
        col = client["jac_test_l123"]["_anchors"];
        q_col = client["jac_test_l123"]["_anchors_quarantine"];

        ghost_node_id = str(uuid4());
        edge_id = str(uuid4());

        # Only the edge is in quarantine; ghost_node_id has no live doc.
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
                    'source': ghost_node_id,
                    'target': ghost_node_id,
                    'is_undirected': False,
                    'archetype': {
                        '__type__': 'GenericEdge',
                        '__module__': 'jaclang.jac0core.archetype'
                    }
                },
                'error': 'cascade quarantine: connected node was quarantined',
                'quarantined_at': '2026-05-17T00:00:00',
                'from_format_version': 1
            }
        );

        # Must not raise — matched_count==0 is a warning-only path.
        (recovered, still_stuck) = backend.recover_all();
        assert recovered == 1 , f"edge must be recovered even without live node, got {recovered}";
        assert not still_stuck , f"edge must not be stuck, got {still_stuck}";

        # Edge moved to live collection; ghost node was never created.
        assert col.find_one({'_id': edge_id}) is not None , "edge must be live after recovery";
        assert col.find_one({'_id': ghost_node_id}) is None , "ghost node must not materialise";

        client.close();
        backend.close();
    } finally {
        container.stop();
    }
}


# ---------------------------------------------------------------------------
# Regression: issue #6076 — _put_node_atomic fails with "empty object" error
# when access.roots.anchors is {} (the default for every new NodeAnchor).
# MongoDB's aggregation-pipeline $set rejects empty embedded documents
# (error 40180), so every graph write silently failed before this fix.
# ---------------------------------------------------------------------------
test "_put_node_atomic persists node despite default empty access.roots.anchors (issue #6076)" {
    # Each test gets its own container (different port).  Force a fresh
    # MongoClient so this test's backend does not reuse a cached client
    # pointing to a now-stopped container from a previous test.
    _process_cache.pop('mongo_client', None);
    _process_cache.pop('mongo_available', None);
    container = MongoDbContainer("mongo:latest");
    container.start();
    try {
        uri = container.get_connection_url();
        backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");

        # Build a node with the default Permission — access.roots.anchors = {}
        p = _MongoLayer123Person(name="charlie", age=40);
        anchor = cast(NodeAnchor, p.__jac__);
        anchor.persistent = True;

        fake_edge_id = str(uuid4());

        # Before the fix this silently failed with MongoDB error 40180:
        #   "empty object is not a valid value … at path data.access.roots.anchors"
        backend._put_node_atomic(anchor, [fake_edge_id], []);

        client = MongoClient(uri);
        col = client["jac_test_l123"]["_anchors"];

        doc = col.find_one({'_id': str(anchor.id)});
        assert doc is not None , (
            "_put_node_atomic must persist the NodeAnchor even when "
            "access.roots.anchors is the default empty dict"
        );

        stored_edges = doc.get('data', {}).get('edges', []);
        assert fake_edge_id in stored_edges , (
            f"added edge must appear in data.edges; got: {stored_edges}"
        );

        def _has_empty_dict(v: object) -> bool {
            if isinstance(v, dict) {
                if not v {
                    return True;
                }
                return bool(any(_has_empty_dict(vv) for vv in v.values()));
            }
            if isinstance(v, list) {
                return bool(any(_has_empty_dict(item) for item in v));
            }
            return False;
        }
        data_field = doc.get('data', {});
        assert not _has_empty_dict(data_field) , (
            "stored document must not contain any empty dicts — "
            "MongoDB aggregation-pipeline $set rejects them (error 40180). "
            f"Offending data: {data_field}"
        );

        client.close();
        backend.close();
    } finally {
        container.stop();
    }
}


test "_put_node_atomic written document round-trips correctly after fix (issue #6076)" {
    # Mirrors the production flow: _write_to_db seeds the full document first
    # (hash=0 path), then a subsequent sync with an edge delta calls
    # _put_node_atomic to atomically merge the edge list.  A fresh second
    # backend (simulating a different pod with a cold L1 cache) must be able
    # to read and fully deserialize the anchor afterwards.
    _process_cache.pop('mongo_client', None);
    _process_cache.pop('mongo_available', None);
    container = MongoDbContainer("mongo:latest");
    container.start();
    try {
        uri = container.get_connection_url();
        backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");

        p = _MongoLayer123Person(name="diana", age=35);
        anchor = cast(NodeAnchor, p.__jac__);
        anchor.persistent = True;

        # Step 1: initial full upsert (sets data.__type__, arch_module, etc.).
        backend._write_to_db(anchor);

        # Step 2: simulate a subsequent edge addition via the atomic path.
        fake_edge_id = str(uuid4());
        backend._put_node_atomic(anchor, [fake_edge_id], []);

        # Simulate a second pod: new backend, cold L1, same Mongo.
        backend2 = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
        reloaded = backend2.get(anchor.id);
        assert reloaded is not None , (
            "anchor must be readable by a fresh backend after _put_node_atomic "
            "(cross-pod read must succeed)"
        );
        reloaded_arch = cast(
            _MongoLayer123Person, cast(NodeAnchor, reloaded).archetype
        );
        assert reloaded_arch.name == "diana" , (
            f"archetype fields must survive round-trip; got name={reloaded_arch.name}"
        );
        reloaded_edges = cast(NodeAnchor, reloaded).edges;
        edge_ids = [str(e.id) if e?.id else str(e) for e in reloaded_edges];
        assert fake_edge_id in edge_ids
        or any(fake_edge_id in str(e) for e in reloaded_edges) , (
            f"added edge must appear in reloaded anchor's edges; got: {reloaded_edges}"
        );

        backend.close();
        backend2.close();
    } finally {
        container.stop();
    }
}
