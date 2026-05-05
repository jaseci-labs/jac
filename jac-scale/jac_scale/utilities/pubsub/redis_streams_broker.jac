"""Redis Streams implementation of MessageBroker.

Maps the abstraction onto Redis primitives:
- publish        -> XADD topic * payload <json>
- subscribe      -> XGROUP CREATE + background thread running XREADGROUP
- consume / ack  -> XREADGROUP / XACK
- DLQ on retry exhaustion -> XADD <topic><dead_letter_suffix>

Delivery metadata (Redis stream id, topic, group) is stored on the
returned Event under reserved header keys so ack(event) can resolve
the right XACK target without a separate handle type.
"""
import from typing { Any, Callable }
import from threading { Thread, Event as _ThreadStop, Lock as _BrokerLock }
import from jac_scale.abstractions.pubsub {
    MessageBroker,
    Event,
    RetryPolicy,
    Subscription,
    HealthStatus
}
import from jac_scale._optdeps.redis { Redis }
import from jac_scale._optdeps.optional_deps { require_optional }
import from jac_scale.db { get_redis_client }
import logging;
import json;
import socket;
import os;
import uuid;

glob _logger = logging.getLogger(__name__);

# Reserved header keys used to carry delivery metadata back to ack().
glob DELIVERY_ID_HEADER = "_jac_scale_delivery_id",
     DELIVERY_TOPIC_HEADER = "_jac_scale_delivery_topic",
     DELIVERY_GROUP_HEADER = "_jac_scale_delivery_group";

"""Redis Streams broker.

Each subscribe() spawns a daemon thread that loops on XREADGROUP.
stop(drain=True) sets the shared stop event and joins all threads.
"""
obj RedisStreamsBroker(MessageBroker) {
    has config: dict[str, Any] = {},
        _client: Redis | None = None,
        _consumer_name: str = "",
        _default_group: str = "jac-scale",
        _default_retry: RetryPolicy = RetryPolicy(),
        _stop_event: _ThreadStop = _ThreadStop(),
        _threads: list[Thread] = [],
        _ensured_groups: dict[str, bool] = {},
        _lock: _BrokerLock = _BrokerLock();

    def postinit {
        try {
            host = socket.gethostname();
        } except Exception {
            host = "unknown";
        }
        self._consumer_name = f"{host}-{os.getpid()}-{str(uuid.uuid4())[:8]}";
        self._default_group = self.config.get("consumer_group", "jac-scale");
        retry_cfg = self.config.get("retry", {});
        self._default_retry = RetryPolicy(
            max_attempts=retry_cfg.get("max_attempts", 3),
            backoff_seconds=retry_cfg.get("backoff_seconds", [1.0, 5.0, 30.0]),
            dead_letter_suffix=retry_cfg.get("dead_letter_suffix", ".dlq")
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
        return json.dumps({
            "type": event.event_type,
            "data": event.data,
            "id": event.id,
            "source": event.source,
            "time": event.time,
            "trace_id": event.trace_id,
            "headers": event.headers
        });
    }

    def _deserialize_event(raw: Any) -> Event {
        if isinstance(raw, bytes) {
            raw = raw.decode("utf-8");
        }
        d = json.loads(raw);
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
            self._get_client().xgroup_create(
                topic, group, id="$", mkstream=True
            );
        } except Exception as e {
            # BUSYGROUP just means the group already exists; anything
            # else is a real error and worth surfacing.
            if "BUSYGROUP" not in str(e) {
                _logger.warning(
                    f"XGROUP CREATE failed for {topic}/{group}: {e}"
                );
            }
        }
        self._ensured_groups[key] = True;
    }

    def _decode_message(
        topic: str, group: str, msg_id: Any, fields: dict
    ) -> Event {
        # redis-py returns bytes by default unless decode_responses=True
        payload = None;
        for (k, v) in fields.items() {
            key_str = k.decode("utf-8") if isinstance(k, bytes) else k;
            if key_str == "payload" {
                payload = v;
                break;
            }
        }
        event = self._deserialize_event(payload);
        msg_id_str = (
            msg_id.decode("utf-8") if isinstance(msg_id, bytes) else str(msg_id)
        );
        event.headers[DELIVERY_ID_HEADER] = msg_id_str;
        event.headers[DELIVERY_TOPIC_HEADER] = topic;
        event.headers[DELIVERY_GROUP_HEADER] = group;
        return event;
    }

    def start -> None {
        # Threads are spawned in subscribe(); start() just signals
        # 'we are operational' by clearing the stop event.
        self._stop_event.clear();
    }

    def stop(drain: bool = True) -> None {
        self._stop_event.set();
        if drain {
            for t in self._threads {
                try {
                    t.join(timeout=10.0);
                } except Exception as e {
                    _logger.warning(f"Thread join failed: {e}");
                }
            }
        }
        self._threads = [];
    }

    def publish(topic: str, event: Event, key: str | None = None) -> None {
        try {
            self._get_client().xadd(
                topic, {"payload": self._serialize_event(event)}
            );
        } except Exception as e {
            _logger.error(f"XADD failed for topic {topic}: {e}");
            raise;
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
                    events.append(
                        self._decode_message(topic, grp, msg_id, fields)
                    );
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
            _logger.warning(
                f"XACK failed for {topic}/{group}/{msg_id}: {e}"
            );
        }
    }

    def _send_to_dlq(topic: str, event: Event, retry: RetryPolicy) -> None {
        dlq = topic + retry.dead_letter_suffix;
        try {
            self._get_client().xadd(
                dlq, {"payload": self._serialize_event(event)}
            );
        } except Exception as e {
            _logger.error(f"DLQ publish failed for {dlq}: {e}");
        }
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
                    if self._stop_event.wait(timeout=delay) {
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
        topic: str,
        group: str,
        handler: Callable[[Event], Any],
        retry: RetryPolicy
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
        require_optional("redis", "data");
        grp = group or self._default_group;
        retry_policy = retry or self._default_retry;
        self._ensure_group(topic, grp);

        broker = self;
        def _loop -> None {
            broker._consumer_loop(topic, grp, handler, retry_policy);
        }

        thread = Thread(
            target=_loop,
            name=f"jac-scale-broker-{topic}-{grp}",
            daemon=True
        );
        with self._lock {
            self._threads.append(thread);
        }
        thread.start();

        return Subscription(topic=topic, group=grp, handler=handler);
    }

    def health -> HealthStatus {
        try {
            ok = bool(self._get_client().ping());
            return HealthStatus(
                healthy=ok,
                backend="redis_streams",
                details={
                    "consumer_name": self._consumer_name,
                    "threads": len(self._threads)
                }
            );
        } except Exception as e {
            return HealthStatus(
                healthy=False,
                backend="redis_streams",
                details={"error": str(e)}
            );
        }
    }

    def is_enabled -> bool {
        return True;
    }
}
