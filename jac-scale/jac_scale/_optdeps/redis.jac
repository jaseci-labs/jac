"""Guarded re-exports for redis (install group: [data])."""

with entry {
    try {
        import redis as redis_module;
        import from redis { Redis }
        HAS_REDIS = True;
    } except ImportError {
        redis_module = None;
        Redis = None;
        HAS_REDIS = False;
    }
}
