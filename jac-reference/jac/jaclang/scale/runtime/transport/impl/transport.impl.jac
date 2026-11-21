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
