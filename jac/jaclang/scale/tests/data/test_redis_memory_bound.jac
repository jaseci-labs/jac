"""Verifies the L2 Redis cache keeps its own memory bounded.

The guarantee is not "every key has a TTL"; it is "memory cannot grow without
bound". That holds when either anchor keys expire (redis_default_ttl > 0) or the
server evicts under pressure (maxmemory > 0 with an evicting policy). These tests
assert that guarantee against an unconfigured redis:latest, which the cache must
bound itself via CONFIG SET on first connect.
"""

import contextlib;
import gc;
import os;
import time;
import from pathlib { Path }

import redis;
import from testcontainers.mongodb { MongoDbContainer }
import from testcontainers.redis { RedisContainer }
import from jaclang.scale.tests.server_support {
    call_walker,
    get_free_port,
    register_user,
    start_server
}

glob FIXTURES_DIR = Path(__file__).parent.parent / "fixtures",
     JAC_FILE = FIXTURES_DIR / "race_app.jac";

"""True when the server reports maxmemory > 0 with an evicting policy."""
def server_memory_bounded(client: redis.Redis) -> bool {
    maxmemory = int(client.config_get("maxmemory").get("maxmemory", 0));
    policy = client.config_get("maxmemory-policy").get(
        "maxmemory-policy", "noeviction"
    );
    return maxmemory > 0 and policy != "noeviction";
}

"""Remove the fixture data directory if it exists."""
def clear_data_dir(data_dir: Path) {
    if data_dir.exists() {
        import shutil;
        shutil.rmtree(data_dir);
    }
}

"""With redis_default_ttl defaulting to 3600, every cached key must expire."""
test "L2 Redis: anchor keys carry a TTL under default config" {
    BATCH_SIZE = 20;
    data_dir = FIXTURES_DIR / ".jac" / "data";
    clear_data_dir(data_dir);

    redis_container = RedisContainer("redis:latest");
    redis_container.start();
    redis_host = redis_container.get_container_host_ip();
    redis_port = redis_container.get_exposed_port(6379);
    redis_url = f"redis://{redis_host}:{redis_port}/0";
    os.environ["REDIS_URL"] = redis_url;

    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    os.environ["MONGODB_URI"] = mongo_container.get_connection_url();

    redis_client = redis.from_url(redis_url);
    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        token = register_user(base_url, "ttl_tester");
        call_walker(base_url, "BulkCreate", token, {"count": BATCH_SIZE});
        time.sleep(0.5);

        all_keys = redis_client.keys("*");
        assert len(all_keys) > 0 , (
            "Redis is empty after BulkCreate; commit path is not using Redis."
        );

        no_ttl_keys = [
            k
            for k in all_keys
            if redis_client.ttl(k) == -1
        ];
        assert len(no_ttl_keys) == 0 , (
            f"{len(no_ttl_keys)}/{len(all_keys)} keys have no TTL despite "
            f"redis_default_ttl=3600. Sample: {[k.decode() for k in no_ttl_keys[:5]]}."
        );
    } finally {
        with contextlib.suppress(Exception) {
            redis_client.close();
        }
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }
        os.environ.pop("REDIS_URL", None);
        os.environ.pop("MONGODB_URI", None);
        mongo_container.stop();
        redis_container.stop();
        time.sleep(0.3);
        gc.collect();
        clear_data_dir(data_dir);
    }
}

"""A bare redis:latest starts unbounded; after the cache connects it must
report maxmemory > 0 with an evicting policy, so memory cannot grow forever.
"""
test "L2 Redis: cache self-enforces a memory bound on an unconfigured server" {
    BATCH_SIZE = 10;
    data_dir = FIXTURES_DIR / ".jac" / "data";
    clear_data_dir(data_dir);

    redis_container = RedisContainer("redis:latest");
    redis_container.start();
    redis_host = redis_container.get_container_host_ip();
    redis_port = redis_container.get_exposed_port(6379);
    redis_url = f"redis://{redis_host}:{redis_port}/0";
    os.environ["REDIS_URL"] = redis_url;

    mongo_container = MongoDbContainer("mongo:latest");
    mongo_container.start();
    os.environ["MONGODB_URI"] = mongo_container.get_connection_url();

    redis_client = redis.from_url(redis_url);
    assert not server_memory_bounded(redis_client) , (
        "Precondition failed: redis:latest should start unbounded (maxmemory=0)."
    );

    port = get_free_port();
    base_url = f"http://localhost:{port}";
    server = start_server(FIXTURES_DIR, JAC_FILE, port);

    try {
        token = register_user(base_url, "bound_tester");
        call_walker(base_url, "BulkCreate", token, {"count": BATCH_SIZE});
        time.sleep(0.5);

        assert server_memory_bounded(redis_client) , (
            "Cache did not bound Redis memory: maxmemory="
            f"{redis_client.config_get('maxmemory')}, policy="
            f"{redis_client.config_get('maxmemory-policy')}."
        );
    } finally {
        with contextlib.suppress(Exception) {
            redis_client.close();
        }
        if server {
            server.terminate();
            with contextlib.suppress(Exception) {
                server.wait(timeout=2);
            }
        }
        os.environ.pop("REDIS_URL", None);
        os.environ.pop("MONGODB_URI", None);
        mongo_container.stop();
        redis_container.stop();
        time.sleep(0.3);
        gc.collect();
        clear_data_dir(data_dir);
    }
}
