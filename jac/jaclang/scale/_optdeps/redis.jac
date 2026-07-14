"""Guarded re-exports for redis (install group: [data])."""

with entry {
    try {
        import redis as redis_module;
        import from redis { Redis }
        import from redis.asyncio { Redis as AsyncRedis }
        HAS_REDIS = True;
    } except ImportError {
        redis_module = None;
        Redis = None;
        AsyncRedis = None;
        HAS_REDIS = False;
    }
}
