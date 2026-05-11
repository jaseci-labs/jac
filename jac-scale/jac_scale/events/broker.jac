"""Event-streaming broker abstraction. Defines EventStreamBroker, Event, RetryPolicy, HealthStatus; concrete impls live in events/streams."""
import from typing { Any, Callable }
import from datetime { datetime, UTC }
import uuid;

"""CloudEvents-style envelope used for every publish/consume. `event_type` defaults to empty and is auto-filled from the topic by the publish() facade."""
obj Event {
    has event_type: str = "",
        data: dict[str, Any] = {},
        id: str = str(uuid.uuid4()),
        source: str = "jac-scale",
        time: str = datetime.now(UTC).isoformat(),
        trace_id: str | None = None,
        headers: dict[str, str] = {},
        delivery_id: str | None = None,
        delivery_topic: str | None = None,
        delivery_group: str | None = None;
}

"""Retry policy applied to a subscription. After max_attempts the message goes to '<topic><dead_letter_suffix>'."""
obj RetryPolicy {
    has max_attempts: int = 3,
        backoff_seconds: list[float] = [1.0, 5.0, 30.0],
        dead_letter_suffix: str = ".dlq";
}

"""Result of a health probe."""
obj HealthStatus {
    has healthy: bool,
        broker: str,
        details: dict[str, Any] = {};
}

"""Abstract base for an event-streaming broker.
Implementations guarantee at-least-once delivery, replayable offsets via start_from, ordered per-group consumption, and DLQ on retry exhaustion.
"""
obj EventStreamBroker {
    """Start background consumer threads / connections. Idempotent."""
    def start -> None;

    """Stop the broker. With drain=True, wait for in-flight handlers to finish."""
    def stop(drain: bool = True) -> None;

    """Publish an event. `key` partitions on Kafka; ignored on simple brokers."""
    def publish(topic: str, event: Event, key: str | None = None) -> None;

    """Register a handler for a topic (push delivery). Internal API; user code should use the @subscribe decorator instead.
    `group` shares load; handler completion acks; raise triggers retry. `start_from` ('latest' | 'earliest' | broker-specific position token) is a one-shot bookmark applied only when the consumer group is first created.
    """
    def register_handler(
        topic: str,
        handler: Callable[[Event], Any],
        group: str | None = None,
        retry: RetryPolicy | None = None,
        start_from: str = "latest"
    ) -> None;

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
