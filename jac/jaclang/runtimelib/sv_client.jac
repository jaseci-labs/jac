import os;

import from jaclang.jac0core.sv_service_host { sv_host_env_key }
import from jaclang.runtimelib.test_sv_host {
    register_test_adapter,
    clear_test_adapters,
    close_all_test_sv_services
}

glob _registry: dict[str, str] = {},
     _consumer_providers: dict[str, list[str]] = {};

def headless_start_args(entry_file: str, port: int) -> list[str] {
    return ["start", entry_file, "--port", str(port), "--no-client"];
}

def register(module_name: str, url: str) {
    _registry[module_name] = url;
}

def unregister(module_name: str) {
    if module_name in _registry {
        del _registry[module_name];
    }
}

def register_test_client(module_name: str, client: any = None) -> None {
    os.environ[sv_host_env_key(module_name)] = 'test';
    if client is not None {
        register_test_adapter(module_name, client);
    }
}

def clear_test_clients {
    clear_test_adapters();
    close_all_test_sv_services();
}

def _declare_consumer_provider(consumer_name: str, provider_name: str) {
    if consumer_name not in _consumer_providers {
        _consumer_providers[consumer_name] = [];
    }
    if provider_name not in _consumer_providers[consumer_name] {
        _consumer_providers[consumer_name].append(provider_name);
    }
}

def get_consumer_providers(consumer_name: str) -> list[str] {
    return list(_consumer_providers.get(consumer_name, []));
}

def clear_consumer_providers {
    _consumer_providers.clear();
}

def peer_url_env_key(module_name: str) -> str {
    return f"JAC_SV_{module_name.upper()}_URL";
}

def peer_url_from_env(module_name: str) -> str {
    return os.environ.get(peer_url_env_key(module_name), "").strip();
}

def resolve_url(module_name: str) -> str {
    if module_name in _registry {
        return _registry[module_name];
    }
    env_url = peer_url_from_env(module_name);
    if env_url {
        return env_url;
    }
    raise RuntimeError(
        f"sv-to-sv service '{module_name}' not registered. "
            + f"Set {peer_url_env_key(module_name)} or call sv_client.register()."
    );
}

def _ensure_available(module_name: str) -> None {
    if module_name in _registry {
        return;
    }
    env_url = peer_url_from_env(module_name);
    if env_url {
        register(module_name, env_url);
        return;
    }
    import jaclang;
    bp = jaclang.JacRuntime.get_base_path_dir() if jaclang?.JacRuntime else None;
    base_path = bp or '.';
    jaclang.JacRuntime.ensure_sv_service(module_name, base_path);
}

def call(module_name: str, func_name: str, args: dict) -> any {
    _ensure_available(module_name);
    import jaclang;
    return jaclang.JacRuntime.sv_service_call(module_name, func_name, args);
}

def spawn_walker(module_name: str, walker_name: str, args: dict, stub_cls: any) -> any {
    _ensure_available(module_name);
    import jaclang;
    return jaclang.JacRuntime.sv_walker_call(module_name, walker_name, args, stub_cls);
}

def ensure_all(module_names: list[str]) -> None {
    pending: list[str] = [
        n
        for n in module_names
        if n not in _registry
    ];
    if not pending {
        return;
    }

    import from concurrent.futures { ThreadPoolExecutor, as_completed }
    executor: any = ThreadPoolExecutor(max_workers=8);
    futures: dict[any, str] = {};
    for name in pending {
        futures[executor.submit(_ensure_available, name)] = name;
    }
    first_error: (Exception | None) = None;
    try {
        for future in as_completed(futures) {
            fut: any = future;
            if first_error is not None {
                continue;
            }
            try {
                fut.result();
            } except Exception as e {
                first_error = e;
                for f in futures {
                    f_any: any = f;
                    if not f_any.done() {
                        f_any.cancel();
                    }
                }
            }
        }
    } finally {
        executor.shutdown(`wait=True);
    }
    if first_error is not None {
        raise first_error;
    }
}
