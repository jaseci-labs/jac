"""Event-streaming broker abstraction for jac_scale.

Defines EventStreamBroker, Event, RetryPolicy, Subscription, HealthStatus. Concrete impls live in events/brokers.
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

"""Handle returned by EventStreamBroker.subscribe()."""
obj Subscription {
    has topic: str,
        group: str | None = None;
}

"""Result of a health probe."""
obj HealthStatus {
    has healthy: bool,
        broker: str = "local",
        details: dict[str, Any] = {};
}

"""Abstract base for an event-streaming broker.

Implementations guarantee at-least-once delivery, auto-ack on handler success, replayable offsets via start_from, and DLQ on retry exhaustion. The semantics are streaming (durable log, consumer groups, offsets) even though the API verbs are pub/sub-shaped.
"""
obj EventStreamBroker {
    """Start background consumer threads / connections. Idempotent."""
    def start -> None;

    """Stop the broker. With drain=True, wait for in-flight handlers to finish."""
    def stop(drain: bool = True) -> None;

    """Publish an event. `key` partitions on Kafka; ignored on simple brokers."""
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
}
