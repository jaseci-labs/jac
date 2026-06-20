"""End-to-end pushdown tests: edge-ref slicing must bound storage-layer reads.

When the user writes `[root --> ][?:T][0:50]`, the compiler should fuse the
slice into the `Jac.refs(...)` call, the topology planner should resolve the
typed targets in order, and the storage layer should be asked for only the
50 sliced UUIDs — not the full neighbor set.

These tests exercise the production stack (ScaleTieredMemory with MongoDB L3
and Redis L2). They use real testcontainers; they run in CI and skip locally
when Docker is unavailable.
"""

import atexit;
import os;
import from pathlib { Path }
import redis;
import from pymongo { MongoClient }
import from testcontainers.mongodb { MongoDbContainer }
import from testcontainers.redis { RedisContainer }

import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.project.config { JacConfig, set_config }
import from jac_scale.memory_hierarchy {
    MongoBackend,
    RedisBackend,
    ScaleTieredMemory,
    _process_cache
}


node _PushdownLead {
    has idx: int = 0;
}

node _PushdownOther {
    has idx: int = 0;
}


glob _shared: dict = {};


"""Lazily start a shared MongoDB container; return uri."""
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

"""Lazily start a shared Redis container; return url + raw client."""
def _get_redis_url -> str {
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
    return _shared["redis_url"];
}

"""Reset Mongo + Redis between tests."""
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
}


"""Build a ScaleTieredMemory bound to the test mongo+redis containers.

Sets the env vars the backend reads at construction time, then constructs
fresh backend instances (so test counters start at zero)."""
def _make_scale_memory -> tuple {
    mongo_uri = _get_mongo_uri();
    redis_url = _get_redis_url();

    # Clear stale singleton clients so each call gets a live connection to
    # the testcontainer URLs (the module-level cache may hold a client from
    # the pytest plugin's initial context setup which points nowhere).
    _process_cache.pop("mongo_client", None);
    _process_cache.pop("redis_client", None);
    _process_cache.pop("mongo_available", None);
    _process_cache.pop("redis_available", None);

    os.environ["JAC_MONGO_URL"] = mongo_uri;
    os.environ["JAC_REDIS_URL"] = redis_url;

    mongo = MongoBackend(mongo_url=mongo_uri, db_name="jac_pushdown_test");
    redis_be = RedisBackend(redis_url=redis_url);
    mem = ScaleTieredMemory();
    # Inject our instrumented backends so the counters belong to us.
    mem.l2 = redis_be;
    mem.l3 = mongo;
    mem._cache_available = True;
    return (mem, mongo, redis_be);
}


"""Slicing must bound MongoDB fetches to ~slice size, not all neighbors."""
test "edge-ref slice bounds mongodb fetches" {
    _reset_dbs();
    orig_base = JacRuntime.get_base_path_dir();
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    JacRuntime.set_base_path("/tmp/_pushdown_mongo");

    try {
        # --- Phase 1: build graph (100 leads + 20 others), persist ---
        (mem1, mongo1, redis1) = _make_scale_memory();
        ctx1 = ExecutionContext();
        ctx1.mem = mem1;
        # Seed the injected memory with the system root so sync() can persist it.
        ctx1.mem.put(ctx1.system_root);
        JacRuntime.set_context(ctx1);

        for i in range(100) {
            root ++> _PushdownLead(idx=i);
        }
        for i in range(20) {
            root ++> _PushdownOther(idx=i);
        }
        root_id = root.__jac__.id;
        ctx1.mem.commit();
        ctx1.close();

        # --- Phase 2: fresh ctx (cold L1+L2), measure mongo reads on slice ---
        (mem2, mongo2, redis2) = _make_scale_memory();
        ctx2 = ExecutionContext();
        ctx2.mem = mem2;
        JacRuntime.set_context(ctx2);

        # Warm just the root so we measure traversal-only fetches.
        root_anchor = ctx2.mem.get(root_id);
        assert root_anchor is not None;
        r2 = root_anchor.archetype;

        mongo2.reset_counters();
        redis2.reset_counters();

        leads = [r2-->][?:_PushdownLead][0:50];
        assert len(leads) == 50 , f"Expected 50 leads, got {len(leads)}";

        assert mongo2.fetch_count <= 60 , (
            f"Slice should bound MongoDB fetches; got {mongo2.fetch_count} "
            "items requested for [0:50]"
        );

        ctx2.close();
    } finally {
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
    }
}


