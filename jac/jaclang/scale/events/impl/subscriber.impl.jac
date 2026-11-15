impl subscribe(
    topic: str,
    group: str | None = None,
    retry: RetryPolicy | None = None,
    start_from: str = StreamPosition.LATEST.value
) -> Callable[..., any] {
    def _decorator(handler: Callable[[Event], any]) -> Callable[..., any] {
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

impl get_subscriptions -> list[_SubscriptionEntry] {
    return _registry;
}
