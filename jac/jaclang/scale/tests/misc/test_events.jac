"""Contract tests for the event-streaming abstraction.

Covers Event, the publisher facade, and @subscribe registry. LocalEventStream behavior is in test_local_stream.jac.
"""

import from jaclang.scale.events.broker {
    EventStreamBroker,
    Event,
    RetryPolicy,
    HealthStatus,
    StreamPosition,
    starts_at_earliest
}
import from threading { Event as _ThreadStop }
import from jaclang.scale.events.publisher { publish, set_broker }
import from jaclang.scale.events.subscriber { subscribe, get_subscriptions }
import from jaclang.scale.events.streams._stream_common { consumer_loop }
import from jaclang.scale.events.streams.local { LocalEventStream }
import from jaclang.scale.events.streams.postgres { PgEventStream }


"""Broker stub that raises on publish; verifies the facade swallows errors."""
obj _ExplodingBroker(EventStreamBroker) {
    def start { }
    def stop(drain: bool = True) { }
    def publish(topic: str, event: Event, key: str | None = None) {
        raise RuntimeError("boom");
    }

    def register_handler(
        topic: str,
        handler: Callable[[Event], any],
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
        handler: Callable[[Event], any],
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


# --- consumer_loop start_from forwarding ---
"""Broker stub that records the start_from consumer_loop passes to consume."""
obj _StartFromRecorder(EventStreamBroker) {
    has _stop_event: _ThreadStop = _ThreadStop(),
        seen_start_from: str = "";

    def start { }
    def stop(drain: bool = True) { }
    def publish(topic: str, event: Event, key: str | None = None) { }
    def register_handler(
        topic: str,
        handler: Callable[[Event], any],
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
        self.seen_start_from = start_from;
        self._stop_event.set();
        return [];
    }

    def ack(event: Event) { }
    def health -> HealthStatus {
        return HealthStatus(healthy=True, broker="recorder");
    }
}


def _noop_handler(ev: Event) -> None {
    return;
}


test "consumer_loop forwards start_from to consume" {
    broker = _StartFromRecorder();
    consumer_loop(
        broker, "topic", "grp", _noop_handler, RetryPolicy(), start_from="earliest"
    );
    assert broker.seen_start_from == "earliest";
}


test "consumer_loop defaults start_from to latest" {
    broker = _StartFromRecorder();
    consumer_loop(broker, "topic", "grp", _noop_handler, RetryPolicy());
    assert broker.seen_start_from == "latest";
}


# --- position tokens ---
# One predicate decides "replay from the beginning" for every backend, so the
# two brokers cannot drift apart on what a position token means.
test "the earliest position is recognized as a string or an enum member" {
    assert starts_at_earliest("earliest");
    assert starts_at_earliest(StreamPosition.EARLIEST.value);
    assert starts_at_earliest(StreamPosition.EARLIEST);
    assert not starts_at_earliest("latest");
    assert not starts_at_earliest(StreamPosition.LATEST);
    assert not starts_at_earliest("some-broker-token");
}


# --- interface signature parity (issue #8047) ---
# PgEventStream.consume shipped without the interface's start_from and with a
# 0.0 timeout default, so callers written against EventStreamBroker raised
# TypeError on Postgres only. These tests compare call contracts directly, and
# check that the interface rejects a divergent implementation at definition.
"""Name, kind, and default of every parameter of a method, minus self."""
def _param_view(fn: any) -> list[tuple] {
    import inspect;
    view: list[tuple] = [];
    for p in inspect.signature(fn).parameters.values() {
        if p.name == "self" {
            continue;
        }
        view.append((p.name, p.kind.name, p.`default));
    }
    return view;
}


"""Public method names the EventStreamBroker interface declares."""
def _interface_methods -> list[str] {
    names: list[str] = [];
    for (name, member) in vars(EventStreamBroker).items() {
        if (not name.startswith("_")) and callable(member) {
            names.append(name);
        }
    }
    return sorted(names);
}


"""Every broker implementation that ships in jaclang.scale.events.streams."""
def _shipped_brokers -> list[type] {
    found: list[type] = [];
    pending: list = list(getattr(EventStreamBroker, "__subclasses__")());
    while pending {
        candidate = pending.pop();
        pending.extend(candidate.__subclasses__());
        if str(getattr(candidate, "__module__", "")).startswith(
            "jaclang.scale.events.streams"
        ) {
            found.append(candidate);
        }
    }
    return found;
}


test "every shipped broker matches the interface signatures" {
    brokers = _shipped_brokers();
    found = sorted([b.__name__ for b in brokers]);
    assert LocalEventStream in brokers , f"discovery found only {found}";
    assert PgEventStream in brokers , f"discovery found only {found}";

    methods = _interface_methods();
    assert "consume" in methods , f"interface methods not discovered: {methods}";

    faults: list[str] = [];
    for method in methods {
        want = _param_view(getattr(EventStreamBroker, method));
        for broker in brokers {
            got = _param_view(getattr(broker, method));
            if got != want {
                faults.append(f"{broker.__name__}.{method}: {got} != {want}");
            }
        }
    }
    assert faults == [] , "divergence from EventStreamBroker: " + "; ".join(faults);
}


"""Method bodies with divergent contracts, spliced onto a broker subclass."""
obj _DivergentMethods {
    def consume_without_start_from(
        topic: str,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 5.0
    ) -> list[Event] {
        return [];
    }

    def consume_with_shrunk_timeout(
        topic: str,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 0.0,
        start_from: str = "latest"
    ) -> list[Event] {
        return [];
    }

    def consume_with_extra_required(
        topic: str,
        shard: int,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 5.0,
        start_from: str = "latest"
    ) -> list[Event] {
        return [];
    }

    def consume_widened(
        topic: str,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 5.0,
        start_from: str = "latest",
        shard: int = 0
    ) -> list[Event] {
        return [];
    }
}


test "dropping an interface parameter fails at class definition" {
    err = "";
    try {
        type(
            "_DropsStartFrom",
            (EventStreamBroker, ),
            {"consume": _DivergentMethods.consume_without_start_from}
        );
    } except TypeError as e {
        err = str(e);
    }
    assert "consume" in err , f"expected a loud parity error, got: {err}";
    assert "start_from" in err , f"expected start_from to be named, got: {err}";
}


test "changing an interface default fails at class definition" {
    err = "";
    try {
        type(
            "_ShrinksTimeout",
            (EventStreamBroker, ),
            {"consume": _DivergentMethods.consume_with_shrunk_timeout}
        );
    } except TypeError as e {
        err = str(e);
    }
    assert "timeout_seconds" in err , f"expected timeout_seconds to be named, got: {err}";
}


test "adding a required parameter fails at class definition" {
    err = "";
    try {
        type(
            "_NeedsShard",
            (EventStreamBroker, ),
            {"consume": _DivergentMethods.consume_with_extra_required}
        );
    } except TypeError as e {
        err = str(e);
    }
    assert "shard" in err , f"expected shard to be named, got: {err}";
}


test "an implementation may widen with optional parameters" {
    widened = type(
        "_WidenedBroker",
        (EventStreamBroker, ),
        {"consume": _DivergentMethods.consume_widened}
    );
    assert widened.__name__ == "_WidenedBroker";
}
