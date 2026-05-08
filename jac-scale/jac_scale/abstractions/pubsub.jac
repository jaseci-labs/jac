"""Pub/Sub abstraction for jac_scale.

Defines MessageBroker, Event, and NoOpBroker; concrete impls live in utilities/pubsub.
"""
import from typing { Any, Callable }
import from datetime { datetime, UTC }
import uuid;

"""CloudEvents-style envelope used for every publish/consume."""
obj Event {
    has event_type: str,
        data: dict[str, Any] = {},
        id: str = str(uuid.uuid4()),
        source: str = "jac-scale",
        time: str = datetime.now(UTC).isoformat(),
        trace_id: str | None = None,
        headers: dict[str, str] = {};
}

"""Retry policy applied to a subscription. After max_attempts the message goes to '<topic><dead_letter_suffix>'."""
obj RetryPolicy {
    has max_attempts: int = 3,
        backoff_seconds: list[float] = [1.0, 5.0, 30.0],
        dead_letter_suffix: str = ".dlq";
}

"""Handle returned by MessageBroker.subscribe()."""
obj Subscription {
    has topic: str,
        group: str | None = None;
}

"""Result of a health probe."""
obj HealthStatus {
    has healthy: bool,
        broker: str = "noop",
        details: dict[str, Any] = {};
}

"""Abstract base for a pub/sub message broker.

Implementations guarantee at-least-once delivery, auto-ack on handler success, DLQ on retry exhaustion.
"""
obj MessageBroker {
    """Start background consumer threads / connections. Idempotent."""
    def start -> None;

    """Stop the broker. With drain=True, wait for in-flight handlers to finish."""
    def stop(drain: bool = True) -> None;

    """Publish an event. `key` partitions on Kafka; ignored on Redis Streams."""
    def publish(topic: str, event: Event, key: str | None = None) -> None;

    """Register a handler for a topic (push delivery).

    `group` shares load across processes; distinct groups each see the full stream. Handler return acks; raise triggers retry.
    `start_from` controls where a brand-new consumer group begins reading: 'latest' (only new messages), 'earliest' (replay all retained), or a broker-specific position token. Ignored for groups that already exist.
    """
    def subscribe(
        topic: str,
        handler: Callable[[Event], Any],
        group: str | None = None,
        retry: RetryPolicy | None = None,
        start_from: str = "latest"
    ) -> Subscription;

    """Pull up to `max_messages` events, blocking up to `timeout_seconds`. Caller MUST ack(event). See subscribe() for `start_from` semantics."""
    def consume(
        topic: str,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 5.0,
        start_from: str = "latest"
    ) -> list[Event];

    """Ack a consume()d event. No-op for subscribe()-delivered events (auto-acked)."""
    def ack(event: Event) -> None;

    """Probe broker health (connection state, consumer lag, etc.)."""
    def health -> HealthStatus;

    """Whether this broker is a real implementation or a no-op."""
    def is_enabled -> bool;
}

"""No-op broker used when pub/sub is disabled. All methods are safe but do nothing."""
obj NoOpBroker(MessageBroker) {
    def start { }
    def stop(drain: bool = True) { }
    def publish(topic: str, event: Event, key: str | None = None) { }
    def subscribe(
        topic: str,
        handler: Callable[[Event], Any],
        group: str | None = None,
        retry: RetryPolicy | None = None,
        start_from: str = "latest"
    ) -> Subscription {
        return Subscription(topic=topic, group=group);
    }

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
        return HealthStatus(healthy=True, broker="noop");
    }

    def is_enabled -> bool {
        return False;
    }
}
