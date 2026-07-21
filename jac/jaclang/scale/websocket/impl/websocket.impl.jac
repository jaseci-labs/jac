impl WebSocketConnectionManager._get_lock -> Lock {
    if self._lock is None {
        self._lock = Lock();
    }
    return self._lock;
}

impl WebSocketConnectionManager._get_sub_lock -> Lock {
    if self._sub_lock is None {
        self._sub_lock = Lock();
    }
    return self._sub_lock;
}

impl WebSocketConnectionManager._target_has_connections(target_key: str) -> bool {
    per_target = self._by_target.get(target_key);
    return per_target is not None and len(per_target) > 0;
}

impl WebSocketConnectionManager._get_backplane -> BaseBackplane {
    if self.backplane is None {
        self.backplane = MemoryBackplane();
    }
    return self.backplane;
}

impl WebSocketConnectionManager.register(ctx: ConnectionContext) -> (str | None) {
    lock = self._get_lock();
    await lock.acquire();
    rejection: (str | None) = None;
    target_key = f"{ctx.target_kind}:{ctx.target_name}";
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
            per_target[ctx.conn_id] = ctx;
        }
    } finally {
        lock.release();
    }
    if rejection is None {
        try {
            await self.ensure_subscribed(target_key);
        } except Exception as e {
            logger.error(f"WS ensure_subscribed failed for {target_key}: {e}");
            await self._release_slot(ctx);
            return 'subscribe_unavailable';
        }
        if self.metrics is not None {
            self.metrics.record_ws_connection_opened();
        }
        logger.info(
            f"WS connected target={ctx.target_kind}:{ctx.target_name} "
            f"user_id={ctx.user_id} conn_id={ctx.conn_id}"
        );
    }
    return rejection;
}

impl WebSocketConnectionManager._release_slot(ctx: ConnectionContext) -> None {
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
}

impl WebSocketConnectionManager.unregister(ctx: ConnectionContext) -> None {
    await self._release_slot(ctx);
    if self.metrics is not None {
        self.metrics.record_ws_connection_closed();
    }
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
    if self.metrics is not None {
        self.metrics.record_ws_broadcast();
    }
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

impl consume_rate_token(
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

impl _ws_stream_next(gen: any) -> any {
    try {
        return gen.__next__();
    } except StopIteration {
        return _WS_STREAM_STOP;
    }
}

impl _ws_stream_result(send_result: any, result: any) {
    stream_error: (str | None) = None;
    try {
        if isgenerator(result) {
            loop = asyncio.get_running_loop();
            while True {
                item = await loop.run_in_executor(None, _ws_stream_next, result);
                if item is _WS_STREAM_STOP {
                    break;
                }
                await send_result({'ok': True, 'type': 'chunk', 'data': item});
            }
        } else {
            async for item in result {
                await send_result({'ok': True, 'type': 'chunk', 'data': item});
            }
        }
    } except WebSocketDisconnect {
        raise;
    } except Exception as e {
        logger.error(f"WS stream error: {e}");
        stream_error = str(e);
    }
    if stream_error is None {
        await send_result({'ok': True, 'type': 'done'});
    } else {
        await send_result(
            {
                'ok': False,
                'type': 'done',
                'error': {'code': 'STREAM_ERROR', 'message': stream_error}
            }
        );
    }
}
