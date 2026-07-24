import contextlib;
import logging;
import from logging.handlers { MemoryHandler }
import from testcontainers.redis { RedisContainer }
import from jaclang.scale.persistence.db { close_all_db_connections, get_redis_client }
import from jaclang.scale.events.broker { Event }
import from jaclang.scale.events.streams.redis { RedisEventStream }
import from jaclang.scale.deploy.database.kubernetes_redis { KubernetesRedisProvider }


glob _redis_container = RedisContainer("redis:7.2-alpine"),
     REDIS_URI: str = "",
     CACHE_PAYLOAD: str = "x" * 4000,
     CACHE_KEYS: int = 4000,
     SMALL_MAXMEMORY: str = "8mb";

with entry {
    _redis_container.start();
}

glob REDIS_URI = (
         f"redis://{_redis_container.get_container_host_ip()}:"
         f"{_redis_container.get_exposed_port(6379)}/0"
     );


def cleanup_connections {
    with contextlib.suppress(Exception) {
        close_all_db_connections();
    }
}


def _make_broker(group: str, stream_maxlen: int = 10000) -> RedisEventStream {
    b = RedisEventStream(
        config={
            "url": REDIS_URI,
            "consumer_group": group,
            "stream_maxlen": stream_maxlen
        }
    );
    b.start();
    return b;
}


def _reset_redis {
    client = get_redis_client(REDIS_URI);
    client.config_set("maxmemory", "0");
    client.config_set("maxmemory-policy", "noeviction");
    client.flushall();
}


def _apply_memory_policy(max_memory: str, policy: str) {
    client = get_redis_client(REDIS_URI);
    client.config_set("maxmemory", max_memory);
    client.config_set("maxmemory-policy", policy);
}


def _fill_cache(ttl: int) -> tuple[int, str | None] {
    client = get_redis_client(REDIS_URI);
    before = int(client.info("stats")["evicted_keys"]);
    write_error: str | None = None;
    for i in range(CACHE_KEYS) {
        try {
            if ttl > 0 {
                client.setex(f"anchor:{i}", ttl, CACHE_PAYLOAD);
            } else {
                client.set(f"anchor:{i}", CACHE_PAYLOAD);
            }
        } except Exception as e {
            write_error = str(e);
            break;
        }
    }
    evicted = int(client.info("stats")["evicted_keys"]) - before;
    return (evicted, write_error);
}


def _buffer_event(broker: RedisEventStream, topic: str, group: str) {
    broker.consume(topic, group=group, max_messages=1, timeout_seconds=0.1);
    broker.publish(topic, Event(event_type="run.chunk", data={"turn": 1}));
}


def _attach_log_capture -> MemoryHandler {
    handler = MemoryHandler(capacity=10000, flushLevel=logging.CRITICAL + 1);
    logging.getLogger().addHandler(handler);
    return handler;
}


def _captured(handler: MemoryHandler, level: int, needle: str) -> bool {
    logging.getLogger().removeHandler(handler);
    return any(
        record.levelno == level and needle in record.getMessage()
        for record in handler.buffer
    );
}


test "allkeys-lru evicts an idle run stream and loses its buffered events" {
    _reset_redis();
    b = _make_broker(group="jc.coder.peer.lru");
    _buffer_event(b, "jc.run.lru", "jc.coder.peer.lru");

    _apply_memory_policy(SMALL_MAXMEMORY, "allkeys-lru");
    (evicted, write_error) = _fill_cache(3600);

    assert evicted > 0 , "cache pressure must actually evict under allkeys-lru";
    assert write_error is None , "allkeys-lru must keep accepting cache writes";
    assert get_redis_client(REDIS_URI).exists("jc.run.lru") == 0 , (
        "allkeys-lru is expected to evict the idle run stream"
    );

    lost = b.consume(
        "jc.run.lru",
        group="jc.coder.peer.lru",
        max_messages=10,
        timeout_seconds=1.0,
        start_from="earliest"
    );
    assert lost == [] , "evicted stream cannot deliver its buffered events";

    b.stop(drain=False);
    _reset_redis();
    cleanup_connections();
}


