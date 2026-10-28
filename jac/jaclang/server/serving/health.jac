import logging;

glob logger: logging.Logger = logging.getLogger(__name__);


obj ReadinessCheck {
    has name: str,
        probe: Callable[[], bool];
}


def register_health_endpoints(
    app: ServingApp, drain: DrainState, checks: (list[ReadinessCheck] | None) = None
);
