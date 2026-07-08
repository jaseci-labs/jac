"""WebSocket connection management for Jac Scale.

Tracks live connections per target and per user, enforces connection caps and
per-send timeouts, and fans broadcasts out through a pluggable backplane so
they reach every worker.
"""
import asyncio;
import logging;
import time;
import uuid;
import from asyncio { Lock }
import from fastapi { WebSocket }
import from jaclang.scale.server.ws_backplane { BaseBackplane, MemoryBackplane }

glob logger = logging.getLogger(__name__);

"""Per-connection state: identity, auth expiry, rate-limit bucket, heartbeat."""
obj ConnectionContext {
    has websocket: WebSocket,
        target_kind: str,
        target_name: str,
        conn_id: str = '',
        user_id: (str | None) = None,
        exp: (float | None) = None,
        rate_tokens: float = 0.0,
        rate_last_refill: float = 0.0,
        last_seen: float = 0.0,
        closed: bool = False;

    def postinit {
        if not self.conn_id {
            self.conn_id = uuid.uuid4().hex;
        }
        now = time.monotonic();
        self.rate_last_refill = now;
        self.last_seen = now;
    }
}

"""Connection manager: tracks active WS contexts per (kind:name) and per user."""
obj WebSocketConnectionManager {
    has _by_target: dict[str, dict[str, ConnectionContext]] = {},
        _by_user: dict[str, int] = {},
        _anon_by_target: dict[str, int] = {},
        _lock: (Lock | None) = None,
        _sub_lock: (Lock | None) = None,
        max_per_target: int = 5000,
        max_per_user: int = 10,
        max_anonymous_per_target: int = 100,
        send_timeout: float = 5.0,
        backplane: (BaseBackplane | None) = None,
        metrics: any = None,
        _subscribed: set[str] = set(),
        _backplane_started: bool = False;

    def _get_lock -> Lock {
        if self._lock is None {
            self._lock = Lock();
        }
        return self._lock;
    }

    def _get_sub_lock -> Lock {
        if self._sub_lock is None {
            self._sub_lock = Lock();
        }
        return self._sub_lock;
    }

    def _target_has_connections(target_key: str) -> bool {
        per_target = self._by_target.get(target_key);
        return per_target is not None and len(per_target) > 0;
    }

    def _get_backplane -> BaseBackplane {
        if self.backplane is None {
            self.backplane = MemoryBackplane();
        }
        return self.backplane;
    }

    def _metric(name: str) -> None {
        if self.metrics is None {
            return;
        }
        try {
            fn = getattr(self.metrics, name, None);
            if fn {
                fn();
            }
        } except Exception as e {
            logger.debug(f"WS metric {name} failed: {e}");
        }
    }

    async def ensure_backplane_started -> None;
    async def shutdown -> None;
    async def ensure_subscribed(target_key: str) -> None;
    async def maybe_unsubscribe(target_key: str) -> None;
    async def _on_backplane_message(channel: str, message: dict) -> None;
    async def _local_fanout(target_key: str, message: dict) -> None;
    async def register(ctx: ConnectionContext) -> (str | None);
    async def unregister(ctx: ConnectionContext) -> None;
    async def broadcast_target(
        target_kind: str, target_name: str, message: dict
    ) -> None;

    async def send_to(ctx: ConnectionContext, message: dict) -> bool;
}

impl WebSocketConnectionManager.register(ctx: ConnectionContext) -> (str | None) {
    lock = self._get_lock();
    await lock.acquire();
    rejection: (str | None) = None;
    target_key = f"{ctx.target_kind}:{ctx.target_name}";
    newly_active = False;
    try {
        per_target = self._by_target.get(target_key);
        if per_target is None {
            per_target = {};
            self._by_target[target_key] = per_target;
        }
        if len(per_target) >= self.max_per_target {
            rejection = 'per_target_limit';
        } elif ctx.user_id and self._by_user.get(ctx.user_id, 0) >= self.max_per_user {
            rejection = 'per_user_limit';
        } elif (
            not ctx.user_id
            and self._anon_by_target.get(target_key, 0) >= self.max_anonymous_per_target
        ) {
            rejection = 'anonymous_target_limit';
        } else {
            if ctx.user_id {
                self._by_user[ctx.user_id] = self._by_user.get(ctx.user_id, 0) + 1;
            } else {
                self._anon_by_target[target_key] = (
                    self._anon_by_target.get(target_key, 0) + 1
                );
            }
            newly_active = len(per_target) == 0;
            per_target[ctx.conn_id] = ctx;
        }
    } finally {
        lock.release();
    }
    if rejection is None {
        if newly_active {
            await self.ensure_subscribed(target_key);
        }
        self._metric('record_ws_connection_opened');
        logger.info(
            f"WS connected target={ctx.target_kind}:{ctx.target_name} "
            f"user_id={ctx.user_id} conn_id={ctx.conn_id}"
        );
    }
    return rejection;
}

