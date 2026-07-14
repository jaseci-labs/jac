impl MemoryBackplane.start{
    if not self._warned {
        logger.warning(
            "WS MemoryBackplane in use: broadcasts are limited to this "
            "process. For multi-worker deployments configure "
            "[scale.websocket].backplane = 'redis'."
        );
        self._warned = True;
    }
}

impl MemoryBackplane.publish(channel: str, message: dict) -> None {
    handlers = list(self._subs.get(channel, []));
    if not handlers {
        return;
    }
    tasks = [h(channel, message) for h in handlers];
    await asyncio.gather(*tasks, return_exceptions=True);
}

impl MemoryBackplane.subscribe(channel: str, handler: Any) {
    if channel not in self._subs {
        self._subs[channel] = [];
    }
    self._subs[channel].append(handler);
}

impl MemoryBackplane.unsubscribe(channel: str, handler: Any) {
    handlers = self._subs.get(channel);
    if handlers is None {
        return;
    }
    try {
        handlers.remove(handler);
    } except ValueError {
        return;
    }
    if not handlers {
        del self._subs[channel];
    }
}

impl MemoryBackplane.close{
    self._subs = {};
}

impl RedisBackplane._get_lock -> Any {
    if self._lock is None {
        self._lock = asyncio.Lock();
    }
    return self._lock;
}

impl RedisBackplane.start -> None {
    if self._client is not None {
        return;
    }
    try {
        import redis.asyncio as redis_async;
    } except ImportError as e {
        raise RuntimeError(
            "RedisBackplane selected but `redis` is not installed. "
            "Run: pip install redis"
        ) from e;
    }
    self._client = redis_async.from_url(
        self.url, decode_responses=True, health_check_interval=30
    );
    self._pubsub = self._client.pubsub();
    logger.info(f"WS RedisBackplane connected url={self.url}");
}

impl RedisBackplane._reader_loop -> None {
    try {
        while not self._closed {
            try {
                msg = await self._pubsub.get_message(
                    ignore_subscribe_messages=True, timeout=1.0
                );
            } except Exception as e {
                logger.warning(f"WS Redis get_message failed: {e}");
                await asyncio.sleep(1.0);
                continue;
            }
            if msg is None {
                continue;
            }
            channel = msg.get('channel');
            raw = msg.get('data');
            if not channel or raw is None {
                continue;
            }
            try {
                payload = json.loads(str(raw));
            } except Exception as e {
                logger.warning(f"WS Redis payload decode failed: {e}");
                continue;
            }
            handlers = list(self._handlers.get(str(channel), []));
            if handlers {
                tasks = [h(channel, payload) for h in handlers];
                await asyncio.gather(*tasks, return_exceptions=True);
            }
        }
    } except asyncio.CancelledError {
        return;
    }
}

impl RedisBackplane.publish(channel: str, message: dict) -> None {
    if self._client is None {
        logger.warning('WS RedisBackplane publish before start; dropping');
        return;
    }
    try {
        await self._client.publish(channel, json.dumps(message));
    } except Exception as e {
        logger.error(f"WS Redis publish failed channel={channel}: {e}");
    }
}

impl RedisBackplane.subscribe(channel: str, handler: Any) {
    lock = self._get_lock();
    await lock.acquire();
    try {
        if channel not in self._handlers {
            await self._pubsub.subscribe(channel);
            self._handlers[channel] = [];
        }
        self._handlers[channel].append(handler);
        if self._reader_task is None and not self._closed {
            self._reader_task = asyncio.create_task(self._reader_loop());
        }
    } finally {
        lock.release();
    }
}

impl RedisBackplane.unsubscribe(channel: str, handler: Any) {
    lock = self._get_lock();
    await lock.acquire();
    try {
        handlers = self._handlers.get(channel);
        if handlers is None {
            return;
        }
        try {
            handlers.remove(handler);
        } except ValueError {
            return;
        }
        if handlers {
            return;
        }
        del self._handlers[channel];
        if self._pubsub is None {
            return;
        }
        try {
            await self._pubsub.unsubscribe(channel);
        } except Exception as e {
            logger.debug(f"WS Redis unsubscribe failed: {e}");
        }
    } finally {
        lock.release();
    }
}

impl RedisBackplane.close{
    self._closed = True;
    if self._reader_task is not None {
        self._reader_task.cancel();
        try {
            await self._reader_task;
        } except Exception as e {
            logger.debug(f"WS Redis reader close exception: {e}");
        }
    }
    if self._pubsub is not None {
        try {
            closer = getattr(self._pubsub, 'aclose', self._pubsub.close);
            await closer();
        } except Exception as e {
            logger.debug(f"WS Redis pubsub close exception: {e}");
        }
    }
    if self._client is not None {
        try {
            closer = getattr(self._client, 'aclose', self._client.close);
            await closer();
        } except Exception as e {
            logger.debug(f"WS Redis client close exception: {e}");
        }
    }
}

"""Select a backplane from WebSocket config.

Precedence: an explicit `backplane = 'memory' | 'redis'` wins; otherwise a
Redis URL (WS section, then database fallback) auto-selects Redis; otherwise
in-process memory.
"""
impl build_backplane(cfg: dict) -> BaseBackplane {
    backplane = cfg.get('backplane');
    url = cfg.get('redis_url');
    if backplane == 'memory' {
        return MemoryBackplane();
    }
    if backplane == 'redis' {
        if not url {
            raise ValueError(
                "[scale.websocket].backplane = 'redis' but no redis_url "
                "is configured (set it in [scale.websocket] or "
                "[scale.database])."
            );
        }
        return RedisBackplane(url=str(url));
    }
    if backplane is not None {
        raise ValueError(
            f"Unknown [scale.websocket].backplane value: {backplane!r}. "
            "Expected 'memory' or 'redis'."
        );
    }
    if url {
        return RedisBackplane(url=str(url));
    }
    return MemoryBackplane();
}
