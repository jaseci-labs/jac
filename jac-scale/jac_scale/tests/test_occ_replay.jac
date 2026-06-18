"""Read-set optimistic-concurrency tests for the node-identity race (#6266).

Starts a real MongoDB container (testcontainers; needs Docker, skipped if
unavailable) and exercises the read-gated version-CAS in
MongoBackend._put_node_atomic plus the abort -> reload -> replay convergence
the request boundary performs. Two writers model two pods racing against the
same root. The CAS fires only when a request READ a traversal from the node
(passed here as `_put_node_atomic`'s `cas_version`); a blind append takes no
dependency and merges lock-free (#5644).

Anchor handles are typed `any`: the checker has no stub for `.__jac__` /
anchor metadata, and these tests poke the persistence layer directly.
"""

import atexit;
import threading;
import from uuid { uuid4 }
import from pymongo { MongoClient }
import from testcontainers.mongodb { MongoDbContainer }

import from jaclang.jac0core.archetype { GenericEdge, Root }
import from jaclang.runtimelib.serializer { Serializer }
import from jaclang.runtimelib.exceptions { WriteConflict }
import from jac_scale.memory_hierarchy { MongoBackend }

glob _shared: dict = {},
     _DB: str = "jac_test_occ";


node OccProfile {
    has uid: str = "";
}


"""Lazily start a shared MongoDB container; return (MongoClient, uri)."""
def _get_mongo -> tuple {
    if "client" not in _shared {
        container = MongoDbContainer("mongo:latest");
        container.start();
        uri = container.get_connection_url();
        _shared["container"] = container;
        _shared["uri"] = uri;
        _shared["client"] = MongoClient(uri);
        atexit.register(container.stop);
    }
    return (_shared["client"], _shared["uri"]);
}


"""Persist a fresh Root via the backend; return (anchor, id_str)."""
def _seed_root(backend: any) -> tuple {
    root_arch: any = Root();
    ranch: any = root_arch.__jac__;
    ranch.persistent = True;
    ranch.root = ranch.id;
    backend._write_to_db(ranch);
    return (ranch, str(ranch.id));
}


test "OCC: a read-gated stale write conflicts" {
    (client, uri) = _get_mongo();
    client.drop_database(_DB);
    backend: any = MongoBackend(mongo_url=uri, db_name=_DB);
    coll: any = client[_DB]["_anchors"];

    (ranch, rid) = _seed_root(backend);
    assert coll.find_one({"_id": rid})["data"]["version"] == 0;

    # Two requests that each READ the root load the same version (two pods).
    a1: any = Serializer.deserialize(coll.find_one({"_id": rid})["data"]);
    a2: any = Serializer.deserialize(coll.find_one({"_id": rid})["data"]);
    assert a1.version == 0 and a2.version == 0;

    # Writer 1 (read v0) wins and bumps the version.
    backend._put_node_atomic(a1, [str(uuid4())], [], set(), 0);
    assert a1.version == 1;
    assert coll.find_one({"_id": rid})["data"]["version"] == 1;

    # Writer 2 (read v0) -> CAS miss -> WriteConflict.
    conflicted = False;
    try {
        backend._put_node_atomic(a2, [str(uuid4())], [], set(), 0);
    } except WriteConflict as wc {
        conflicted = True;
        assert wc.expected_version == 0 and wc.actual_version == 1;
    }
    assert conflicted , "stale read-gated writer must raise WriteConflict";
    assert len(coll.find_one({"_id": rid})["data"]["edges"]) == 1;
}


test "OCC: a read-gated write on a legacy doc (no data.version) does not conflict" {
    (client, uri) = _get_mongo();
    client.drop_database(_DB);
    backend: any = MongoBackend(mongo_url=uri, db_name=_DB);
    coll: any = client[_DB]["_anchors"];
    (ranch, rid) = _seed_root(backend);

    # Simulate a document written before this feature shipped: no data.version.
    coll.update_one({"_id": rid}, {"$unset": {"data.version": ""}});
    assert "version" not in coll.find_one({"_id": rid})["data"];

    # A request reads it (absent version -> default 0) and adds an edge. The CAS
    # must treat absent as 0 and succeed, not 409 on the legacy node.
    a: any = Serializer.deserialize(coll.find_one({"_id": rid})["data"]);
    assert a.version == 0;
    conflicted = False;
    try {
        backend._put_node_atomic(a, [str(uuid4())], [], set(), 0);
    } except WriteConflict {
        conflicted = True;
    }
    assert not conflicted , "legacy doc (absent version) must not spuriously conflict";
    assert coll.find_one({"_id": rid})["data"]["version"] == 1;
}


