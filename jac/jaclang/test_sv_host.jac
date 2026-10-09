glob _RUNTIMES: dict[str, any] = {},
     _ADAPTERS: dict[str, any] = {};


def register_test_adapter(module_name: str, client: any) {
    _ADAPTERS[module_name] = client;
}


def get_test_adapter(module_name: str) -> any {
    return _ADAPTERS.get(module_name);
}


def clear_test_adapters {
    _ADAPTERS.clear();
}


def prepare_test_sv_service(module_name: str, jac_file: str, base_path: str) -> str {
    import from jaclang.scale.server.inprocess { prepare_inprocess_runtime }
    runtime = prepare_inprocess_runtime(
        jac_file=jac_file,
        base_path=base_path,
        endpoint_profile='test',
        setup_background_services=False
    );
    _RUNTIMES[module_name] = runtime;
    port = runtime.server.port;
    return f"http://127.0.0.1:{port}";
}


def close_test_sv_service(module_name: str) {
    runtime = _RUNTIMES.pop(module_name, None);
    if runtime is not None {
        runtime.close();
    }
    if module_name in _ADAPTERS {
        del _ADAPTERS[module_name];
    }
}


def close_all_test_sv_services {
    for name in list(_RUNTIMES.keys()) {
        close_test_sv_service(name);
    }
    _ADAPTERS.clear();
}
