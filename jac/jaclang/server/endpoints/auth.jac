import logging;

import traceback;

glob logger: logging.Logger = logging.getLogger('jaclang.serve');


def fail(
    code: str,
    message: str,
    status: int,
    extra: (dict[str, any] | None) = None,
    details: (dict[str, any] | None) = None
) -> TransportResponse;


def refused(
    result: dict[str, any], fallback: str, statuses: (dict[str, int] | None) = None
) -> TransportResponse;


def throttled(retry: int, what: str) -> TransportResponse;


def ok(
    data: dict[str, any], status: int = 200, extra: (dict[str, any] | None) = None
) -> TransportResponse;


def registration_limit(
    request: Request, scope: str, cap: int, seconds: int
) -> TransportResponse | None;

def register_auth_endpoints(server: EndpointHost);


def register_mail_endpoints(server: EndpointHost);
