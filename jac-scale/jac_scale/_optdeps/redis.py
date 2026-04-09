"""Guarded re-exports for redis (install group: [data])."""

try:
    import redis as redis_module
    from redis import Redis

    HAS_REDIS = True
except ImportError:
    redis_module = None
    Redis = None

    HAS_REDIS = False
