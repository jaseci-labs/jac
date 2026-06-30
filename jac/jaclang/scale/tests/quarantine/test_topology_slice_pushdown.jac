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


test "edge-ref slice bounds mongodb fetches" {
    _reset_dbs();
    orig_base = JacRuntime.get_base_path_dir();
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    JacRuntime.set_base_path("/tmp/_pushdown_mongo");

    try {
        (mem1, mongo1, redis1) = _make_scale_memory();
        ctx1 = ExecutionContext();
        ctx1.mem = mem1;
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

        (mem2, mongo2, redis2) = _make_scale_memory();
        ctx2 = ExecutionContext();
        ctx2.mem = mem2;
        JacRuntime.set_context(ctx2);

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


test "edge-ref slice bounds redis cache promotions" {
    _reset_dbs();
    orig_base = JacRuntime.get_base_path_dir();
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    JacRuntime.set_base_path("/tmp/_pushdown_redis");

    try {
        (mem1, mongo1, redis1) = _make_scale_memory();
        ctx1 = ExecutionContext();
        ctx1.mem = mem1;
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

        _shared["redis_client"].flushall();

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
