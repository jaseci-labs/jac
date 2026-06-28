import atexit;
import json;
import os;
import redis;
import from typing { cast }
import from uuid { uuid4, UUID }
import from pymongo { MongoClient }
import from testcontainers.mongodb { MongoDbContainer }
import from testcontainers.redis { RedisContainer }

import from jaclang.jac0core.archetype {
    Anchor,
    EdgeAnchor,
    GenericEdge,
    NodeAnchor,
    Root,
    NodeArchetype
}
import from jaclang.runtimelib.serializer { Serializer }
import from jac_scale.memory.memory_hierarchy {
    _process_cache,
    MongoBackend,
    ScaleTieredMemory
}

glob _shared: dict = {};


obj _MongoLayer123Person(Root) {
    has name: str = "",
        age: int = 0;
}

obj _MongoRequiredField(Root) {
    has name: str;
}

obj _MongoEmptyDictNode(Root) {
    has label: str = "",
        settings: dict = {},
        metadata: dict = {};
}

def _get_mongo -> tuple {
    if "mongo_client" not in _shared {
        container = MongoDbContainer("mongo:latest");
        container.start();
        uri = container.get_connection_url();
        _shared["mongo_container"] = container;
        _shared["mongo_uri"] = uri;
        _shared["mongo_client"] = MongoClient(uri);
        atexit.register(container.stop);
    }
    return (_shared["mongo_client"], _shared["mongo_uri"]);
}


def _reset_mongo -> None {
    if "mongo_client" not in _shared {
        return;
    }
    system_dbs = {"admin", "config", "local"};
    for db_name in _shared["mongo_client"].list_database_names() {
        if db_name not in system_dbs {
            _shared["mongo_client"].drop_database(db_name);
        }
    }
}


def _get_redis -> tuple {
    if "redis_client" not in _shared {
        container = RedisContainer("redis:latest", port=6379);
        container.start();
        host = container.get_container_host_ip();
        exposed_port = container.get_exposed_port(6379);
        redis_url = f"redis://{host}:{exposed_port}/0";
        _shared["redis_container"] = container;
        _shared["redis_url"] = redis_url;
        _shared["redis_client"] = redis.Redis(
            host=host, port=int(exposed_port), decode_responses=False
        );
        atexit.register(container.stop);
    }
    return (_shared["redis_client"], _shared["redis_url"]);
}


def _reset_redis {
    if "redis_client" in _shared {
        _shared["redis_client"].flushall();
    }
}


test "MongoBackend stamps fingerprint + archetype identity on write" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
    person_node = _MongoLayer123Person(name="alice", age=30);
    anchor = person_node.__jac__;
    anchor.persistent = True;
    backend._write_to_db(anchor);
    doc = client["jac_test_l123"]["_anchors"].find_one({'_id': str(anchor.id)});
    assert doc is not None;
    assert doc.get('arch_module');
    assert doc.get('arch_type') == '_MongoLayer123Person';
    assert doc.get('fingerprint');
    assert doc.get('format_version') == 1;
    assert doc.get('updated_at');
    backend.close();
}


test "MongoBackend quarantines un-deserializable documents instead of dropping" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
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
    quarantine_col = client["jac_test_l123"]["_anchors_quarantine"];
    quarantined_doc = quarantine_col.find_one({'_id': bad_id});
    assert quarantined_doc is not None;
    assert quarantined_doc.get('arch_type') == 'Missing';
    assert quarantined_doc.get('error');
    anchors_col = client["jac_test_l123"]["_anchors"];
    assert anchors_col.find_one({'_id': bad_id}) is None;
    backend.close();
}


