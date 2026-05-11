"""In-memory implementation of EventStreamBroker.
Single-process, no persistence. Per-topic append-only lists + per-group integer offsets mimic Redis Streams semantics. Right for dev, tests, single-pod deployments without Redis.
"""
import from typing { Any, Callable }
import from threading { Thread, Event as _ThreadStop, Lock }
import from jac_scale.events.broker {
    EventStreamBroker,
    Event,
    RetryPolicy,
    HealthStatus
}
import logging;
import time;

glob _logger = logging.getLogger(__name__);

"""LocalEventStream. In-process append-only event log keyed by topic, with per-group offsets and competing-consumer fan-in within a group."""
obj LocalEventStream(EventStreamBroker) {
    has config: dict[str, Any] = {},
        _default_group: str = "jac-scale",
        _default_retry: RetryPolicy = RetryPolicy(),
        _stop_event: _ThreadStop = _ThreadStop(),
        _threads: list[Thread] = [],
        _lock: Lock = Lock(),
        _topics: dict[str, list[Event]] = {},
        _offsets: dict[str, int] = {},
        _condition_events: dict[str, _ThreadStop] = {};

    def postinit {
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

    def start {
        self._stop_event.clear();
    }

    def stop(drain: bool = True) {
        self._stop_event.set();
        # Wake every signal so blocked consumers exit promptly.
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

    def _topic_signal(topic: str) -> _ThreadStop {
        if topic not in self._condition_events {
            self._condition_events[topic] = _ThreadStop();
        }
        return self._condition_events[topic];
    }

    def _ensure_offset(topic: str, group: str, start_from: str) -> None {
        # Per-group cursor; created once on first sight.
        key = f"{topic}::{group}";
        if key in self._offsets {
            return;
        }
        with self._lock {
            if key in self._offsets {
                return;
            }
            log = self._topics.get(topic, []);
            if start_from == "earliest" {
                self._offsets[key] = 0;
            } else {
                # 'latest' or any unrecognized value falls through to latest.
                self._offsets[key] = len(log);
            }
        }
    }

    def publish(topic: str, event: Event, key: str | None = None) {
        # `key` is accepted for API parity; in-memory broker does no partitioning.
        with self._lock {
            log = self._topics.setdefault(topic, []);
            log.append(event);
            sig = self._topic_signal(topic);
        }
        sig.set();
    }

    def consume(
        topic: str,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 5.0,
        start_from: str = "latest"
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
            sig.wait(timeout=min(remaining, 1.0));
            if self._stop_event.is_set() {
                return [];
            }
        }
    }

    def ack(event: Event) -> None {
        # No-op; offsets advance on consume() in the in-memory broker.
        return;
    }

    def _send_to_dlq(topic: str, event: Event, retry: RetryPolicy) {
        # In-memory publish is effectively infallible; just log and move on.
        try {
            self.publish(topic + retry.dead_letter_suffix, event);
        } except Exception as e {
            _logger.error(f"DLQ publish failed for {topic}: {e}");
        }
    }

    def _wait_or_stop(seconds: float) -> bool {
        deadline = time.time() + seconds;
        while time.time() < deadline {
            chunk = min(deadline - time.time(), 1.0);
            if self._stop_event.wait(timeout=chunk) {
                return True;
            }
        }
        return False;
    }

    def _handle_with_retry(
        topic: str,
        group: str,
        event: Event,
        handler: Callable[[Event], Any],
        retry: RetryPolicy
    ) -> None {
        import inspect;
        backoff = retry.backoff_seconds or [1.0];
        for attempt in range(retry.max_attempts) {
            try {
                result = handler(event);
                # Async handlers would silently no-op (coroutine never awaited),
                # so reject them loudly. Subscribers must be sync today.
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
                    if self._wait_or_stop(delay) {
                        return;
                    }
                }
            }
        }
        self._send_to_dlq(topic, event, retry);
    }

    def _consumer_loop(
        topic: str, group: str, handler: Callable[[Event], Any], retry: RetryPolicy
    ) -> None {
        while not self._stop_event.is_set() {
            events = self.consume(
                topic, group=group, max_messages=10, timeout_seconds=5.0
            );
            for event in events {
                if self._stop_event.is_set() {
                    return;
                }
                self._handle_with_retry(topic, group, event, handler, retry);
            }
        }
    }

    def register_handler(
        topic: str,
        handler: Callable[[Event], Any],
        group: str | None = None,
        retry: RetryPolicy | None = None,
        start_from: str = "latest"
    ) {
        grp = group or self._default_group;
        retry_policy = retry or self._default_retry;
        self._ensure_offset(topic, grp, start_from);

        broker = self;
        def _loop {
            broker._consumer_loop(topic, grp, handler, retry_policy);
        }

        thread = Thread(
            target=_loop, name=f"jac-scale-local-{topic}-{grp}", daemon=True
        );
        self._threads.append(thread);
        thread.start();
    }

    def health -> HealthStatus {
        with self._lock {
            return HealthStatus(
                healthy=True,
                broker="local",
                details={"topics": len(self._topics), "threads": len(self._threads)}
            );
        }
    }
}
