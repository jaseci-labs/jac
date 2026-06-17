"""WebSocket support for Jac Scale."""
import asyncio;
import logging;
import time;
import uuid;
import from asyncio { Lock }
import from fastapi { WebSocket }
import from jac_scale.ws_backplane { BaseBackplane, MemoryBackplane }
import from jac_scale.ws_metrics {
    connection_opened,
    connection_closed,
    broadcast_published
}

glob logger = logging.getLogger(__name__),
     WS_CLOSE_UNAUTHORIZED: int = 4401,
     WS_CLOSE_FORBIDDEN: int = 4403,
     WS_CLOSE_IDLE: int = 4408,
     WS_CLOSE_TOO_LARGE: int = 4413,
     HEARTBEAT_SECONDS: float = 30.0,
     HEARTBEAT_MISSED_ALLOWED: int = 2,
     SEND_TIMEOUT_SECONDS: float = 5.0,
     AUTH_HANDSHAKE_TIMEOUT_SECONDS: float = 10.0;

"""Per-connection state: identity, auth, rate-limit bucket, heartbeat."""
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

    """Start the backplane the first time it's used (idempotent)."""
    async def ensure_backplane_started -> None;

    """Shutdown hook: close the backplane cleanly."""
    async def shutdown -> None;

    """Subscribe this worker to the target's channel (idempotent)."""
    async def ensure_subscribed(target_key: str) -> None;

    """Unsubscribe this worker from the target's channel if empty locally."""
    async def maybe_unsubscribe(target_key: str) -> None;

    """Handler invoked when the backplane delivers a message for a target."""
    async def _on_backplane_message(channel: str, message: dict) -> None;

    """Fan out a message to this worker's local connections for a target."""
    async def _local_fanout(target_key: str, message: dict) -> None;

    """Register a new connection. Returns an error reason string on rejection."""
    async def register(ctx: ConnectionContext) -> (str | None);

    """Remove a connection from the manager (idempotent)."""
    async def unregister(ctx: ConnectionContext) -> None;

    """Parallel broadcast with per-send timeout; one slow client doesn't block others."""
    async def broadcast(target_kind: str, target_name: str, message: dict) -> None;

    """Send to a single connection with timeout; closes the socket on timeout."""
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
            # Anonymous connections share a much tighter cap so a single
            # misbehaving client cannot exhaust the per-target budget on
            # public (`pub`) endpoints.
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
        connection_opened(ctx.target_kind, ctx.target_name);
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
    connection_closed(ctx.target_kind, ctx.target_name);
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
    # `_sub_lock` serializes the check/await/mutate sequence with
    # `maybe_unsubscribe` so a reconnect can't slip past a concurrent
    # unsubscribe and end up registered with no backplane subscription.
    sub_lock = self._get_sub_lock();
    await sub_lock.acquire();
    try {
        if target_key in self._subscribed {
            return;
        }
        await self.ensure_backplane_started();
        # Re-check liveness right before subscribing (no await in between):
        # the connection that triggered this may already be gone.
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
        # A reconnect may have re-populated this target after unregister
        # released the connection lock; keep the subscription if so.
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
    # Channel is "ws:{kind}:{name}"; strip the "ws:" prefix.
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

impl WebSocketConnectionManager.broadcast(
    target_kind: str, target_name: str, message: dict
) -> None {
    target_key = f"{target_kind}:{target_name}";
    backplane = self._get_backplane();
    channel = f"ws:{target_key}";
    broadcast_published(target_kind, target_name);
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
            await ctx.websocket.close(code=WS_CLOSE_IDLE, reason='send_timeout');
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
