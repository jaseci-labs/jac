"""Commit behaves like MongoDB but also syncs Redis."""

impl RedisDB.redis_key_exists(id: UUID) -> bool {
    try {
        return bool(self.redis_client.exists(self._redis_key(id)));
    } except Exception {
        return False;
    }
}

impl RedisDB.commit(
    anchor: (Anchor | None) = None, keys: Iterable[Anchor] = []
) -> None {
    if (anchor) {
        if (self.redis_key_exists(anchor.id)) {
            self.set(anchor);
        }
        return;
    }
    for anc in keys {
        if (self.redis_key_exists(anc.id)) {
            self.set(anc);
        }
    }
}

impl RedisDB.find_by_id(id: UUID) -> (Anchor | None) {
    _id = self._to_uuid(id);
    data = self._load_anchor_from_redis(_id);
    return data;
}

"""Delete from MongoDB AND Redis."""
impl RedisDB.remove(anchor: Anchor) -> None {
    if (self.redis_client is None) {
        return None;
    }
    self.redis_client.delete(self._redis_key(anchor.id));
}

"""Save to MongoDB AND Redis."""
impl RedisDB.<>set(anchor: Anchor) -> None {
    if (self.redis_client is None) {
        return;
    }
    self.redis_client.set(self._redis_key(anchor.id), dumps(anchor));
}

impl RedisDB._load_anchor_from_redis(id: UUID) -> (Anchor | None) {
    if (self.redis_client is None) {
        return None;
    }
    key = self._redis_key(id);
    raw = self.redis_client.get(key);
    if not raw {
        return None;
    }
    try {
        return loads(raw);
    } except Exception {
        return None;
    }
}

impl RedisDB._to_uuid(id: (UUID | str)) -> UUID {
    if not isinstance(id, UUID) {
        return UUID(str(id));
    }
    return id;
}

impl RedisDB._redis_key(id: UUID) -> str {
    return f"anchor:{str(id)}";
}

"""Check whether Redis connection is alive and reachable."""
impl RedisDB.redis_is_available -> bool {
    client = None;
    if (self.redis_url) {
        try {
            client = redis.from_url(self.redis_url);

            try {
                client.ping();
                return True;
            } except Exception {
                return False;
            }
        } except Exception {
            return False;
        } finally {
            if (client) {
                try {
                    client.close();
                } except Exception { }
            }
        }
    } else {
        return False;
    }
}

"""Initialize Redis."""
impl RedisDB.postinit -> None {
    # Only initialize if redis_url is not empty and client is None
    if (self.redis_url and self.redis_client is None) {
        self.redis_client = redis.from_url(self.redis_url);
    }
}
