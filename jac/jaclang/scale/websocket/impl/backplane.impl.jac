import uuid as _uuid;

glob _NOTIFY_LIMIT = 7000,
     _SPILL_TTL_SECONDS = 60;


impl MemoryBackplane.start{
    if not self._warned {
        logger.warning(
            "WS MemoryBackplane in use: broadcasts are limited to this "
            "process. For multi-worker deployments configure "
            "[scale.websocket].backplane = 'pg'."
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


impl PgBackplane._pg_channel(channel: str) -> str {
    out = '';
    for ch in channel.lower() {
        out += ch if (ch.isalnum() or ch == '_') else '_';
    }
    return f"jac_ws_{out}"[:63];
}


impl PgBackplane.start -> None {
    if self._store is not None {
        return;
    }
    import from jaclang.scale.persistence.pg { shared_store }
    store = await asyncio.to_thread(shared_store);
    if store is None {
        raise RuntimeError(
            "PgBackplane selected but no database is reachable "
            "(set JAC_DB_URL or [plugins.scale.database] url)."
        );
    }
    self._store = store;
    self._loop = asyncio.get_running_loop();
    logger.info("WS PgBackplane attached to the shared store");
}


impl PgBackplane.publish(channel: str, message: dict) -> None {
    await self.start();
    payload = json.dumps(message);
    if len(payload.encode('utf-8')) > _NOTIFY_LIMIT {
        key = f"wsmsg:{_uuid.uuid4()}";
        def _spill {
            self._store.kv_put_ttl(key, payload, _SPILL_TTL_SECONDS);
            self._store.notify(self._pg_channel(channel), json.dumps({'__kv': key}));
        }
        await asyncio.to_thread(_spill);
    } else {
        await asyncio.to_thread(self._store.notify, self._pg_channel(channel), payload);
    }
}


impl PgBackplane._on_notify(channel: str, payload: str) -> None {
    if self._closed or self._loop is None {
        return;
    }
    try {
        data = json.loads(payload);
        if isinstance(data, dict) and '__kv' in data {
            key = str(data['__kv']);
            got = self._store.kv_get(key);
            if got is None {
                logger.warning(
                    f"PgBackplane: spilled payload {key} missing on {channel}; "
                    "dropping broadcast"
                );
                return;
            }
            data = json.loads(got);
        }
    } except Exception as e {
        logger.warning(f"PgBackplane: bad payload on {channel}: {e}");
        return;
    }
    for (name, handlers) in list(self._handlers.items()) {
        if self._pg_channel(name) == channel and handlers {
            coro: Any = self._dispatch(name, data);
            asyncio.run_coroutine_threadsafe(coro, self._loop);
        }
    }
}


impl PgBackplane._dispatch(channel: str, message: dict) -> None {
    handlers = list(self._handlers.get(channel, []));
    if handlers {
        tasks = [h(channel, message) for h in handlers];
        await asyncio.gather(*tasks, return_exceptions=True);
    }
}


impl PgBackplane.subscribe(channel: str, handler: Any) {
    await self.start();
    if channel not in self._handlers {
        self._handlers[channel] = [];
    }
    self._handlers[channel].append(handler);
    pg_chan = self._pg_channel(channel);
    if pg_chan not in self._listening {
        self._listening.add(pg_chan);
        cb = lambda (payload: str) { self._on_notify(pg_chan, payload); };
        await asyncio.to_thread(self._store.listen, pg_chan, cb);
    }
}


impl PgBackplane.unsubscribe(channel: str, handler: Any) {
    handlers = self._handlers.get(channel);
    if handlers is None {
        return;
    }
    try {
        handlers.remove(handler);
    } except ValueError {
        return;
    }
    if not handlers {
        del self._handlers[channel];
    }
}


impl PgBackplane.close{
    self._closed = True;
    self._handlers = {};
}


impl build_backplane(cfg: dict) -> BaseBackplane {
    backplane = cfg.get('backplane');
    if backplane == 'memory' {
        return MemoryBackplane();
    }
    if backplane == 'pg' {
        return PgBackplane();
    }
    if backplane is not None {
        raise ValueError(
            f"Unknown [scale.websocket].backplane value: {backplane!r}. "
            "Expected 'memory' or 'pg'."
        );
    }
    import from jaclang.scale.persistence.pg { scale_db_url }
    if scale_db_url() {
        return PgBackplane();
    }
    return MemoryBackplane();
}
