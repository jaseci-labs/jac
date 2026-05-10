**Redis process-level connection pool + MGET pipeline + TTL default**

- `RedisBackend` now uses a process-level singleton client (`_process_cache['redis_client']`)
  shared across all requests in a worker, avoiding per-request connection churn.
- `is_available()` only caches `True` so a missing Redis URL in one execution context
  does not permanently block Redis for subsequent contexts in the same process.
- `batch_get()` replaced N individual GETs with a single `MGET` pipeline call, reducing
  Redis round-trips from O(n) to O(1).
- Default `redis_default_ttl` raised from `0` (no expiry) to `3600` seconds to prevent
  unbounded key growth.
- New `redis_max_connections` config key (default `20`) caps the connection pool per worker.
- `close()` drops the local reference only; the shared client is kept alive for the
  lifetime of the worker process.
