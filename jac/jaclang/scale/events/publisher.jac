import from jaclang.scale.events.broker { EventStreamBroker, Event }
import logging;

glob _broker: EventStreamBroker | None = None,
     _logger = logging.getLogger(__name__);

def set_broker(broker: EventStreamBroker | None) {
    _broker = broker;
}

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
