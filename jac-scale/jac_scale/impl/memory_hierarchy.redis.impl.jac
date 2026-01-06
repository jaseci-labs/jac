"""Redis CacheBackend Implementation."""
import redis;
import from uuid { UUID }
import from jaclang.pycore.archetype { Anchor }
import logging;
import from jaclang.runtimelib.storage { AnchorMergeStrategy }
import from jaclang.runtimelib.utils { storage_key, to_uuid }

glob logger = logging.getLogger(__name__);

"""Post-initialization: connect to Redis."""
impl RedisBackend.postinit -> None {
    if self.redis_url and self.redis_client is None {
        self.redis_client = redis.from_url(self.redis_url);
    }
}

"""Check if Redis is available and connected."""
impl RedisBackend.is_available -> bool {
    if not self.redis_url {
        return False;
    }
    client = None;
    try {
        client = redis.from_url(self.redis_url);
        client.ping();
        return True;
    } except Exception as e {
        logger.debug(f"Redis availability check failed: {e}");
        return False;
    } finally {
        if client {
            try {
                client.close();
            } except Exception { }
        }
    }
}

"""Get anchor by UUID from Redis cache."""
impl RedisBackend.get(id: UUID) -> (Anchor | None) {
    if self.redis_client is None {
        return None;
    }
    key = storage_key(to_uuid(id));
    raw = self.redis_client.get(key);
    if not raw {
        return None;
    }
    return AnchorMergeStrategy.deserialize(raw);
}

"""Store anchor in Redis cache."""
impl RedisBackend.put(anchor: Anchor) -> None {
    if self.redis_client is None {
        return;
    }
    data = AnchorMergeStrategy.serialize(anchor);
    if data is None {
        return;
    }
    key = storage_key(anchor.id);
    self.redis_client.set(key, data);
}

"""Delete anchor from Redis cache."""
impl RedisBackend.delete(id: UUID) -> None {
    if self.redis_client is None {
        return;
    }
    key = storage_key(to_uuid(id));
    self.redis_client.delete(key);
}

"""Close Redis connection."""
impl RedisBackend.close -> None {
    if self.redis_client {
        try {
            self.redis_client.close();
        } except Exception as e {
            logger.warning(f"Error closing Redis connection: {e}");
        }
        self.redis_client = None;
    }
}

# CacheBackend specific methods
"""Check if key exists in cache."""
impl RedisBackend.exists(id: UUID) -> bool {
    if self.redis_client is None {
        return False;
    }
    try {
        key = storage_key(to_uuid(id));
        return bool(self.redis_client.exists(key));
    } except Exception {
        return False;
    }
}

"""Store anchor only if it already exists in cache. Returns True if stored."""
impl RedisBackend.put_if_exists(anchor: Anchor) -> bool {
    if self.redis_client is None {
        return False;
    }
    if not self.exists(anchor.id) {
        return False;
    }
    self.put(anchor);
    return True;
}

"""Remove an entry from cache."""
impl RedisBackend.invalidate(id: UUID) -> None {
    self.delete(id);
}
