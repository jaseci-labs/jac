import logging;
import os;
import socket;
import threading;
import uuid;
import from jaclang.scale.state.state_backend { StateBackend }

glob logger = logging.getLogger(__name__);


def _lock_owner -> str {
    return f"{socket.gethostname()}:{os.getpid()}:{uuid.uuid4().hex}";
}


obj PgStateBackend(StateBackend) {
    has store: any,
        _held: dict[str, str] = {},
        _held_guard: threading.Lock = threading.Lock();

    def get(key: str) -> (str | None) {
        return self.store.kv_get(key);
    }

    def `set(key: str, value: str, ttl_seconds: (int | None) = None) {
        self.store.rows(
            """
            INSERT INTO kv_state (key, value, expires_at, updated_at)
            VALUES (
                :k, :v,
                CASE WHEN CAST(:ttl AS int) IS NULL THEN NULL
                     ELSE now() + make_interval(secs => CAST(:ttl AS int)) END,
                now()
            )
            ON CONFLICT (key) DO UPDATE SET
                value = EXCLUDED.value,
                expires_at = EXCLUDED.expires_at,
                updated_at = now()
            """,
            {'k': key, 'v': value, 'ttl': ttl_seconds}
        );
    }

    def delete(key: str) {
        self.store.kv_delete(key);
    }

    def increment(
        key: str, amount: float = 1.0, ttl_seconds: (int | None) = None
    ) -> float {
        rows = self.store.rows(
            """
            INSERT INTO kv_state (key, value, expires_at, updated_at)
            VALUES (
                :k, CAST(:a AS float8)::text,
                CASE WHEN CAST(:ttl AS int) IS NULL THEN NULL
                     ELSE now() + make_interval(secs => CAST(:ttl AS int)) END,
                now()
            )
            ON CONFLICT (key) DO UPDATE SET
                value = CASE
                    WHEN kv_state.expires_at IS NOT NULL
                         AND kv_state.expires_at <= now()
                    THEN CAST(:a AS float8)::text
                    ELSE (kv_state.value::float8 + CAST(:a AS float8))::text
                END,
                expires_at = CASE
                    WHEN kv_state.expires_at IS NOT NULL
                         AND kv_state.expires_at <= now()
                    THEN EXCLUDED.expires_at
                    ELSE COALESCE(kv_state.expires_at, EXCLUDED.expires_at)
                END,
                updated_at = now()
            RETURNING value
            """,
            {'k': key, 'a': amount, 'ttl': ttl_seconds}
        );
        return float(str(rows[0][0]));
    }

    def acquire_lock(key: str, ttl_seconds: int) -> bool {
        owner = _lock_owner();
        if not self.store.kv_acquire_lease(key, ttl_seconds, owner) {
            return False;
        }
        with self._held_guard {
            self._held[key] = owner;
        }
        return True;
    }

    def release_lock(key: str) {
        with self._held_guard {
            owner = self._held.pop(key, None);
        }
        if owner is not None {
            self.store.kv_release_lease(key, owner);
        }
    }
}
