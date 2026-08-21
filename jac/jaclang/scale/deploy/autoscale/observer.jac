import from threading { Lock }
import time;
import from jaclang.scale.deploy.autoscale.autoscaler { AutoscalerTransition }

enum BackpressurePolicy {
    DROP_OLDEST = "drop_oldest",
    DROP_NEWEST = "drop_newest",
    CLOSE = "close",
}

obj AutoscalerSubscription {
    has autoscaler_name: (str | None) = None,
        scale_target_name: (str | None) = None,
        max_queue: int = 100,
        backpressure: str = BackpressurePolicy.DROP_OLDEST.value,
        _queue: list[AutoscalerTransition] = [],
        _dropped: int = 0,
        _closed: bool = False,
        _lock: Lock = Lock();

    def _matches(transition: AutoscalerTransition) -> bool {
        if self.autoscaler_name is not None
            and transition.autoscaler_name != self.autoscaler_name {
            return False;
        }
        if self.scale_target_name is not None
            and transition.scale_target_name != self.scale_target_name {
            return False;
        }
        return True;
    }

    def _deliver(transition: AutoscalerTransition) -> None {
        with self._lock {
            if self._closed {
                return;
            }
            if not self._matches(transition) {
                return;
            }
            if len(self._queue) < self.max_queue {
                self._queue.append(transition);
                return;
            }
            if self.backpressure == BackpressurePolicy.DROP_OLDEST.value {
                self._queue.pop(0);
                self._queue.append(transition);
                self._dropped += 1;
            } elif self.backpressure == BackpressurePolicy.DROP_NEWEST.value {
                self._dropped += 1;
            } elif self.backpressure == BackpressurePolicy.CLOSE.value {
                self._closed = True;
                self._dropped += 1;
            } else {
                raise ValueError(f"Unknown backpressure policy: {self.backpressure}");
            }
        }
    }

    def poll(timeout_seconds: float = 5.0) -> (AutoscalerTransition | None) {
        deadline = time.time() + timeout_seconds;
        while True {
            with self._lock {
                if self._queue {
                    return self._queue.pop(0);
                }
                if self._closed {
                    return None;
                }
            }
            remaining = deadline - time.time();
            if remaining <= 0 {
                return None;
            }
            time.sleep(min(0.05, remaining));
        }
    }

    def close {
        with self._lock {
            self._closed = True;
        }
    }

    def is_closed -> bool {
        with self._lock {
            return self._closed;
        }
    }

    def dropped_count -> int {
        with self._lock {
            return self._dropped;
        }
    }
}
