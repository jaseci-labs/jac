import time;
import from jaclang.scale.state.state_backend { InProcessStateBackend }
import from jaclang.scale.state.redis_state_backend { RedisStateBackend }


obj _FakeRedis {
    has store: dict[str, any] = {};

    def set(
        key: str, value: any, ex: any = None, px: any = None, nx: bool = False
    ) -> any {
        if (ex is not None and ex <= 0) or (px is not None and px <= 0) {
            raise ValueError("invalid expire time in 'set' command");
        }
        if nx and key in self.store {
            return None;
        }
        self.store[key] = value;
        return True;
    }

    def get(key: str) -> any {
        v = self.store.get(key);
        return v.encode("utf-8") if isinstance(v, str) else v;
    }

    def delete(key: str) {
        self.store.pop(key, None);
    }
}


test "redis adapter matches in-process ttl<=0 immediate-expiry without erroring" {
    backends = [RedisStateBackend(client=_FakeRedis()), InProcessStateBackend()];
    for backend in backends {
        backend.set("k", "v", ttl_seconds=0);
        time.sleep(0.02);
        assert backend.get("k") is None;

        assert backend.acquire_lock("lock", 0) is not None;
    }
}


test "a value past its ttl is dropped on read, one without a ttl persists" {
    backend = InProcessStateBackend();
    backend.set("durable", "v");
    backend.set("ephemeral", "v", ttl_seconds=0);
    time.sleep(0.02);
    assert backend.get("durable") == "v";
    assert backend.get("ephemeral") is None;
}


test "acquire_lock is exclusive until released" {
    backend = InProcessStateBackend();
    assert backend.acquire_lock("job", 60);
    assert not backend.acquire_lock("job", 60);
    backend.release_lock("job");
    assert backend.acquire_lock("job", 60);
}


test "increment accumulates atomically and returns the new total" {
    backend = InProcessStateBackend();
    assert backend.increment("counter", 1.0) == 1.0;
    assert backend.increment("counter", 2.5) == 3.5;
}