test "volatile-lru keeps an idle run stream through the same cache pressure" {
    _reset_redis();
    b = _make_broker(group="jc.coder.peer.vol");
    _buffer_event(b, "jc.run.vol", "jc.coder.peer.vol");

    _apply_memory_policy(SMALL_MAXMEMORY, "volatile-lru");
    (evicted, write_error) = _fill_cache(3600);

    assert evicted > 0 , "cache pressure must actually evict under volatile-lru";
    assert write_error is None , (
        "volatile-lru must keep accepting cache writes while TTL keys are evictable"
    );
    assert get_redis_client(REDIS_URI).exists("jc.run.vol") == 1 , (
        "volatile-lru must not evict a stream that carries no TTL"
    );

    delivered = b.consume(
        "jc.run.vol",
        group="jc.coder.peer.vol",
        max_messages=10,
        timeout_seconds=2.0,
        start_from="earliest"
    );
    assert len(delivered) == 1 , "buffered events must survive cache pressure";
    assert delivered[0].data["turn"] == 1;

    b.stop(drain=False);
    _reset_redis();
    cleanup_connections();
}


test "volatile-lru without cache ttls rejects writes once full" {
    _reset_redis();
    _apply_memory_policy(SMALL_MAXMEMORY, "volatile-lru");
    (evicted, write_error) = _fill_cache(0);

    assert evicted == 0 , "no key carries a TTL, so nothing is evictable";
    assert write_error is not None , (
        "volatile-lru degenerates into noeviction when no key expires"
    );
    assert "maxmemory" in write_error;

    _reset_redis();
    cleanup_connections();
}


test "provisioned redis settings keep run streams through cache pressure" {
    _reset_redis();
    provider = KubernetesRedisProvider(config={'app_name': 'evict-test'});
    db_config = {'redis_memory_limit': '16Mi'};

    max_memory = provider._resolve_max_memory(db_config);
    default_ttl = provider._resolve_default_ttl(db_config);
    policy = provider._resolve_eviction_policy(db_config, default_ttl);

    assert int(max_memory) == int(16 * 1024 ** 2 * 0.7) , (
        "maxmemory must be derived from the pod memory limit"
    );
    assert policy == 'volatile-lru';
    assert default_ttl > 0;

    b = _make_broker(group="jc.coder.peer.gen");
    _buffer_event(b, "jc.run.gen", "jc.coder.peer.gen");

    _apply_memory_policy(max_memory, policy);
    (evicted, write_error) = _fill_cache(default_ttl);

    assert evicted > 0;
    assert write_error is None;
    delivered = b.consume(
        "jc.run.gen",
        group="jc.coder.peer.gen",
        max_messages=10,
        timeout_seconds=2.0,
        start_from="earliest"
    );
    assert len(delivered) == 1 , (
        "the provisioned defaults must protect an active run's events"
    );

    b.stop(drain=False);
    _reset_redis();
    cleanup_connections();
}


test "publish trims a stream to the configured maxlen" {
    _reset_redis();
    b = _make_broker(group="t_maxlen", stream_maxlen=100);
    for i in range(600) {
        b.publish("trimmed", Event(event_type="x", data={"n": i}));
    }

    length = get_redis_client(REDIS_URI).xlen("trimmed");
    assert length < 600 , "streams must be trimmed on publish";
    assert length >= 100 , "trimming must not drop below the configured maxlen";

    b.stop(drain=False);
    _reset_redis();
    cleanup_connections();
}


test "stream loss is reported as an error" {
    _reset_redis();
    b = _make_broker(group="t_loss");
    _buffer_event(b, "loss.topic", "t_loss");
    get_redis_client(REDIS_URI).delete("loss.topic");

    handler = _attach_log_capture();
    b.consume("loss.topic", group="t_loss", max_messages=1, timeout_seconds=0.5);

    assert _captured(handler, logging.ERROR, "Event loss on loss.topic") , (
        "a vanished stream must be reported as data loss, not a silent empty read"
    );

    b.stop(drain=False);
    _reset_redis();
    cleanup_connections();
}


test "broker warns when the connected redis can evict streams" {
    _reset_redis();
    _apply_memory_policy(SMALL_MAXMEMORY, "allkeys-lru");

    handler = _attach_log_capture();
    b = _make_broker(group="t_policy");
    b.publish("policy.topic", Event(event_type="x", data={"n": 1}));

    assert _captured(handler, logging.WARNING, "maxmemory-policy is 'allkeys-lru'") , (
        "an evictable stream configuration must be reported at startup"
    );

    b.stop(drain=False);
    _reset_redis();
    cleanup_connections();
}


test "health reports the eviction settings of the connected redis" {
    _reset_redis();
    _apply_memory_policy(SMALL_MAXMEMORY, "volatile-lru");
    b = _make_broker(group="t_health");

    h = b.health();
    assert h.healthy is True;
    assert h.details["maxmemory-policy"] == "volatile-lru";
    assert h.details["evicted_keys"] is not None;

    b.stop(drain=False);
    _reset_redis();
    cleanup_connections();
}
