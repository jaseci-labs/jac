import time;
import unittest;
import from jaclang.scale.state.state_backend { InProcessStateBackend }
import from jaclang.scale.state.redis_state_backend { RedisStateBackend }
import from testcontainers.redis { RedisContainer }

# A real Redis, not a hand-rolled fake: the fake could only ever assert the
# semantics its author already assumed (ttl<=0, SET NX PX, incrbyfloat). Every
# lock/ttl/increment test below runs against the real backend AND the in-process
# one, so the two implementations must actually agree.
glob _redis_client: any = None;

with entry {
    try {
        _container = RedisContainer("redis:7");
        _container.start();
        _redis_client = _container.get_client();
    } except Exception as e {
        print(f"[skip] Redis container unavailable: {e}");
    }
}


def _both_backends -> list {
    if _redis_client is None {
        raise unittest.SkipTest("Redis container unavailable");
    }
    _redis_client.flushdb();
    return [RedisStateBackend(client=_redis_client), InProcessStateBackend()];
}


test "ttl<=0 drops the key immediately without erroring (redis + in-process parity)" {
    for backend in _both_backends() {
        backend.set("k", "v", ttl_seconds=0);
        time.sleep(0.02);
        assert backend.get("k") is None;

        assert backend.acquire_lock("lock", 0) is not None;
    }
}


test "a value with a ttl persists until it lapses, one without a ttl stays (redis + in-process)" {
    for backend in _both_backends() {
        backend.set("durable", "v");
        backend.set("ephemeral", "v", ttl_seconds=60);
        assert backend.get("durable") == "v";
        assert backend.get("ephemeral") == "v";
    }
}


test "acquire_lock is exclusive until released (redis + in-process)" {
    for backend in _both_backends() {
        assert backend.acquire_lock("job", 60);
        assert not backend.acquire_lock("job", 60);
        backend.release_lock("job");
        assert backend.acquire_lock("job", 60);
    }
}


test "increment accumulates atomically and returns the new total (redis + in-process)" {
    for backend in _both_backends() {
        assert backend.increment("counter", 1.0) == 1.0;
        assert backend.increment("counter", 2.5) == 3.5;
    }
}
