import logging;

glob _agg_logger = logging.getLogger(__name__);

def _prefixed_paths(paths: dict[str, any], prefix: str) -> dict[str, any];

obj SpecFetch {
    has status: int = 0,
        doc: dict[str, any] | None = None;

    def answered -> bool;
}


async def fetch_service_spec(
    service_entry: ServiceEntry, timeout: float = 5.0
) -> SpecFetch;


async def aggregate_openapi(registry: ServiceRegistry) -> dict[str, any];
