import from jaclang.scale.runtime.context.tracing { start_memory_span, end_memory_span }

glob _FILL_IF_LEASED = """
if redis.call('GET', KEYS[2]) ~= ARGV[1] then return 0 end
redis.call('DEL', KEYS[2])
if tonumber(ARGV[3]) > 0 then
    redis.call('SET', KEYS[1], ARGV[2], 'EX', ARGV[3])
else
    redis.call('SET', KEYS[1], ARGV[2])
end
return 1
""";

def _lease_key(key: str) -> str {
    return f"lease:{key}";
}

def _deserialize_cached(data: dict) -> (Anchor | None) {
    anchor = Serializer.deserialize(data);
    if anchor is not None {
        snapshot_field_hashes(anchor);
    }
    return anchor;
}

impl RedisBackend.postinit -> None {
    if self.redis_url is None {
        self.redis_url = _get_db_config().get('redis_url');
    }
    if not self.redis_url {
        return;
    }
    if 'redis_client' not in _process_cache {
        try {
            db_config = _get_db_config();
            max_connections = db_config.get('redis_max_connections', 20);
            _process_cache['redis_client'] = redis.from_url(
                self.redis_url, max_connections=max_connections
            );
        } except Exception as e {
            logger.warning(f"Redis connection failed: {e}");
        }
    }
    self.redis_client = _process_cache.get('redis_client');
}

impl RedisBackend.is_available -> bool {
    if _process_cache.get('redis_available') is True {
        return True;
    }
    if self.redis_client is None {
        return False;
    }
    try {
        self.redis_client.ping();
        _process_cache['redis_available'] = True;
        return True;
    } except Exception as e {
        logger.debug(f"Redis availability check failed: {e}");
        return False;
    }
}

impl RedisBackend.get(id: UUID) -> (Anchor | None) {
    if self.redis_client is None {
        return None;
    }
    self.fetch_count += 1;
    key = storage_key(to_uuid(id));
    span = start_memory_span(
        "memory.get redis", {"db.system": "redis", "mem.tier": "L2", "mem.op": "get"}
    );
    try {
        raw = self.redis_client.get(key);
        if not raw {
            return None;
        }
        data = json.loads(raw);
        return _deserialize_cached(data);
    } except Exception as e {
        logger.debug(f"Redis get failed: {e}");
        return None;
    } finally {
        end_memory_span(span);
    }
}

impl RedisBackend.reset_counters -> None {
    self.fetch_count = 0;
    self.put_count = 0;
}

impl RedisBackend.put(anchor: Anchor) -> None {
    if self.redis_client is None {
        return;
    }
    self.put_count += 1;
    span = start_memory_span(
        "memory.put redis", {"db.system": "redis", "mem.tier": "L2", "mem.op": "put"}
    );
    try {
        data = Serializer.serialize(anchor, include_type=True);
        key = storage_key(anchor.id);

        db_config = _get_db_config();
        ttl = db_config.get('redis_default_ttl', 0);

        pipe = self.redis_client.pipeline();
        if ttl > 0 {
            pipe.setex(key, ttl, json.dumps(data));
            logger.debug(f"Stored anchor {anchor.id} in Redis with TTL={ttl}s");
        } else {
            pipe.set(key, json.dumps(data));
        }
        pipe.delete(_lease_key(key));
        pipe.execute();
    } except Exception as e {
        logger.debug(f"Redis put failed: {e}");
    } finally {
        end_memory_span(span);
    }
}

impl RedisBackend.delete(id: UUID) -> None {
    if self.redis_client is None {
        return;
    }
    try {
        key = storage_key(to_uuid(id));
        self.redis_client.delete(key, _lease_key(key));
    } except Exception as e {
        logger.debug(f"Redis delete failed: {e}");
    }
}

impl RedisBackend.lease(ids: list[UUID]) -> dict[UUID, str] {
    if self.redis_client is None or not ids {
        return {};
    }
    leases = {id: uuid4().hex for id in ids};
    try {
        pipe = self.redis_client.pipeline(transaction=False);
        for (id, token) in leases.items() {
            pipe.set(
                _lease_key(storage_key(to_uuid(id))), token, px=_REFILL_LEASE_MS, nx=True
            );
        }
        taken = pipe.execute();
    } except Exception as e {
        logger.debug(f"Redis lease failed: {e}");
        return {};
    }
    return {id: leases[id] for (id, ok) in zip(leases, taken) if ok};
}

