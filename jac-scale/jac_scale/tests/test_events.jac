"""Contract tests for the event-streaming abstraction.

Covers Event, the publisher facade, and @subscribe registry. LocalEventStream behavior is in test_local_stream.jac; Redis-specific behavior is in test_redis_stream.jac.
"""

import from jac_scale.events.broker {
    EventStreamBroker,
    Event,
    RetryPolicy,
    HealthStatus
}
import from typing { Any, Callable }
import from jac_scale.events.publisher { publish, set_broker }
import from jac_scale.events.subscriber { subscribe, get_subscriptions }


"""Broker stub that raises on publish; verifies the facade swallows errors."""
obj _ExplodingBroker(EventStreamBroker) {
    def start { }
    def stop(drain: bool = True) { }
    def publish(topic: str, event: Event, key: str | None = None) {
        raise RuntimeError("boom");
    }

    def register_handler(
        topic: str,
        handler: Callable[[Event], Any],
        group: str | None = None,
        retry: RetryPolicy | None = None,
        start_from: str = "latest"
    ) { }

    def consume(
        topic: str,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 5.0,
        start_from: str = "latest"
    ) -> list[Event] {
        return [];
    }

    def ack(event: Event) { }
    def health -> HealthStatus {
        return HealthStatus(healthy=True, broker="exploding");
    }
}


# --- Event envelope ---
test "event auto fills id" {
    e1 = Event(event_type="walker.completed");
    e2 = Event(event_type="walker.completed");
    assert e1.id;
    assert e2.id;
    assert e1.id != e2.id;
}

test "event auto fills time" {
    e = Event(event_type="walker.completed");
    assert e.time;
    assert "T" in e.time;
}

test "event respects explicit id" {
    e = Event(event_type="x", id="replay-42");
    assert e.id == "replay-42";
}

test "event default headers and data are independent" {
    a = Event(event_type="x");
    b = Event(event_type="x");
    a.data["k"] = 1;
    a.headers["h"] = "v";
    assert b.data == {};
    assert b.headers == {};
}


# --- Publisher facade ---
test "publish with no broker wired is a safe no-op" {
    set_broker(None);
    publish("topic.x", Event(event_type="topic.x", data={"k": 1}));
}

test "publish swallows broker errors" {
    # If the wired broker raises, publish() must log and return cleanly so
    # walker code doesn't blow up on a fire-and-forget emit.
    raised_inside = False;
    set_broker(_ExplodingBroker());
    try {
        publish("any", Event(event_type="any"));
    } except Exception {
        raised_inside = True;
    }
    set_broker(None);
    assert raised_inside is False;
}


"""Captures the last event passed to publish; lets us inspect what the facade forwarded."""
obj _CapturingBroker(EventStreamBroker) {
    has last_event: Event | None = None;

    def start { }
    def stop(drain: bool = True) { }
    def publish(topic: str, event: Event, key: str | None = None) {
        self.last_event = event;
    }

    def register_handler(
        topic: str,
        handler: Callable[[Event], Any],
        group: str | None = None,
        retry: RetryPolicy | None = None,
        start_from: str = "latest"
    ) { }

    def consume(
        topic: str,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 5.0,
        start_from: str = "latest"
    ) -> list[Event] {
        return [];
    }

    def ack(event: Event) { }
    def health -> HealthStatus {
        return HealthStatus(healthy=True, broker="capturing");
    }
}


test "publish auto-defaults event_type from topic" {
    cap = _CapturingBroker();
    set_broker(cap);
    publish("orders.placed", Event(data={"n": 1}));
    set_broker(None);
    assert cap.last_event is not None;
    assert cap.last_event.event_type == "orders.placed";
}

test "publish preserves explicit event_type" {
    cap = _CapturingBroker();
    set_broker(cap);
    publish("orders.placed", Event(event_type="orders.shipped", data={"n": 1}));
    set_broker(None);
    assert cap.last_event is not None;
    assert cap.last_event.event_type == "orders.shipped";
}


# --- @subscribe decorator + registry ---
test "subscribe decorator registers entry" {
    before = len(get_subscriptions());

    @subscribe("orders.placed")
    def _h1(ev: Event) { }

    after = get_subscriptions();
    assert len(after) == before + 1;
    last = after[-1];
    assert last.topic == "orders.placed";
    assert last.handler is _h1;
    assert last.group is None;
    assert last.retry is None;
}

test "subscribe decorator preserves group and retry" {
    policy = RetryPolicy(max_attempts=5, dead_letter_suffix=".dead");

    @subscribe("orders.shipped", group="ops", retry=policy)
    def _h2(ev: Event) { }

    last = get_subscriptions()[-1];
    assert last.topic == "orders.shipped";
    assert last.group == "ops";
    assert last.retry is policy;
    assert last.retry.max_attempts == 5;
    assert last.retry.dead_letter_suffix == ".dead";
}

test "subscribe decorator defaults start_from to latest" {
    @subscribe("orders.default")
    def _h_default(ev: Event) { }

    last = get_subscriptions()[-1];
    assert last.start_from == "latest";
}

test "subscribe decorator preserves start_from override" {
    @subscribe("orders.replay", start_from="earliest")
    def _h_replay(ev: Event) { }

    last = get_subscriptions()[-1];
    assert last.start_from == "earliest";
}

test "subscribe decorator returns the original function" {
    @subscribe("orders.refunded")
    def my_handler(ev: Event) -> None {
        return;
    }
    assert my_handler.__name__ == "my_handler";
}
