import from typing { cast }
import from datetime { datetime, UTC }
import uuid;

enum StreamPosition { EARLIEST = 'earliest', LATEST = 'latest', }

def starts_at_earliest(start_from: any) -> bool;

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

glob _POSITIONAL_KINDS = {'POSITIONAL_ONLY', 'POSITIONAL_OR_KEYWORD'},
     _VARIADIC_KINDS = {'VAR_POSITIONAL', 'VAR_KEYWORD'};

obj MethodParam {
    has name: str,
        kind: str,
        has_default: bool,
        `default: any = None;
}

def _method_params(fn: any) -> list[MethodParam];

def _signature_faults(
    method: str, want: list[MethodParam], got: list[MethodParam]
) -> list[str];

def _assert_signature_parity(broker_cls: type);

obj EventStreamBroker {
    class def __init_subclass__(**kwargs: object);
    def start -> None abst;
    def stop(drain: bool = True) -> None abst;
    def publish(topic: str, event: Event, key: str | None = None) -> None abst;
    def register_handler(
        topic: str,
        handler: Callable[[Event], any],
        group: str | None = None,
        retry: RetryPolicy | None = None,
        start_from: str = StreamPosition.LATEST.value
    ) -> None abst;

    def consume(
        topic: str,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 5.0,
        start_from: str = StreamPosition.LATEST.value
    ) -> list[Event] abst;

    def ack(event: Event) -> None abst;
    def health -> HealthStatus abst;
}
