"""Redis Streams implementation of MessageBroker.

Maps publish/subscribe/consume/ack to XADD/XREADGROUP/XACK; routes to <topic><dead_letter_suffix> on retry exhaustion.
"""
import from typing { Any, Callable }
import from threading { Thread, Event as _ThreadStop }
import from jac_scale.abstractions.pubsub {
    MessageBroker,
    Event,
    RetryPolicy,
    Subscription,
    HealthStatus
}
import from jac_scale._optdeps.redis { Redis }
import from jac_scale.db { get_redis_client }
import logging;
import json;
import socket;
import os;
import time;
import uuid;


"""Decode bytes to str if needed; pass through everything else as str(x)."""
def _to_str(value: Any) -> str {
    if isinstance(value, bytes) {
        return value.decode("utf-8");
    }
    return str(value);
}

# Reserved header keys used to carry delivery metadata back to ack().
glob _logger = logging.getLogger(__name__),
     DELIVERY_ID_HEADER = "_jac_scale_delivery_id",
     DELIVERY_TOPIC_HEADER = "_jac_scale_delivery_topic",
     DELIVERY_GROUP_HEADER = "_jac_scale_delivery_group";

"""Redis Streams broker. subscribe() spawns a daemon thread; stop(drain=True) joins all threads."""
obj RedisStreamsBroker(MessageBroker) {
    has config: dict[str, Any] = {},
        _client: Redis | None = None,
        _consumer_name: str = "",
        _default_group: str = "jac-scale",
        _default_retry: RetryPolicy = RetryPolicy(),
        _stop_event: _ThreadStop = _ThreadStop(),
        _threads: list[Thread] = [],
        _ensured_groups: set[str] = set();

    def postinit {
        try {
            host = socket.gethostname();
        } except (socket.gaierror, OSError) {
            host = "unknown";
        }
        self._consumer_name = f"{host}-{os.getpid()}-{str(uuid.uuid4())[:8]}";
        self._default_group = self.config.get("consumer_group", "jac-scale");
        # Pull retry defaults from the abstraction so they live in one place.
        retry_cfg = self.config.get("retry", {});
        defaults = RetryPolicy();
        self._default_retry = RetryPolicy(
            max_attempts=retry_cfg.get("max_attempts", defaults.max_attempts),
            backoff_seconds=retry_cfg.get("backoff_seconds", defaults.backoff_seconds),
            dead_letter_suffix=retry_cfg.get(
                "dead_letter_suffix", defaults.dead_letter_suffix
            )
        );
    }

    def _get_client -> Redis {
        if self._client is None {
            url = self.config.get("url");
            self._client = get_redis_client(url);
        }
        return self._client;
    }

    def _serialize_event(event: Event) -> str {
        # Wire format follows CloudEvents ('type' on the wire) even
        # though jac forces the in-memory field to be 'event_type'.
        clean_headers = {
            k: v
            for (k, v) in event.headers.items()
            if not k.startswith("_jac_scale_")
        };
        return json.dumps(
            {
                "type": event.event_type,
                "data": event.data,
                "id": event.id,
                "source": event.source,
                "time": event.time,
                "trace_id": event.trace_id,
                "headers": clean_headers
            }
        );
    }

    def _xadd_payload(stream: str, event: Event) {
        self._get_client().xadd(stream, {"payload": self._serialize_event(event)});
    }

    def _deserialize_event(raw: Any) -> Event {
        d = json.loads(_to_str(raw));
        return Event(
            event_type=d.get("type", ""),
            data=d.get("data", {}),
            id=d.get("id", str(uuid.uuid4())),
            source=d.get("source", "jac-scale"),
            time=d.get("time", ""),
            trace_id=d.get("trace_id"),
            headers=d.get("headers", {})
        );
    }

    def _ensure_group(topic: str, group: str) -> None {
        key = f"{topic}::{group}";
        if key in self._ensured_groups {
            return;
        }
        try {
            self._get_client().xgroup_create(topic, group, id="$", mkstream=True);
        } except Exception as e {
            # BUSYGROUP just means the group already exists; anything
            # else is a real error and worth surfacing.
            if "BUSYGROUP" not in str(e) {
                _logger.warning(f"XGROUP CREATE failed for {topic}/{group}: {e}");
            }
        }
        self._ensured_groups.add(key);
    }

    def _decode_message(topic: str, group: str, msg_id: Any, fields: dict) -> Event {
        # redis-py returns bytes by default unless decode_responses=True
        payload = fields.get(b"payload") or fields.get("payload");
        event = self._deserialize_event(payload);
        event.headers[DELIVERY_ID_HEADER] = _to_str(msg_id);
        event.headers[DELIVERY_TOPIC_HEADER] = topic;
        event.headers[DELIVERY_GROUP_HEADER] = group;
        return event;
    }

    def start {
        # Threads are spawned in subscribe(); start() just signals
        # 'we are operational' by clearing the stop event.
        self._stop_event.clear();
    }

    def stop(drain: bool = True) {
        self._stop_event.set();
        if drain {
            # Shared deadline so total wait is <=10s regardless of thread count.
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

    def publish(topic: str, event: Event, key: str | None = None) {
        # Fire-and-forget: log and swallow so emit sites don't have to try/except.
        try {
            self._xadd_payload(topic, event);
        } except Exception as e {
            _logger.error(f"XADD failed for topic {topic}: {e}");
        }
    }

    def consume(
        topic: str,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 5.0
    ) -> list[Event] {
        grp = group or self._default_group;
        self._ensure_group(topic, grp);
        block_ms = max(1, int(timeout_seconds * 1000));
        try {
            result = self._get_client().xreadgroup(
                groupname=grp,
                consumername=self._consumer_name,
                streams={topic: ">"},
                count=max_messages,
                block=block_ms
            );
        } except Exception as e {
            _logger.error(f"XREADGROUP failed for {topic}/{grp}: {e}");
            return [];
        }
        events: list[Event] = [];
        if not result {
            return events;
        }
        for (_stream, messages) in result {
            for (msg_id, fields) in messages {
                try {
                    events.append(self._decode_message(topic, grp, msg_id, fields));
                } except Exception as e {
                    _logger.error(f"Decode failed for message {msg_id}: {e}");
                }
            }
        }
        return events;
    }

    def ack(event: Event) -> None {
        msg_id = event.headers.get(DELIVERY_ID_HEADER);
        topic = event.headers.get(DELIVERY_TOPIC_HEADER);
        group = event.headers.get(DELIVERY_GROUP_HEADER);
        if not msg_id or not topic or not group {
            return;
        }
        try {
            self._get_client().xack(topic, group, msg_id);
        } except Exception as e {
            _logger.warning(f"XACK failed for {topic}/{group}/{msg_id}: {e}");
        }
    }

    def _send_to_dlq(topic: str, event: Event, retry: RetryPolicy) {
        dlq = topic + retry.dead_letter_suffix;
        try {
            self._xadd_payload(dlq, event);
        } except Exception as e {
            _logger.error(f"DLQ publish failed for {dlq}: {e}");
        }
    }

    def _wait_or_stop(seconds: float) -> bool {
        # Wait up to `seconds`, polling _stop_event in <=1s chunks so a SIGTERM
        # during a long backoff doesn't block shutdown for the full delay.
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
        backoff = retry.backoff_seconds or [1.0];
        for attempt in range(retry.max_attempts) {
            try {
                handler(event);
                self.ack(event);
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
        # Exhausted - DLQ then ack so it doesn't redeliver forever.
        self._send_to_dlq(topic, event, retry);
        self.ack(event);
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

    def subscribe(
        topic: str,
        handler: Callable[[Event], Any],
        group: str | None = None,
        retry: RetryPolicy | None = None
    ) -> Subscription {
        grp = group or self._default_group;
        retry_policy = retry or self._default_retry;
        self._ensure_group(topic, grp);

        broker = self;
        def _loop {
            broker._consumer_loop(topic, grp, handler, retry_policy);
        }

        thread = Thread(
            target=_loop, name=f"jac-scale-broker-{topic}-{grp}", daemon=True
        );
        self._threads.append(thread);
        thread.start();

        return Subscription(topic=topic, group=grp);
    }

    def health -> HealthStatus {
        try {
            ok = bool(self._get_client().ping());
            return HealthStatus(
                healthy=ok,
                broker="redis_streams",
                details={
                    "consumer_name": self._consumer_name,
                    "threads": len(self._threads)
                }
            );
        } except Exception as e {
            return HealthStatus(
                healthy=False, broker="redis_streams", details={"error": str(e)}
            );
        }
    }

    def is_enabled -> bool {
        return True;
    }
}
