import from .breaker {
    breaker_should_skip,
    breaker_record_success,
    breaker_record_failure,
    _BREAKER_COOLDOWN_SECONDS
}


def service_call(module_name: str, func_name: str, args: dict) -> any {
    import time;
    import from jaclang.runtimelib { sv_client }
    import from jaclang.runtimelib.sv_sse { consume_sse_stream }
    import from jac_scale.runtime.context.auth_ctx { get_current_auth }
    import from jac_scale.runtime.context.trace_ctx { get_current_trace }

    func_label = f"{module_name}.{func_name}";

    if module_name in sv_client._test_clients {
        tc = sv_client._test_clients[module_name];
        stream_cm = tc.stream("POST", f"/function/{func_name}", json=args);
        resp = stream_cm.__enter__();
        ct = resp.headers.get("content-type", "");
        if ct.startswith("text/event-stream") {
            return _wrap_sse_keepalive_scale(stream_cm, resp, None, func_label);
        }
        try {
            resp.read();
            data = resp.json();
        } finally {
            stream_cm.__exit__(None, None, None);
        }
        return _unwrap_sv_envelope(data, module_name, func_name);
    }

    if breaker_should_skip(module_name) {
        raise RuntimeError(
            f"sv-to-sv RPC '{module_name}.{func_name}' blocked by " + f"open circuit breaker (cooldown {int(
                _BREAKER_COOLDOWN_SECONDS
            )}s)"
        );
    }

    import jaclang;
    ms_registry: dict[str, str] = jaclang.JacRuntime.get_sv_registry();
    url: str = ms_registry.get(module_name, "");
    if not url {
        url = sv_client.resolve_url(module_name);
    }
    try {
        import httpx;
    } except ImportError {
        raise RuntimeError(
            "httpx is required for sv-to-sv RPC calls. " + "Install it via `pip install httpx`."
        );
    }

    headers: dict[str, str] = {};
    auth = get_current_auth();
    if auth {
        headers["Authorization"] = auth;
    }

    trace = get_current_trace();
    if trace {
        headers["X-Trace-Id"] = trace;
    }

    import from jac_scale.runtime.context.tracing { current_traceparent }
    tp = current_traceparent(trace);
    if tp {
        headers["traceparent"] = tp;
    }

    max_attempts: int = 3;
    backoff: float = 0.1;
    last_err: Exception | None = None;

    rpc_timeout: float = _sv_rpc_timeout(module_name);

    for attempt in range(max_attempts) {
        try {
            client = httpx.Client(timeout=rpc_timeout);
            stream_cm = client.stream(
                "POST", f"{url}/function/{func_name}", json=args, headers=headers
            );
            resp = stream_cm.__enter__();
            ct = resp.headers.get("content-type", "");
            if ct.startswith("text/event-stream") {
                breaker_record_success(module_name);
                return _wrap_sse_keepalive_scale(stream_cm, resp, client, func_label);
            }
            try {
                resp.read();
                data = resp.json();
            } finally {
                stream_cm.__exit__(None, None, None);
                client.close();
            }
            breaker_record_success(module_name);
            return _unwrap_sv_envelope(data, module_name, func_name);
        } except (httpx.RequestError, httpx.TimeoutException) as e {
            last_err = e;
            if attempt < max_attempts - 1 {
                time.sleep(backoff);
                backoff = backoff * 2.0;
            }
        }
    }

    breaker_record_failure(module_name);

    raise RuntimeError(
        f"sv-to-sv RPC '{module_name}.{func_name}' failed after " + f"{max_attempts} attempts: {last_err}"
    );
}


