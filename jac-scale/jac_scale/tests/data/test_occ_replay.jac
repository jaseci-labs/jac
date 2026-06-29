import atexit;
import threading;
import from uuid { uuid4 }
import from pymongo { MongoClient }
import from testcontainers.mongodb { MongoDbContainer }

import from jaclang.jac0core.archetype { EdgeAnchor, GenericEdge, Root }
import from jaclang.runtimelib.changeset { ChangeSet }
import from jaclang.runtimelib.serializer { Serializer }
import from jaclang.runtimelib.exceptions { WriteConflict }
import from jac_scale.memory.memory_hierarchy { MongoBackend }

glob _shared: dict = {},
     _DB: str = "jac_test_occ";


node OccProfile {
    has uid: str = "";
}


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

    a1: any = Serializer.deserialize(coll.find_one({"_id": rid})["data"]);
    a2: any = Serializer.deserialize(coll.find_one({"_id": rid})["data"]);
    assert a1.version == 0 and a2.version == 0;

    backend._put_node_atomic(a1, [str(uuid4())], [], set(), 0);
    assert a1.version == 1;
    assert coll.find_one({"_id": rid})["data"]["version"] == 1;

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


test "OCC: a read-gated first write to a never-persisted anchor inserts, not conflicts" {
    (client, uri) = _get_mongo();
    client.drop_database(_DB);
    backend: any = MongoBackend(mongo_url=uri, db_name=_DB);
    coll: any = client[_DB]["_anchors"];

    root_arch: any = Root();
    ranch: any = root_arch.__jac__;
    ranch.persistent = True;
    ranch.root = ranch.id;
    rid: str = str(ranch.id);
    assert coll.find_one({"_id": rid}) is None;

    conflicted = False;
    try {
        backend._put_node_atomic(ranch, [str(uuid4())], [], set(), 0);
    } except WriteConflict {
        conflicted = True;
    }
    assert not conflicted , "first read-gated write to an absent doc must insert, not conflict";
    stored: any = coll.find_one({"_id": rid});
    assert stored is not None;
    assert stored["data"]["version"] == 1;
    assert len(stored["data"]["edges"]) == 1;
}


test "OCC: a read-gated write on a legacy doc (no data.version) does not conflict" {
    (client, uri) = _get_mongo();
    client.drop_database(_DB);
    backend: any = MongoBackend(mongo_url=uri, db_name=_DB);
    coll: any = client[_DB]["_anchors"];
    (ranch, rid) = _seed_root(backend);

    coll.update_one({"_id": rid}, {"$unset": {"data.version": ""}});
    assert "version" not in coll.find_one({"_id": rid})["data"];

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


test "OCC (Mongo): apply() precheck aborts a stale unit before writing the child" {
    (client, uri) = _get_mongo();
    client.drop_database(_DB);
    backend: any = MongoBackend(mongo_url=uri, db_name=_DB);
    coll: any = client[_DB]["_anchors"];
    (ranch, rid) = _seed_root(backend);

    backend._put_node_atomic(ranch, [str(uuid4())], [], set(), 0);
    assert coll.find_one({"_id": rid})["data"]["version"] == 1;

    rstale: any = Serializer.deserialize(coll.find_one({"_id": rid})["data"]);
    rstale.version = 0;
    prof: any = OccProfile(uid="loser");
    panch: any = prof.__jac__;
    panch.persistent = True;
    panch.root = rstale.id;
    edge_arch: any = GenericEdge();
    eanch: any = edge_arch.__jac__;
    eanch.source = rstale;
    eanch.target = panch;
    eanch.persistent = True;
    eanch.root = rstale.id;
    rstale.edges.append(eanch);
    panch.edges.append(eanch);
    cs: any = ChangeSet();
    cs.record_create(panch);
    cs.record_create(eanch);
    cs.record_edge_delta(rstale, [eanch.id], []);
    cs.intents[rstale.id].cas_version = 0;
    rep: any = backend.apply(cs);

    assert len(rep.conflicts) == 1 , f"precheck must conflict, got {rep.conflicts}";
    assert coll.count_documents({"_id": str(panch.id)}) == 0 , "loser's child must NOT be written (precheck aborts before staging)";
    assert coll.count_documents({"_id": str(eanch.id)}) == 0 , "loser's edge must NOT be written (precheck aborts before staging)";
    assert len(coll.find_one({"_id": rid})["data"]["edges"]) == 1 , "root keeps only the winner's edge";
}


test "fsck (Mongo): a half-linked edge + its stranded child are collected" {
    (client, uri) = _get_mongo();
    client.drop_database(_DB);
    backend: any = MongoBackend(mongo_url=uri, db_name=_DB);
    coll: any = client[_DB]["_anchors"];
    (ranch, rid) = _seed_root(backend);

    prof: any = OccProfile(uid="kid");
    panch: any = prof.__jac__;
    panch.persistent = True;
    panch.root = ranch.id;

    edge_arch: any = GenericEdge();
    eanch: any = EdgeAnchor(
        archetype=edge_arch, source=ranch, target=panch, is_undirected=False
    );
    edge_arch.__jac__ = eanch;
    eanch.persistent = True;
    eanch.root = ranch.id;
    panch.edges.append(eanch);
    backend._write_to_db(panch);
    backend._write_to_db(eanch);
    backend._put_node_atomic(ranch, [str(eanch.id)], [], set());
    assert len(coll.find_one({"_id": rid})["data"]["edges"]) == 1;

    coll.update_one({"_id": rid}, {"$pull": {"data.edges": str(eanch.id)}});
    assert len(coll.find_one({"_id": rid})["data"]["edges"]) == 0;

    rpt: any = backend.fsck(repair=False);
    assert any(str(e[0]) == str(eanch.id) for e in rpt['half_linked_edges']) , f"edge must be flagged half-linked, got {rpt[
        'half_linked_edges'
    ]}";
    assert str(panch.id) in [str(n) for n in rpt['orphan_nodes']] , f"stranded kid must be flagged orphan_node, got {rpt[
        'orphan_nodes'
    ]}";

    rep: any = backend.fsck(repair=True);
    assert rep['repaired_counts']['collected'] >= 2 , f"edge + kid collected, got {rep[
        'repaired_counts'
    ]}";
    assert coll.count_documents({"_id": str(panch.id)}) == 0 , "stranded kid must be collected";
    assert coll.count_documents({"_id": str(eanch.id)}) == 0 , "half-linked edge must be collected";
}
