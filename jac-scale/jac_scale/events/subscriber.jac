"""@subscribe decorator and global handler registry.
Decorator records entries at import time; _setup_events wires each into the broker at server startup.
"""
import from typing { Any, Callable }
import from jac_scale.events.broker { Event, RetryPolicy }

obj _SubscriptionEntry {
    has topic: str,
        handler: Callable[[Event], Any],
        group: str | None = None,
        retry: RetryPolicy | None = None,
        start_from: str = "latest";
}

glob _registry: list[_SubscriptionEntry] = [];

"""Register a handler for a topic.
`group` shares load; `retry` overrides defaults; `start_from` ('latest' | 'earliest' | broker-specific position token) is a one-shot bookmark applied only when the consumer group is first created.
"""
def subscribe(
    topic: str,
    group: str | None = None,
    retry: RetryPolicy | None = None,
    start_from: str = "latest"
) -> Callable[..., Any] {
    def _decorator(handler: Callable[[Event], Any]) -> Callable[..., Any] {
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

"""Return all registered subscriptions. Called by _setup_events at startup."""
def get_subscriptions -> list[_SubscriptionEntry] {
    return _registry;
}
