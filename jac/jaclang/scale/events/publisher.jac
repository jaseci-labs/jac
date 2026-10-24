import logging;

glob _broker: EventStreamBroker | None = None,
     _logger = logging.getLogger(__name__);

def set_broker(broker: EventStreamBroker | None);

def publish(topic: str, event: Event, key: str | None = None) -> None;
