"""Optimistic-concurrency tests for the node-identity duplicate race (#6266).

Starts a real MongoDB container (testcontainers; needs Docker, skipped if
unavailable) and exercises the version-CAS in MongoBackend._put_node_atomic
plus the abort -> reload -> replay convergence the request boundary performs.
Two writers model two pods racing a check-then-create against the same root.

Anchor handles are typed `any`: the checker has no stub for `.__jac__` /
anchor metadata, and this test pokes the persistence layer directly.
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


test "OCC version-CAS detects a concurrent root mutation" {
    (client, uri) = _get_mongo();
    client.drop_database(_DB);
    backend: any = MongoBackend(mongo_url=uri, db_name=_DB);
    coll: any = client[_DB]["_anchors"];

    (ranch, rid) = _seed_root(backend);
    assert coll.find_one({"_id": rid})["data"]["version"] == 0;

    # Two stale handles loaded at the same version (models two pods).
    a1: any = Serializer.deserialize(coll.find_one({"_id": rid})["data"]);
    a2: any = Serializer.deserialize(coll.find_one({"_id": rid})["data"]);
    assert a1.version == 0 and a2.version == 0;

    # Writer 1 wins and bumps the version.
    backend._put_node_atomic(a1, [str(uuid4())], [], set());
    assert a1.version == 1;
    assert coll.find_one({"_id": rid})["data"]["version"] == 1;

    # Writer 2 is still at v0 -> CAS miss -> WriteConflict.
    conflicted = False;
    try {
        backend._put_node_atomic(a2, [str(uuid4())], [], set());
    } except WriteConflict as wc {
        conflicted = True;
        assert wc.expected_version == 0 and wc.actual_version == 1;
    }
    assert conflicted , "stale writer must raise WriteConflict";
    # Only the winner's edge landed.
    assert len(coll.find_one({"_id": rid})["data"]["edges"]) == 1;
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
        b: any = MongoBackend(mongo_url=uri, db_name=_DB);
        cc: any = b.client[_DB]["_anchors"];
        waited = False;
        outcome = "exhausted";
        attempt = 0;
        while attempt < 5 {
            attempt += 1;
            # Re-read root from the DB (models a pod's request-local load).
            r2: any = Serializer.deserialize(cc.find_one({"_id": rid})["data"]);
            linked_now = cc.count_documents(
                {"arch_type": "OccProfile", "data._linked": True}
            );
            if linked_now > 0 {
                outcome = "found";
                break;
            }
            # Barrier once so both pods clear the check before either commits
            # (the exact A/B interleaving of #6266).
            if not waited {
                barrier.wait();
                waited = True;
            }
            # Faithful to the ChangeSet stage order: the new node doc is
            # written (stage 0) BEFORE the root edge-list CAS (stage 2). A
            # lost CAS therefore leaves the profile as an accepted orphan.
            prof: any = OccProfile(uid=str(uuid4()));
            panch: any = prof.__jac__;
            panch.persistent = True;
            panch.root = r2.id;
            edge_arch: any = GenericEdge();
            eanch: any = edge_arch.__jac__;
            eanch.source = r2;
            eanch.target = panch;
            eanch.persistent = True;
            eanch.root = r2.id;
            b._write_to_db(panch);
            b._write_to_db(eanch);
            try {
                b._put_node_atomic(r2, [str(eanch.id)], [], set());
            } except WriteConflict {
                # Lost the race: replay (re-read now sees the winner's child).
                continue;
            }
            cc.update_one(
                {"_id": str(panch.id)}, {"$set": {"data._linked": True}}, upsert=True
            );
            outcome = "created";
            break;
        }
        with lock {
            results.append(outcome);
        }
    }

    t1: any = threading.Thread(target=worker);
    t2: any = threading.Thread(target=worker);
    t1.start();
    t2.start();
    t1.join();
    t2.join();

    # One pod created; the other converged on the find branch.
    assert sorted(results) == ["created", "found"] , f"expected one of each, got {results}";

    # The fix: exactly ONE child linked onto root (the bug produced two).
    root_edges = coll.find_one({"_id": rid})["data"]["edges"];
    assert len(root_edges) == 1 , f"expected 1 linked child, got {len(root_edges)}";
    linked = coll.count_documents({"arch_type": "OccProfile", "data._linked": True});
    assert linked == 1 , f"expected exactly 1 linked OccProfile, got {linked}";
    # The loser's pre-CAS node write is an accepted orphan (unreferenced,
    # collectable by fsck) — never a dangling reference.
    total = coll.count_documents({"arch_type": "OccProfile"});
    assert total == 2 , f"expected 1 linked + 1 orphan, got {total}";
}
