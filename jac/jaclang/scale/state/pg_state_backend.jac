import logging;
import from jaclang.scale.state.state_backend { StateBackend }

glob logger = logging.getLogger(__name__);


obj PgStateBackend(StateBackend) {
    has store: any;

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
        rows = self.store.rows(
            """
            INSERT INTO kv_state (key, value, expires_at, updated_at)
            VALUES (
                :k, '1', now() + make_interval(secs => CAST(:ttl AS int)), now()
            )
            ON CONFLICT (key) DO UPDATE SET
                expires_at = EXCLUDED.expires_at,
                updated_at = now()
            WHERE kv_state.expires_at IS NOT NULL
                  AND kv_state.expires_at <= now()
            RETURNING key
            """,
            {'k': f"lock:{key}", 'ttl': ttl_seconds}
        );
        return bool(rows);
    }

    def release_lock(key: str) {
        self.store.kv_delete(f"lock:{key}");
    }
}
