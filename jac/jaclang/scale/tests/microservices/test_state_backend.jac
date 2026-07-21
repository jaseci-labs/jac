import os;
import shutil;
import tempfile;
import time;
import unittest;
import jaclang.scale.state.factory as state_factory;
import from pathlib { Path }
import from jaclang.scale.state.state_backend { InProcessStateBackend }
import from jaclang.scale.state.redis_state_backend { RedisStateBackend }
import from jaclang.scale.config.config_loader { get_scale_config, reset_scale_config }
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


# --- get_state_backend() selection logic ------------------------------------
# These exercise the factory itself, which the parity tests above bypass by
# constructing the concrete backends directly. get_state_backend caches its
# choice in a module-level holder, so every test clears it first to observe a
# real fresh selection.

def _seed_no_redis_config -> str {
    # A real jac.toml with no redis_url, pointed at get_scale_config(), so the
    # factory's Redis branch resolves against genuine config and finds nothing.
    project_dir = tempfile.mkdtemp(prefix="jac-state-factory-test-");
    (Path(project_dir) / "jac.toml").write_text(
        "[project]\nname = \"state-factory-test\"\nentry-point = \"main.jac\"\n"
    );
    reset_scale_config();
    get_scale_config(project_dir=Path(project_dir));
    return project_dir;
}


def _teardown_config(project_dir: str) {
    reset_scale_config();
    shutil.rmtree(project_dir, ignore_errors=True);
}


test "get_state_backend(scale_enabled=False) selects the in-process backend" {
    state_factory._backend_holder.clear();
    backend = state_factory.get_state_backend(scale_enabled=False);
    assert isinstance(backend, InProcessStateBackend);
    assert not isinstance(backend, RedisStateBackend);
    state_factory._backend_holder.clear();
}


test "get_state_backend() defaults to the in-process backend" {
    state_factory._backend_holder.clear();
    backend = state_factory.get_state_backend();
    assert isinstance(backend, InProcessStateBackend);
    state_factory._backend_holder.clear();
}


test "get_state_backend memoizes the first backend across later calls" {
    state_factory._backend_holder.clear();
    first = state_factory.get_state_backend(scale_enabled=False);
    # A later scale_enabled=True call must NOT re-select: the holder is sticky.
    second = state_factory.get_state_backend(scale_enabled=True);
    assert second is first;
    assert isinstance(second, InProcessStateBackend);
    state_factory._backend_holder.clear();
}


test "get_state_backend(scale_enabled=True) with a redis URL selects the redis backend" {
    state_factory._backend_holder.clear();
    prev = os.environ.get("REDIS_URL");
    # A resolvable URL is enough: Redis.from_url is lazy, so no live server is
    # contacted at selection time - the factory returns a RedisStateBackend.
    os.environ["REDIS_URL"] = "redis://localhost:6379/0";
    try {
        backend = state_factory.get_state_backend(scale_enabled=True);
        assert isinstance(backend, RedisStateBackend);
    } finally {
        if prev is None {
            os.environ.pop("REDIS_URL", None);
        } else {
            os.environ["REDIS_URL"] = prev;
        }
        state_factory._backend_holder.clear();
    }
}


test "get_state_backend(scale_enabled=True) with no redis URL falls back to in-process" {
    state_factory._backend_holder.clear();
    prev = os.environ.get("REDIS_URL");
    os.environ.pop("REDIS_URL", None);
    project_dir = _seed_no_redis_config();
    try {
        backend = state_factory.get_state_backend(scale_enabled=True);
        assert isinstance(backend, InProcessStateBackend);
    } finally {
        _teardown_config(project_dir);
        if prev is not None {
            os.environ["REDIS_URL"] = prev;
        }
        state_factory._backend_holder.clear();
    }
}
