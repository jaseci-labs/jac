import logging;
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry,
    ServiceStatus
}

glob _agg_logger = logging.getLogger(__name__);

def _prefixed_paths(paths: dict, prefix: str) -> dict {
    clean_prefix: str = prefix.rstrip("/");
    result: dict = {};
    for (path, op) in paths.items() {
        path_str: str = str(path);
        if path_str.startswith("/") {
            result[f"{clean_prefix}{path_str}"] = op;
        } else {
            result[f"{clean_prefix}/{path_str}"] = op;
        }
    }
    return result;
}

async def fetch_service_spec(
    service_entry: ServiceEntry, timeout: float = 5.0
) -> dict | None {
    import json;
    import from jaclang.scale.runtime.transport.http_forward { raw_forward }

    result = await raw_forward(
        "GET", f"{service_entry.url}/openapi.json", {}, b"", timeout=int(timeout)
    );
    if result is None {
        return None;
    }
    (status, _headers, body) = result;
    if status != 200 {
        return None;
    }
    try {
        doc = json.loads(body.decode("utf-8"));
    } except Exception as e {
        _agg_logger.warning(f"openapi: unreadable spec from {service_entry.name}: {e}");
        return None;
    }
    return doc if isinstance(doc, dict) else None;
}


async def aggregate_openapi(registry: ServiceRegistry) -> dict {
    import asyncio;

    candidates: list = [
        (name, `entry)
        for (name, `entry) in registry.entries.items()
        if `entry.status in (ServiceStatus.HEALTHY, ServiceStatus.STARTING)
            and `entry.url
    ];
    docs = await asyncio.gather(
        *[fetch_service_spec(`entry) for (_, `entry) in candidates],
        return_exceptions=True
    );

    merged_paths: dict = {};
    merged_schemas: dict = {};
    for ((name, `entry), doc) in zip(candidates, docs) {
        if isinstance(doc, BaseException) {
            _agg_logger.warning(f"openapi aggregate: {name} failed: {doc}");
            continue;
        }
        if doc is None {
            _agg_logger.warning(f"openapi aggregate: skipping {name}");
            continue;
        }

        paths: dict = doc.get("paths") or {};
        for (path, op) in _prefixed_paths(paths, `entry.prefix).items() {
            if path in merged_paths {
                _agg_logger.warning(
                    f"openapi aggregate: path collision on {path}; keeping the "
                    f"first operation seen, dropping {name}'s"
                );
                continue;
            }
            merged_paths[path] = op;
        }

        comps: dict = doc.get("components") or {};
        schemas: dict = comps.get("schemas") or {};
        for (schema_name, schema_def) in schemas.items() {
            if schema_name in merged_schemas {
                if merged_schemas[schema_name] != schema_def {
                    _agg_logger.warning(
                        f"openapi aggregate: schema collision on {schema_name}; "
                        f"keeping the first definition, dropping {name}'s"
                    );
                }
                continue;
            }
            merged_schemas[schema_name] = schema_def;
        }
    }

    merged_paths["/health"] = {
        "get": {
            "summary": "Gateway aggregated health status",
            "tags": ["gateway"],
            "responses": {"200": {"description": "healthy"}}
        }
    };
    merged_paths["/metrics"] = {
        "get": {
            "summary": "Prometheus exposition",
            "tags": ["gateway"],
            "responses": {"200": {"description": "metrics"}}
        }
    };

    return {
        "openapi": "3.0.2",
        "info": {
            "title": "Jac Microservice Gateway",
            "version": "1.0.0",
            "description": "Aggregated OpenAPI across all healthy microservices."
        },
        "paths": merged_paths,
        "components": {"schemas": merged_schemas}
    };
}
