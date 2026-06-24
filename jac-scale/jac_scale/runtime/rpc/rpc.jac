"""sv-to-sv RPC call bodies: auth/trace forwarding, retry with backoff,
circuit breaker, SSE-aware function calls and walker spawns.

Moved out of jac_scale.plugin so the @hookimpl methods there stay thin
delegators. Behavior is identical to the original in-plugin bodies.
"""
import from .breaker {
    breaker_should_skip,
    breaker_record_success,
    breaker_record_failure,
    _BREAKER_COOLDOWN_SECONDS
}


"""Call an sv-imported sibling service function over HTTP.

Reads the auth token from auth context (set by the FastAPI middleware in
jfast_api.impl.jac at the start of each inbound request) and attaches
it to the outgoing httpx.post.

Retries transport-level failures (connect errors, timeouts) with
exponential backoff: 0.1s, 0.2s, 0.4s (3 attempts total). Does NOT
retry on successful HTTP responses that carry application errors in
the envelope (ok=false) - those are deterministic and a retry won't
change them. 4xx/5xx HTTP statuses surface as envelope errors in
jac-scale's server, so they also don't retry.

Per-provider circuit breaker wraps the retry loop. After
_BREAKER_TRIP_THRESHOLD consecutive transport-failure cycles the
breaker opens and subsequent calls fail fast (no httpx.post) until
_BREAKER_COOLDOWN_SECONDS elapses; the first call after cooldown
becomes a probe that either closes the breaker on success or
re-opens it on failure.

In K8s, this covers the common transient failures: pod restarts
mid-request, DNS propagation lag, brief network blips. The breaker
also prevents a bad downstream pod from exhausting calling threads
while waiting on long timeouts.

Streaming returns: when the downstream function returns a generator,
serve.endpoints emits an `text/event-stream` body framed by
sse_frame_stream. We detect that via Content-Type and return a
Python generator (consume_sse_stream) that yields parsed event
dicts. Retries only cover connect-time failures - once a stream is
open, an in-flight error surfaces to the caller's iterator as a
RuntimeError (we cannot replay events that were already consumed).
"""
def service_call(module_name: str, func_name: str, args: dict) -> any {
    import time;
    import from jaclang.runtimelib { sv_client }
    import from jaclang.runtimelib.sv_sse { consume_sse_stream }
    import from jac_scale.runtime.context.auth_ctx { get_current_auth }
    import from jac_scale.runtime.context.trace_ctx { get_current_trace }

    func_label = f"{module_name}.{func_name}";

    # Test clients take precedence (matches core) and bypass retry +
    # breaker - they're in-process TestClient instances; transient
    # transport errors are not a concern.
    if module_name in sv_client._test_clients {
        tc = sv_client._test_clients[module_name];
        stream_cm = tc.stream("POST", f"/function/{func_name}", json=args);
        resp = stream_cm.__enter__();
        ct = resp.headers.get("content-type", "");
        if ct.startswith("text/event-stream") {
            # Wrapper takes ownership of stream_cm.__exit__; do NOT
            # exit it here. Pass None for client (TestClient is
            # owned by sv_client._test_clients).
            return _wrap_sse_keepalive_scale(stream_cm, resp, None, func_label);
        }
        try {
            # Streaming responses don't auto-read the body; httpx
            # raises ResponseNotRead on .json() otherwise.
            resp.read();
            data = resp.json();
        } finally {
            stream_cm.__exit__(None, None, None);
        }
        return _unwrap_sv_envelope(data, module_name, func_name);
    }

    # Circuit breaker: short-circuit when OPEN + cooldown not elapsed.
    if breaker_should_skip(module_name) {
        raise RuntimeError(
            f"sv-to-sv RPC '{module_name}.{func_name}' blocked by " + f"open circuit breaker (cooldown {int(
                _BREAKER_COOLDOWN_SECONDS
            )}s)"
        );
    }

    # Hookspec wins in K8s (DNS map); local mode falls back to
    # sv_client._registry then JAC_SV_*_URL env-var lookup.
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
    # Thread the trace id across the sv-import hop so downstream
    # service logs + its further sv calls carry the same correlator.
    trace = get_current_trace();
    if trace {
        headers["X-Trace-Id"] = trace;
    }
    # O-02: forward traceparent so the downstream span links as our child.
    import from jac_scale.runtime.context.tracing { current_traceparent }
    tp = current_traceparent(trace);
    if tp {
        headers["traceparent"] = tp;
    }

    max_attempts: int = 3;
    backoff: float = 0.1;  # doubles each attempt: 0.1, 0.2, 0.4
    last_err: Exception | None = None;

    rpc_timeout: float = _sv_rpc_timeout(module_name);

    for attempt in range(max_attempts) {
        try {
            # Use httpx.stream() so we can inspect Content-Type before
            # buffering the body. SSE replies stay open and feed the
            # consumer iterator; JSON replies are read fully then the
            # connection is closed in the finally branch.
            client = httpx.Client(timeout=rpc_timeout);
            stream_cm = client.stream(
                "POST", f"{url}/function/{func_name}", json=args, headers=headers
            );
            resp = stream_cm.__enter__();
            ct = resp.headers.get("content-type", "");
            if ct.startswith("text/event-stream") {
                # Streaming success: connection stays open. Record a
                # transport success and hand back a generator that
                # owns connection cleanup.
                breaker_record_success(module_name);
                return _wrap_sse_keepalive_scale(
                    stream_cm, resp, client, func_label
                );
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
            # Transport-level error: connect refused, read timeout,
            # DNS failure. Worth retrying - the downstream pod may
            # still be coming up or the network blip will clear.
            last_err = e;
            if attempt < max_attempts - 1 {
                time.sleep(backoff);
                backoff = backoff * 2.0;
            }
        }
    }

    # All retries exhausted on transport errors: count one failure
    # against the breaker. If this trips OPEN, subsequent calls
    # fail fast until cooldown.
    breaker_record_failure(module_name);

    raise RuntimeError(
        f"sv-to-sv RPC '{module_name}.{func_name}' failed after " + f"{max_attempts} attempts: {last_err}"
    );
}


