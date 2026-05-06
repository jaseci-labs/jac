"""Pub/Sub abstraction for jac_scale.

Provides a clean interface for publishing and consuming messages.
All broker implementations (Redis Streams, Kafka, NATS, ...) inherit
from MessageBroker. NoOpBroker is used when pub/sub is disabled so
call sites never need null checks.
"""
import from typing { Any, Callable }
import from datetime { datetime, UTC }
import uuid;

"""CloudEvents-style message envelope.

Used for every publish/consume round-trip. Vendor-neutral so external
consumers (Kafka clients, Redis CLI, ...) do not need to learn a
jac-scale-specific schema.
"""
obj Event {
    has event_type: str,
        data: dict[str, Any] = {},
        id: str = str(uuid.uuid4()),
        source: str = "jac-scale",
        time: str = datetime.now(UTC).isoformat(),
        trace_id: str | None = None,
        headers: dict[str, str] = {};
}

"""Retry policy applied to a subscription.

backoff_seconds is consulted positionally by attempt index, clamped to
the last entry. After max_attempts failures the message is published
to '<topic><dead_letter_suffix>'.
"""
obj RetryPolicy {
    has max_attempts: int = 3,
        backoff_seconds: list[float] = [1.0, 5.0, 30.0],
        dead_letter_suffix: str = ".dlq";
}

"""Handle returned by MessageBroker.subscribe().

Backends populate `cancel` with a callable that tears down the
consumer (close iterator, stop thread, leave consumer group, etc.).
"""
obj Subscription {
    has topic: str,
        group: str | None = None,
        handler: Callable[..., Any] | None = None,
        cancel: Callable[..., Any] | None = None;
}

"""Result of a health probe."""
obj HealthStatus {
    has healthy: bool,
        backend: str = "noop",
        details: dict[str, Any] = {};
}

"""Abstract base for a pub/sub message broker.

Implementations must guarantee at-least-once delivery, ack on
handler success, and route to dead-letter on retry exhaustion.
"""
obj MessageBroker {
    """Start background consumer threads / connections.

    Idempotent. Must be safe to call after subscribe().
    """
    def start -> None;

    """Stop the broker.

    If drain is True, wait for in-flight handlers to finish (with a
    backend-defined timeout) before closing connections.
    """
    def stop(drain: bool = True) -> None;

    """Publish an event to a topic.

    `key` is used by partitioned backends (Kafka) to route messages
    to the same partition. Ignored by Redis Streams.
    """
    def publish(topic: str, event: Event, key: str | None = None) -> None;

    """Register a handler for a topic (push delivery).

    `group` is the consumer group name. Multiple processes sharing a
    group will load-balance messages; distinct groups each receive a
    full copy of the stream. None lets the backend pick a default.
    Successful handler returns auto-ack; raised exceptions trigger
    retry per `retry` policy.
    """
    def subscribe(
        topic: str,
        handler: Callable[[Event], Any],
        group: str | None = None,
        retry: RetryPolicy | None = None
    ) -> Subscription;

    """Pull a batch of events synchronously.

    Returns up to `max_messages` events, blocking up to
    `timeout_seconds` for at least one. Empty list on timeout.
    Caller MUST call ack(event) after processing or the broker will
    redeliver the message after its own visibility timeout.
    """
    def consume(
        topic: str,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 5.0
    ) -> list[Event];

    """Acknowledge an event pulled via consume().

    No-op for events delivered through subscribe() (those are
    auto-acked on handler success). For consume(), this advances
    the consumer-group offset so the message is not redelivered.
    """
    def ack(event: Event) -> None;

    """Probe backend health (connection state, consumer lag, etc.)."""
    def health -> HealthStatus;

    """Whether this broker is a real implementation or a no-op."""
    def is_enabled -> bool;
}

"""No-op broker used when pub/sub is disabled.

All methods are safe to call but perform no work. Lets the rest of
the codebase publish unconditionally without an `if enabled` check.
"""
obj NoOpBroker(MessageBroker) {
    def start { }
    def stop(drain: bool = True) { }
    def publish(topic: str, event: Event, key: str | None = None) { }
    def subscribe(
        topic: str,
        handler: Callable[[Event], Any],
        group: str | None = None,
        retry: RetryPolicy | None = None
    ) -> Subscription {
        return Subscription(topic=topic, group=group, handler=handler);
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
        return HealthStatus(healthy=True, backend="noop");
    }

    def is_enabled -> bool {
        return False;
    }
}
