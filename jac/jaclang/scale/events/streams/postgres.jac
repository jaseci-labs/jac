import json;
import logging;
import socket;
import os;
import time;
import uuid;
import from threading { Thread, Event as _ThreadStop }
import from typing { cast }
import from jaclang.data.store { TxnIsolation }
import from jaclang.scale.events.broker {
    EventStreamBroker,
    Event,
    RetryPolicy,
    HealthStatus,
    StreamPosition,
    starts_at_earliest
}

def _jsonable(o: any) -> str {
    return str(o);
}


glob _logger = logging.getLogger(__name__),
     _POLL_SECONDS = 0.5,
     _STREAM_SCHEMA = [
         """
         CREATE TABLE IF NOT EXISTS jac_events (
             id         bigserial PRIMARY KEY,
             topic      text NOT NULL,
             payload    jsonb NOT NULL,
             created_at timestamptz NOT NULL DEFAULT now()
         )
         """,
         """
         CREATE INDEX IF NOT EXISTS idx_jac_events_topic
             ON jac_events (topic, id)
         """,
         """
         CREATE TABLE IF NOT EXISTS jac_event_offsets (
             topic   text NOT NULL,
             grp     text NOT NULL,
             last_id bigint NOT NULL DEFAULT 0,
             PRIMARY KEY (topic, grp)
         )
         """
     ];


