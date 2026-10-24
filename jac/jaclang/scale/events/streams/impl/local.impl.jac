impl LocalEventStream.postinit {
    self._default_group = self.config.get('consumer_group', 'jac-scale');
    retry_cfg = self.config.get('retry', {});
    defaults = RetryPolicy();
    self._default_retry = RetryPolicy(
        max_attempts=retry_cfg.get('max_attempts', defaults.max_attempts),
        backoff_seconds=retry_cfg.get('backoff_seconds', defaults.backoff_seconds),
        dead_letter_suffix=retry_cfg.get(
            'dead_letter_suffix', defaults.dead_letter_suffix
        )
    );
}

impl LocalEventStream.start {
    self._stop_event.clear();
}

impl LocalEventStream.stop(drain: bool = True) {
    self._stop_event.set();

    with self._lock {
        for sig in self._condition_events.values() {
            sig.set();
        }
    }
    if drain {
        deadline = time.time() + 10.0;
        for t in self._threads {
            remaining = max(0.0, deadline - time.time());
            try {
                t.join(timeout=remaining);
            } except Exception as e {
                _logger.warning(f"Thread join failed: {e}");
            }
        }
    }
    self._threads = [];
}

impl LocalEventStream._topic_signal(topic: str) -> _ThreadStop {
    if topic not in self._condition_events {
        self._condition_events[topic] = _ThreadStop();
    }
    return self._condition_events[topic];
}

impl LocalEventStream._ensure_offset(topic: str, group: str, start_from: str) -> None {
    key = f"{topic}::{group}";
    if key in self._offsets {
        return;
    }
    with self._lock {
        if key in self._offsets {
            return;
        }
        log = self._topics.get(topic, []);
        if starts_at_earliest(start_from) {
            self._offsets[key] = 0;
        } else {
            self._offsets[key] = len(log);
        }
    }
}

impl LocalEventStream.publish(topic: str, event: Event, key: str | None = None) {
    with self._lock {
        log = self._topics.setdefault(topic, []);
        log.append(event);
        sig = self._topic_signal(topic);
    }
    sig.set();
}

impl LocalEventStream.consume(
    topic: str,
    group: str | None = None,
    max_messages: int = 1,
    timeout_seconds: float = 5.0,
    start_from: str = StreamPosition.LATEST.value
) -> list[Event] {
    grp = group or self._default_group;
    self._ensure_offset(topic, grp, start_from);
    offset_key = f"{topic}::{grp}";
    deadline = time.time() + timeout_seconds;

    while True {
        with self._lock {
            log = self._topics.get(topic, []);
            start = self._offsets.get(offset_key, 0);
            slice_end = min(len(log), start + max_messages);
            events = log[start:slice_end];
            if events {
                self._offsets[offset_key] = slice_end;
                return events;
            }
            sig = self._topic_signal(topic);
            sig.clear();
        }
        remaining = deadline - time.time();
        if remaining <= 0 {
            return [];
        }
        if self._stop_event.is_set() {
            return [];
        }
        sig.`wait(timeout=min(remaining, 1.0));
        if self._stop_event.is_set() {
            return [];
        }
    }
}

impl LocalEventStream.ack(event: Event) -> None {
    return;
}

impl LocalEventStream._send_to_dlq(topic: str, event: Event, retry: RetryPolicy) {
    try {
        self.publish(topic + retry.dead_letter_suffix, event);
    } except Exception as e {
        _logger.error(f"DLQ publish failed for {topic}: {e}");
    }
}

impl LocalEventStream._handle_with_retry(
    topic: str,
    group: str,
    event: Event,
    handler: Callable[[Event], any],
    retry: RetryPolicy
) -> None {
    import inspect;
    backoff = retry.backoff_seconds or [1.0];
    for attempt in range(retry.max_attempts) {
        try {
            result = handler(event);

            if inspect.iscoroutine(result) {
                result.close();
                raise TypeError(
                    "subscribed handler returned a coroutine. "
                    "@subscribe handlers must be synchronous; "
                    "wrap async work with asyncio.run() or schedule it explicitly."
                );
            }
            return;
        } except Exception as e {
            _logger.warning(
                f"Handler raised on {topic} attempt "
                f"{attempt + 1}/{retry.max_attempts}: {e}"
            );
            if attempt + 1 < retry.max_attempts {
                delay = backoff[min(attempt, len(backoff) - 1)];
                if wait_or_stop(self, delay) {
                    return;
                }
            }
        }
    }
    self._send_to_dlq(topic, event, retry);
}

impl LocalEventStream.register_handler(
    topic: str,
    handler: Callable[[Event], any],
    group: str | None = None,
    retry: RetryPolicy | None = None,
    start_from: str = StreamPosition.LATEST.value
) {
    grp = group or self._default_group;
    retry_policy = retry or self._default_retry;
    self._ensure_offset(topic, grp, start_from);

    broker = self;
    def _loop {
        consumer_loop(broker, topic, grp, handler, retry_policy, start_from);
    }

    thread = Thread(target=_loop, name=f"jac-scale-local-{topic}-{grp}", daemon=True);
    self._threads.append(thread);
    thread.start();
}

impl LocalEventStream.health -> HealthStatus {
    with self._lock {
        return HealthStatus(
            healthy=True,
            broker="local",
            details={"topics": len(self._topics), "threads": len(self._threads)}
        );
    }
}