"""Slicing must bound Redis writes too: only the sliced anchors should be
promoted to the L2 cache (today's behavior promotes every loaded item)."""
test "edge-ref slice bounds redis cache promotions" {
    _reset_dbs();
    orig_base = JacRuntime.get_base_path_dir();
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    JacRuntime.set_base_path("/tmp/_pushdown_redis");

    try {
        # --- Phase 1: build graph + persist; clears Redis between phases ---
        (mem1, mongo1, redis1) = _make_scale_memory();
        ctx1 = ExecutionContext();
        ctx1.mem = mem1;
        ctx1.mem.put(ctx1.system_root);
        JacRuntime.set_context(ctx1);

        for i in range(100) {
            root ++> _PushdownLead(idx=i);
        }
        for i in range(20) {
            root ++> _PushdownOther(idx=i);
        }
        root_id = root.__jac__.id;
        ctx1.mem.commit();
        ctx1.close();

        # Flush Redis to simulate a fresh cache for Phase 2.
        _shared["redis_client"].flushall();

        # --- Phase 2: cold caches, run sliced query, measure Redis writes ---
        (mem2, mongo2, redis2) = _make_scale_memory();
        ctx2 = ExecutionContext();
        ctx2.mem = mem2;
        JacRuntime.set_context(ctx2);

        root_anchor = ctx2.mem.get(root_id);
        assert root_anchor is not None;
        r2 = root_anchor.archetype;

        redis2.reset_counters();

        leads = [r2-->][?:_PushdownLead][0:50];
        assert len(leads) == 50;

        # L1→L3 promotions populate Redis. With slice pushdown, only the 50
        # loaded anchors should land in Redis. Today, all neighbors + their
        # edge anchors are loaded and promoted (~220 puts).
        assert redis2.put_count <= 60 , (
            f"Slice should bound Redis cache promotions; got {redis2.put_count} "
            "puts for [0:50]"
        );

        ctx2.close();
    } finally {
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
    }
}


"""[?:Type, field op const] must work correctly when the backend has no pushdown
capability — FilterSpec falls back to calling its embedded lambda per-node.

This tests the path where execute_path returns None (no persistent origin or
topology index disabled) and refs() falls through to the edge-walk, using
FilterSpec.__call__ → func as the node filter."""
test "field-predicate filter falls back to lambda on non-pushdown backend" {
    orig_base = JacRuntime.get_base_path_dir();
    cfg = JacConfig();
    cfg.run.topology_index = False;
    set_config(cfg);
    JacRuntime.set_base_path("/tmp/_pushdown_fallback");

    try {
        ctx = ExecutionContext();
        JacRuntime.set_context(ctx);

        for i in range(10) {
            root ++> _PushdownLead(idx=i);
        }

        leads = [root-->[?:_PushdownLead, idx<5]];
        assert len(leads) == 5 , f"Expected 5 leads with idx < 5, got {len(leads)}";
        for lead in leads {
            assert lead.idx < 5 , f"Lambda fallback not applied: idx={lead.idx}";
        }

        ctx.close();
    } finally {
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
    }
}


