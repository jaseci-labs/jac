"""Module-level publish facade.
Hides the broker reference so call sites just `publish('topic', event)`. Wired at startup by _setup_events.
"""
import from jac_scale.events.broker { EventStreamBroker, Event }
import logging;

glob _broker: EventStreamBroker | None = None,
     _logger = logging.getLogger(__name__);

"""Wire the active broker. Called once at startup by _setup_events."""
def set_broker(broker: EventStreamBroker | None) {
    global _broker;
    _broker = broker;
}

"""Publish an event. No-op when events are disabled; broker errors are logged but not re-raised. `event.event_type` defaults to `topic` so callers don't have to repeat the string."""
def publish(topic: str, event: Event, key: str | None = None) -> None {
    if _broker is None {
        return;
    }
    if not event.event_type {
        event.event_type = topic;
    }
    try {
        _broker.publish(topic, event, key=key);
    } except Exception as e {
        _logger.error(f"publish to '{topic}' failed: {e}");
    }
}
