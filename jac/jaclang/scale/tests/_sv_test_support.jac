import jaclang.server.serving.client as sv_http;
import jaclang.scale.runtime.rpc.rpc as rpc_mod;


obj _MockRequest {
    has url: str = '',
        headers: dict[str, str] = {},
        timeout: float = 0.0,
        json_body: any = None;
}

obj _MockResponse {
    has json_payload: any = None;
}

def _install_mock(handler: any) -> any {
    original = sv_http.post_stream_aware_sync;

    def fake(
        url: str,
        json_body: any = None,
        headers: (dict | None) = None,
        timeout: float = 30.0,
        label: str = ''
    ) -> tuple[str, any] {
        request = _MockRequest(
            url=url, headers=headers or {}, timeout=timeout, json_body=json_body
        );
        return ('json', handler(request).json_payload);
    }
    sv_http.post_stream_aware_sync = fake;
    return original;
}

"""Pin rpc_timeout for one module; every other module keeps the real resolver."""
def _install_rpc_timeout(module_name: str, seconds: float) -> any {
    original = getattr(rpc_mod, "_sv_rpc_timeout");

    def resolver(name: str) -> float {
        return seconds if name == module_name else original(name);
    }
    setattr(rpc_mod, "_sv_rpc_timeout", resolver);
    return original;
}

def _restore_rpc_timeout(original: any) {
    setattr(rpc_mod, "_sv_rpc_timeout", original);
}

"""Replace the function transport with one that always fails to connect."""
def _install_unreachable_transport(round_trips: dict) -> any {
    import from jaclang.server.serving.client { ClientRequestNotSent }
    original = sv_http.post_stream_aware_sync;

    def fake(*args: any, **kwargs: any) -> tuple[str, any] {
        round_trips["n"] = round_trips["n"] + 1;
        raise ClientRequestNotSent(detail="connection refused");
    }
    sv_http.post_stream_aware_sync = fake;
    return original;
}

"""Replace the walker transport with one that always fails to connect."""
def _install_unreachable_walker_transport(round_trips: dict) -> any {
    import from jaclang.server.serving.client { ClientRequestNotSent }
    original = sv_http.request_sync;

    def fake(*args: any, **kwargs: any) -> any {
        round_trips["n"] = round_trips["n"] + 1;
        raise ClientRequestNotSent(detail="connection refused");
    }
    sv_http.request_sync = fake;
    return original;
}
