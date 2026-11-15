import logging;

glob logger: logging.Logger = logging.getLogger('jaclang.serve');


def unavailable -> TransportResponse;


def refused(result: dict[str, any], proof_status: int) -> TransportResponse;


def account_label(user: dict[str, any]) -> str;

def register_second_factor_endpoints(server: EndpointHost);