"""Multi-predicate AND (gte + lt on the same field) and eq operator must push
down to MongoDB as a single collection.find() call.

  [?:_PushdownLead, idx >= 20, idx < 50]  → {$gte: 20, $lt: 50}   → 30 docs
  [?:_PushdownLead, idx == 42]            → {$eq: 42}              →  1 doc

Pushdown proof: execute_plan_fetch_count equals the expected result count and
fetch_count remains 0 (batch_get / the floor path was not used)."""
test "field-predicate range and eq operators push down to mongodb" {
    _reset_dbs();
    orig_base = JacRuntime.get_base_path_dir();
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    JacRuntime.set_base_path("/tmp/_pushdown_ops");

    try {
        # --- Phase 1: build 100 leads (idx 0-99), persist ---
        (mem1, mongo1, redis1) = _make_scale_memory();
        ctx1 = ExecutionContext();
        ctx1.mem = mem1;
        ctx1.mem.put(ctx1.system_root);
        JacRuntime.set_context(ctx1);

        for i in range(100) {
            root ++> _PushdownLead(idx=i);
        }
        root_id = root.__jac__.id;
        ctx1.mem.commit();
        ctx1.close();

        # --- Phase 2: range AND (gte + lt on same field) ---
        (mem2, mongo2, redis2) = _make_scale_memory();
        ctx2 = ExecutionContext();
        ctx2.mem = mem2;
        JacRuntime.set_context(ctx2);

        root_anchor = ctx2.mem.get(root_id);
        assert root_anchor is not None;
        r2 = root_anchor.archetype;

        mongo2.reset_counters();
        leads = [r2-->[?:_PushdownLead, idx>=20, idx<50]];

        assert len(leads) == 30 , f"Expected 30 leads (20 ≤ idx < 50), got {len(
            leads
        )}";
        for lead in leads {
            assert lead.idx >= 20 and lead.idx < 50 , (
                f"Range predicate not applied: idx={lead.idx}"
            );
        }
        assert mongo2.execute_plan_fetch_count == 30 , (
            f"Expected execute_plan to fetch 30 docs; got {mongo2.execute_plan_fetch_count}"
        );
        assert mongo2.fetch_count == 0 , (
            f"fetch_count should be 0 (pushdown only); got {mongo2.fetch_count}"
        );

        # eq: idx == 42 → exactly 1 result
        mongo2.reset_counters();
        exact = [r2-->[?:_PushdownLead, idx==42]];

        assert len(exact) == 1 , f"Expected 1 lead with idx == 42, got {len(exact)}";
        assert exact[0].idx == 42 , f"Wrong node returned: idx={exact[0].idx}";
        assert mongo2.execute_plan_fetch_count == 1 , (
            f"Expected 1 doc from execute_plan; got {mongo2.execute_plan_fetch_count}"
        );
        assert mongo2.fetch_count == 0 , (
            f"fetch_count should be 0 (pushdown only); got {mongo2.fetch_count}"
        );

        ctx2.close();
    } finally {
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
    }
}


"""Membership (`in`) and negative-literal predicates must push down too.

  [?:_PushdownLead, idx in [3, 17, 42]]  → {$in: [3, 17, 42]}  → 3 docs
  [?:_PushdownLead, idx < -1]            → {$lt: -1}           → 0 docs (no negatives)

These operators were previously emitted only into the per-node lambda and never
into FilterSpec.predicates, so they silently fell back to the floor path. Proof
of pushdown is identical: execute_plan_fetch_count carries the result and
fetch_count stays 0."""
test "field-predicate membership and negative-literal operators push down to mongodb" {
    _reset_dbs();
    orig_base = JacRuntime.get_base_path_dir();
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    JacRuntime.set_base_path("/tmp/_pushdown_in_neg");

    try {
        # --- Phase 1: build 50 leads (idx 0-49), persist ---
        (mem1, mongo1, redis1) = _make_scale_memory();
        ctx1 = ExecutionContext();
        ctx1.mem = mem1;
        ctx1.mem.put(ctx1.system_root);
        JacRuntime.set_context(ctx1);

        for i in range(50) {
            root ++> _PushdownLead(idx=i);
        }
        root_id = root.__jac__.id;
        ctx1.mem.commit();
        ctx1.close();

        # --- Phase 2: membership pushdown ---
        (mem2, mongo2, redis2) = _make_scale_memory();
        ctx2 = ExecutionContext();
        ctx2.mem = mem2;
        JacRuntime.set_context(ctx2);

        root_anchor = ctx2.mem.get(root_id);
        assert root_anchor is not None;
        r2 = root_anchor.archetype;

        mongo2.reset_counters();
        chosen = [r2-->[?:_PushdownLead, idxin[3,17,42]]];

        assert len(chosen) == 3 , f"Expected 3 leads for `in [3,17,42]`, got {len(
            chosen
        )}";
        for lead in chosen {
            assert lead.idx in [3, 17, 42] , f"Membership not applied: idx={lead.idx}";
        }
        assert mongo2.execute_plan_fetch_count == 3 , (
            f"Expected execute_plan to fetch 3 docs; got {mongo2.execute_plan_fetch_count}"
        );
        assert mongo2.fetch_count == 0 , (
            f"fetch_count should be 0 (pushdown only); got {mongo2.fetch_count}"
        );

        # negative-literal bound: no idx is < -1, so the backend returns nothing.
        mongo2.reset_counters();
        none_match = [r2-->[?:_PushdownLead, idx<-1]];

        assert len(none_match) == 0 , f"Expected 0 leads for `idx < -1`, got {len(
            none_match
        )}";
        assert mongo2.execute_plan_fetch_count == 0 , (
            f"Expected 0 docs from execute_plan; got {mongo2.execute_plan_fetch_count}"
        );
        assert mongo2.fetch_count == 0 , (
            f"fetch_count should be 0 (pushdown only); got {mongo2.fetch_count}"
        );

        ctx2.close();
    } finally {
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
    }
}