def walker_call(
    module_name: str, walker_name: str, args: dict, stub_cls: any = None
) -> any {
    import time;
    import from jaclang.runtimelib { sv_client }
    import from jac_scale.runtime.context.auth_ctx { get_current_auth }
    import from jac_scale.runtime.context.trace_ctx { get_current_trace }

    label = f"{module_name}.{walker_name}";

    if module_name in sv_client._test_clients {
        tc = sv_client._test_clients[module_name];
        resp = tc.post(f"/walker/{walker_name}", json=args);
        data = resp.json();
        return _hydrate_walker_envelope(data, module_name, walker_name, stub_cls);
    }

    if breaker_should_skip(module_name) {
        raise RuntimeError(
            f"sv-to-sv walker spawn '{label}' blocked by " + f"open circuit breaker (cooldown {int(
                _BREAKER_COOLDOWN_SECONDS
            )}s)"
        );
    }

    url = sv_client.resolve_url(module_name);
    try {
        import httpx;
    } except ImportError {
        raise RuntimeError(
            "httpx is required for sv-to-sv RPC calls. " + "Install it via `pip install httpx`."
        );
    }

    headers: dict[str, str] = {};
    auth = get_current_auth();
    if auth {
        headers["Authorization"] = auth;
    }
    trace = get_current_trace();
    if trace {
        headers["X-Trace-Id"] = trace;
    }

    import from jac_scale.runtime.context.tracing { current_traceparent }
    tp = current_traceparent(trace);
    if tp {
        headers["traceparent"] = tp;
    }

    max_attempts: int = 3;
    backoff: float = 0.1;
    last_err: Exception | None = None;

    rpc_timeout: float = _sv_rpc_timeout(module_name);

    for attempt in range(max_attempts) {
        try {
            client = httpx.Client(timeout=rpc_timeout);
            try {
                resp = client.post(
                    f"{url}/walker/{walker_name}", json=args, headers=headers
                );
                data = resp.json();
            } finally {
                client.close();
            }
            breaker_record_success(module_name);
            return _hydrate_walker_envelope(data, module_name, walker_name, stub_cls);
        } except (httpx.RequestError, httpx.TimeoutException) as e {
            last_err = e;
            if attempt < max_attempts - 1 {
                time.sleep(backoff);
                backoff = backoff * 2.0;
            }
        }
    }

    breaker_record_failure(module_name);

    raise RuntimeError(
        f"sv-to-sv walker spawn '{label}' failed after " + f"{max_attempts} attempts: {last_err}"
    );
}


def _wrap_sse_keepalive_scale(
    stream_cm: any, resp: any, client: any, func_label: str
) -> any {
    import from jaclang.runtimelib.sv_sse { consume_sse_stream }
    try {
        for ev in consume_sse_stream(resp, func_label) {
            yield ev;
        }
    } finally {
        try {
            stream_cm.__exit__(None, None, None);
        } except Exception {
            ;
        }
        if client {
            try {
                client.close();
            } except Exception {
                ;
            }
        }
    }
}

glob _SV_DEFAULT_RPC_TIMEOUT: float = 10.0;


def _sv_rpc_timeout(module_name: str) -> float {
    try {
        import from jac_scale.config.config_loader { get_scale_config }
        ms_cfg = get_scale_config().get_microservices_config();
        svc_cfg = ms_cfg.get("services", {}).get(module_name, {});
        if "rpc_timeout" in svc_cfg {
            return float(svc_cfg["rpc_timeout"]);
        }
    } except Exception {
        ;
    }
    return _SV_DEFAULT_RPC_TIMEOUT;
}


def _unwrap_sv_envelope(data: any, module_name: str, func_name: str) -> any {
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

def _hydrate_walker_envelope(
    data: any, module_name: str, walker_name: str, stub_cls: any
) -> any {
    if isinstance(data, dict) and data.get("ok") {
        envelope = data.get("data") or {};
        result_dict = envelope.get("result") if isinstance(envelope, dict) else None;
        reports = envelope.get("reports") if isinstance(envelope, dict) else None;
        instance = stub_cls._from_wire(result_dict)
            if (stub_cls is not None and result_dict is not None)
            else result_dict;
        if instance is not None and reports is not None {
            try {
                instance.reports = reports;
            } except Exception {
                ;
            }
        }
        return instance;
    }
    err = (data.get("error") if isinstance(data, dict) else None) or {};
    msg = err.get("message") if isinstance(err, dict) else str(err);
    raise RuntimeError(
        f"sv-to-sv walker spawn '{module_name}.{walker_name}' failed: {msg
        or 'unknown error'}"
    );
}