test "OCC: a blind append (no read) merges lock-free" {
    (client, uri) = _get_mongo();
    client.drop_database(_DB);
    backend: any = MongoBackend(mongo_url=uri, db_name=_DB);
    coll: any = client[_DB]["_anchors"];
    (ranch, rid) = _seed_root(backend);

    a1: any = Serializer.deserialize(coll.find_one({"_id": rid})["data"]);
    a2: any = Serializer.deserialize(coll.find_one({"_id": rid})["data"]);

    # No cas_version -> no dependency -> both edges merge, no conflict.
    conflicted = False;
    try {
        backend._put_node_atomic(a1, [str(uuid4())], [], set());
        backend._put_node_atomic(a2, [str(uuid4())], [], set());
    } except WriteConflict {
        conflicted = True;
    }
    assert not conflicted , "blind appends must not conflict";
    assert len(coll.find_one({"_id": rid})["data"]["edges"]) == 2;
}


"""One pod's find-or-create with abort + reload + replay on conflict (mirrors
the server boundary). The read of `[-->(?:OccProfile)]` is modelled by passing
the loaded version as `cas_version`. Returns 'created' or 'found'."""
def _find_or_create(uri: str, rid: str, barrier: any) -> str {
    backend: any = MongoBackend(mongo_url=uri, db_name=_DB);
    coll: any = backend.client[_DB]["_anchors"];
    waited = False;
    attempt = 0;
    while attempt < 5 {
        attempt += 1;
        ranch: any = Serializer.deserialize(coll.find_one({"_id": rid})["data"]);
        if coll.count_documents(
            {"arch_type": "OccProfile", "data._linked": True}
        ) > 0 {
            return "found";
        }
        if not waited {
            barrier.wait();
            waited = True;
        }
        prof: any = OccProfile(uid=str(uuid4()));
        panch: any = prof.__jac__;
        panch.persistent = True;
        panch.root = ranch.id;
        edge_arch: any = GenericEdge();
        eanch: any = edge_arch.__jac__;
        eanch.source = ranch;
        eanch.target = panch;
        eanch.persistent = True;
        eanch.root = ranch.id;
        backend._write_to_db(panch);
        backend._write_to_db(eanch);
        try {
            backend._put_node_atomic(ranch, [str(eanch.id)], [], set(), ranch.version);
        } except WriteConflict {
            continue;
        }
        coll.update_one(
            {"_id": str(panch.id)}, {"$set": {"data._linked": True}}, upsert=True
        );
        return "created";
    }
    return "exhausted";
}


test "OCC + replay converges concurrent find-or-create to one linked child" {
    (client, uri) = _get_mongo();
    client.drop_database(_DB);
    backend: any = MongoBackend(mongo_url=uri, db_name=_DB);
    coll: any = client[_DB]["_anchors"];
    (ranch, rid) = _seed_root(backend);

    barrier: any = threading.Barrier(2);
    results: list = [];
    lock: any = threading.Lock();

    def worker {
        r = _find_or_create(uri, rid, barrier);
        with lock {
            results.append(r);
        }
    }

    t1: any = threading.Thread(target=worker);
    t2: any = threading.Thread(target=worker);
    t1.start();
    t2.start();
    t1.join();
    t2.join();

    assert sorted(results) == ["created", "found"] , f"expected one of each, got {results}";
    root_edges = coll.find_one({"_id": rid})["data"]["edges"];
    assert len(root_edges) == 1 , f"expected 1 linked child, got {len(root_edges)}";
    linked = coll.count_documents({"arch_type": "OccProfile", "data._linked": True});
    assert linked == 1 , f"expected exactly 1 linked OccProfile, got {linked}";
}
