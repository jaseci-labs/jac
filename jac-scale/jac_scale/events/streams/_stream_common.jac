"""Shared consumer-loop helpers for event-stream brokers.

LocalEventStream and RedisEventStream drive their background consumer threads
with identical loop/backoff logic. These free functions take the broker as the
first argument so that logic lives in exactly one place.
"""
import from typing { Callable }
import from jac_scale.events.broker { Event, RetryPolicy }
import time;


"""Run the per-(topic, group) consume loop until the broker's stop event is set."""
def consumer_loop(
    broker: any,
    topic: str,
    group: str,
    handler: Callable[[Event], any],
    retry: RetryPolicy
) -> None {
    while not broker._stop_event.is_set() {
        events = broker.consume(
            topic, group=group, max_messages=10, timeout_seconds=5.0
        );
        for event in events {
            if broker._stop_event.is_set() {
                return;
            }
            broker._handle_with_retry(topic, group, event, handler, retry);
        }
    }
}


"""Wait up to `seconds`, polling the broker stop event in <=1s chunks so a
SIGTERM during a long backoff doesn't block shutdown for the full delay.

Returns True if the stop event fired during the wait (caller should abort),
False if the full delay elapsed.
"""
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
