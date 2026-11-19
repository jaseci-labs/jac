obj ServiceTransport {
    def call_function(
        service: str,
        name: str,
        payload: dict[str, any],
        headers: dict[str, str] | None = None
    ) -> any;

    def call_walker(
        service: str,
        name: str,
        payload: dict[str, any],
        stub_cls: any = None,
        headers: dict[str, str] | None = None
    ) -> any;
}


obj HttpTransport(ServiceTransport) {
    def call_function(
        service: str,
        name: str,
        payload: dict[str, any],
        headers: dict[str, str] | None = None
    ) -> any;

    def call_walker(
        service: str,
        name: str,
        payload: dict[str, any],
        stub_cls: any = None,
        headers: dict[str, str] | None = None
    ) -> any;
}


glob _HTTP_TRANSPORT: HttpTransport = HttpTransport();


def http_transport -> HttpTransport;
