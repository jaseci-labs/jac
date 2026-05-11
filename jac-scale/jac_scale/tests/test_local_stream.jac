"""Unit tests for LocalEventStream (in-memory event-streaming broker).

No external dependencies; runs everywhere.
"""

import time;
import threading;
import from jac_scale.events.broker { Event, RetryPolicy }
import from jac_scale.events.streams.local { LocalEventStream }


def _make_broker(
    group: str = "test_group", retry: dict | None = None
) -> LocalEventStream {
    cfg: dict = {
        "consumer_group": group,
        "retry": retry
        or {
            "max_attempts": 3,
            "backoff_seconds": [0.01, 0.01, 0.01],
            "dead_letter_suffix": ".dlq"
        }
    };
    b = LocalEventStream(config=cfg);
    b.start();
    return b;
}


# --- publish + consume roundtrip ---
test "publish then consume roundtrips event fields" {
    b = _make_broker(group="t_rt");
    sent = Event(event_type="orders.placed", data={"order_id": 42}, source="test");
    b.publish("orders", sent);

    received = b.consume(
        "orders",
        group="t_rt",
        max_messages=1,
        timeout_seconds=2.0,
        start_from="earliest"
    );
    assert len(received) == 1;
    got = received[0];
    assert got.event_type == "orders.placed";
    assert got.data["order_id"] == 42;
    assert got.id == sent.id;

    b.stop(drain=False);
}


# --- start_from semantics ---
test "start_from earliest replays prior messages" {
    b = _make_broker(group="t_replay");
    b.publish("replay", Event(event_type="x", data={"n": 1}));
    b.publish("replay", Event(event_type="x", data={"n": 2}));

    msgs = b.consume(
        "replay",
        group="t_replay",
        max_messages=10,
        timeout_seconds=1.0,
        start_from="earliest"
    );
    assert len(msgs) == 2;
    assert msgs[0].data["n"] == 1;
    assert msgs[1].data["n"] == 2;

    b.stop(drain=False);
}

test "start_from latest skips prior messages" {
    b = _make_broker(group="t_skip");
    b.publish("skip", Event(event_type="x", data={"n": 1}));

    out = b.consume("skip", group="t_skip", max_messages=5, timeout_seconds=0.3);
    assert out == [];

    b.stop(drain=False);
}


# --- consume timeout ---
test "consume returns empty list on timeout" {
    b = _make_broker(group="t_empty");
    out = b.consume(
        "empty.topic", group="t_empty", max_messages=5, timeout_seconds=0.2
    );
    assert out == [];
    b.stop(drain=False);
}


# --- subscribe drives handler ---
test "subscribe handler receives published events" {
    b = _make_broker(group="t_sub");

    received: list[Event] = [];
    done = threading.Event();

    def handler(ev: Event) {
        received.append(ev);
        done.set();
    }

    b.register_handler("subs", handler, group="t_sub");
    time.sleep(0.1);
    b.publish("subs", Event(event_type="ping", data={"n": 7}));

    assert done.wait(timeout=3.0);
    assert len(received) >= 1;
    assert received[0].event_type == "ping";
    assert received[0].data["n"] == 7;

    b.stop(drain=True);
}


# --- retry exhaustion -> DLQ ---
test "retry exhaustion routes to dlq stream" {
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

    def always_fails(ev: Event) {
        failures.append(1);
        if len(failures) >= 2 {
            done.set();
        }
        raise RuntimeError("nope");
    }

    b.register_handler("dlqtest", always_fails, group="t_dlq");
    time.sleep(0.1);
    b.publish("dlqtest", Event(event_type="boom", data={"n": 1}));

    assert done.wait(timeout=5.0);
    time.sleep(0.2);

    dlq_msgs = b.consume(
        "dlqtest.dlq",
        group="t_dlq_reader",
        max_messages=1,
        timeout_seconds=2.0,
        start_from="earliest"
    );
    assert len(dlq_msgs) == 1;
    assert dlq_msgs[0].event_type == "boom";

    b.stop(drain=False);
}


# --- async handler is rejected ---
test "async handler triggers retry path with TypeError" {
    b = _make_broker(
        group="t_async",
        retry={
            "max_attempts": 2,
            "backoff_seconds": [0.01],
            "dead_letter_suffix": ".dlq"
        }
    );

    attempts: list[int] = [];

    async def async_handler(ev: Event) {
        attempts.append(1);
    }

    b.register_handler("asyncs", async_handler, group="t_async");
    time.sleep(0.1);
    b.publish("asyncs", Event(event_type="x"));

    # The handler "runs" twice (returns a coroutine each time, both flagged).
    # After max_attempts, the event lands in the DLQ.
    dlq_msgs = b.consume(
        "asyncs.dlq",
        group="t_async_reader",
        max_messages=1,
        timeout_seconds=3.0,
        start_from="earliest"
    );
    assert len(dlq_msgs) == 1;
    b.stop(drain=False);
}


# --- health probe ---
test "health returns healthy local broker" {
    b = _make_broker(group="t_health");
    h = b.health();
    assert h.healthy is True;
    assert h.broker == "local";
    assert "topics" in h.details;
    b.stop(drain=False);
}
