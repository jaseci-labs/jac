import logging;

glob _rt_logger = logging.getLogger(__name__),
     _SPEC_PROBE_TIMEOUT_SECONDS: float = 1.0;


def literal_prefix(template: str) -> str;


obj ServiceRouteTable {
    has _owner_of: dict[str, str] = {},
        _by_length: list[tuple[str, str]] = [],
        _learned: set[str] = set(),
        _spec_seen: dict[str, tuple[str, str, float]] = {};

    def learn(service_name: str, templates: list[str]) -> list[str];
    def forget(service_name: str) -> None;
    def owner(path: str) -> str;
    def prefixes -> dict[str, str];
    def is_learned(service_name: str) -> bool;
    def spec_due(service_entry: ServiceEntry, now: float, max_age: float) -> bool;
    def mark_spec_seen(service_entry: ServiceEntry, now: float) -> None;
    def unlearn(service_name: str) -> None;
    def _reindex -> None;
}


async def learn_service_routes(
    registry: ServiceRegistry, table: ServiceRouteTable, now: float, max_age: float
) -> int;
