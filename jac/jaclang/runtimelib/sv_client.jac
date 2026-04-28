"""Runtime client for sv-to-sv microservice calls.

When a Jac server module does sv import from another_module { func },
the compiler generates HTTP stub functions that call into this module
to route the request to the provider service.

The wire contract is identical to cl-to-sv interop:
  POST /function/{name}
  Body: JSON dict of kwargs
  Response: TransportResponse envelope {ok, data, error, meta}
"""

import os;
import from typing { Any }

# Module name -> base URL (set by jac start orchestration or test code)
glob _registry: dict[str, str] = {},
     # Module name -> TestClient instance (set by tests for in-process routing)
     _test_clients: dict[str, Any] = {},
     # Consumer module name -> list of provider module names it sv-imports.
     # Populated at consumer module import time by compile-time-emitted
     # _declare_consumer_provider() calls in the generated stubs. Read at
     # consumer server startup by JacAPIServer._ensure_sv_siblings() to
     # eager-spawn every provider before serving traffic.
     _consumer_providers: dict[str, list[str]] = {};

"""Register a service URL for sv-to-sv resolution."""
def register(module_name: str, url: str) {
    _registry[module_name] = url;
}

"""Remove a service registration."""
def unregister(module_name: str) {
    if module_name in _registry {
        del _registry[module_name];
    }
}

"""Register an in-process TestClient for a service (testing only)."""
def register_test_client(module_name: str, client: Any) {
    _test_clients[module_name] = client;
}

"""Remove a TestClient registration."""
def unregister_test_client(module_name: str) {
    if module_name in _test_clients {
        del _test_clients[module_name];
    }
}

"""Clear all TestClient registrations (between tests)."""
def clear_test_clients {
    _test_clients.clear();
}

"""Record that a consumer module sv-imports a given provider module.

Called from the compile-time-generated stub preamble in every consumer
that has at least one `sv import from <provider>` statement. Idempotent;
safe to call multiple times for the same (consumer, provider) pair.
"""
def _declare_consumer_provider(consumer_name: str, provider_name: str) {
    if consumer_name not in _consumer_providers {
        _consumer_providers[consumer_name] = [];
    }
    if provider_name not in _consumer_providers[consumer_name] {
        _consumer_providers[consumer_name].append(provider_name);
    }
}

"""Return the list of provider module names a given consumer sv-imports.

Returns an empty list if the consumer has no recorded sv-import providers
(i.e. it has no `sv import` statements, or its module-level code has not
yet executed). Used by the eager-spawn pass at consumer server startup.
"""
def get_consumer_providers(consumer_name: str) -> list[str] {
    return list(_consumer_providers.get(consumer_name, []));
}

"""Clear all consumer-provider declarations (between tests)."""
def clear_consumer_providers {
    _consumer_providers.clear();
}

"""Resolve a service URL via registry or environment."""
def resolve_url(module_name: str) -> str {
    if module_name in _registry {
        return _registry[module_name];
    }
    env_var = f"JAC_SV_{module_name.upper()}_URL";
    if env_var in os.environ {
        return os.environ[env_var];
    }
    raise RuntimeError(
        f"sv-to-sv service '{module_name}' not registered. " + f"Set {env_var} or call sv_client.register()."
    );
}

"""Lazily ensure a service is available, invoking the plugin hook if needed.

Resolution order:
  1. TestClient registered via register_test_client()
  2. URL registered via register()
  3. JAC_SV_{MODULE}_URL environment variable
  4. JacAPIServer.ensure_sv_service() plugin hook (default: spawn local server)
"""
def _ensure_available(module_name: str) -> None {
    if module_name in _test_clients {
        return;
    }
    if module_name in _registry {
        return;
    }
    env_var = f"JAC_SV_{module_name.upper()}_URL";
    if env_var in os.environ {
        register(module_name, os.environ[env_var]);
        return;
    }
    import jaclang;
    base_path = jaclang.JacRuntime?.base_path_dir or '.';
    jaclang.JacRuntime.ensure_sv_service(module_name, base_path);
}

"""Make an sv-to-sv RPC call.

Resolution order:
  1. TestClient registered via register_test_client()
  2. URL registered via register()
  3. JAC_SV_{MODULE}_URL environment variable
  4. JacAPIServer.ensure_sv_service() plugin hook on cache miss

Returns the unwrapped result from the TransportResponse envelope.
Raises RuntimeError on failure.
"""
def call(module_name: str, func_name: str, args: dict) -> Any {
    _ensure_available(module_name);
    if module_name in _test_clients {
        resp = _test_clients[module_name].post(f"/function/{func_name}", json=args);
        data = resp.json();
    } else {
        url = resolve_url(module_name);
        try {
            import httpx;
        } except ImportError {
            raise RuntimeError(
                "httpx is required for sv-to-sv RPC calls. " + "Install it via `pip install httpx`."
            );
        }
        resp = httpx.post(f"{url}/function/{func_name}", json=args);
        data = resp.json();
    }

    if isinstance(data, dict) and data.get("ok") {
        result_envelope = data.get("data");
        if isinstance(result_envelope, dict) and ("result" in result_envelope) {
            return result_envelope["result"];
        }
        return result_envelope;
    }

    err = (data.get("error") if isinstance(data, dict) else None) or {};
    msg = err.get("message") if isinstance(err, dict) else str(err);
    raise RuntimeError(
        f"sv-to-sv RPC '{module_name}.{func_name}' failed: {msg or 'unknown error'}"
    );
}

"""Eagerly resolve every named provider before serving traffic.

Walks providers in parallel through a bounded ThreadPoolExecutor (max 8
workers), routing each through the existing _ensure_available resolution
chain (test client, registry, env var, ensure_sv_service plugin hook).
Idempotent: providers already in _registry / _test_clients are skipped
without ever submitting a task.

Fail-fast: if any provider fails to resolve, the first failure cancels
all in-flight spawns and the exception is re-raised at the caller. The
intent is for the consumer to crash at startup, not at first request, so
operators discover misconfiguration at deploy time.

Called by JacAPIServer._ensure_sv_siblings() during consumer server
startup. The bound of 8 caps worst-case startup latency at
ceil(N/8) * spawn_time; for typical N < 8 every provider spawns in
parallel and the bound is irrelevant.
"""
def ensure_all(module_names: list[str]) -> None {
    pending: list[str] = [
        n
        for n in module_names
        if n not in _registry and n not in _test_clients
    ];
    if not pending {
        return;
    }
    # Typeshed re-exports for `concurrent.futures` do not flow through
    # Jac's type checker, so bind the names as Any locally and trust the
    # runtime contract.
    import from concurrent.futures { ThreadPoolExecutor, as_completed }
    executor: Any = ThreadPoolExecutor(max_workers=8);
    futures: dict[Any, str] = {};
    for name in pending {
        futures[executor.submit(_ensure_available, name)] = name;
    }
    first_error: (Exception | None) = None;
    try {
        for future in as_completed(futures) {
            fut: Any = future;
            if first_error is not None {
                continue;
            }
            try {
                fut.result();
            } except Exception as e {
                first_error = e;
                for f in futures {
                    f_any: Any = f;
                    if not f_any.done() {
                        f_any.cancel();
                    }
                }
            }
        }
    } finally {
        executor.shutdown(wait=True);
    }
    if first_error is not None {
        raise first_error;
    }
}