"""[?:Type, field op const] must push predicates to MongoDB via execute_plan.

Proof of pushdown: mongo.fetch_count == 0 (execute_plan uses collection.find()
directly, not get/batch_get) AND mongo.execute_plan_fetch_count equals exactly
the number of matching nodes (MongoDB applied the predicate, not Python).

Without pushdown, the floor path would batch_get all neighbors (~110 anchors)
then discard those failing the Python-side filter, so fetch_count would be ~110.
"""
test "field-predicate filter pushes down to mongodb" {
    _reset_dbs();
    orig_base = JacRuntime.get_base_path_dir();
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    JacRuntime.set_base_path("/tmp/_pushdown_field_pred");

    try {
        # --- Phase 1: build graph (100 leads idx 0-99, 10 others) ---
        (mem1, mongo1, redis1) = _make_scale_memory();
        ctx1 = ExecutionContext();
        ctx1.mem = mem1;
        ctx1.mem.put(ctx1.system_root);
        JacRuntime.set_context(ctx1);

        for i in range(100) {
            root ++> _PushdownLead(idx=i);
        }
        for i in range(10) {
            root ++> _PushdownOther(idx=i);
        }
        root_id = root.__jac__.id;
        ctx1.mem.commit();
        ctx1.close();

        # --- Phase 2: fresh context (cold L1+L2), verify field pushdown ---
        (mem2, mongo2, redis2) = _make_scale_memory();
        ctx2 = ExecutionContext();
        ctx2.mem = mem2;
        JacRuntime.set_context(ctx2);

        root_anchor = ctx2.mem.get(root_id);
        assert root_anchor is not None , (
            f"root_anchor not found in Phase 2 memory. root_id={root_id}, "
            f"mongo2.client={mongo2.client is not None}, "
            f"mongo2.collection={mongo2.collection is not None}, "
            f"mongo2.db_name={mongo2.db_name}"
        );
        r2 = root_anchor.archetype;

        mongo2.reset_counters();

        # idx < 50 matches exactly 50 of the 100 leads.
        leads = [r2-->][?:_PushdownLead, idx<50];

        # Correctness: right count and every result satisfies the predicate.
        assert len(leads) == 50 , f"Expected 50 leads with idx < 50, got {len(leads)}";
        for lead in leads {
            assert lead.idx < 50 , f"Predicate not applied: got lead.idx={lead.idx}";
        }

        # Pushdown proof: execute_plan served exactly 50 docs from MongoDB.
        assert mongo2.execute_plan_fetch_count == 50 , (
            f"Expected execute_plan to fetch exactly 50 docs; "
            f"got {mongo2.execute_plan_fetch_count}"
        );

        # fetch_count == 0 confirms the floor path (batch_get) was not used.
        # Without pushdown, batch_get would be called with ~110 IDs.
        assert mongo2.fetch_count == 0 , (
            f"Expected fetch_count=0 (pushdown only); "
            f"got {mongo2.fetch_count} - batch_get was used instead of execute_plan"
        );

        ctx2.close();
    } finally {
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
    }
}
