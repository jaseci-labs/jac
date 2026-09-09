import from .breaker {
    breaker_should_skip,
    breaker_record_success,
    breaker_record_failure,
    _BREAKER_COOLDOWN_SECONDS
}

glob _RPC_MAX_ATTEMPTS: int = 3,
     _RPC_INITIAL_BACKOFF_SECONDS: float = 0.1;

def _rpc_with_retries(module_name: str, label: str, send: any) -> any {
    import time;
    import from jaclang.server.serving.client {
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


def _rpc_headers(extra: dict[str, str] | None = None) -> dict[str, str] {
    import from jaclang.server { sv_client }
    import from jaclang.scale.runtime.context.auth_ctx { get_current_auth }
    import from jaclang.scale.runtime.context.trace_ctx { get_current_trace }
    import from jaclang.scale.runtime.context.tracing { current_traceparent }

    headers: dict[str, str] = dict(sv_client.auth_headers());
    for (key, value) in (extra or {}).items() {
        headers[str(key)] = str(value);
    }
    auth = get_current_auth();
    if auth {
        headers["Authorization"] = auth;
    }
    trace = get_current_trace();
    if trace {
        headers["X-Trace-Id"] = trace;
    }
    tp = current_traceparent(trace);
    if tp {
        headers["traceparent"] = tp;
    }
    return headers;
}


def _provider_url(app_name: str) -> str {
    import jaclang;
    import from jaclang.server { sv_client }
    registry: dict[str, str] = jaclang.JacRuntime.get_sv_registry();
    base: str = str(registry.get(app_name, "") or "").rstrip("/");
    if not base {
        return sv_client.resolve_url(app_name);
    }
    route: str = sv_client.registered_route(app_name);
    if route and not base.endswith(route) {
        return base + route;
    }
    return base;
}


def service_call(
    module_name: str, func_name: str, args: dict, headers: dict[str, str] | None = None
) -> any {
    import from jaclang.server { sv_client }

    func_label = f"{module_name}.{func_name}";

    if module_name in sv_client._test_clients {
        tc = sv_client._test_clients[module_name];
        resp = tc.post(
            f"/function/{func_name}", json=args, headers=_rpc_headers(headers)
        );
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

    url: str = _provider_url(module_name);
    import from jaclang.server.serving.client { post_stream_aware_sync }

    send_headers: dict[str, str] = _rpc_headers(headers);

    rpc_timeout: float = _sv_rpc_timeout(module_name);

    def send -> any {
        return post_stream_aware_sync(
            f"{url}/function/{func_name}",
            json_body=args,
            headers=send_headers,
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
    module_name: str,
    walker_name: str,
    args: dict,
    stub_cls: any = None,
    headers: dict[str, str] | None = None
) -> any {
    import from jaclang.server { sv_client }

    label = f"{module_name}.{walker_name}";

    if module_name in sv_client._test_clients {
        tc = sv_client._test_clients[module_name];
        resp = tc.post(
            f"/walker/{walker_name}", json=args, headers=_rpc_headers(headers)
        );
        data = resp.json();
        return _hydrate_walker_envelope(data, module_name, walker_name, stub_cls);
    }

    if breaker_should_skip(module_name) {
        raise RuntimeError(
            f"sv-to-sv walker spawn '{label}' blocked by "
                + f"open circuit breaker (cooldown {int(_BREAKER_COOLDOWN_SECONDS)}s)"
        );
    }

    url = _provider_url(module_name);
    import from jaclang.server.serving.client { request_sync }

    send_headers: dict[str, str] = _rpc_headers(headers);

    rpc_timeout: float = _sv_rpc_timeout(module_name);

    def send -> any {
        resp = request_sync(
            'POST',
            f"{url}/walker/{walker_name}",
            json_body=args,
            headers=send_headers,
            timeout=rpc_timeout
        );
        return resp.json();
    }

    data = _rpc_with_retries(module_name, f"walker spawn '{label}'", send);
    return _hydrate_walker_envelope(data, module_name, walker_name, stub_cls);
}


def _iter_sse_text(text: str, func_label: str) -> any {
    import from jaclang.server.serving.sse { consume_sse_events }
    for ev in consume_sse_events(text.splitlines(), func_label) {
        yield ev;
    }
}

glob _SV_DEFAULT_RPC_TIMEOUT: float = 10.0;


def _sv_rpc_timeout(app_name: str) -> float {
    try {
        import from jaclang.scale.config.config_loader { get_scale_config }
        app_cfg = get_scale_config().get_app_scale_config(app_name);
        if "rpc_timeout" in app_cfg {
            return float(app_cfg["rpc_timeout"]);
        }
    } except Exception {}
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
            } except Exception {}
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
