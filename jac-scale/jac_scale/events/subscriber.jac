"""@subscribe decorator and global handler registry.

Decorator records entries at import time; _setup_pubsub wires each into the broker at server startup.
"""
import from typing { Any, Callable }
import from jac_scale.abstractions.pubsub { Event, RetryPolicy }

obj _SubscriptionEntry {
    has topic: str,
        handler: Callable[[Event], Any],
        group: str | None = None,
        retry: RetryPolicy | None = None,
        start_from: str = "latest";
}

glob _registry: list[_SubscriptionEntry] = [];

"""Register a handler for a topic.

`group` shares load; `retry` overrides defaults; `start_from` controls where a brand-new consumer group starts ('latest', 'earliest', or a broker-specific position token). Existing groups ignore `start_from` and resume from their stored position.
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

"""Return all registered subscriptions. Called by _setup_pubsub at startup."""
def get_subscriptions -> list[_SubscriptionEntry] {
    return _registry;
}

"""Drop all registered subscriptions. Used by tests to keep registrations isolated across runs."""
def clear_subscriptions {
    global _registry;
    _registry = [];
}
