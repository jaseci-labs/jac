import from typing { Callable }
import from datetime { datetime, UTC }
import uuid;

obj Event {
    has event_type: str = "",
        data: dict[str, any] = {},
        id: str = str(uuid.uuid4()),
        source: str = "jac-scale",
        time: str = datetime.now(UTC).isoformat(),
        trace_id: str | None = None,
        headers: dict[str, str] = {},
        delivery_id: str | None = None,
        delivery_topic: str | None = None,
        delivery_group: str | None = None;
}

obj RetryPolicy {
    has max_attempts: int = 3,
        backoff_seconds: list[float] = [1.0, 5.0, 30.0],
        dead_letter_suffix: str = ".dlq";
}

obj HealthStatus {
    has healthy: bool,
        broker: str,
        details: dict[str, any] = {};
}

obj EventStreamBroker {
    def start -> None;
    def stop(drain: bool = True) -> None;
    def publish(topic: str, event: Event, key: str | None = None) -> None;
    def register_handler(
        topic: str,
        handler: Callable[[Event], any],
        group: str | None = None,
        retry: RetryPolicy | None = None,
        start_from: str = "latest"
    ) -> None;

    def consume(
        topic: str,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 5.0,
        start_from: str = "latest"
    ) -> list[Event];

    def ack(event: Event) -> None;
    def health -> HealthStatus;
}
