"""Multi-pod coherency: system-root topology index (GTI) invalidation.

GTI is runtime-maintained metadata stored on the system root. User-root edge
list deltas are reconstructable from edge anchors, but the system-root GTI blob
must still be persisted, cached fresh in Redis L2, and broadcast so other pods
evict stale L1 system-root anchors before resolving traversals.

Real Mongo + Redis via testcontainers. A custom `Root()` gives each test a real
per-user root (fresh UUID, persistent), avoiding the anonymous root (id 0) that
every ExecutionContext re-creates locally.
"""

import atexit;
import json;
import os;
import time;
import redis;
import from typing { cast }
import from uuid { UUID }
import from pymongo { MongoClient }
import from testcontainers.community.mongodb { MongoDbContainer }
import from testcontainers.community.redis { RedisContainer }

import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.jac0core.archetype { NodeAnchor, Root }
import from jaclang.jac0core.constant { Constants as Con }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.runtimelib.serializer { Serializer }
import from jaclang.project.config { JacConfig, set_config }
import from jaclang.scale.memory.memory_hierarchy {
    MongoBackend,
    RedisBackend,
    ScaleTieredMemory,
    _process_cache
}
import from jaclang.scale.memory.l1_invalidation {
    DEFAULT_INVALIDATION_CHANNEL,
    ensure_listener
}


node _XPodTypeA {
    has idx: int = 0;
}


glob _shared: dict = {},
     _DB_NAME = "jac_xpod_test";


def _get_mongo_uri -> str {
    if "mongo_container" not in _shared {
        c = MongoDbContainer("mongo:latest");
        c.start();
        _shared["mongo_container"] = c;
        _shared["mongo_uri"] = c.get_connection_url();
        _shared["mongo_client"] = MongoClient(c.get_connection_url());
        atexit.register(c.stop);
    }
    return _shared["mongo_uri"];
}


def _get_redis -> tuple {
    if "redis_container" not in _shared {
        c = RedisContainer("redis:latest", port=6379);
        c.start();
        host = c.get_container_host_ip();
        port = c.get_exposed_port(6379);
        url = f"redis://{host}:{port}/0";
        _shared["redis_container"] = c;
        _shared["redis_url"] = url;
        _shared["redis_client"] = redis.Redis(
            host=host, port=int(port), decode_responses=False
        );
        atexit.register(c.stop);
    }
    return (_shared["redis_client"], _shared["redis_url"]);
}


def _reset_dbs {
    if "mongo_client" in _shared {
        for db_name in _shared["mongo_client"].list_database_names() {
            if db_name not in {"admin", "config", "local"} {
                _shared["mongo_client"].drop_database(db_name);
            }
        }
    }
    if "redis_client" in _shared {
        _shared["redis_client"].flushall();
    }
    _process_cache.pop("system_root", None);
    _process_cache.pop("redis_client", None);
    _process_cache.pop("redis_available", None);
}


"""Build a pod: a ScaleTieredMemory wired to the shared Mongo (L3) + Redis (L2)."""
def _make_pod -> ScaleTieredMemory {
    mongo_uri = _get_mongo_uri();
    (_, redis_url) = _get_redis();
    mongo = MongoBackend(mongo_url=mongo_uri, db_name=_DB_NAME);
    redis_be = RedisBackend(redis_url=redis_url);
    mem = ScaleTieredMemory();
    mem.l2 = redis_be;
    mem.l3 = mongo;
    mem._cache_available = True;
    return mem;
}


"""Topology-index length of an anchor cached in Redis L2; -1 if not cached."""
def _l2_index_len(mem: ScaleTieredMemory, anchor_id: UUID) -> int {
    raw = cast(RedisBackend, mem.l2).redis_client.get(f"anchor:{anchor_id}");
    if not raw {
        return -1;
    }
    anchor = Serializer.deserialize(json.loads(raw));
    if not isinstance(anchor, NodeAnchor) {
        return -2;
    }
    return len(anchor.get_topology_index());
}


def _bind_system_root(ctx: ExecutionContext, mem: ScaleTieredMemory) -> NodeAnchor {
    system_id = UUID(Con.SUPER_ROOT_UUID);
    system_anchor = mem.get(system_id);
    if not isinstance(system_anchor, NodeAnchor) {
        system_anchor = ctx.system_root;
        system_anchor.id = system_id;
        system_anchor.persistent = True;
        mem.__mem__[system_id] = system_anchor;
    }
    ctx.system_root = system_anchor;
    return system_anchor;
}


"""Builder pod: persist a root with `n` _XPodTypeA children; return its id."""
def _seed_root(n: int) -> UUID {
    memB = _make_pod();
    ctxB = ExecutionContext();
    ctxB.mem = memB;
    _bind_system_root(ctxB, memB);
    JacRuntime.set_context(ctxB);
    user_root = Root();
    root_anchor = user_root.__jac__;
    root_anchor.persistent = True;
    memB.__mem__[root_anchor.id] = root_anchor;
    root_id = root_anchor.id;
    for i in range(n) {
        user_root ++> _XPodTypeA(idx=i);
    }
    ctxB.mem.commit();
    ctxB.close();
    return root_id;
}


def _topology_cfg {
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    JacRuntime.set_base_path("/tmp/_xpod_topology");
}


