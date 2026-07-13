"""Dev-only devtools support for the base jaclang HTTP server.

Captures byllm LLM calls made during a single walker/function request and lets
the caller attach them (slim + truncated) to that request's response as
`llm_calls`, so the jac-client devtools overlay can show, per request, the LLM
calls it triggered.

Gated on JAC_DEVTOOLS (active unless set to 0/false/no). byllm is an optional
import -- when it is absent this module is inert. Only real requests that
actually made byllm calls get an `llm_calls` field; a cache hit or a byllm-free
app attaches nothing.
"""

import os;
import from contextvars { ContextVar }

glob _llm_sink: ContextVar = ContextVar('jac_devtools_llm_sink', default=None),
     _state: dict = {'registered': False};

"""Whether devtools request instrumentation is active (JAC_DEVTOOLS != 0)."""
def devtools_enabled() -> bool {
    val = os.environ.get('JAC_DEVTOOLS', '').lower();
    return val not in ('0', 'false', 'no');
}

"""byllm agent-telemetry callback: append a slim record to the current buffer.

A no-op unless a capture buffer is active on this context (i.e. inside a
request that called `begin_llm_capture`).
"""
def _llm_sink_callback(record: dict) -> None {
    buf = _llm_sink.get();
    if buf is None {
        return;
    }
    buf.append(
        {
            'caller': record.get('caller_name'),
            'model': record.get('model'),
            'latency_ms': record.get('latency_ms'),
            'status': record.get('status'),
            'prompt': (record.get('user_prompt') or '')[:1000],
            'response': (record.get('agent_response') or '')[:1000],
            'error': record.get('error')
        }
    );
}

"""Register the byllm telemetry callback exactly once (no-op without byllm)."""
def _ensure_registered() -> None {
    if _state['registered'] {
        return;
    }
    _state['registered'] = True;
    try {
        import from byllm.lib { register_agent_callback }
        register_agent_callback(_llm_sink_callback);
    } except Exception {
        # byllm not installed (or its telemetry API changed): capture stays inert.
        ;
    }
}

"""Begin capturing LLM calls for a request. Returns the buffer, or None if off."""
def begin_llm_capture() -> list | None {
    if not devtools_enabled() {
        return None;
    }
    _ensure_registered();
    buf: list = [];
    _llm_sink.set(buf);
    return buf;
}

"""Attach captured LLM calls to a dict response (skips streaming/empty buffers)."""
def attach_llm_calls(response: any, buf: any) -> None {
    if not buf {
        return;
    }
    # The response is a plain dict envelope or a TransportResponse whose `data`
    # is the `{result, reports}` envelope the client reads. Attach to whichever
    # dict the client will see under `data`.
    if isinstance(response, dict) {
        response['llm_calls'] = buf;
        return;
    }
    data = getattr(response, 'data', None);
    if isinstance(data, dict) {
        data['llm_calls'] = buf;
    }
}
