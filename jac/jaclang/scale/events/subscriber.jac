obj _SubscriptionEntry {
    has topic: str,
        handler: Callable[[Event], any],
        group: str | None = None,
        retry: RetryPolicy | None = None,
        start_from: str = StreamPosition.LATEST.value;
}

glob _registry: list[_SubscriptionEntry] = [];

def subscribe(
    topic: str,
    group: str | None = None,
    retry: RetryPolicy | None = None,
    start_from: str = StreamPosition.LATEST.value
) -> Callable[..., any];

def get_subscriptions -> list[_SubscriptionEntry];
