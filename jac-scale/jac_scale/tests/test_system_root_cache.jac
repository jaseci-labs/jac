"""Tests for process-level system root cache in JScaleExecutionContext.

After the fix in context.impl.jac, _process_cache['system_root'] is populated
on the first JScaleExecutionContext init and pre-injected into L1 on every
subsequent init so the system root lookup never reaches MongoDB past request 1.

All tests here are in-process: no server subprocess needed. Each test spins
up a real MongoDB testcontainer and creates JScaleExecutionContext directly,
measuring MongoBackend.fetch_count to count L3 round-trips precisely.
"""

import contextlib;
import gc;
import os;

import from testcontainers.mongodb { MongoDbContainer }
import from jac_scale.context { JScaleExecutionContext }
import from jac_scale.memory_hierarchy { _process_cache, MongoBackend }
import from jac_scale.db { close_all_db_connections }


"""Wipe process-level singletons so each test starts from a cold state."""
def _reset {
    _process_cache.clear();
    with contextlib.suppress(Exception) {
        close_all_db_connections();
    }
}

"""Create a JScaleExecutionContext pointed at the given MongoDB URI."""
def _new_ctx(mongo_uri: str) -> JScaleExecutionContext {
    os.environ["MONGODB_URI"] = mongo_uri;
    os.environ.pop("REDIS_URL", None);
    return JScaleExecutionContext();
}

"""Return the number of L3 (MongoDB) fetches this context's backend made."""
def _l3_fetch_count(ctx: JScaleExecutionContext) -> int {
    l3 = ctx.mem.l3;
    if isinstance(l3, MongoBackend) {
        return l3.fetch_count;
    }
    return 0;
}


"""After the very first JScaleExecutionContext(), _process_cache['system_root']
must hold a NodeAnchor whose id equals SUPER_ROOT_UUID."""
test "_process_cache populated with system root after first context init" {
    import from uuid { UUID }
    import from jaclang.jac0core.constant { Constants as Con }
    import from jaclang.jac0core.archetype { NodeAnchor }

    _reset();
    assert "system_root" not in _process_cache;

    mongo = MongoDbContainer("mongo:latest");
    mongo.start();
    try {
        _new_ctx(mongo.get_connection_url());

        assert "system_root" in _process_cache , (
            "_process_cache must contain 'system_root' after first context init"
        );
        cached = _process_cache["system_root"];
        assert isinstance(cached, NodeAnchor) , (
            f"Cached value must be a NodeAnchor, got {type(cached).__name__}"
        );
        assert cached.id == UUID(Con.SUPER_ROOT_UUID) , (
            f"Cached anchor id {cached.id} != SUPER_ROOT_UUID"
        );
    } finally {
        _reset();
        mongo.stop();
        gc.collect();
    }
}


"""First init must fetch the system root from MongoDB (fetch_count >= 1).
Second init must find it in L1 from the process cache (fetch_count == 0).

Each JScaleExecutionContext creates a fresh MongoBackend with fetch_count=0,
so the count measured is per-context, not cumulative.
"""
test "first context init hits MongoDB; second does not" {
    _reset();

    mongo = MongoDbContainer("mongo:latest");
    mongo.start();
    try {
        uri = mongo.get_connection_url();

        ctx1 = _new_ctx(uri);
        first_fetches = _l3_fetch_count(ctx1);
        assert first_fetches >= 1 , (
            f"First context init must fetch system root from MongoDB "
            f"(got fetch_count={first_fetches})"
        );
        assert "system_root" in _process_cache , (
            "Cache must be warm after first init"
        );

        ctx2 = _new_ctx(uri);
        second_fetches = _l3_fetch_count(ctx2);
        assert second_fetches == 0 , (
            f"Second context init issued {second_fetches} MongoDB fetch(es) "
            "for system root, expected 0. "
            "_process_cache pre-injection into L1 is not working."
        );
    } finally {
        _reset();
        mongo.stop();
        gc.collect();
    }
}


"""When _process_cache is empty (fresh process), context init must succeed
and set system_root, user_root, and entry_node correctly."""
test "cold cache still produces a valid system root" {
    import from uuid { UUID }
    import from jaclang.jac0core.constant { Constants as Con }

    _reset();

    mongo = MongoDbContainer("mongo:latest");
    mongo.start();
    try {
        ctx = _new_ctx(mongo.get_connection_url());

        assert ctx.system_root is not None , "system_root must not be None";
        assert ctx.system_root.id == UUID(Con.SUPER_ROOT_UUID) , (
            f"system_root.id {ctx.system_root.id} != SUPER_ROOT_UUID"
        );
        assert ctx.user_root is ctx.system_root , (
            "user_root must default to system_root before auth"
        );
        assert ctx.entry_node is ctx.system_root , (
            "entry_node must default to system_root before auth"
        );
    } finally {
        _reset();
        mongo.stop();
        gc.collect();
    }
}


"""After the first init warms the cache, inits 2..N must each cost 0 fetches.
Total MongoDB fetches for the system root across N inits equals the first
init's fetch count, not N times that."""
test "N consecutive context inits cost exactly one system root MongoDB fetch total" {
    N = 10;

    _reset();

    mongo = MongoDbContainer("mongo:latest");
    mongo.start();
    try {
        uri = mongo.get_connection_url();

        ctx_first = _new_ctx(uri);
        first_cost = _l3_fetch_count(ctx_first);
        assert first_cost >= 1 , "First init must fetch from MongoDB";

        total_extra = 0;
        for i in range(N - 1) {
            ctx = _new_ctx(uri);
            extra = _l3_fetch_count(ctx);
            total_extra += extra;
            assert extra == 0 , (
                f"Context init #{i + 2} of {N} issued {extra} MongoDB fetch(es) "
                "for system root. Expected 0 — cache should be warm."
            );
        }

        assert total_extra == 0 , (
            f"Inits 2..{N} collectively issued {total_extra} MongoDB fetches "
            "for system root; expected 0."
        );
    } finally {
        _reset();
        mongo.stop();
        gc.collect();
    }
}
