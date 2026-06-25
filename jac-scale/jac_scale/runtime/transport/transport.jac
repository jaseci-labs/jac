"""ServiceTransport port and the in-process (monolith-collapse) adapter.

A transport invokes a function or spawns a walker on a named service and returns
the result. The blueprint always declares service boundaries; the transport
decides whether crossing one is a direct call (monolith) or a network hop
(microservice). Keeping that decision behind the port is what makes
"works local => works cloud" structural rather than aspirational.
"""


"""Abstract transport contract. `payload` is the already-marshalled call data;
the return value is the target's result. Adapters must be safe to share across
concurrent requests."""
obj ServiceTransport {
    """Invoke function `name` on `service` with `payload` and return its result."""
    def call_function(service: str, name: str, payload: dict[str, any]) -> any {
        raise NotImplementedError("call_function() must be implemented by a ServiceTransport");
    }

    """Spawn walker `name` on `service` with `payload` and return its result.
    `stub_cls`, when given, is the consumer-side stub the result is rehydrated
    into; a network adapter needs it to type the wire envelope, an in-process
    adapter returns the real object and ignores it."""
    def call_walker(
        service: str, name: str, payload: dict[str, any], stub_cls: any = None
    ) -> any {
        raise NotImplementedError("call_walker() must be implemented by a ServiceTransport");
    }
}


"""Compose the registry key for a service member so functions and walkers in the
same service share one namespace per kind."""
def _member_key(service: str, name: str) -> str {
    return f"{service}:{name}";
}


"""In-process transport: dispatches an `sv` call to a locally-registered
callable with no network hop.

This is the collapse that turns the microservice blueprint into a monolith: the
realizer registers every service's functions and walkers here, and a cross-service
call becomes a direct invocation. Because the boundary is still declared (the
call still goes through the transport), expanding to HttpTransport later changes
only the wire, never the app code.
"""
obj InProcessTransport(ServiceTransport) {
    has _functions: dict[str, any] = {};
    has _walkers: dict[str, any] = {};

    """Register the local callable backing function `name` on `service`."""
    def register_function(service: str, name: str, handler: any) -> None {
        self._functions[_member_key(service, name)] = handler;
    }

    """Register the local callable backing walker `name` on `service`."""
    def register_walker(service: str, name: str, handler: any) -> None {
        self._walkers[_member_key(service, name)] = handler;
    }

    def call_function(service: str, name: str, payload: dict[str, any]) -> any {
        key = _member_key(service, name);
        handler = self._functions.get(key);
        if handler is None {
            raise KeyError(f"no in-process function registered for {key}");
        }
        return handler(payload);
    }

    def call_walker(
        service: str, name: str, payload: dict[str, any], stub_cls: any = None
    ) -> any {
        key = _member_key(service, name);
        handler = self._walkers.get(key);
        if handler is None {
            raise KeyError(f"no in-process walker registered for {key}");
        }
        # In-process returns the real walker object; no wire rehydration, so
        # stub_cls is accepted for port-conformance and intentionally unused.
        return handler(payload);
    }
}


"""Network transport: forwards an `sv` call over HTTP to the target service.

Delegates to the rpc layer, which carries the distributed-topology concerns the
in-process adapter has no need for: auth/trace-header forwarding, retry with
exponential backoff, a per-provider circuit breaker, and SSE-aware function
calls. This is the adapter the `sv_service_call` / `sv_walker_call` hooks and the
process gateway use; collapsing to a monolith swaps in `InProcessTransport` at the
same port, so no call site branches on topology.

Stateless, so a single shared instance is safe across concurrent requests (the
breaker/registry state it touches lives in the rpc layer, not on the adapter).
"""
obj HttpTransport(ServiceTransport) {
    def call_function(service: str, name: str, payload: dict[str, any]) -> any {
        import from jac_scale.runtime.rpc.rpc { service_call }
        return service_call(service, name, payload);
    }

    def call_walker(
        service: str, name: str, payload: dict[str, any], stub_cls: any = None
    ) -> any {
        import from jac_scale.runtime.rpc.rpc { walker_call }
        return walker_call(service, name, payload, stub_cls);
    }
}


"""Process-wide HTTP transport singleton. `HttpTransport` is stateless, so the
sv-RPC hooks share one instance rather than constructing a new adapter per call."""
glob _HTTP_TRANSPORT: HttpTransport = HttpTransport();


"""The shared HttpTransport adapter the sv-RPC hooks dispatch through."""
def http_transport() -> HttpTransport {
    return _HTTP_TRANSPORT;
}
