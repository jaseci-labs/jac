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


def _member_key(service: str, name: str) -> str;


obj InProcessTransport(ServiceTransport) {
    has _functions: dict[str, any] = {},
        _walkers: dict[str, any] = {};

    def register_function(service: str, name: str, handler: any);
    def register_walker(service: str, name: str, handler: any);
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
