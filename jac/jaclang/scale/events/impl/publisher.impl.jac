impl set_broker(broker: EventStreamBroker | None) {
    _broker = broker;
}

impl publish(topic: str, event: Event, key: str | None = None) -> None {
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
