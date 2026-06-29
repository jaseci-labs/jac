obj ServiceTransport {
    def call_function(service: str, name: str, payload: dict[str, any]) -> any {
        raise NotImplementedError(
            "call_function() must be implemented by a ServiceTransport"
        );
    }

    def call_walker(
        service: str, name: str, payload: dict[str, any], stub_cls: any = None
    ) -> any {
        raise NotImplementedError(
            "call_walker() must be implemented by a ServiceTransport"
        );
    }
}


def _member_key(service: str, name: str) -> str {
    return f"{service}:{name}";
}


obj InProcessTransport(ServiceTransport) {
    has _functions: dict[str, any] = {},
        _walkers: dict[str, any] = {};

    def register_function(service: str, name: str, handler: any) {
        self._functions[_member_key(service, name)] = handler;
    }

    def register_walker(service: str, name: str, handler: any) {
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

        return handler(payload);
    }
}


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


glob _HTTP_TRANSPORT: HttpTransport = HttpTransport();


def http_transport -> HttpTransport {
    return _HTTP_TRANSPORT;
}
