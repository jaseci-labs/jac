"""Contract tests for the pub/sub abstraction.

Covers everything that can be exercised without a real broker:
- Event envelope auto-fills id and time
- NoOpBroker satisfies the MessageBroker contract safely
- UtilityFactory.create_broker selects the right impl from config
- Publisher facade swallows calls when no broker is wired
- @subscribe decorator records entries in the registry

Real Redis behavior is covered by test_redis_streams_broker.jac.
"""

import from jac_scale.abstractions.pubsub {
    NoOpBroker,
    Event,
    RetryPolicy,
    Subscription,
    HealthStatus
}
import from typing { Any, Callable }
import from jac_scale.abstractions.pubsub { MessageBroker }
import from jac_scale.factories.utility_factory { UtilityFactory }
import from jac_scale.events.publisher { publish, set_broker }
import from jac_scale.events.subscriber { subscribe, get_subscriptions }


"""Broker stub that raises on publish; used to verify the facade swallows errors."""
obj _ExplodingBroker(MessageBroker) {
    def start { }
    def stop(drain: bool = True) { }
    def publish(topic: str, event: Event, key: str | None = None) {
        raise RuntimeError("boom");
    }

    def subscribe(
        topic: str,
        handler: Callable[[Event], Any],
        group: str | None = None,
        retry: RetryPolicy | None = None
    ) -> Subscription {
        return Subscription(topic=topic);
    }

    def consume(
        topic: str,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 5.0
    ) -> list[Event] {
        return [];
    }

    def ack(event: Event) { }
    def health -> HealthStatus {
        return HealthStatus(healthy=True);
    }

    def is_enabled -> bool {
        return True;
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


# --- NoOpBroker contract ---
test "noop broker is_enabled returns false" {
    b = NoOpBroker();
    assert b.is_enabled() is False;
}

test "noop broker start and stop are safe" {
    b = NoOpBroker();
    b.start();
    b.stop();
    b.stop(drain=False);
}

test "noop broker publish does nothing" {
    b = NoOpBroker();
    b.publish("any.topic", Event(event_type="x", data={"k": 1}));
}

test "noop broker subscribe returns subscription" {
    b = NoOpBroker();
    def _handler(ev: Event) { }
    sub = b.subscribe("my.topic", _handler, group="my.group");
    assert isinstance(sub, Subscription);
    assert sub.topic == "my.topic";
    assert sub.group == "my.group";
}

test "noop broker consume returns empty list" {
    b = NoOpBroker();
    out = b.consume("my.topic", max_messages=10, timeout_seconds=0.01);
    assert out == [];
}

test "noop broker ack does not raise" {
    b = NoOpBroker();
    b.ack(Event(event_type="x"));
}

test "noop broker health is healthy noop" {
    b = NoOpBroker();
    h = b.health();
    assert isinstance(h, HealthStatus);
    assert h.healthy is True;
    assert h.backend == "noop";
}


# --- UtilityFactory.create_broker selection ---
test "factory returns noop when config is None" {
    b = UtilityFactory.create_broker("redis_streams", None);
    assert b.is_enabled() is False;
    assert isinstance(b, NoOpBroker);
}

test "factory returns noop when config disabled" {
    b = UtilityFactory.create_broker("redis_streams", {"enabled": False});
    assert b.is_enabled() is False;
    assert isinstance(b, NoOpBroker);
}

test "factory returns noop when explicitly requested" {
    b = UtilityFactory.create_broker("noop", {"enabled": True});
    assert isinstance(b, NoOpBroker);
}

test "factory raises on unsupported broker type" {
    raised = False;
    try {
        UtilityFactory.create_broker("kafka", {"enabled": True});
    } except ValueError {
        raised = True;
    }
    assert raised , "expected ValueError for unsupported broker type";
}


# --- Publisher facade ---
test "publish via facade with noop is a safe noop" {
    set_broker(NoOpBroker());
    publish("topic.x", Event(event_type="topic.x", data={"k": 1}));
}

test "publish swallows backend errors" {
    # If the wired broker raises, publish() must log and return cleanly so
    # walker code doesn't blow up on a fire-and-forget emit.
    raised_inside = False;
    set_broker(_ExplodingBroker());
    try {
        publish("any", Event(event_type="any"));
    } except Exception {
        raised_inside = True;
    }
    set_broker(NoOpBroker());
    assert raised_inside is False;
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

test "subscribe decorator returns the original function" {
    @subscribe("orders.refunded")
    def my_handler(ev: Event) -> None {
        return;
    }
    assert my_handler.__name__ == "my_handler";
}