test "MongoBackend recovers null field to class default and loads anchor normally" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
    arch_mod = getattr(_MongoLayer123Person, '__module__');
    bad_id = str(uuid4());
    backend.collection.insert_one(
        {
            '_id': bad_id,
            'type': 'NodeAnchor',
            'arch_module': arch_mod,
            'arch_type': '_MongoLayer123Person',
            'fingerprint': None,
            'data': {
                '__type__': 'NodeAnchor',
                '__module__': 'jaclang.jac0core.archetype',
                'id': bad_id,
                'persistent': True,
                'archetype': {
                    '__type__': '_MongoLayer123Person',
                    '__module__': arch_mod,
                    'name': None,
                    'age': 0
                },
                'edges': []
            },
            'format_version': 1,
            'updated_at': '2026-05-26T00:00:00'
        }
    );
    loaded = backend.get(UUID(bad_id));
    assert loaded is not None , "anchor with null field must load after fix";
    arch = cast(_MongoLayer123Person, cast(NodeAnchor, loaded).archetype);
    assert arch.name == "" , (
        f"null field must be restored to class default ''; got '{arch.name}'"
    );
    quarantine_col = client["jac_test_l123"]["_anchors_quarantine"];
    assert quarantine_col.find_one({'_id': bad_id}) is None , "recovered anchor must NOT be quarantined";
    backend.close();
}


test "MongoBackend quarantine reason identifies field failure not class unresolvable" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
    arch_mod = getattr(_MongoRequiredField, '__module__');
    bad_id = str(uuid4());
    backend.collection.insert_one(
        {
            '_id': bad_id,
            'type': 'NodeAnchor',
            'arch_module': arch_mod,
            'arch_type': '_MongoRequiredField',
            'fingerprint': None,
            'data': {
                '__type__': 'NodeAnchor',
                '__module__': 'jaclang.jac0core.archetype',
                'id': bad_id,
                'persistent': True,
                'archetype': {
                    '__type__': '_MongoRequiredField',
                    '__module__': arch_mod,
                    'name': None
                },
                'edges': []
            },
            'format_version': 1,
            'updated_at': '2026-05-26T00:00:00'
        }
    );
    loaded = backend.get(UUID(bad_id));
    assert loaded is None , "anchor with no-default null field must be quarantined";
    quarantine_col = client["jac_test_l123"]["_anchors_quarantine"];
    q_doc = cast(dict, quarantine_col.find_one({'_id': bad_id}));
    assert q_doc is not None , "anchor must be in quarantine";
    reason = cast(str, q_doc.get('error', ''));
    assert "archetype field deserialization failed" in reason , (
        f"reason must identify field failure, not class-unresolvable; got: '{reason}'"
    );
    backend.close();
}