impl RedisBackend.fill(anchor: Anchor, token: (str | None)) -> None {
    if self.redis_client is None or token is None {
        return;
    }
    self.put_count += 1;
    span = start_memory_span(
        "memory.put redis", {"db.system": "redis", "mem.tier": "L2", "mem.op": "put"}
    );
    try {
        key = storage_key(anchor.id);
        data = json.dumps(Serializer.serialize(anchor, include_type=True));
        ttl = _get_db_config().get('redis_default_ttl', 0);
        self.redis_client.eval(_FILL_IF_LEASED, 2, key, _lease_key(key), token, data, ttl);
    } except Exception as e {
        logger.debug(f"Redis fill failed: {e}");
    } finally {
        end_memory_span(span);
    }
}

impl RedisBackend.close -> None {
    self.redis_client = None;
}

impl RedisBackend.`has(id: UUID) -> bool {
    return self.exists(id);
}

impl RedisBackend.query(
    filter: (Callable[[Anchor], bool] | None) = None
) -> Generator[Anchor, None, None] {
    return;
    yield ;
}

impl RedisBackend.get_roots -> Generator[Root, None, None] {
    return;
    yield ;
}

impl RedisBackend.commit(anchor: (Anchor | None) = None) -> None { }

impl RedisBackend.batch_get(ids: list[UUID]) -> dict[UUID, Anchor] {
    result: dict[UUID, Anchor] = {};
    if not ids or self.redis_client is None {
        return result;
    }
    self.fetch_count += len(ids);
    span = start_memory_span(
        "memory.batch_get redis",
        {
            "db.system": "redis",
            "mem.tier": "L2",
            "mem.op": "batch_get",
            "mem.count": len(ids)
        }
    );
    try {
        keys = [storage_key(to_uuid(id)) for id in ids];
        values = self.redis_client.mget(keys);
        for (id, raw) in zip(ids, values) {
            if raw {
                try {
                    data = json.loads(raw);
                    anchor = _deserialize_cached(data);
                    if anchor {
                        result[id] = anchor;
                    }
                } except Exception as e {
                    logger.debug(f"Redis batch_get deserialize failed for {id}: {e}");
                }
            }
        }
    } except Exception as e {
        logger.debug(f"Redis batch_get failed: {e}");
    } finally {
        end_memory_span(span);
    }
    return result;
}

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

impl RedisBackend.invalidate(id: UUID) -> None {
    self.delete(id);
}

impl RedisBackend.publish_invalidation(
    anchor_id: str, origin_l1_id: (str | None) = None
) -> None {
    if self.redis_client is None {
        return;
    }
    try {
        db_config = _get_db_config();
        if not db_config.get('redis_l1_invalidation_enabled', True) {
            return;
        }
        channel = (
            db_config.get('redis_l1_invalidation_channel')
            or DEFAULT_INVALIDATION_CHANNEL
        );
        self.redis_client.publish(channel, build_message(anchor_id, origin_l1_id));
    } except Exception as e {
        logger.debug(f"Redis publish_invalidation failed: {e}");
    }
}

impl RedisBackend.aget(id: UUID) -> (Anchor | None) {
    import from jaclang.scale._optdeps.redis { AsyncRedis, HAS_REDIS }
    if not HAS_REDIS or AsyncRedis is None {
        return await super.aget(id);
    }
    if self._async_redis is None {
        if self.redis_url is None {
            return await super.aget(id);
        }
        self._async_redis = AsyncRedis.from_url(self.redis_url);
    }
    key = storage_key(to_uuid(id));
    span = start_memory_span(
        "memory.get redis", {"db.system": "redis", "mem.tier": "L2", "mem.op": "get"}
    );
    try {
        raw = await self._async_redis.get(key);
        if not raw {
            return None;
        }
        data = json.loads(raw);
        return _deserialize_cached(data);
    } except Exception as e {
        logger.debug(f"Redis async get failed: {e}");
        return None;
    } finally {
        end_memory_span(span);
    }
}

impl RedisBackend.aput(anchor: Anchor) -> None {
    import from jaclang.scale._optdeps.redis { AsyncRedis, HAS_REDIS }
    if not HAS_REDIS or AsyncRedis is None {
        await super.aput(anchor);
        return;
    }
    if self._async_redis is None {
        if self.redis_url is None {
            await super.aput(anchor);
            return;
        }
        self._async_redis = AsyncRedis.from_url(self.redis_url);
    }
    span = start_memory_span(
        "memory.put redis", {"db.system": "redis", "mem.tier": "L2", "mem.op": "put"}
    );
    try {
        data = Serializer.serialize(anchor, include_type=True);
        key = storage_key(anchor.id);
        db_config = _get_db_config();
        ttl = db_config.get('redis_default_ttl', 0);
        if ttl > 0 {
            await self._async_redis.setex(key, ttl, json.dumps(data));
        } else {
            await self._async_redis.set(key, json.dumps(data));
        }
    } except Exception as e {
        logger.debug(f"Redis async put failed: {e}");
    } finally {
        end_memory_span(span);
    }
}
