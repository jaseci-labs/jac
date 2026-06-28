import logging;
import from jac_scale.runtime.gateway.service_registry {
    ServiceRegistry,
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

async def aggregate_openapi(registry: ServiceRegistry) -> dict {
    import json;
    import urllib.request;
    import from urllib.error { URLError }

    merged_paths: dict = {};
    merged_schemas: dict = {};

    for (name, entry) in registry.entries.items() {
        if entry.status not in (ServiceStatus.HEALTHY, ServiceStatus.STARTING) {
            continue;
        }
        if not entry.url {
            continue;
        }
        try {
            with urllib.request.urlopen(
                f"{entry.url}/openapi.json", timeout=5.0
            ) as resp {
                status_code: int = getattr(resp, "status", 0);
                if status_code != 200 {
                    continue;
                }
                body: bytes = resp.read();
                doc: dict = json.loads(body.decode("utf-8"));
            }
        } except URLError as e {
            _agg_logger.warning(f"openapi aggregate: skipping {name}: {e}");
            continue;
        } except Exception as e {
            _agg_logger.warning(f"openapi aggregate: skipping {name}: {e}");
            continue;
        }

        paths: dict = doc.get("paths") or {};
        merged_paths.update(_prefixed_paths(paths, entry.prefix));

        comps: dict = doc.get("components") or {};
        schemas: dict = comps.get("schemas") or {};
        for (schema_name, schema_def) in schemas.items() {
            if schema_name not in merged_schemas {
                merged_schemas[schema_name] = schema_def;
            }
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

def _empty_openapi -> dict {
    return {
        "openapi": "3.0.2",
        "info": {
            "title": "Jac Microservice Gateway",
            "version": "1.0.0",
            "description": "Aggregated OpenAPI (no services reachable)."
        },
        "paths": {
            "/health": {
                "get": {
                    "summary": "Gateway aggregated health status",
                    "tags": ["gateway"],
                    "responses": {"200": {"description": "healthy"}}
                }
            }
        },
        "components": {"schemas": {}}
    };
}
