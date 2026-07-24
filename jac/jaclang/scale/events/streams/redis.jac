import from typing { Callable }
import from threading { Thread, Event as _ThreadStop }
import from jaclang.scale.events.broker {
    EventStreamBroker,
    Event,
    RetryPolicy,
    HealthStatus
}
import from jaclang.scale.events.streams._stream_common { consumer_loop, wait_or_stop }
import from jaclang.scale._optdeps.redis { Redis }
import from jaclang.scale.persistence.db { get_redis_client }
import logging;
import json;
import socket;
import os;
import time;
import uuid;


def _to_str(value: any) -> str {
    if isinstance(value, bytes) {
        return value.decode("utf-8");
    }
    return str(value);
}

glob _logger = logging.getLogger(__name__),
     _CONSUME_ERROR_BACKOFF: float = 0.5,
     _STREAM_MAXLEN_DEFAULT: int = 10000,
     _NOGROUP_MAX_ATTEMPTS: int = 3,
     _NOGROUP_RETRY_BACKOFF: float = 0.05;

obj RedisEventStream(EventStreamBroker) {
    has config: dict[str, any] = {},
        _client: Redis | None = None,
        _consumer_name: str = "",
        _default_group: str = "jac-scale",
        _default_retry: RetryPolicy = RetryPolicy(),
        _stop_event: _ThreadStop = _ThreadStop(),
        _threads: list[Thread] = [],
        _ensured_groups: set[str] = set(),
        _stream_maxlen: int = _STREAM_MAXLEN_DEFAULT,
        _eviction_checked: bool = False;

    def postinit {
        try {
            host = socket.gethostname();
        } except (socket.gaierror, OSError) {
            host = "unknown";
        }
        self._consumer_name = f"{host}-{os.getpid()}-{str(uuid.uuid4())[:8]}";
        self._default_group = self.config.get("consumer_group", "jac-scale");
        self._stream_maxlen = int(
            self.config.get("stream_maxlen", _STREAM_MAXLEN_DEFAULT)
        );

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
            self._warn_on_evictable_streams();
        }
        return self._client;
    }

    def _eviction_settings -> dict[str, str] {
        try {
            raw = self._client.config_get("maxmemory*");
        } except Exception as e {
            _logger.debug(f"CONFIG GET maxmemory failed: {e}");
            return {};
        }
        settings = {_to_str(k): _to_str(v) for (k, v) in raw.items()};
        return {
            key: settings[key]
            for key in ("maxmemory", "maxmemory-policy")
            if key in settings
        };
    }

    def _warn_on_evictable_streams -> None {
        if self._eviction_checked {
            return;
        }
        self._eviction_checked = True;
        settings = self._eviction_settings();
        policy = settings.get("maxmemory-policy", "");
        max_memory = settings.get("maxmemory", "0");
        if not policy.startswith("allkeys-") or max_memory in ("", "0") {
            return;
        }
        _logger.warning(
            f"Redis maxmemory-policy is '{policy}' with maxmemory {max_memory}; event "
            f"streams carry no TTL and can be evicted under memory pressure, dropping "
            f"undelivered events. Use a 'volatile-*' policy so only expiring cache keys "
            f"are evicted."
        );
    }

    def _serialize_event(event: Event) -> str {
        return json.dumps(
            {
                "specversion": "1.0",
                "type": event.event_type,
                "data": event.data,
                "id": event.id,
                "source": event.source,
                "time": event.time,
                "trace_id": event.trace_id,
                "headers": event.headers
            }
        );
    }

    def _xadd_payload(stream: str, event: Event) {
        self._get_client().xadd(
            stream,
            {"payload": self._serialize_event(event)},
            maxlen=self._stream_maxlen if self._stream_maxlen > 0 else None,
            approximate=True
        );
    }

    def _deserialize_event(raw: any) -> Event {
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

    def _resolve_start_id(start_from: str) -> str {
        if start_from == "latest" {
            return "$";
        }
        if start_from == "earliest" {
            return "0";
        }
        return start_from;
    }

    def _ensure_group(
        topic: str, group: str, start_from: str = "latest", force: bool = False
    ) -> None {
        key = f"{topic}::{group}";
        if not force and key in self._ensured_groups {
            return;
        }
        try {
            self._get_client().xgroup_create(
                topic, group, id=self._resolve_start_id(start_from), mkstream=True
            );
        } except Exception as e {
            if "BUSYGROUP" not in str(e) {
                _logger.warning(f"XGROUP CREATE failed for {topic}/{group}: {e}");
                self._ensured_groups.discard(key);
                return;
            }
        }
        self._ensured_groups.add(key);
    }

    def _decode_message(topic: str, group: str, msg_id: any, fields: dict) -> Event {
        payload = fields.get(b"payload") or fields.get("payload");
        event = self._deserialize_event(payload);
        event.delivery_id = _to_str(msg_id);
        event.delivery_topic = topic;
        event.delivery_group = group;
        return event;
    }

    def start {
        self._stop_event.clear();
    }

    def stop(drain: bool = True) {
        self._stop_event.set();
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

    def publish(topic: str, event: Event, key: str | None = None) {
        try {
            self._xadd_payload(topic, event);
        } except Exception as e {
            _logger.error(f"XADD failed for topic {topic}: {e}");
        }
    }

    def _xreadgroup(topic: str, group: str, max_messages: int, block_ms: int) -> any {
        return self._get_client().xreadgroup(
            groupname=group,
            consumername=self._consumer_name,
            streams={topic: ">"},
            count=max_messages,
            block=block_ms
        );
    }

    def _read_group(
        topic: str, group: str, max_messages: int, block_ms: int, start_from: str
    ) -> any {
        last_error: Exception | None = None;
        for attempt in range(_NOGROUP_MAX_ATTEMPTS) {
            try {
                return self._xreadgroup(topic, group, max_messages, block_ms);
            } except Exception as e {
                if "NOGROUP" not in str(e) {
                    raise;
                }
                last_error = e;
            }
            _logger.error(
                f"Event loss on {topic}: stream or group {group} disappeared "
                f"(NOGROUP), undelivered events are gone; recreating "
                f"(attempt {attempt + 1}/{_NOGROUP_MAX_ATTEMPTS})"
            );
            self._ensure_group(topic, group, start_from, force=True);
            if wait_or_stop(self, _NOGROUP_RETRY_BACKOFF) {
                return None;
            }
        }
        raise last_error;
    }

    def consume(
        topic: str,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 5.0,
        start_from: str = "latest"
    ) -> list[Event] {
        grp = group or self._default_group;
        self._ensure_group(topic, grp, start_from);
        block_ms = max(1, int(timeout_seconds * 1000));
        try {
            result = self._read_group(topic, grp, max_messages, block_ms, start_from);
        } except Exception as e {
            _logger.error(f"XREADGROUP failed for {topic}/{grp}: {e}");
            wait_or_stop(self, _CONSUME_ERROR_BACKOFF);
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
        msg_id = event.delivery_id;
        topic = event.delivery_topic;
        group = event.delivery_group;
        if not msg_id or not topic or not group {
            return;
        }
        try {
            self._get_client().xack(topic, group, msg_id);
        } except Exception as e {
            _logger.warning(f"XACK failed for {topic}/{group}/{msg_id}: {e}");
        }
    }

    def _send_to_dlq(topic: str, event: Event, retry: RetryPolicy) -> bool {
        dlq = topic + retry.dead_letter_suffix;
        try {
            self._xadd_payload(dlq, event);
            return True;
        } except Exception as e {
            _logger.error(f"DLQ publish failed for {dlq}: {e}");
            return False;
        }
    }

    def _handle_with_retry(
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
                self.ack(event);
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

        if self._send_to_dlq(topic, event, retry) {
            self.ack(event);
        }
    }

    def register_handler(
        topic: str,
        handler: Callable[[Event], any],
        group: str | None = None,
        retry: RetryPolicy | None = None,
        start_from: str = "latest"
    ) {
        grp = group or self._default_group;
        retry_policy = retry or self._default_retry;
        self._ensure_group(topic, grp, start_from);

        broker = self;
        def _loop {
            consumer_loop(broker, topic, grp, handler, retry_policy, start_from);
        }

        thread = Thread(
            target=_loop, name=f"jac-scale-broker-{topic}-{grp}", daemon=True
        );
        self._threads.append(thread);
        thread.start();
    }

    def _evicted_keys -> int | None {
        try {
            return int(self._client.info("stats").get("evicted_keys"));
        } except Exception as e {
            _logger.debug(f"INFO stats failed: {e}");
            return None;
        }
    }

    def health -> HealthStatus {
        try {
            ok = bool(self._get_client().ping());
            details: dict[str, any] = {
                "consumer_name": self._consumer_name,
                "threads": len(self._threads),
                "evicted_keys": self._evicted_keys()
            };
            details.update(self._eviction_settings());
            return HealthStatus(healthy=ok, broker="redis", details=details);
        } except Exception as e {
            return HealthStatus(
                healthy=False, broker="redis", details={"error": str(e)}
            );
        }
    }
}
