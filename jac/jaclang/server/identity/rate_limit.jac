import hashlib;
import math;
import logging;
import from jaclang.server.shared_store { shared_store }

def consume_limit(scope: str, actor: str, limit: int, seconds: int) -> int {
    if limit <= 0 {
        return 0;
    }
    try {
        db = shared_store();
        if db is None {
            return -1;
        }
        key = "ratelimit:" + hashlib.sha256((scope + ":" + actor).encode()).hexdigest();
        params = {"k": key, "cap": limit, "ttl": seconds};
        rows = db.rows(
            """
            INSERT INTO kv_state (key, value, expires_at)
            VALUES (:k, '1', now() + make_interval(secs => CAST(:ttl AS float8)))
            ON CONFLICT (key) DO UPDATE SET
                value = CASE WHEN kv_state.expires_at <= now() THEN '1'
                             ELSE (CAST(kv_state.value AS integer) + 1)::text END,
                expires_at = CASE WHEN kv_state.expires_at <= now()
                                  THEN EXCLUDED.expires_at ELSE kv_state.expires_at END
            WHERE kv_state.expires_at <= now() OR CAST(kv_state.value AS integer) < :cap
            RETURNING key
            """,
            params
        );
        if rows {
            return 0;
        }
        rows = db.rows(
            "SELECT EXTRACT(EPOCH FROM (expires_at - now())) AS remaining FROM kv_state WHERE key = :k",
            {"k": key}
        );
        return max(1, math.ceil(float(rows[0][0]))) if rows else 1;
    } except Exception as error {
        logging.getLogger(__name__).warning(f"Rate limit storage failed: {error}");
        return -1;
    }
}