obj PgEventStream(EventStreamBroker) {
    has config: dict[str, any] = {},
        _store: any = None,
        _consumer_name: str = "",
        _default_group: str = "jac-scale",
        _default_retry: RetryPolicy = RetryPolicy(),
        _stop_event: _ThreadStop = _ThreadStop(),
        _threads: list[Thread] = [],
        _positioned: set[str] = set();

    def postinit {
        self._consumer_name = (
            f"{socket.gethostname()}-{os.getpid()}-{uuid.uuid4().hex[:6]}"
        );
    }

    def _ensure_store -> any {
        if self._store is None {
            import from jaclang.server.session { conninfo_from_url }
            import from jaclang.data.store { PgStore }
            import from jaclang.server.shared_store { scale_db_url }
            url = self.config.get('url') or scale_db_url();
            assert url , "PgEventStream needs a database url (JAC_DB_URL)";
            store = PgStore(conninfo=conninfo_from_url(str(url)));
            for stmt in _STREAM_SCHEMA {
                store.rows(stmt, {});
            }
            self._store = store;
        }
        return self._store;
    }

    def start {
        self._ensure_store();
    }

    def stop(drain: bool = True) {
        self._stop_event.set();
        for t in self._threads {
            t.join(timeout=5.0);
        }
        self._threads = [];
        self._positioned = set();
        if self._store is not None {
            self._store.close();
            self._store = None;
        }
    }

    def publish(topic: str, event: Event, key: str | None = None) {
        store = self._ensure_store();
        payload = {
            'id': event.id,
            'event_type': event.event_type,
            'data': event.data,
            'key': key
        };
        store.rows(
            """
            INSERT INTO jac_events (topic, payload)
            VALUES (:t, CAST(:p AS jsonb))
            """,
            {'t': topic, 'p': json.dumps(payload, `default=_jsonable)}
        );
    }

    def _ensure_offset(topic: str, group: str, start_from: str) -> None {
        key = f"{topic}::{group}";
        if key in self._positioned {
            return;
        }
        store = self._ensure_store();
        if starts_at_earliest(start_from) {
            store.rows(
                """
                INSERT INTO jac_event_offsets (topic, grp, last_id)
                VALUES (:t, :g, 0) ON CONFLICT DO NOTHING
                """,
                {'t': topic, 'g': group}
            );
        } else {
            store.rows(
                """
                INSERT INTO jac_event_offsets (topic, grp, last_id)
                SELECT :t, :g, COALESCE(max(id), 0) FROM jac_events
                WHERE topic = :t
                ON CONFLICT DO NOTHING
                """,
                {'t': topic, 'g': group}
            );
        }
        self._positioned.add(key);
    }

    def _claim(topic: str, group: str, max_messages: int) -> list {
        store = self._ensure_store();
        store.begin(TxnIsolation.READ_COMMITTED);
        try {
            store.rows(
                """
                INSERT INTO jac_event_offsets (topic, grp)
                VALUES (:t, :g) ON CONFLICT DO NOTHING
                """,
                {'t': topic, 'g': group}
            );
            cur = store.rows(
                """
                SELECT last_id FROM jac_event_offsets
                WHERE topic = :t AND grp = :g FOR UPDATE SKIP LOCKED
                """,
                {'t': topic, 'g': group}
            );
            if not cur {
                store.commit();
                return [];
            }
            rows = store.rows(
                """
                SELECT id, payload FROM jac_events
                WHERE topic = :t AND id > :last ORDER BY id LIMIT :n
                """,
                {'t': topic, 'last': int(cur[0][0]), 'n': max_messages}
            );
            store.commit();
            return rows;
        } except Exception {
            store.rollback();
            raise;
        }
    }

    def _advance(topic: str, group: str, hi: int) {
        self._ensure_store().rows(
            """
            UPDATE jac_event_offsets SET last_id = :hi
            WHERE topic = :t AND grp = :g AND last_id < :hi
            """,
            {'t': topic, 'g': group, 'hi': hi}
        );
    }

    def _to_event(payload: any) -> Event {
        data = payload if isinstance(payload, dict) else json.loads(str(payload));
        return Event(
            event_type=str(data.get('event_type') or ''),
            data=cast(dict, data.get('data') or {}),
            id=str(data.get('id') or uuid.uuid4())
        );
    }

    def consume(
        topic: str,
        group: str | None = None,
        max_messages: int = 1,
        timeout_seconds: float = 5.0,
        start_from: str = StreamPosition.LATEST.value
    ) -> list[Event] {
        grp = group or self._default_group;
        self._ensure_offset(topic, grp, start_from);
        deadline = time.monotonic() + timeout_seconds;
        while True {
            rows = self._claim(topic, grp, max_messages);
            if rows {
                self._advance(topic, grp, int(rows[-1][0]));
                return [self._to_event(r[1]) for r in rows];
            }
            if time.monotonic() >= deadline {
                return [];
            }
            time.sleep(min(_POLL_SECONDS, max(0.05, deadline - time.monotonic())));
        }
    }

    def ack(event: Event) {}
    def _send_to_dlq(topic: str, event: Event, retry: RetryPolicy) {
        try {
            self.publish(topic + retry.dead_letter_suffix, event);
        } except Exception as e {
            _logger.error(f"PgEventStream: DLQ publish failed for {topic}: {e}");
        }
    }

    def _handle_with_retry(
        topic: str, group: str, event: Event, handler: Callable, retry: RetryPolicy
    ) {
        h: any = handler;
        for attempt in range(retry.max_attempts) {
            try {
                h(event);
                return;
            } except Exception as e {
                _logger.warning(
                    f"handler for {topic} failed "
                    f"(attempt {attempt + 1}/{retry.max_attempts}): {e}"
                );
                if attempt + 1 < retry.max_attempts {
                    idx = min(attempt, len(retry.backoff_seconds) - 1);
                    time.sleep(retry.backoff_seconds[idx]);
                }
            }
        }
        self._send_to_dlq(topic, event, retry);
    }

    def register_handler(
        topic: str,
        handler: Callable[[Event], any],
        group: str | None = None,
        retry: RetryPolicy | None = None,
        start_from: str = StreamPosition.LATEST.value
    ) {
        grp = group or self._default_group;
        pol = retry or self._default_retry;
        self._ensure_offset(topic, grp, start_from);

        def _loop {
            while not self._stop_event.is_set() {
                try {
                    rows = self._claim(topic, grp, 16);
                    if rows {
                        for r in rows {
                            self._handle_with_retry(
                                topic, grp, self._to_event(r[1]), handler, pol
                            );
                        }
                        self._advance(topic, grp, int(rows[-1][0]));
                        continue;
                    }
                } except Exception as e {
                    _logger.warning(f"PgEventStream consume error on {topic}: {e}");
                }
                self._stop_event.`wait(_POLL_SECONDS);
            }
        }
        t = Thread(target=_loop, daemon=True, name=f"jac-events-{topic}");
        self._threads.append(t);
        t.start();
    }

    def health -> HealthStatus {
        try {
            ok = self._ensure_store().is_available();
        } except Exception {
            ok = False;
        }
        return HealthStatus(
            healthy=ok, broker='postgres', details={'consumer': self._consumer_name}
        );
    }
}
