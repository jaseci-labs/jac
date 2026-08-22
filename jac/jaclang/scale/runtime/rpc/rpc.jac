import from .breaker {
    breaker_should_skip,
    breaker_record_success,
    breaker_record_failure,
    _BREAKER_COOLDOWN_SECONDS
}

glob _RPC_MAX_ATTEMPTS: int = 3,
     _RPC_INITIAL_BACKOFF_SECONDS: float = 0.1;

def _test_adapter(module_name: str) -> any {
    import from jaclang.jac0core.host { HOST_TEST }
    import from jaclang.jac0core.sv_service_host { resolve_sv_service_host }
    import from jaclang.runtimelib.test_sv_host { get_test_adapter }
    if resolve_sv_service_host(module_name) != HOST_TEST {
        return None;
    }
    return get_test_adapter(module_name);
}

def _rpc_with_retries(module_name: str, label: str, send: any) -> any {
    import time;
    import from jaclang.runtimelib.serving.client {
        ClientConnectionError,
        ClientRequestNotSent
    }

    backoff: float = _RPC_INITIAL_BACKOFF_SECONDS;
    last_err: Exception | None = None;
    attempts: int = 0;
    tripped: bool = False;

    for attempt in range(_RPC_MAX_ATTEMPTS) {
        attempts = attempt + 1;
        try {
            payload = send();
            breaker_record_success(module_name);
            return payload;
        } except ClientRequestNotSent as e {
            err_ref: any = e;
            last_err = err_ref;
            breaker_record_failure(module_name);
            if breaker_should_skip(module_name) {
                tripped = True;
                break;
            }
            if attempt < _RPC_MAX_ATTEMPTS - 1 {
                time.sleep(backoff);
                backoff = backoff * 2.0;
            }
        } except (ClientConnectionError, OSError) as e {
            sent_ref: any = e;
            last_err = sent_ref;
            breaker_record_failure(module_name);
            break;
        }
    }

    stopped_by = " (stopped by open circuit breaker)" if tripped else "";
    raise RuntimeError(
        f"sv-to-sv {label} failed after {attempts} attempts{stopped_by}: {last_err}"
    );
}


def service_call(module_name: str, func_name: str, args: dict) -> any {
    import from jaclang.runtimelib { sv_client }
    import from jaclang.scale.runtime.context.auth_ctx { get_current_auth }
    import from jaclang.scale.runtime.context.trace_ctx { get_current_trace }

    func_label = f"{module_name}.{func_name}";

    adapter = _test_adapter(module_name);
    if adapter is not None {
        resp = adapter.post(f"/function/{func_name}", json=args);
        ct = str(resp.headers.get("Content-Type") or "");
        if ct.startswith("text/event-stream") {
            return _iter_sse_text(str(resp.text), func_label);
        }
        data = resp.json();
        return _unwrap_sv_envelope(data, module_name, func_name);
    }

    if breaker_should_skip(module_name) {
        raise RuntimeError(
            f"sv-to-sv RPC '{module_name}.{func_name}' blocked by "
                + f"open circuit breaker (cooldown {int(_BREAKER_COOLDOWN_SECONDS)}s)"
        );
    }

    import jaclang;
    ms_registry: dict[str, str] = jaclang.JacRuntime.get_sv_registry();
    url: str = ms_registry.get(module_name, "");
    if not url {
        url = sv_client.resolve_url(module_name);
    }
    import from jaclang.runtimelib.serving.client { post_stream_aware_sync }

    headers: dict[str, str] = {};
    auth = get_current_auth();
    if auth {
        headers["Authorization"] = auth;
    }

    trace = get_current_trace();
    if trace {
        headers["X-Trace-Id"] = trace;
    }

    import from jaclang.scale.runtime.context.tracing { current_traceparent }
    tp = current_traceparent(trace);
    if tp {
        headers["traceparent"] = tp;
    }

    rpc_timeout: float = _sv_rpc_timeout(module_name);

    def send -> any {
        return post_stream_aware_sync(
            f"{url}/function/{func_name}",
            json_body=args,
            headers=headers,
            timeout=rpc_timeout,
            label=func_label
        );
    }

    (kind, payload) = _rpc_with_retries(module_name, f"RPC '{func_label}'", send);
    if kind == 'sse' {
        return payload;
    }
    return _unwrap_sv_envelope(payload, module_name, func_name);
}


def walker_call(
    module_name: str, walker_name: str, args: dict, stub_cls: any = None
) -> any {
    import from jaclang.runtimelib { sv_client }
    import from jaclang.scale.runtime.context.auth_ctx { get_current_auth }
    import from jaclang.scale.runtime.context.trace_ctx { get_current_trace }

    label = f"{module_name}.{walker_name}";

    adapter = _test_adapter(module_name);
    if adapter is not None {
        resp = adapter.post(f"/walker/{walker_name}", json=args);
        data = resp.json();
        return _hydrate_walker_envelope(data, module_name, walker_name, stub_cls);
    }

    if breaker_should_skip(module_name) {
        raise RuntimeError(
            f"sv-to-sv walker spawn '{label}' blocked by "
                + f"open circuit breaker (cooldown {int(_BREAKER_COOLDOWN_SECONDS)}s)"
        );
    }

    url = sv_client.resolve_url(module_name);
    import from jaclang.runtimelib.serving.client { request_sync }

    headers: dict[str, str] = {};
    auth = get_current_auth();
    if auth {
        headers["Authorization"] = auth;
    }
    trace = get_current_trace();
    if trace {
        headers["X-Trace-Id"] = trace;
    }

    import from jaclang.scale.runtime.context.tracing { current_traceparent }
    tp = current_traceparent(trace);
    if tp {
        headers["traceparent"] = tp;
    }

    rpc_timeout: float = _sv_rpc_timeout(module_name);

    def send -> any {
        resp = request_sync(
            'POST',
            f"{url}/walker/{walker_name}",
            json_body=args,
            headers=headers,
            timeout=rpc_timeout
        );
        return resp.json();
    }

    data = _rpc_with_retries(module_name, f"walker spawn '{label}'", send);
    return _hydrate_walker_envelope(data, module_name, walker_name, stub_cls);
}


def _iter_sse_text(text: str, func_label: str) -> any {
    import from jaclang.runtimelib.serving.sse { consume_sse_events }
    for ev in consume_sse_events(text.splitlines(), func_label) {
        yield ev;
    }
}

glob _SV_DEFAULT_RPC_TIMEOUT: float = 10.0;


def _sv_rpc_timeout(module_name: str) -> float {
    try {
        import from jaclang.scale.config.config_loader { get_scale_config }
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
