import from typing { Callable }
import from jaclang.scale.events.broker { Event, RetryPolicy }

obj _SubscriptionEntry {
    has topic: str,
        handler: Callable[[Event], any],
        group: str | None = None,
        retry: RetryPolicy | None = None,
        start_from: str = "latest";
}

glob _registry: list[_SubscriptionEntry] = [];

def subscribe(
    topic: str,
    group: str | None = None,
    retry: RetryPolicy | None = None,
    start_from: str = "latest"
) -> Callable[..., any] {
    def _decorator(handler: Callable[[Event], any]) -> Callable[..., any] {
        _registry.append(
            _SubscriptionEntry(
                topic=topic,
                handler=handler,
                group=group,
                retry=retry,
                start_from=start_from
            )
        );
        return handler;
    }
    return _decorator;
}

def get_subscriptions -> list[_SubscriptionEntry] {
    return _registry;
}
