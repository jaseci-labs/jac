import from typing { cast }
import from datetime { datetime, UTC }
import uuid;

enum StreamPosition { EARLIEST = 'earliest', LATEST = 'latest', }

def starts_at_earliest(start_from: any) -> bool {
    token = start_from.value if isinstance(start_from, StreamPosition) else start_from;
    return token == StreamPosition.EARLIEST.value;
}

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

def _method_params(fn: any) -> list[MethodParam] {
    import inspect;
    params: list[MethodParam] = [];
    for p in inspect.signature(fn).parameters.values() {
        if p.name == 'self' {
            continue;
        }
        params.append(
            MethodParam(
                name=p.name,
                kind=p.kind.name,
                has_default=(p.`default is not inspect.Parameter.empty),
                `default=(None if p.`default is inspect.Parameter.empty else p.`default)
            )
        );
    }
    return params;
}

def _signature_faults(
    method: str, want: list[MethodParam], got: list[MethodParam]
) -> list[str] {
    faults: list[str] = [];
    provided: dict[str, MethodParam] = {p.name: p for p in got};
    absorbs = any(p.kind in _VARIADIC_KINDS for p in got);
    declared = [p.name for p in want];
    for w in want {
        have = provided.get(w.name);
        if have is None {
            if not absorbs {
                faults.append(f"{method} drops parameter '{w.name}'");
            }
            continue;
        }
        if have.kind == 'POSITIONAL_ONLY' and w.kind != 'POSITIONAL_ONLY' {
            faults.append(f"{method} makes '{w.name}' positional-only");
        }
        if w.has_default and not have.has_default {
            faults.append(f"{method} drops the default {w.`default} for '{w.name}'");
        } elif w.has_default and have.`default != w.`default {
            faults.append(
                f"{method} defaults '{w.name}' to {have.`default}, "
                f"interface declares {w.`default}"
            );
        }
    }
    ordered = [
        p.name
        for p in got
        if p.kind in _POSITIONAL_KINDS and p.name in declared
    ];
    expected = [
        name
        for name in declared
        if name in ordered
    ];
    if ordered != expected {
        faults.append(f"{method} orders parameters {ordered}, expected {expected}");
    }
    for p in got {
        if (
            (p.kind not in _VARIADIC_KINDS)
            and (p.name not in declared)
            and not p.has_default
        ) {
            faults.append(f"{method} adds required parameter '{p.name}'");
        }
    }
    return faults;
}

def _assert_signature_parity(broker_cls: type) {
    faults: list[str] = [];
    for (name, declared) in vars(EventStreamBroker).items() {
        if name.startswith('_') or not callable(declared) {
            continue;
        }
        supplied = getattr(broker_cls, name, None);
        if supplied is declared {
            continue;
        }
        if not callable(supplied) {
            faults.append(f"{name} is not a method");
            continue;
        }
        faults.extend(
            _signature_faults(name, _method_params(declared), _method_params(supplied))
        );
    }
    if faults {
        detail = '; '.join(faults);
        raise TypeError(
            f"{broker_cls.__module__}.{broker_cls.__name__} diverges from the "
            f"EventStreamBroker interface: {detail}"
        );
    }
}

obj EventStreamBroker {
    class def __init_subclass__(**kwargs: object) {
        super.__init_subclass__(**kwargs);
        _assert_signature_parity(cast(type, cls));
    }

    def start -> None;
    def stop(drain: bool = True) -> None;
    def publish(topic: str, event: Event, key: str | None = None) -> None;
    def register_handler(
        topic: str,
        handler: Callable[[Event], any],
        group: str | None = None,
        retry: RetryPolicy | None = None,
        start_from: str = StreamPosition.LATEST.value
    ) -> None;

    def consume(
        topic: str,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 5.0,
        start_from: str = StreamPosition.LATEST.value
    ) -> list[Event];

    def ack(event: Event) -> None;
    def health -> HealthStatus;
}
