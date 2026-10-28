impl ServiceTransport.call_function(
    service: str,
    name: str,
    payload: dict[str, any],
    headers: dict[str, str] | None = None
) -> any {
    raise NotImplementedError(
        "call_function() must be implemented by a ServiceTransport"
    );
}

impl ServiceTransport.call_walker(
    service: str,
    name: str,
    payload: dict[str, any],
    stub_cls: any = None,
    headers: dict[str, str] | None = None
) -> any {
    raise NotImplementedError(
        "call_walker() must be implemented by a ServiceTransport"
    );
}

impl _member_key(service: str, name: str) -> str {
    return f"{service}:{name}";
}

impl InProcessTransport.register_function(service: str, name: str, handler: any) {
    self._functions[_member_key(service, name)] = handler;
}

impl InProcessTransport.register_walker(service: str, name: str, handler: any) {
    self._walkers[_member_key(service, name)] = handler;
}

impl InProcessTransport.call_function(
    service: str,
    name: str,
    payload: dict[str, any],
    headers: dict[str, str] | None = None
) -> any {
    key = _member_key(service, name);
    handler = self._functions.get(key);
    if handler is None {
        raise KeyError(f"no in-process function registered for {key}");
    }
    return handler(payload);
}

impl InProcessTransport.call_walker(
    service: str,
    name: str,
    payload: dict[str, any],
    stub_cls: any = None,
    headers: dict[str, str] | None = None
) -> any {
    key = _member_key(service, name);
    handler = self._walkers.get(key);
    if handler is None {
        raise KeyError(f"no in-process walker registered for {key}");
    }

    return handler(payload);
}

impl HttpTransport.call_function(
    service: str,
    name: str,
    payload: dict[str, any],
    headers: dict[str, str] | None = None
) -> any {
    return service_call(service, name, payload, headers=headers);
}

impl HttpTransport.call_walker(
    service: str,
    name: str,
    payload: dict[str, any],
    stub_cls: any = None,
    headers: dict[str, str] | None = None
) -> any {
    return walker_call(service, name, payload, stub_cls, headers=headers);
}

impl http_transport -> HttpTransport {
    return _HTTP_TRANSPORT;
}
