"""Deployment-condition value-predicate pushdown: real Jac queries against a
real MongoDB (L3) + Redis (L2) stack via testcontainers.

The stub-backed runtime tests prove the planner logic; this proves the rest
of the stack a deployment actually exercises: `MongoBackend` translating
`field_predicates` into a real `data.archetype.<field>` query, the server
filtering, and the hybrid evaluating fresh L1 nodes locally while pushing only
cold ones. A delegating spy on the live L3 records the exact translated filter
and the row count the server returned.

Requires Docker; runs in the integration CI job. Each test uses its own
node/edge types and resets the containers.
"""

import atexit;
import contextlib;
import os;
import redis;
import from pymongo { MongoClient }
import from testcontainers.mongodb { MongoDbContainer }
import from testcontainers.redis { RedisContainer }

import from jaclang.jac0core.runtime { JacRuntime }
import from jaclang.project.config { JacConfig, set_config }
import from jac_scale.context { JScaleExecutionContext }
import from jac_scale.memory_hierarchy { _plan_to_mongo_filter, _process_cache }
import from jac_scale.db { close_all_db_connections }

glob _shared: dict = {};

node BasicMAcct {
    has balance: int = 0;
}

edge BasicMOwns {}

node CompMAcct {
    has balance: int = 0,
        age: int = 0,
        tier: str = "std";
}

edge CompMOwns {}

node HybMAcct {
    has balance: int = 0;
}

edge HybMOwns {}


"""Lazily start a shared MongoDB container; return (MongoClient, uri)."""
def _get_mongo -> tuple {
    if "mongo_client" not in _shared {
        c = MongoDbContainer("mongo:latest");
        c.start();
        uri = c.get_connection_url();
        _shared["mongo_container"] = c;
        _shared["mongo_uri"] = uri;
        _shared["mongo_client"] = MongoClient(uri);
        atexit.register(c.stop);
    }
    return (_shared["mongo_client"], _shared["mongo_uri"]);
}


"""Lazily start a shared Redis container; return (redis.Redis, url)."""
def _get_redis -> tuple {
    if "redis_client" not in _shared {
        c = RedisContainer("redis:latest", port=6379);
        c.start();
        host = c.get_container_host_ip();
        exposed_port = c.get_exposed_port(6379);
        url = f"redis://{host}:{exposed_port}/0";
        _shared["redis_container"] = c;
        _shared["redis_url"] = url;
        _shared["redis_client"] = redis.Redis(
            host=host, port=int(exposed_port), decode_responses=False
        );
        atexit.register(c.stop);
    }
    return (_shared["redis_client"], _shared["redis_url"]);
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


"""Flush all Redis keys between tests."""
def _reset_redis {
    if "redis_client" in _shared {
        _shared["redis_client"].flushall();
    }
}


"""Fresh JScaleExecutionContext wired to the given Mongo + Redis, with the
topology index enabled so the planner can narrow before pushdown."""
def _new_ctx(mongo_uri: str, redis_url: str) -> JScaleExecutionContext {
    os.environ["MONGODB_URI"] = mongo_uri;
    os.environ["REDIS_URL"] = redis_url;
    _process_cache.clear();
    with contextlib.suppress(Exception) {
        close_all_db_connections();
    }
    cfg = JacConfig();
    cfg.run.topology_index = True;
    set_config(cfg);
    return JScaleExecutionContext();
}


# Delegates to the real MongoBackend but records the translated filter and the
# number of documents the server returned, so tests can assert filtering ran
# DB-side rather than in memory.
obj _SpyMongo {
    has inner: any,
        calls: list = [];

    def capabilities -> set[str] {
        return self.inner.capabilities();
    }

    def execute_plan(plan: any) -> list {
        (filt, _, _) = _plan_to_mongo_filter(plan);
        results = list(self.inner.execute_plan(plan));
        self.calls.append({"filter": filt, "returned": len(results)});
        return results;
    }

    def get(id: any) -> any {
        return self.inner.get(id);
    }

    def put(anchor: any) {
        self.inner.put(anchor);
    }

    def sync {
        self.inner.sync();
    }

    def commit(anchor: any = None) {
        self.inner.commit(anchor);
    }

    def close {
        self.inner.close();
    }
}


"""Flush L1 so the given ids resolve cold (forcing a backend round-trip)."""
def _chill(ctx: any, ids: list) {
    for id in ids {
        ctx.mem.__mem__.pop(id, None);
    }
}


def _comp_threshold -> int {
    return 1500;
}


test "pushdown sends a data.archetype filter to mongo and fetches only matches" {
    _reset_mongo();
    _reset_redis();
    (_, muri) = _get_mongo();
    (_, ruri) = _get_redis();
    ctx = _new_ctx(muri, ruri);
    JacRuntime.set_context(ctx);
    spy = _SpyMongo(inner=ctx.mem.l3);
    try {
        r = root;
        nodes: list = [];
        for i in range(20) {
            n = BasicMAcct(balance=i * 200);
            r +>:BasicMOwns:+> n;
            nodes.append(n);
        }
        ctx.mem.commit();
        _chill(ctx, [n.__jac__.id for n in nodes]);
        ctx.mem.l3 = spy;

        result = [r->:BasicMOwns:->[?:BasicMAcct, balance>3000]];
        vals = sorted([a.balance for a in result]);
        assert vals == [3200, 3400, 3600, 3800] , f"got {vals}";

        assert len(spy.calls) >= 1 , "backend must be queried for the cold partition";
        call = spy.calls[-1];
        assert call["filter"].get("data.archetype.balance") == {"$gt": 3000} , (
            f"predicate not translated for mongo: {call['filter']}"
        );
        assert call["returned"] == 4 , (
            f"server returned {call['returned']} docs, expected only the 4 matches"
        );
    } finally {
        ctx.mem.l3 = spy.inner;
        ctx.close();
        set_config(JacConfig());
    }
}


test "compound and complex predicates translate to mongo filters" {
    _reset_mongo();
    _reset_redis();
    (_, muri) = _get_mongo();
    (_, ruri) = _get_redis();
    ctx = _new_ctx(muri, ruri);
    JacRuntime.set_context(ctx);
    spy = _SpyMongo(inner=ctx.mem.l3);
    try {
        r = root;
        data = [
            (1000, 20, "std"),
            (1500, 25, "gold"),
            (2000, 30, "gold"),
            (2500, 35, "plat"),
            (3000, 40, "std"),
            (3500, 45, "plat")
        ];
        nodes: list = [];
        for (b, a, t) in data {
            n = CompMAcct(balance=b, age=a, tier=t);
            r +>:CompMOwns:+> n;
            nodes.append(n);
        }
        ctx.mem.commit();
        ids = [n.__jac__.id for n in nodes];
        ctx.mem.l3 = spy;

        # Compound range on one field.
        spy.calls = [];
        _chill(ctx, ids);
        r1 = [r->:CompMOwns:->[?:CompMAcct, balance>=1000, balance<2000]];
        assert sorted([a.balance for a in r1]) == [1000, 1500];
        assert spy.calls[-1]["filter"].get("data.archetype.balance") == {
            "$gte": 1000,
            "$lt": 2000
        } , f"got {spy.calls[-1]['filter']}";

        # Compound across two fields.
        spy.calls = [];
        _chill(ctx, ids);
        r2 = [r->:CompMOwns:->[?:CompMAcct, balance>1000, age>=30]];
        assert sorted([a.balance for a in r2]) == [2000, 2500, 3000, 3500];
        f2 = spy.calls[-1]["filter"];
        assert f2.get("data.archetype.balance") == {"$gt": 1000} , f"got {f2}";
        assert f2.get("data.archetype.age") == {"$gte": 30} , f"got {f2}";

        # Membership (`in`) -> `$in` is covered in the filter-dict unit test;
        # it can't run as a real query here because `jac format` corrupts
        # `field in [...]` inside a filter comprehension (drops the space).

        # Computed comparator pushes its resolved value.
        spy.calls = [];
        _chill(ctx, ids);
        r4 = [r->:CompMOwns:->[?:CompMAcct, balance>_comp_threshold()]];
        assert sorted([a.balance for a in r4]) == [2000, 2500, 3000, 3500];
        assert spy.calls[-1]["filter"].get("data.archetype.balance") == {"$gt": 1500} , f"got {spy.calls[
            -1
        ]['filter']}";
    } finally {
        ctx.mem.l3 = spy.inner;
        ctx.close();
        set_config(JacConfig());
    }
}


