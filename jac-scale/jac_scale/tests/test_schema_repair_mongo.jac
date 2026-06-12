"""Integration tests for MongoBackend schema repair (read-repair + retry).

Exercises the v1 drift-management surface end to end against a real
MongoDB container: lazy read-repair with CAS write-back (renames, upgrade
callbacks, drop-attic, dual-written shadows), quarantine reason codes,
and the startup auto-retry that recovers quarantined docs once the
deploy that fixes them arrives.

Locally these require Docker; in CI they run against a throwaway Mongo
instance.
"""

import atexit;
import from typing { cast }
import from uuid { uuid4, UUID }
import from pymongo { MongoClient }
import from testcontainers.mongodb { MongoDbContainer }

import from jaclang.jac0core.archetype { Anchor, NodeAnchor, Root }
import from jaclang.runtimelib.serializer { Serializer }
import from jac_scale.memory_hierarchy { MongoBackend }

glob _shared: dict = {};


"""Upgrade callback: legacy comma-string tags become list[str]."""
def _split_repair_tags(doc: dict) -> dict {
    doc['tags'] = [
        t.strip()
        for t in doc['tags'].split(',')
        if t.strip()
    ];
    return doc;
}


obj _RepairUser(Root) {
    has name: str = "",
        tags: list[str] = [];

    static def __jac_schema__ -> None;
}

impl _RepairUser.__jac_schema__ -> None {
    schema_alias("name", stored="username");
    schema_drop("legacy_bio");
    schema_upgrade(
        _split_repair_tags, when=(lambda doc: dict : isinstance(doc.get('tags'), str))
    );
}


"""Lazily start a shared MongoDB container; return (MongoClient, uri)."""
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


"""Drop all non-system databases between tests."""
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


"""Insert a pre-rename-shape _RepairUser doc; returns its id string."""
def _insert_old_shape_doc(backend: MongoBackend, stored_fp: str) -> str {
    arch_mod = getattr(_RepairUser, '__module__');
    doc_id = str(uuid4());
    backend.collection.insert_one(
        {
            '_id': doc_id,
            'type': 'NodeAnchor',
            'arch_module': arch_mod,
            'arch_type': '_RepairUser',
            'fingerprint': stored_fp,
            'data': {
                '__type__': 'NodeAnchor',
                '__module__': 'jaclang.jac0core.archetype',
                'id': doc_id,
                'persistent': True,
                'archetype': {
                    '__type__': '_RepairUser',
                    '__module__': arch_mod,
                    'username': 'ada',
                    'tags': 'math, computing',
                    'legacy_bio': 'wrote the first program'
                },
                'edges': []
            },
            'format_version': 1,
            'updated_at': '2026-01-01T00:00:00'
        }
    );
    return doc_id;
}


test "read-repair renames, upgrades, attics, and write-backs with CAS" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_repair");
    doc_id = _insert_old_shape_doc(backend, stored_fp="00000000deadbeef");

    loaded = backend.get(UUID(doc_id));
    assert loaded is not None , "old-shape doc must load via repair, not quarantine";
    arch = cast(_RepairUser, cast(NodeAnchor, loaded).archetype);
    assert arch.name == 'ada' , f"rename failed: {arch}";
    assert arch.tags == ['math', 'computing'] , f"upgrade failed: {arch.tags}";

    # The repaired form must be persisted back (lazy migration).
    stored = backend.collection.find_one({'_id': doc_id});
    assert stored is not None;
    stored_arch = stored['data']['archetype'];
    assert stored_arch.get('name') == 'ada' , (
        f"write-back missing renamed field: {stored_arch}"
    );
    # Dual-write: the old stored name rides along for old-version readers.
    assert stored_arch.get('username') == 'ada' , (
        f"write-back must dual-write the shadow copy: {stored_arch}"
    );
    assert stored_arch.get('tags') == ['math', 'computing'];
    attic = stored_arch.get('__jac_attic__') or {};
    assert attic.get('legacy_bio', {}).get('value') == 'wrote the first program' , (
        f"dropped field must persist in the attic: {attic}"
    );
    # Fingerprint re-stamped to the live class (CAS succeeded).
    assert stored.get('fingerprint') == getattr(_RepairUser, '__jac_fingerprint__');
    # Nothing quarantined.
    q = client["jac_test_repair"]["_anchors_quarantine"].find_one({'_id': doc_id});
    assert q is None;
    backend.close();
}


test "second read of a repaired doc causes no further write-back churn" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_repair");
    doc_id = _insert_old_shape_doc(backend, stored_fp="00000000deadbeef");
    assert backend.get(UUID(doc_id)) is not None;
    first = backend.collection.find_one({'_id': doc_id});

    # Drop the in-memory anchor cacheless path: fetch again fresh.
    loaded = backend.get(UUID(doc_id));
    assert loaded is not None;
    second = backend.collection.find_one({'_id': doc_id});
    assert first.get('updated_at') == second.get('updated_at') , (
        "loading an already-repaired (dual-written) doc must not rewrite it"
    );
    backend.close();
}


test "quarantine stamps machine-readable reason codes" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_repair");
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
            'updated_at': '2026-01-01T00:00:00'
        }
    );
    assert backend.get(UUID(bad_id)) is None;
    q = client["jac_test_repair"]["_anchors_quarantine"].find_one({'_id': bad_id});
    assert q is not None;
    assert q.get('reason_code') == 'CLASS_MISSING' , (
        f"expected CLASS_MISSING, got {q.get('reason_code')}"
    );
    backend.close();
}


test "startup auto-retry recovers quarantined docs the deploy fixed" {
    _reset_mongo();
    (client, uri) = _get_mongo();
    arch_mod = getattr(_RepairUser, '__module__');
    doc_id = str(uuid4());
    # Simulate a doc quarantined by a previous deploy that lacked the
    # class (CLASS_MISSING); the class + drift rules exist in this one.
    client["jac_test_repair"]["_anchors_quarantine"].insert_one(
        {
            '_id': doc_id,
            'type': 'NodeAnchor',
            'arch_module': arch_mod,
            'arch_type': '_RepairUser',
            'fingerprint': '00000000deadbeef',
            'data': {
                '__type__': 'NodeAnchor',
                '__module__': 'jaclang.jac0core.archetype',
                'id': doc_id,
                'persistent': True,
                'archetype': {
                    '__type__': '_RepairUser',
                    '__module__': arch_mod,
                    'username': 'grace',
                    'tags': 'navy, compilers',
                    'legacy_bio': 'COBOL'
                },
                'edges': []
            },
            'error': 'class unresolvable in previous deploy',
            'reason_code': 'CLASS_MISSING',
            'quarantined_at': '2026-01-01T00:00:00',
            'from_format_version': 1
        }
    );
    # Constructing the backend runs postinit -> _auto_retry_quarantine.
    backend = MongoBackend(mongo_url=uri, db_name="jac_test_repair");
    q = client["jac_test_repair"]["_anchors_quarantine"].find_one({'_id': doc_id});
    assert q is None , "auto-retry must recover the now-loadable doc at startup";
    live = backend.collection.find_one({'_id': doc_id});
    assert live is not None , "recovered doc must be back in the live collection";
    live_arch = live['data']['archetype'];
    assert live_arch.get('name') == 'grace' , (
        f"recovery must apply drift rules: {live_arch}"
    );
    assert live_arch.get('tags') == ['navy', 'compilers'];
    backend.close();
}
