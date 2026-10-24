impl _after_fork_in_child {
    _lock = threading.Lock();
    store: any = _holder.pop('store', None);
    _holder.pop('key', None);
    _holder.pop('failure', None);
    if store is None {
        return;
    }
    for attr in ('_conn', '_side_conn') {
        detach(getattr(store, attr, None));
        try {
            setattr(store, attr, None);
        } except Exception {}
    }
}

impl scale_db_url -> (str | None) {
    url = os.environ.get('JAC_DB_URL', '');
    if url {
        return url;
    }
    try {
        import from jaclang.scale.config.config_loader { get_scale_config }
        cfg = get_scale_config().get_database_config();
        got = cfg.get('url') or cfg.get('postgres_url');
        return str(got) if got else None;
    } except Exception as e {
        logger.debug(f"[scale.database] url unreadable: {e}");
        return None;
    }
}

impl _url_source -> str {
    return ('JAC_DB_URL' if os.environ.get('JAC_DB_URL') else '[scale.database] url');
}

impl _store_target(store: any) -> str {
    try {
        info = store.conninfo;
        where = info.unix_socket_dir or info.host or '?';
        return f"{where}:{info.port}/{info.database}";
    } except Exception {
        return 'the resolved database';
    }
}

impl _in_cluster -> bool {
    return bool(os.environ.get('KUBERNETES_SERVICE_HOST', '').strip());
}

impl _fail(reason: str) {
    if _holder.get('failure') == reason {
        logger.debug(f"scale shared store still unavailable: {reason}");
    } else {
        logger.warning(f"scale shared store unavailable: {reason}");
    }
    _holder.pop('key', None);
    _holder.pop('store', None);
    _holder['failure'] = reason;
}

impl shared_store_failure -> (str | None) {
    got = _holder.get('failure');
    return str(got) if got else None;
}

impl shared_store -> (any | None) {
    with _lock {
        import from jaclang.runtime.runtime { JacRuntime }
        url = scale_db_url();
        key = url
            or (
                f"{JacRuntime.get_base_path_dir() or ''}"
                f"::{JacRuntime.get_full_target_path() or ''}"
            );
        if _holder.get('key') == key and 'store' in _holder {
            return _holder['store'];
        }
        old_store: any = _holder.pop('store', None);
        if old_store is not None {
            try {
                old_store.close();
            } except Exception {}
        }
        store: (any | None) = None;
        reset = False;
        stage = 'resolve';
        source = _url_source() if url else 'the embedded server';
        try {
            import from jaclang.server.session { conninfo_from_url, promotions_for }
            import from jaclang.data.store { PgStore }
            promotions = promotions_for(JacRuntime.get_base_path_dir());
            if url {
                store = PgStore(conninfo=conninfo_from_url(url), promotions=promotions);
            } elif _in_cluster() {
                _fail(NO_DATABASE_IN_CLUSTER);
                return None;
            } else {
                import from jaclang.server.session { runtime_for_base }
                base = JacRuntime.get_base_path_dir();
                if base {
                    stage = 'provision';
                    lease = runtime_for_base(base, JacRuntime.get_full_target_path());
                    rt = lease.runtime;
                    store = PgStore(
                        conninfo=rt.ensure(), ensure_cb=rt.ensure, promotions=promotions
                    );
                    reset = lease.reset;
                }
            }
            if store is None {
                _fail(NO_DATABASE_RESOLVED);
                return None;
            }

            stage = 'connect';
            store.rows('SELECT 1', {});
            stage = 'schema';
            store.ensure_schema_once(promotions);
            if reset {
                store.reset_data();
            }
        } except Exception as e {
            if store is not None {
                try {
                    store.close();
                } except Exception {}
            }
            _fail(_failure_reason(stage, source, store, e));
            return None;
        }
        _holder['key'] = key;
        _holder['store'] = store;
        _holder.pop('failure', None);
        return store;
    }
}

impl _failure_reason(stage: str, source: str, store: any, e: Exception) -> str {
    cause = f"{type(e).__name__}: {e}";
    if stage == 'provision' {
        return f"the embedded Postgres server could not be provisioned ({cause})";
    }
    if stage == 'resolve' {
        return f"the store named by {source} could not be built ({cause})";
    }
    where = _store_target(store);
    if stage == 'schema' {
        return (
            f"connected to {where} but the shared schema could not be set up"
            f" ({cause})"
        );
    }
    return f"cannot reach {where}, resolved from {source} ({cause})";
}