test "hybrid evaluates fresh L1 nodes locally and pushes only cold ids" {
    _reset_mongo();
    _reset_redis();
    (_, muri) = _get_mongo();
    (_, ruri) = _get_redis();
    ctx = _new_ctx(muri, ruri);
    JacRuntime.set_context(ctx);
    spy = _SpyMongo(inner=ctx.mem.l3);
    try {
        r = root;
        nodes: list = [];
        for i in range(10) {
            n = HybMAcct(balance=i * 100);
            r +>:HybMOwns:+> n;
            nodes.append(n);
        }
        ctx.mem.commit();

        # Even-indexed evict to cold (their synced value is authoritative);
        # odd-indexed stay resident in L1.
        cold_ids: set = set();
        resident_ids: set = set();
        for (i, n) in enumerate(nodes) {
            anchor = n.__jac__;
            if i % 2 == 0 {
                cold_ids.add(str(anchor.id));
                ctx.mem.__mem__.pop(anchor.id, None);
            } else {
                resident_ids.add(str(anchor.id));
            }
        }
        ctx.mem.l3 = spy;

        # A resident node mutated this session (not re-synced) must be judged on
        # its live value, not the stale 100 sitting in mongo.
        nodes[1].balance = 999;

        result = [r->:HybMOwns:->[?:HybMAcct, balance>500]];
        vals = sorted([a.balance for a in result]);
        # Resident odd live {999, 300, 500, 700, 900} pass: 999, 700, 900.
        # Cold even {0, 200, 400, 600, 800} pass via mongo: 600, 800.
        assert vals == [600, 700, 800, 900, 999] , f"got {vals}";

        assert len(spy.calls) >= 1 , "cold partition must hit mongo";
        sent_ids = set();
        for call in spy.calls {
            in_clause = call["filter"].get("_id", {}).get("$in", []);
            sent_ids.update(in_clause);
        }
        assert sent_ids == cold_ids , (
            f"mongo asked about {sent_ids}, expected only cold {cold_ids}"
        );
        assert not (sent_ids & resident_ids) , "fresh L1 nodes must not be pushed";
        assert 999 in vals , "live L1 value must win over the stale mongo snapshot";
    } finally {
        ctx.mem.l3 = spy.inner;
        ctx.close();
        set_config(JacConfig());
    }
}