impl WebSocketConnectionManager.unregister(ctx: ConnectionContext) -> None {
    lock = self._get_lock();
    await lock.acquire();
    target_key = f"{ctx.target_kind}:{ctx.target_name}";
    now_empty = False;
    try {
        per_target = self._by_target.get(target_key);
        if per_target is not None and ctx.conn_id in per_target {
            del per_target[ctx.conn_id];
            if not per_target {
                del self._by_target[target_key];
                now_empty = True;
            }
        }
        if ctx.user_id and self._by_user.get(ctx.user_id, 0) > 0 {
            self._by_user[ctx.user_id] -= 1;
            if self._by_user[ctx.user_id] <= 0 {
                del self._by_user[ctx.user_id];
            }
        } elif not ctx.user_id and self._anon_by_target.get(target_key, 0) > 0 {
            self._anon_by_target[target_key] -= 1;
            if self._anon_by_target[target_key] <= 0 {
                del self._anon_by_target[target_key];
            }
        }
        ctx.closed = True;
    } finally {
        lock.release();
    }
    if now_empty {
        await self.maybe_unsubscribe(target_key);
    }
    self._metric('record_ws_connection_closed');
    logger.info(
        f"WS disconnected target={ctx.target_kind}:{ctx.target_name} "
        f"user_id={ctx.user_id} conn_id={ctx.conn_id}"
    );
}

impl WebSocketConnectionManager.ensure_backplane_started -> None {
    if self._backplane_started {
        return;
    }
    backplane = self._get_backplane();
    await backplane.start();
    self._backplane_started = True;
}

impl WebSocketConnectionManager.shutdown -> None {
    if self.backplane is not None {
        try {
            await self.backplane.close();
        } except Exception as e {
            logger.debug(f"WS backplane close exception: {e}");
        }
    }
    self._subscribed = set();
    self._backplane_started = False;
}

impl WebSocketConnectionManager.ensure_subscribed(target_key: str) -> None {
    sub_lock = self._get_sub_lock();
    await sub_lock.acquire();
    try {
        if target_key in self._subscribed {
            return;
        }
        await self.ensure_backplane_started();
        if not self._target_has_connections(target_key) {
            return;
        }
        backplane = self._get_backplane();
        channel = f"ws:{target_key}";
        await backplane.subscribe(channel, self._on_backplane_message);
        self._subscribed.add(target_key);
    } finally {
        sub_lock.release();
    }
}

impl WebSocketConnectionManager.maybe_unsubscribe(target_key: str) -> None {
    sub_lock = self._get_sub_lock();
    await sub_lock.acquire();
    try {
        if target_key not in self._subscribed {
            return;
        }
        if self._target_has_connections(target_key) {
            return;
        }
        backplane = self._get_backplane();
        channel = f"ws:{target_key}";
        try {
            await backplane.unsubscribe(channel, self._on_backplane_message);
        } except Exception as e {
            logger.debug(f"WS unsubscribe {channel} failed: {e}");
        }
        self._subscribed.discard(target_key);
    } finally {
        sub_lock.release();
    }
}

impl WebSocketConnectionManager._on_backplane_message(
    channel: str, message: dict
) -> None {
    if not channel.startswith('ws:') {
        return;
    }
    target_key = channel[3:];
    await self._local_fanout(target_key, message);
}

impl WebSocketConnectionManager._local_fanout(target_key: str, message: dict) -> None {
    per_target = self._by_target.get(target_key, {});
    conns = list(per_target.values());
    if not conns {
        return;
    }
    tasks = [self.send_to(ctx, message) for ctx in conns];
    await asyncio.gather(*tasks, return_exceptions=True);
}

impl WebSocketConnectionManager.broadcast_target(
    target_kind: str, target_name: str, message: dict
) -> None {
    target_key = f"{target_kind}:{target_name}";
    await self.ensure_backplane_started();
    backplane = self._get_backplane();
    channel = f"ws:{target_key}";
    self._metric('record_ws_broadcast');
    await backplane.publish(channel, message);
}

impl WebSocketConnectionManager.send_to(ctx: ConnectionContext, message: dict) -> bool {
    if ctx.closed {
        return False;
    }
    try {
        await asyncio.wait_for(
            ctx.websocket.send_json(message), timeout=self.send_timeout
        );
        return True;
    } except asyncio.TimeoutError {
        logger.warning(
            f"WS send timeout conn_id={ctx.conn_id} target="
            f"{ctx.target_kind}:{ctx.target_name}; closing connection"
        );
        ctx.closed = True;
        try {
            await ctx.websocket.close(code=4408, reason='send_timeout');
        } except Exception as close_err {
            logger.debug(f"WS close after send timeout failed: {close_err}");
        }
        return False;
    } except Exception as e {
        logger.warning(f"WS send failed conn_id={ctx.conn_id}: {e}");
        return False;
    }
}

"""Token-bucket consumer. Returns True if a message is allowed to proceed."""
def consume_rate_token(
    ctx: ConnectionContext, capacity: float, refill_per_sec: float
) -> bool {
    now = time.monotonic();
    elapsed = now - ctx.rate_last_refill;
    ctx.rate_tokens = min(capacity, ctx.rate_tokens + elapsed * refill_per_sec);
    ctx.rate_last_refill = now;
    if ctx.rate_tokens >= 1.0 {
        ctx.rate_tokens -= 1.0;
        return True;
    }
    return False;
}
