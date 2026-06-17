"""Pluggable WebSocket pub/sub backplane."""
import asyncio;
import json;
import logging;
import from typing { Any }

glob logger = logging.getLogger(__name__);

"""Protocol-agnostic backplane interface."""
obj BaseBackplane {
    async def start -> None;
    async def publish(channel: str, message: dict) -> None;
    async def subscribe(channel: str, handler: Any) -> None;
    async def unsubscribe(channel: str, handler: Any) -> None;
    async def close -> None;
    def is_distributed -> bool;
}

"""In-process backplane; messages never leave this worker."""
obj MemoryBackplane(BaseBackplane) {
    has _subs: dict[str, list[Any]] = {},
        _warned: bool = False;

    async def start {
        if not self._warned {
            logger.warning(
                "WS MemoryBackplane in use: broadcasts are limited to this "
                "process. For multi-worker deployments configure "
                "[plugins.scale.websocket].backplane = 'redis'."
            );
            self._warned = True;
        }
    }

    async def publish(channel: str, message: dict) -> None {
        handlers = list(self._subs.get(channel, []));
        if not handlers {
            return;
        }
        tasks = [h(channel, message) for h in handlers];
        await asyncio.gather(*tasks, return_exceptions=True);
    }

    async def subscribe(channel: str, handler: Any) {
        if channel not in self._subs {
            self._subs[channel] = [];
        }
        self._subs[channel].append(handler);
    }

    async def unsubscribe(channel: str, handler: Any) {
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

    async def close {
        self._subs = {};
    }

    def is_distributed -> bool {
        return False;
    }
}

obj RedisBackplane(BaseBackplane) {
    has url: str,
        _client: (Any | None) = None,
        _pubsub: (Any | None) = None,
        _reader_task: (Any | None) = None,
        _handlers: dict[str, list[Any]] = {},
        _lock: (Any | None) = None,
        _closed: bool = False;

    def _get_lock -> Any {
        if self._lock is None {
            self._lock = asyncio.Lock();
        }
        return self._lock;
    }

    async def start -> None {
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
        # Reader task is started lazily on first subscribe(); calling
        # get_message() before any channel is subscribed raises
        # "pubsub connection not set" and poisons the loop.
        logger.info(f"WS RedisBackplane connected url={self.url}");
    }

    async def _reader_loop -> None {
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
                    payload = json.loads(raw);
                } except Exception as e {
                    logger.warning(f"WS Redis payload decode failed: {e}");
                    continue;
                }
                handlers = list(self._handlers.get(channel, []));
                if handlers {
                    tasks = [h(channel, payload) for h in handlers];
                    await asyncio.gather(*tasks, return_exceptions=True);
                }
            }
        } except asyncio.CancelledError {
            return;
        }
    }

    async def publish(channel: str, message: dict) -> None {
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

    async def subscribe(channel: str, handler: Any) {
        lock = self._get_lock();
        await lock.acquire();
        try {
            if channel not in self._handlers {
                # Subscribe upstream first so a transient Redis failure can't
                # leave a stale `_handlers[channel] = []` that makes future
                # callers think we're subscribed when we aren't.
                await self._pubsub.subscribe(channel);
                self._handlers[channel] = [];
            }
            self._handlers[channel].append(handler);
            # Start the reader only once we have a subscription, so
            # get_message() always sees a connected pubsub.
            if self._reader_task is None and not self._closed {
                self._reader_task = asyncio.create_task(self._reader_loop());
            }
        } finally {
            lock.release();
        }
    }

    async def unsubscribe(channel: str, handler: Any) {
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

    async def close {
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
                # redis-py >= 5.0.1 renamed close() to aclose(); prefer the new
                # name but fall back for older versions.
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

    def is_distributed -> bool {
        return True;
    }
}

def build_backplane(cfg: dict) -> BaseBackplane {
    # Selection precedence:
    #   1. Explicit `[plugins.scale.websocket].backplane = 'memory' | 'redis'`
    #   2. Auto-detect from a Redis URL (WS section first, then DB fallback)
    backplane = cfg.get('backplane');
    url = cfg.get('redis_url');
    if backplane == 'memory' {
        return MemoryBackplane();
    }
    if backplane == 'redis' {
        if not url {
            raise ValueError(
                "[plugins.scale.websocket].backplane = 'redis' but no redis_url "
                "is configured (set it in [plugins.scale.websocket] or "
                "[plugins.scale.database])."
            );
        }
        return RedisBackplane(url=url);
    }
    if backplane is not None {
        raise ValueError(
            f"Unknown [plugins.scale.websocket].backplane value: {backplane!r}. "
            "Expected 'memory' or 'redis'."
        );
    }
    if url {
        return RedisBackplane(url=url);
    }
    return MemoryBackplane();
}
