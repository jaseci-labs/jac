import logging;
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry
}

glob _rt_logger = logging.getLogger(__name__),
     _SPEC_PROBE_TIMEOUT_SECONDS: float = 1.0;


def literal_prefix(template: str) -> str {
    kept: list[str] = [];
    for segment in template.strip("/").split("/") {
        if not segment or "{" in segment or "*" in segment {
            break;
        }
        kept.append(segment);
    }
    if not kept {
        return "";
    }
    return "/" + "/".join(kept);
}


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
) -> int {
    import asyncio;
    import from jaclang.scale.runtime.gateway.openapi_agg {
        fetch_service_spec,
        SpecFetch
    }

    due: list[tuple[str, ServiceEntry]] = [
        (name, `entry)
        for (name, `entry) in registry.entries.items()
        if `entry.is_routable() and table.spec_due(`entry, now, max_age)
    ];
    if not due {
        return 0;
    }
    answers: dict[str, SpecFetch] = {};

    async def ask(name: str, service_entry: ServiceEntry) {
        answers[name] = await fetch_service_spec(
            service_entry, timeout=_SPEC_PROBE_TIMEOUT_SECONDS
        );
    }
    await asyncio.gather(
        *[ask(name, service_entry) for (name, service_entry) in due],
        return_exceptions=True
    );

    for (name, `entry) in due {
        got: SpecFetch | None = answers.get(name);
        if got is None or not got.answered() {
            continue;
        }
        table.mark_spec_seen(`entry, now);
        if got.doc is None {
            table.unlearn(name);
            _rt_logger.warning(
                f"service '{name}' publishes no readable /openapi.json "
                f"(HTTP {got.status}); its routes cannot be learned, so its "
                f"walkers are reached by discovery instead of ownership"
            );
            continue;
        }
        clashes = table.learn(name, list((got.doc.get("paths") or {}).keys()));
        if clashes {
            _rt_logger.warning(
                f"service '{name}' declares {clashes}, already claimed by another "
                f"service; reach them under '{`entry.prefix}' instead"
            );
        }
    }
    return len(due);
}