"""Spawn an sv-imported sibling walker over HTTP.

Mirrors `service_call` for the walker-spawn flavour of sv-to-sv:
POST to `/walker/<name>` rather than `/function/<name>`, decode the
TransportResponse envelope, and rehydrate `data.result` into an
instance of the consumer-side stub class via `stub_cls._from_wire`.
The walker's `data.reports` list is attached to the rehydrated
instance so call sites read `walker_inst.reports[0]` directly.

Walker calls share the per-provider circuit breaker with function
calls - both express the same liveness signal for the provider, so
a breaker trip from either RPC kind protects the other. Auth and
trace headers are forwarded the same way. SSE streaming is not
plumbed for walkers (walker endpoints don't return generators); the
Content-Type pivot from service_call is intentionally absent.
"""
def walker_call(
    module_name: str, walker_name: str, args: dict, stub_cls: any = None
) -> any {
    import time;
    import from jaclang.runtimelib { sv_client }
    import from jac_scale.runtime.context.auth_ctx { get_current_auth }
    import from jac_scale.runtime.context.trace_ctx { get_current_trace }

    label = f"{module_name}.{walker_name}";

    # In-process TestClient path: bypass retry + breaker, no transport.
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
    # O-02: forward traceparent so the downstream span links as our child.
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
            return _hydrate_walker_envelope(
                data, module_name, walker_name, stub_cls
            );
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


"""Drive the SSE consumer against an already-entered Response, then
__exit__ the parent context manager (and close() the owning httpx
Client, if any) when the consumer is done iterating. Hoisted to
module scope because Jac doesn't support nested defs.

The TestClient branch passes `client=None` because the TestClient
instance is owned by sv_client._test_clients and outlives the call.
"""
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

# [plugins.scale.microservices.services.NAME].rpc_timeout overrides
# the default for LLM / long-running services.
glob _SV_DEFAULT_RPC_TIMEOUT: float = 10.0;


def _sv_rpc_timeout(module_name: str) -> float {
    try {
        import from jac_scale.config_loader { get_scale_config }
        ms_cfg = get_scale_config().get_microservices_config();
        svc_cfg = ms_cfg.get("services", {}).get(module_name, {});
        if "rpc_timeout" in svc_cfg {
            return float(svc_cfg["rpc_timeout"]);
        }
    } except Exception {
        # Fall through on config read failure (e.g. no jac.toml in tests).
        ;
    }
    return _SV_DEFAULT_RPC_TIMEOUT;
}


"""Unwrap a TransportResponse envelope from an sv-service RPC response.

Shared between the retry and test-client paths in service_call so
both observe the same error semantics. Raises RuntimeError with the
envelope's error message when ok=false.
"""
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

"""Rehydrate a /walker/<name> response envelope into a stub instance.

The wire envelope has both `data.result` (the executed walker as a
dict with `_jac_type` / `_jac_id` / `_jac_archetype` / has-fields)
and `data.reports` (the list of values the walker emitted via
`report`). We hand back an instance of the consumer-side stub class
with the has-fields populated and `reports` attached, so call sites
can read both like a locally-spawned walker. Raises RuntimeError on
envelope-level failure, matching `_unwrap_sv_envelope`.
"""
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
