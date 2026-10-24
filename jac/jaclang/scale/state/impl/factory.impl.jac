impl _after_fork_in_child {
    _backend_holder.clear();
}

impl in_fleet -> bool {
    return bool(os.environ.get('KUBERNETES_SERVICE_HOST', '').strip())
        or os.environ.get('JAC_SV_SIBLING') == '1';
}

impl get_state_backend(shared: bool = False) -> StateBackend {
    backend = _backend_holder.get("default");
    if backend is not None {
        return backend;
    }
    if shared or in_fleet() {
        store = shared_store();
        if store is None {
            raise RuntimeError(
                "shared state needs a reachable database "
                f"({shared_store_failure() or 'no database resolved'}); rate limits "
                "and locks cannot be kept per process across a fleet"
            );
        }
        backend = PgStateBackend(store=store);
    } else {
        backend = InProcessStateBackend();
    }
    _backend_holder["default"] = backend;
    return backend;
}
