"""Redis CacheBackend Implementation."""
import redis;
import logging;
import from collections.abc { Callable, Generator, Iterable }
import from pickle { dumps, loads }
import from uuid { UUID }
import from jaclang.pycore.archetype { Anchor, Root }
import from jaclang.runtimelib.utils { storage_key, to_uuid }

glob logger = logging.getLogger(__name__);

"""Post-initialization: connect to Redis."""
impl RedisBackend.postinit -> None {
    if self.redis_url and self.redis_client is None {
        try {
            self.redis_client = redis.from_url(self.redis_url);
        } except Exception as e {
            logger.debug(f"Redis connection failed: {e}");
            self.redis_client = None;
        }
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
    try {
        raw = self.redis_client.get(key);
        if not raw {
            return None;
        }
        return loads(raw);
    } except Exception as e {
        logger.debug(f"Redis get failed: {e}");
        return None;
    }
}

"""Store anchor in Redis cache."""
impl RedisBackend.put(anchor: Anchor) -> None {
    if self.redis_client is None {
        return;
    }
    try {
        data = dumps(anchor);
        key = storage_key(anchor.id);
        self.redis_client.set(key, data);
    } except Exception as e {
        logger.debug(f"Redis put failed: {e}");
    }
}

"""Delete anchor from Redis cache."""
impl RedisBackend.delete(id: UUID) -> None {
    if self.redis_client is None {
        return;
    }
    try {
        key = storage_key(to_uuid(id));
        self.redis_client.delete(key);
    } except Exception as e {
        logger.debug(f"Redis delete failed: {e}");
    }
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

"""Check if an anchor is in the cache."""
impl RedisBackend.has(id: UUID) -> bool {
    return self.exists(id);
}

"""Query all anchors - not supported for distributed cache."""
impl RedisBackend.query(
    filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    # Redis doesn't support iteration efficiently
    return;
    yield ;
}

"""Get all root anchors - not supported for distributed cache."""
impl RedisBackend.get_roots -> Generator[Root, None, None] {
    return;
    yield ;
}

"""Find anchors by IDs with optional filter."""
impl RedisBackend.find(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> Generator[Anchor, None, None] {
    id_list = [ids] if isinstance(ids, UUID) else list(ids);
    for id in id_list {
        if (anchor := self.get(id)) {
            if filter is None or filter(anchor) {
                yield anchor;
            }
        }
    }
}

"""Find one anchor by ID(s) with optional filter."""
impl RedisBackend.find_one(
    ids: (UUID | Iterable[UUID]), filter: (Callable[[Anchor], Anchor] | None) = None
) -> (Anchor | None) {
    id_list = [ids] if isinstance(ids, UUID) else list(ids);
    for id in id_list {
        if (anchor := self.get(id)) {
            if filter is None or filter(anchor) {
                return anchor;
            }
        }
    }
    return None;
}

"""Commit - no-op for cache."""
impl RedisBackend.commit(anchor: (Anchor | None) = None) -> None {
# No-op: cache doesn't need commit
}

# CacheMemory-specific methods
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

"""Store anchor only if it already exists in cache."""
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
