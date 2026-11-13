import time;


def consumer_loop(
    broker: any,
    topic: str,
    group: str,
    handler: Callable[[Event], any],
    retry: RetryPolicy,
    start_from: str = StreamPosition.LATEST.value
) -> None;


def wait_or_stop(broker: any, seconds: float) -> bool;
