import from threading { Thread, Event as _ThreadStop, Lock }

import logging;
import time;

glob _logger = logging.getLogger(__name__);

obj LocalEventStream(EventStreamBroker) {
    has config: dict[str, any] = {},
        _default_group: str = "jac-scale",
        _default_retry: RetryPolicy = RetryPolicy(),
        _stop_event: _ThreadStop = _ThreadStop(),
        _threads: list[Thread] = [],
        _lock: Lock = Lock(),
        _topics: dict[str, list[Event]] = {},
        _offsets: dict[str, int] = {},
        _condition_events: dict[str, _ThreadStop] = {};

    def postinit;
    def start;
    def stop(drain: bool = True);
    def _topic_signal(topic: str) -> _ThreadStop;
    def _ensure_offset(topic: str, group: str, start_from: str) -> None;
    def publish(topic: str, event: Event, key: str | None = None);
    def consume(
        topic: str,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 5.0,
        start_from: str = StreamPosition.LATEST.value
    ) -> list[Event];

    def ack(event: Event) -> None;
    def _send_to_dlq(topic: str, event: Event, retry: RetryPolicy);
    def _handle_with_retry(
        topic: str,
        group: str,
        event: Event,
        handler: Callable[[Event], any],
        retry: RetryPolicy
    ) -> None;

    def register_handler(
        topic: str,
        handler: Callable[[Event], any],
        group: str | None = None,
        retry: RetryPolicy | None = None,
        start_from: str = StreamPosition.LATEST.value
    );

    def health -> HealthStatus;
}
