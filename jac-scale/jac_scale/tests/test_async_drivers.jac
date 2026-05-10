"""
Correctness tests for native async drivers.

Proves that MongoBackend.aget/acommit (Motor) and RedisBackend.aget/aput
(redis.asyncio) actually read and write anchor data, not just that the
methods exist, but that round-trips produce the correct values.

Requires running MongoDB and Redis via testcontainers (installed via [test]).
"""
import asyncio;
import from typing { Any }
import from uuid { UUID }
import from jaclang.runtimelib.serializer { Serializer }
import from jac_scale.memory_hierarchy { MongoBackend, RedisBackend }
import from jaclang.runtimelib.utils { storage_key }

glob _mongo_uri: (str | None) = None,
     _redis_url: (str | None) = None;

node CounterNode {
    has value: int = 0;
}

import from testcontainers.mongodb { MongoDbContainer }
import from testcontainers.redis { RedisContainer }

with entry {
    try {
        _mongo_container = MongoDbContainer("mongo:7");
        _mongo_container.start();
        _mongo_uri = _mongo_container.get_connection_url();
    } except Exception as e {
        print(f"[skip] MongoDB container failed: {e}");
    }
    try {
        _redis_container = RedisContainer("redis:7");
        _redis_container.start();
        _redis_url = f"redis://{_redis_container.get_container_host_ip()}:{_redis_container.get_exposed_port(
            6379
        )}";
    } except Exception as e {
        print(f"[skip] Redis container failed: {e}");
    }
}

test "MongoBackend.aget retrieves stored anchor via Motor" {
    if _mongo_uri is None {
        print("[skip] MongoDB unavailable");
        return;
    }
    counter = CounterNode(value=42);
    anchor = counter.__jac__;
    anchor.persistent = True;
    backend = MongoBackend(mongo_url=_mongo_uri, db_name="jac_async_test");
    backend.postinit();
    backend.set_memory_ref({anchor.id: anchor});
    backend.sync();

    async def _read -> object {
        return await backend.aget(anchor.id);
    }
    result = asyncio.run(_read());

    assert result is not None , "aget returned None - Motor read failed";
    assert isinstance(result.archetype, CounterNode);
    assert result.archetype.value == 42;
    backend.close();
}

test "MongoBackend.acommit persists modified anchor via Motor" {
    if _mongo_uri is None {
        print("[skip] MongoDB unavailable");
        return;
    }
    counter = CounterNode(value=99);
    anchor = counter.__jac__;
    anchor.persistent = True;
    backend = MongoBackend(mongo_url=_mongo_uri, db_name="jac_async_test2");
    backend.postinit();
    mem: dict[UUID, Any] = {anchor.id: anchor};
    backend.set_memory_ref(mem);

    async def _commit {
        await backend.acommit();
    }
    asyncio.run(_commit());

    backend2 = MongoBackend(mongo_url=_mongo_uri, db_name="jac_async_test2");
    backend2.postinit();
    result = backend2.get(anchor.id);
    assert result is not None , "acommit did not persist anchor";
    assert result.archetype.value == 99;
    backend.close();
    backend2.close();
}

test "RedisBackend.aput and aget round-trip via redis.asyncio" {
    if _redis_url is None {
        print("[skip] Redis unavailable");
        return;
    }
    counter = CounterNode(value=7);
    anchor = counter.__jac__;
    anchor.persistent = True;

    backend = RedisBackend(redis_url=_redis_url);
    backend.postinit();

    async def _roundtrip -> object {
        await backend.aput(anchor);
        return await backend.aget(anchor.id);
    }
    result = asyncio.run(_roundtrip());

    assert result is not None , "aget returned None after aput";
    assert isinstance(result.archetype, CounterNode);
    assert result.archetype.value == 7;
    backend.close();
}
