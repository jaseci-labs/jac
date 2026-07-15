import atexit;
import os;
import from typing { cast }
import from pathlib { Path }
import redis;
import from pymongo { MongoClient }
import from testcontainers.mongodb { MongoDbContainer }
import from testcontainers.redis { RedisContainer }

import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.runtimelib.context { ExecutionContext }
import from jaclang.project.config { JacConfig, set_config }
import from jaclang.scale.memory.memory_hierarchy {
    MongoBackend,
    RedisBackend,
    ScaleTieredMemory
}


node _PushdownLead {
    has idx: int = 0;
}

node _PushdownOther {
    has idx: int = 0;
}


glob _shared: dict = {};


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


def _make_scale_memory -> tuple {
    mongo_uri = _get_mongo_uri();
    redis_url = _get_redis_url();

    os.environ["JAC_MONGO_URL"] = mongo_uri;
    os.environ["JAC_REDIS_URL"] = redis_url;

    mongo = MongoBackend(mongo_url=mongo_uri, db_name="jac_pushdown_test");
    redis_be = RedisBackend(redis_url=redis_url);
    mem = ScaleTieredMemory();

    mem.l2 = redis_be;
    mem.l3 = mongo;
    mem._cache_available = True;
    return (mem, mongo, redis_be);
}


"""Bind a fresh tiered mongo/redis memory to `ctx`, returning its backends."""
def _bind_scale_memory(ctx: ExecutionContext, persist_root: bool) -> tuple {
    (mem, mongo, redis_be) = _make_scale_memory();
    ctx.mem = mem;
    if persist_root {
        # The context's root is created against the default memory, so register
        # it with the tiered memory that actually commits or it is never saved.
        mem.put(ctx.system_root);
    }
    JacRuntime.set_context(ctx);
    return (mongo, redis_be);
}


def _seed_pushdown_graph {
    for i in range(100) {
        root ++> _PushdownLead(idx=i);
    }
    for i in range(20) {
        root ++> _PushdownOther(idx=i);
    }
}


def _close_ctx(ctx: (ExecutionContext | None)) {
    if ctx is not None {
        cast(ExecutionContext, ctx).close();
    }
}


test "edge-ref slice bounds mongodb fetches" {
    _reset_dbs();
    orig_base = JacRuntime.get_base_path_dir();
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    JacRuntime.set_base_path("/tmp/_pushdown_mongo");

    ctx1: (ExecutionContext | None) = None;
    ctx2: (ExecutionContext | None) = None;
    try {
        ctx1 = ExecutionContext();
        (mongo1, redis1) = _bind_scale_memory(ctx1, persist_root=True);

        _seed_pushdown_graph();
        root_id = root.__jac__.id;
        ctx1.mem.commit();
        ctx1.close();
        ctx1 = None;

        # Drop the L2 cache so the slice is served from mongo, making the fetch
        # count reflect what the database is actually asked to load.
        _shared["redis_client"].flushall();

        ctx2 = ExecutionContext();
        (mongo2, redis2) = _bind_scale_memory(ctx2, persist_root=False);

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
    } finally {
        _close_ctx(ctx2);
        _close_ctx(ctx1);
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
    }
}


test "edge-ref slice bounds redis cache promotions" {
    _reset_dbs();
    orig_base = JacRuntime.get_base_path_dir();
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    JacRuntime.set_base_path("/tmp/_pushdown_redis");

    ctx1: (ExecutionContext | None) = None;
    ctx2: (ExecutionContext | None) = None;
    try {
        ctx1 = ExecutionContext();
        (mongo1, redis1) = _bind_scale_memory(ctx1, persist_root=True);

        _seed_pushdown_graph();
        root_id = root.__jac__.id;
        ctx1.mem.commit();
        ctx1.close();
        ctx1 = None;

        _shared["redis_client"].flushall();

        ctx2 = ExecutionContext();
        (mongo2, redis2) = _bind_scale_memory(ctx2, persist_root=False);

        root_anchor = ctx2.mem.get(root_id);
        assert root_anchor is not None;
        r2 = root_anchor.archetype;

        redis2.reset_counters();

        leads = [r2-->][?:_PushdownLead][0:50];
        assert len(leads) == 50;

        assert redis2.put_count <= 60 , (
            f"Slice should bound Redis cache promotions; got {redis2.put_count} "
            "puts for [0:50]"
        );
    } finally {
        _close_ctx(ctx2);
        _close_ctx(ctx1);
        JacRuntime.set_base_path(orig_base);
        set_config(JacConfig());
    }
}
