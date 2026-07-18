import from typing { Callable }
import from jaclang.scale.events.broker { Event, RetryPolicy }
import time;


def consumer_loop(
    broker: any,
    topic: str,
    group: str,
    handler: Callable[[Event], any],
    retry: RetryPolicy,
    start_from: str = "latest"
) -> None {
    while not broker._stop_event.is_set() {
        events = broker.consume(
            topic,
            group=group,
            max_messages=10,
            timeout_seconds=5.0,
            start_from=start_from
        );
        for event in events {
            if broker._stop_event.is_set() {
                return;
            }
            broker._handle_with_retry(topic, group, event, handler, retry);
        }
    }
}


def wait_or_stop(broker: any, seconds: float) -> bool {
    deadline = time.time() + seconds;
    while time.time() < deadline {
        chunk = min(deadline - time.time(), 1.0);
        if broker._stop_event.wait(timeout=chunk) {
            return True;
        }
    }
    return False;
}
