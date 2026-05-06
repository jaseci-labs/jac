"""Integration tests for RedisStreamsBroker against a real Redis (testcontainers).

Mirrors test_direct_db.jac: spins up a Redis container once at import,
exposes its URI as a global, and exercises the broker end-to-end.

Coverage:
- publish then consume roundtrips an event with all envelope fields
- ack advances the consumer-group offset (no redelivery after ack)
- subscribe drives a handler from a daemon consumer thread
- retry-exhaustion sends the event to the dead-letter stream
- health() returns healthy=True with the right backend label
"""

import contextlib;
import time;
import threading;
import from testcontainers.redis { RedisContainer }
import from jac_scale.db { close_all_db_connections, get_redis_client }
import from jac_scale.abstractions.pubsub { Event, RetryPolicy }
import from jac_scale.utilities.pubsub.redis_streams_broker {
    RedisStreamsBroker
}


def cleanup_connections {
    with contextlib.suppress(Exception) {
        close_all_db_connections();
    }
}


# Session-scoped container, mirrors test_direct_db.jac
glob _redis_container = RedisContainer("redis:7.2-alpine"),
     REDIS_URI: str = "";

with entry {
    _redis_container.start();
}

glob REDIS_URI = (
         f"redis://{_redis_container.get_container_host_ip()}:"
         f"{_redis_container.get_exposed_port(6379)}/0"
     );


def _make_broker(group: str = "test_group", retry: dict | None = None) -> RedisStreamsBroker {
    cfg: dict = {
        "url": REDIS_URI,
        "consumer_group": group,
        "retry": retry or {
            "max_attempts": 3,
            "backoff_seconds": [0.01, 0.01, 0.01],
            "dead_letter_suffix": ".dlq"
        }
    };
    b = RedisStreamsBroker(config=cfg);
    b.start();
    return b;
}


def _flush_redis {
    # Each test gets a fresh keyspace so streams from prior tests don't leak.
    client = get_redis_client(REDIS_URI);
    client.flushdb();
}


# --- publish + consume roundtrip ---

test "publish then consume roundtrips event fields" {
    _flush_redis();
    b = _make_broker(group="t_rt");

    sent = Event(
        event_type="orders.placed",
        data={"order_id": 42, "amount": 99.5},
        source="test",
        trace_id="trace-1",
        headers={"x-tenant": "acme"}
    );
    b.publish("orders", sent);

    received = b.consume("orders", group="t_rt", max_messages=1, timeout_seconds=2.0);
    assert len(received) == 1;
    got = received[0];
    assert got.event_type == "orders.placed";
    assert got.data["order_id"] == 42;
    assert got.data["amount"] == 99.5;
    assert got.id == sent.id;
    assert got.source == "test";
    assert got.trace_id == "trace-1";
    assert got.headers["x-tenant"] == "acme";

    b.ack(got);
    b.stop(drain=False);
    cleanup_connections();
}


# --- ack semantics ---

test "ack prevents redelivery in same group" {
    _flush_redis();
    b = _make_broker(group="t_ack");
    b.publish("acks", Event(event_type="x", data={"n": 1}));

    first = b.consume("acks", group="t_ack", max_messages=1, timeout_seconds=2.0);
    assert len(first) == 1;
    b.ack(first[0]);

    # After ack, the consumer group should not see the same message again.
    second = b.consume(
        "acks", group="t_ack", max_messages=1, timeout_seconds=0.2
    );
    assert second == [];

    b.stop(drain=False);
    cleanup_connections();
}


test "consume returns empty on timeout when stream is empty" {
    _flush_redis();
    b = _make_broker(group="t_empty");
    out = b.consume(
        "empty.topic", group="t_empty", max_messages=5, timeout_seconds=0.2
    );
    assert out == [];
    b.stop(drain=False);
    cleanup_connections();
}


# --- subscribe drives handler ---

test "subscribe handler receives published events" {
    _flush_redis();
    b = _make_broker(group="t_sub");

    received: list[Event] = [];
    done = threading.Event();

    def handler(ev: Event) -> None {
        received.append(ev);
        done.set();
    }

    b.subscribe("subs", handler, group="t_sub");
    # Give the consumer thread a beat to issue its first XREADGROUP.
    time.sleep(0.2);
    b.publish("subs", Event(event_type="ping", data={"n": 7}));

    assert done.wait(timeout=3.0);
    assert len(received) >= 1;
    assert received[0].event_type == "ping";
    assert received[0].data["n"] == 7;

    b.stop(drain=True);
    cleanup_connections();
}


# --- retry exhaustion -> dead-letter ---

test "retry exhaustion routes to dlq stream" {
    _flush_redis();
    b = _make_broker(
        group="t_dlq",
        retry={
            "max_attempts": 2,
            "backoff_seconds": [0.01],
            "dead_letter_suffix": ".dlq"
        }
    );

    failures: list[int] = [];
    done = threading.Event();

    def always_fails(ev: Event) -> None {
        failures.append(1);
        if len(failures) >= 2 {
            done.set();
        }
        raise RuntimeError("nope");
    }

    b.subscribe("dlqtest", always_fails, group="t_dlq");
    time.sleep(0.2);
    b.publish("dlqtest", Event(event_type="boom", data={"n": 1}));

    # Wait for both attempts to fire and the broker to publish to DLQ.
    assert done.wait(timeout=5.0);
    time.sleep(0.3);

    # Pull from the DLQ via a fresh group on the .dlq stream.
    dlq_msgs = b.consume(
        "dlqtest.dlq", group="t_dlq_reader", max_messages=1, timeout_seconds=2.0
    );
    assert len(dlq_msgs) == 1;
    assert dlq_msgs[0].event_type == "boom";
    assert dlq_msgs[0].data["n"] == 1;

    b.stop(drain=False);
    cleanup_connections();
}


# --- health probe ---

test "health returns healthy redis_streams" {
    b = _make_broker(group="t_health");
    h = b.health();
    assert h.healthy is True;
    assert h.backend == "redis_streams";
    assert "consumer_name" in h.details;
    b.stop(drain=False);
    cleanup_connections();
}