test "edge-list-delta refreshes the system-root GTI in Redis L2 + broadcasts" {
    _reset_dbs();
    orig_base = JacRuntime.get_base_path_dir();
    _topology_cfg();
    try {
        # --- Builder: root -> 100 _XPodTypeA, committed ---
        root_id = _seed_root(100);

        # --- Pod A: warm read promotes the system root into Redis L2 (100-edge GTI) ---
        memA = _make_pod();
        ctxA = ExecutionContext();
        ctxA.mem = memA;
        _bind_system_root(ctxA, memA);
        JacRuntime.set_context(ctxA);
        rA_anchor = ctxA.mem.get(root_id);
        assert rA_anchor is not None , "root must load from L3";
        leadsA = [rA_anchor.archetype-->][?:_XPodTypeA];
        assert len(leadsA) == 100 , f"warm query expected 100, got {len(leadsA)}";
        system_id = UUID(Con.SUPER_ROOT_UUID);
        assert _l2_index_len(memA, system_id) == 100 , (
            "system root must be cached in Redis L2 with a 100-edge index after warm read"
        );
        ctxA.close();

        # Subscribe a raw pubsub client BEFORE the write so we can prove the
        # cross-pod invalidation is broadcast (the L1-eviction signal).
        (redis_client, _) = _get_redis();
        pubsub = redis_client.pubsub(ignore_subscribe_messages=True);
        pubsub.subscribe(DEFAULT_INVALIDATION_CHANNEL);
        # Drain the subscribe confirmation.
        pubsub.get_message(timeout=1.0);

        # --- Pod B: add ONE more edge to the root, commit ---
        memB2 = _make_pod();
        ctxB2 = ExecutionContext();
        ctxB2.mem = memB2;
        _bind_system_root(ctxB2, memB2);
        JacRuntime.set_context(ctxB2);
        rB2_anchor = ctxB2.mem.get(root_id);
        assert rB2_anchor is not None;
        rB2_anchor.archetype ++> _XPodTypeA(idx=100);
        ctxB2.mem.commit();

        # try/finally so a failed assert can't leak the subscriber onto the
        # shared Redis channel and skew message counts in later tests.
        try {
            # L3 (Mongo) is fresh: 101 edges, index length 101.
            doc = _shared["mongo_client"][_DB_NAME]["_anchors"].find_one(
                {'_id': str(root_id)}
            );
            assert doc is not None , "root must be persisted in Mongo";
            assert len(doc['data']['edges']) == 101 , (
                f"Mongo L3 must have 101 edges; got {len(doc['data']['edges'])}"
            );
            system_doc = _shared["mongo_client"][_DB_NAME]["_anchors"].find_one(
                {'_id': str(system_id)}
            );
            assert system_doc is not None , "system root must be persisted in Mongo";
            restored = Serializer.deserialize(system_doc['data']);
            assert len(cast(NodeAnchor, restored).get_topology_index()) == 101 , (
                "Mongo L3 system-root topology index must be fresh (101)"
            );

            # THE FIX (L2 coherency): the system-root Redis L2 entry must carry
            # the fresh GTI so other pods can reload it.
            assert _l2_index_len(memB2, system_id) == 101 , (
                "system root's Redis L2 entry must be fresh after the topology "
                f"metadata update; got index len {_l2_index_len(memB2, system_id)}"
            );

            # THE FIX (cross-pod signal): an invalidation for the system root
            # must be broadcast so other pods evict their L1 copies.
            saw_system_root = False;
            for _ in range(50) {
                msg = pubsub.get_message(timeout=0.1);
                if msg is not None and msg.get("type") == "message" {
                    payload = json.loads(msg.get("data"));
                    if payload.get("a") == str(system_id) {
                        saw_system_root = True;
                        break;
                    }
                }
            }
            assert saw_system_root , (
                "an invalidation message for the system root must be published on "
                f"'{DEFAULT_INVALIDATION_CHANNEL}' so other pods evict their L1"
            );
        } finally {
            pubsub.close();
        }

        ctxB2.close();
    } finally {
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
    }
}


test "a second pod sees the fresh GTI after a cross-pod edge add (end-to-end)" {
    _reset_dbs();
    orig_base = JacRuntime.get_base_path_dir();
    _topology_cfg();
    try {
        root_id = _seed_root(100);

        # Run the cross-pod L1 invalidation listener (subscribes to the channel).
        (_, redis_url) = _get_redis();
        ensure_listener(_process_cache, redis_url, DEFAULT_INVALIDATION_CHANNEL);

        # --- Pod A: warm read, kept alive so its L1 holds the soon-stale system root ---
        memA = _make_pod();
        ctxA = ExecutionContext();
        ctxA.mem = memA;
        _bind_system_root(ctxA, memA);
        JacRuntime.set_context(ctxA);
        rA_anchor = ctxA.mem.get(root_id);
        assert rA_anchor is not None;
        assert len([rA_anchor.archetype-->][?:_XPodTypeA]) == 100;

        # --- Pod B: add one edge to the root and commit ---
        memB2 = _make_pod();
        ctxB2 = ExecutionContext();
        ctxB2.mem = memB2;
        _bind_system_root(ctxB2, memB2);
        JacRuntime.set_context(ctxB2);
        rB2_anchor = ctxB2.mem.get(root_id);
        assert rB2_anchor is not None;
        rB2_anchor.archetype ++> _XPodTypeA(idx=100);
        ctxB2.mem.commit();

        # --- Pod A re-queries: the listener should evict stale system-root L1,
        # forcing a reload of the fresh index from L3. Bounded poll for pub/sub. ---
        JacRuntime.set_context(ctxA);
        seen = -1;
        for _ in range(50) {
            rA2 = ctxA.mem.get(root_id);
            seen = len([rA2.archetype-->][?:_XPodTypeA]);
            if seen == 101 {
                break;
            }
            time.sleep(0.1);
        }
        assert seen == 101 , (
            "Pod A must observe the fresh 101-edge GTI after the cross-pod edge "
            f"add (via L1 eviction + L3 reload); still saw {seen}"
        );

        ctxA.close();
        ctxB2.close();
    } finally {
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
    }
}