test "MongoBackend alias add/list/remove round-trip + recover_all works" {
    _reset_mongo();
    (_, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
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
    assert backend.get(UUID(seed_id)) is None;
    (raw_rec, raw_still) = backend.recover_all();
    recovered = cast(int, raw_rec);
    still = cast(list, raw_still);
    assert recovered == 0;
    assert len(still) == 1;
    assert backend.list_aliases() == [];
    live_mod = getattr(_MongoLayer123Person, '__module__');
    live_name = getattr(_MongoLayer123Person, '__name__');
    live_key = f"{live_mod}.{live_name}";
    backend.add_alias("__main__.LegacyPerson", live_key);
    aliases = backend.list_aliases();
    assert len(aliases) == 1;
    assert aliases[0].get('old_name') == '__main__.LegacyPerson';
    (raw_rec, raw_still) = backend.recover_all();
    recovered = cast(int, raw_rec);
    still = cast(list, raw_still);
    assert recovered == 1 , f"expected 1 recovered, got {recovered}, {still}";
    assert still == [];
    summary = backend.inspect_summary();
    assert summary.get('quarantine_total') == 0;
    assert summary.get('anchors_total') >= 1;
    removed = backend.remove_alias("__main__.LegacyPerson");
    assert removed is True;
    assert backend.list_aliases() == [];
    backend.close();
}


test "MongoBackend inspect_summary shape matches SqliteMemory's" {
    _reset_mongo();
    (_, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
    summary = backend.inspect_summary();
    for key in [
        'format_version',
        'anchors_total',
        'anchors_by_type',
        'quarantine_total',
        'quarantine_by_type',
        'aliases_total',
        'location'
    ] {
        assert key in summary , f"missing key in summary: {key}";
    }
    backend.close();
}


test "MongoBackend cascade-quarantines edges when their target node is quarantined" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
    anchors_col = client["jac_test_l123"]["_anchors"];
    quarantine_col = client["jac_test_l123"]["_anchors_quarantine"];

    source_id = str(uuid4());
    edge_id = str(uuid4());
    foo_id = str(uuid4());

    anchors_col.insert_one(
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

    anchors_col.insert_one(
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

    anchors_col.insert_one(
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

    loaded = backend.get(UUID(foo_id));
    assert loaded is None , "unresolvable Foo must not rehydrate";

    assert anchors_col.find_one({'_id': foo_id}) is None , "Foo must be removed from _anchors";
    assert quarantine_col.find_one({'_id': foo_id}) is not None , "Foo must be in quarantine";

    assert anchors_col.find_one({'_id': edge_id}) is None , "orphaned edge must be removed from _anchors";
    q_edge = quarantine_col.find_one({'_id': edge_id});
    assert q_edge is not None , "orphaned edge must be in quarantine";
    assert 'cascade quarantine' in q_edge.get('error', '') , (
        f"edge quarantine error should mention cascade, got: {q_edge.get('error')}"
    );

    source_doc = anchors_col.find_one({'_id': source_id});
    assert source_doc is not None , "source node must still be live";
    live_edges = source_doc.get('data', {}).get('edges', []);
    assert edge_id not in live_edges , (
        f"source node data.edges should not contain orphaned edge; got: {live_edges}"
    );

    backend.close();
}


test "MongoBackend recover re-links undirected edge to both endpoints" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
    anchors_col = client["jac_test_l123"]["_anchors"];
    quarantine_col = client["jac_test_l123"]["_anchors_quarantine"];

    source_id = str(uuid4());
    target_id = str(uuid4());
    edge_id = str(uuid4());

    for (nid, nname) in [(source_id, 'src'), (target_id, 'tgt')] {
        anchors_col.insert_one(
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

    quarantine_col.insert_one(
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

    (ok, reason) = backend.recover_one(edge_id);
    assert ok , f"recover_one must succeed for a GenericEdge, got: {reason}";

    src_doc = anchors_col.find_one({'_id': source_id});
    tgt_doc = anchors_col.find_one({'_id': target_id});
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

    backend.close();
}


test "MongoBackend recover_all processes nodes before edges so re-link finds live endpoints" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
    anchors_col = client["jac_test_l123"]["_anchors"];
    quarantine_col = client["jac_test_l123"]["_anchors_quarantine"];

    node_id = str(uuid4());
    edge_id = str(uuid4());

    quarantine_col.insert_one(
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
    quarantine_col.insert_one(
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

    node_doc = anchors_col.find_one({'_id': node_id});
    assert node_doc is not None , "recovered node must be live in _anchors";
    node_edges = node_doc.get('data', {}).get('edges', []);
    assert edge_id in node_edges , (
        f"node data.edges must contain the re-linked edge (ordering fix); got: {node_edges}"
    );

    backend.close();
}


test "MongoBackend recover_all emits warning when re-link target is missing" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
    anchors_col = client["jac_test_l123"]["_anchors"];
    quarantine_col = client["jac_test_l123"]["_anchors_quarantine"];

    ghost_node_id = str(uuid4());
    edge_id = str(uuid4());

    quarantine_col.insert_one(
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

    (recovered, still_stuck) = backend.recover_all();
    assert recovered == 1 , f"edge must be recovered even without live node, got {recovered}";
    assert not still_stuck , f"edge must not be stuck, got {still_stuck}";

    assert anchors_col.find_one({'_id': edge_id}) is not None , "edge must be live after recovery";
    assert anchors_col.find_one({'_id': ghost_node_id}) is None , "ghost node must not materialise";

    backend.close();
}


test "_put_node_atomic persists node despite default empty access.roots.anchors (issue #6076)" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");

    person_node = _MongoLayer123Person(name="charlie", age=40);
    anchor = cast(NodeAnchor, person_node.__jac__);
    anchor.persistent = True;

    fake_edge_id = str(uuid4());

    backend._put_node_atomic(anchor, [fake_edge_id], [], set());

    anchors_col = client["jac_test_l123"]["_anchors"];

    doc = anchors_col.find_one({'_id': str(anchor.id)});
    assert doc is not None , (
        "_put_node_atomic must persist the NodeAnchor even when "
        "access.roots.anchors is the default empty dict"
    );

    stored_edges = doc.get('data', {}).get('edges', []);
    assert fake_edge_id in stored_edges , (
        f"added edge must appear in data.edges; got: {stored_edges}"
    );

    stored_access = doc.get('data', {}).get('access');
    assert stored_access is not None , (
        "access (which carries the default empty roots.anchors dict) must be "
        f"persisted through the atomic pipeline $set; got data: {doc.get('data', {})}"
    );

    backend.close();
}


test "_put_node_atomic written document round-trips correctly after fix (issue #6076)" {
    _reset_mongo();
    (_, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");

    person_node = _MongoLayer123Person(name="diana", age=35);
    anchor = cast(NodeAnchor, person_node.__jac__);
    anchor.persistent = True;

    backend._write_to_db(anchor);

    fake_edge_id = str(uuid4());
    backend._put_node_atomic(anchor, [fake_edge_id], [], set());

    backend2 = MongoBackend(mongo_url=uri, db_name="jac_test_l123");
    reloaded = backend2.get(anchor.id);
    assert reloaded is not None , (
        "anchor must be readable by a fresh backend after _put_node_atomic "
        "(cross-pod read must succeed)"
    );
    reloaded_arch = cast(_MongoLayer123Person, cast(NodeAnchor, reloaded).archetype);
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
}


test "data.edges preserves insertion order on atomic add (issue #6785)" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");

    person_node = _MongoLayer123Person(name="seq", age=1);
    anchor = cast(NodeAnchor, person_node.__jac__);
    anchor.persistent = True;
    backend._write_to_db(anchor);

    edge_ids = [str(UUID(int=200 - i)) for i in range(10)];
    backend._put_node_atomic(anchor, edge_ids, [], set());

    doc = client["jac_test_l123"]["_anchors"].find_one({'_id': str(anchor.id)});
    assert doc is not None;
    stored = doc.get('data', {}).get('edges', []);
    assert stored == edge_ids , (
        "out-edges must persist in connection (insertion) order; "
        f"expected {edge_ids}, got {stored}"
    );

    backend.close();
}


test "data.edges preserves order when a middle edge is removed (issue #6785)" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");

    person_node = _MongoLayer123Person(name="seq2", age=2);
    anchor = cast(NodeAnchor, person_node.__jac__);
    anchor.persistent = True;
    backend._write_to_db(anchor);

    edge_ids = [str(UUID(int=200 - i)) for i in range(10)];
    backend._put_node_atomic(anchor, edge_ids, [], set());

    removed = edge_ids[4];
    expected = [
        e
        for e in edge_ids
        if e != removed
    ];
    backend._put_node_atomic(anchor, [], [removed], set());

    doc = client["jac_test_l123"]["_anchors"].find_one({'_id': str(anchor.id)});
    assert doc is not None;
    stored = doc.get('data', {}).get('edges', []);
    assert stored == expected , (
        "removing an edge must preserve the relative order of the rest; "
        f"expected {expected}, got {stored}"
    );

    backend.close();
}


test "_put_node_atomic stores a dict field with $-prefixed keys verbatim on the atomic path" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");

    ref_like = {"$ref": "deadbeefdeadbeefdeadbeefdeadbeef", "$type": "node"};
    inst = _MongoEmptyDictNode(label="seed");
    anchor = cast(NodeAnchor, inst.__jac__);
    anchor.persistent = True;
    backend._write_to_db(anchor);

    inst.settings = ref_like;
    inst.__dict__['__jac_dirty_fields__'] = {'settings'};
    fake_edge_id = str(uuid4());
    backend._put_node_atomic(anchor, [fake_edge_id], [], {'settings'});

    col = client["jac_test_l123"]["_anchors"];
    doc = col.find_one({'_id': str(anchor.id)});
    assert doc is not None , (
        "None document means the pipeline $set tried to evaluate the "
        "$-prefixed keys as operators — the $literal wrap must store them "
        "as data."
    );
    arch_data = cast(dict, doc.get('data', {}).get('archetype', {}));
    assert arch_data.get('settings') == ref_like , (
        "a dict with $-prefixed keys must round-trip verbatim through the "
        f"atomic path; got settings={arch_data.get('settings')!r}"
    );

    backend.close();
}


glob _MONGO_40180_IMAGE = "mongo:6.0";


def _get_mongo_40180 -> tuple {
    if "mongo40180_client" not in _shared {
        container = MongoDbContainer(_MONGO_40180_IMAGE);
        container.start();
        uri = container.get_connection_url();
        _shared["mongo40180_container"] = container;
        _shared["mongo40180_uri"] = uri;
        _shared["mongo40180_client"] = MongoClient(uri);
        atexit.register(container.stop);
    }
    return (_shared["mongo40180_client"], _shared["mongo40180_uri"]);
}


def _reset_mongo_40180 -> None {
    if "mongo40180_client" not in _shared {
        return;
    }
    system_dbs = {"admin", "config", "local"};
    for db_name in _shared["mongo40180_client"].list_database_names() {
        if db_name not in system_dbs {
            _shared["mongo40180_client"].drop_database(db_name);
        }
    }
}


test "_put_node_atomic persists a cleared-to-{} dict field on mongo:6.0 via $literal (#6167/#6294)" {
    _reset_mongo_40180();
    _process_cache.pop('mongo_client', None);
    _process_cache.pop('mongo_available', None);
    (client, uri) = _get_mongo_40180();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");

    inst = _MongoEmptyDictNode(label="seed", settings={"keep": 1});
    anchor = cast(NodeAnchor, inst.__jac__);
    anchor.persistent = True;
    backend._write_to_db(anchor);

    inst.settings = {};
    inst.__dict__['__jac_dirty_fields__'] = {'settings'};
    fake_edge_id = str(uuid4());

    backend._put_node_atomic(anchor, [fake_edge_id], [], {'settings'});

    col = client["jac_test_l123"]["_anchors"];
    doc = col.find_one({'_id': str(anchor.id)});
    assert doc is not None , (
        "None document means the pipeline $set raised 40180 — the $literal "
        "wrap must let an empty dict through on mongo:6.0."
    );

    arch_data = cast(dict, doc.get('data', {}).get('archetype', {}));
    assert arch_data.get('settings') == {} , (
        "clearing a non-empty dict field to {} on the atomic path must "
        "persist a real empty object on mongo:6.0 (via $literal); stale value "
        "means the clear was silently swallowed. Got settings="
        f"{arch_data.get('settings')!r}"
    );

    backend.close();
}


test "cascade quarantine invalidates Redis L2 cache for connected live nodes" {
    _reset_mongo();
    _reset_redis();
    (_, mongo_uri) = _get_mongo();
    (_, redis_url) = _get_redis();
    _process_cache.clear();
    os.environ["MONGODB_URI"] = str(mongo_uri);
    os.environ["REDIS_URL"] = str(redis_url);
    try {
        mem = ScaleTieredMemory();
        mem.postinit();
        assert mem.l3 is not None , "MongoDB backend must be available";
        assert mem.l2 is not None , "Redis backend must be available";

        anchors_col = mem.l3.collection;

        source_id = str(uuid4());
        edge_id = str(uuid4());
        bar_id = str(uuid4());

        anchors_col.insert_one(
            {
                '_id': source_id,
                'type': 'NodeAnchor',
                'arch_module': 'jaclang.jac0core.archetype',
                'arch_type': 'Root',
                'fingerprint': None,
                'data': {
                    '__type__': 'NodeAnchor',
                    '__module__': 'jaclang.jac0core.archetype',
                    'id': source_id,
                    'persistent': True,
                    'archetype': {
                        '__type__': 'Root',
                        '__module__': 'jaclang.jac0core.archetype'
                    },
                    'edges': [edge_id]
                },
                'format_version': 1,
                'updated_at': '2026-01-01T00:00:00'
            }
        );
        anchors_col.insert_one(
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
                    'target': bar_id,
                    'is_undirected': False,
                    'archetype': {
                        '__type__': 'GenericEdge',
                        '__module__': 'jaclang.jac0core.archetype'
                    }
                },
                'format_version': 1,
                'updated_at': '2026-01-01T00:00:00'
            }
        );
        anchors_col.insert_one(
            {
                '_id': bar_id,
                'type': 'NodeAnchor',
                'arch_module': 'jaclang.jac0core.archetype',
                'arch_type': 'Root',
                'fingerprint': None,
                'data': {
                    '__type__': 'NodeAnchor',
                    '__module__': 'jaclang.jac0core.archetype',
                    'id': bar_id,
                    'persistent': True,
                    'archetype': {
                        '__type__': 'Root',
                        '__module__': 'jaclang.jac0core.archetype'
                    },
                    'edges': []
                },
                'format_version': 1,
                'updated_at': '2026-01-01T00:00:00'
            }
        );

        source_anchor = mem.get(UUID(source_id));
        assert source_anchor is not None , "source must load from Mongo";
        assert mem.l2.redis_client.get(f"anchor:{source_id}") is not None , (
            "source must be cached in Redis after tiered get"
        );

        mem.__mem__.clear();
        anchors_col.update_one(
            {'_id': bar_id},
            {
                '$set': {
                    'arch_module': 'no.such',
                    'arch_type': 'Missing',
                    'data.archetype.__module__': 'no.such',
                    'data.archetype.__type__': 'Missing'
                }
            }
        );
        bar_result = mem.get(UUID(bar_id));
        assert bar_result is None , "corrupt bar must not rehydrate";

        source_doc = anchors_col.find_one({'_id': source_id});
        assert source_doc is not None , "source node must still be live in Mongo";
        live_edges = source_doc.get('data', {}).get('edges', []);
        assert edge_id not in live_edges , (
            f"orphaned edge must be stripped from source.data.edges in Mongo; got: {live_edges}"
        );

        source_in_redis = mem.l2.redis_client.get(f"anchor:{source_id}");
        assert source_in_redis is None , (
            f"source Redis entry must be invalidated after cascade quarantine; "
            f"got: {json.loads(source_in_redis) if source_in_redis else None}"
        );

        mem.__mem__.clear();
        source_reloaded = mem.get(UUID(source_id));
        assert source_reloaded is not None , "source must still be loadable after cascade";
        reloaded_edges = source_reloaded.edges;
        assert reloaded_edges == [] , (
            f"tiered read must return source with empty edges after cascade; "
            f"got: {reloaded_edges}"
        );

        mem.l3.close();
    } finally {
        _process_cache.clear();
        os.environ.pop("MONGODB_URI", None);
        os.environ.pop("REDIS_URL", None);
    }
}

test "sync writes endpoint nodes before the edges that reference them" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");

    source = cast(NodeAnchor, _MongoLayer123Person(name="src").__jac__);
    source.persistent = True;
    backend._write_to_db(source);

    source.hash = 0;
    source.__dict__['_initial_edge_ids'] = frozenset();

    target = cast(NodeAnchor, _MongoLayer123Person(name="tgt").__jac__);
    target.persistent = True;
    eanch = EdgeAnchor(
        archetype=GenericEdge(), source=source, target=target, is_undirected=False
    );
    eanch.persistent = True;
    source.edges = [eanch];
    target.edges = [eanch];

    import from jaclang.runtimelib.changeset { ChangeSet }
    cs = ChangeSet();
    cs.record_edge_delta(source, added=[eanch.id], removed=[]);
    cs.record_create(eanch);
    cs.record_create(target);

    written: list = [];
    orig_write = backend._write_to_db;
    orig_atomic = backend._put_node_atomic;
    def _rec_write(anchor: Anchor) {
        written.append(anchor);
        orig_write(anchor);
    }
    def _rec_atomic(
        anchor: NodeAnchor,
        added: list,
        removed: list,
        fields: set,
        cas_version: (int | None) = None
    ) {
        written.append(anchor);
        orig_atomic(anchor, added, removed, fields, cas_version);
    }
    backend._write_to_db = _rec_write;
    backend._put_node_atomic = _rec_atomic;

    backend.apply(cs);

    live: set = {str(source.id)};
    for anchor in written {
        if isinstance(anchor, EdgeAnchor) {
            assert str(anchor.source.id) in live , (
                "eanch written before its source node: a crash here would "
                "orphan the eanch (issue #6488)"
            );
            assert str(anchor.target.id) in live , (
                "eanch written before its target node: a crash here would "
                "orphan the eanch (issue #6488)"
            );
        }
        live.add(str(anchor.id));
    }

    types = [type(a).__name__ for a in written];
    assert 'NodeAnchor' in types and 'EdgeAnchor' in types;
    assert types.index('NodeAnchor') < types.index('EdgeAnchor') , (
        f"target node must be written before the eanch; got order {types}"
    );

    anchors_col = client["jac_test_l123"]["_anchors"];
    assert anchors_col.find_one({'_id': str(eanch.id)}) is not None;
    assert anchors_col.find_one({'_id': str(target.id)}) is not None;
    assert anchors_col.find_one({'_id': str(source.id)}) is not None;

    backend.close();
}


test "apply writes exactly the intent's fields, never re-derived dirtiness" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_l123");

    person = cast(NodeAnchor, _MongoLayer123Person(name="orig", age=30).__jac__);
    person.persistent = True;
    backend._write_to_db(person);
    person.__dict__['_initial_edge_ids'] = frozenset();

    person.archetype.name = "sneaky";
    person.archetype.age = 31;

    edge_id = uuid4();
    stub = EdgeAnchor.__new__(EdgeAnchor);
    setattr(stub, 'id', edge_id);
    setattr(stub, 'persistent', True);
    person.edges.append(stub);

    import from jaclang.runtimelib.changeset { ChangeSet }
    cs = ChangeSet();
    cs.record_edge_delta(person, added=[edge_id], removed=[]);
    cs.record_update(person, {'age'});

    apply_report = backend.apply(cs);
    assert apply_report.ok() , (
        f"apply must succeed: {apply_report.failed} {apply_report.skipped}"
    );

    doc = client["jac_test_l123"]["_anchors"].find_one({'_id': str(person.id)});
    assert doc is not None;
    arch_doc = doc['data']['archetype'];
    assert arch_doc.get('age') == 31 , (
        f"intent field 'age' must be persisted; got {arch_doc.get('age')}"
    );
    assert arch_doc.get('name') == "orig" , (
        "apply persisted a field the collect pass did not put on the intent: "
        "the backend re-derived dirtiness instead of executing intent.fields "
        f"(got name={arch_doc.get('name')!r})"
    );
    assert str(edge_id) in doc['data']['edges'] , "edge delta must still land";

    backend.close();
}
