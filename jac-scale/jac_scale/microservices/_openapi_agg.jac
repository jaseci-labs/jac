"""OpenAPI schema aggregation for the microservice gateway (ROADMAP P9).

Each microservice exposes its own `/openapi.json` via jac-scale's
FastAPI machinery. Individually those are useful only to callers who
already know each service's port. The gateway hides the ports - all
traffic goes through `/api/{service}/...` - so the gateway should
expose ONE merged OpenAPI document that describes the full external
API surface.

Strategy:
  1. For each healthy service in the registry, fetch its raw
     /openapi.json over HTTP (async, parallel).
  2. Rewrite every path by prefixing with the service's gateway route
     prefix, e.g. /function/list_products -> /api/products/function/list_products.
  3. Merge components.schemas across services. Name collisions keep
     the first occurrence (deterministic by iteration order).
  4. Overlay the gateway's own paths (/health, /metrics) so consumers
     see the full surface in one schema.

Failure mode: a service that's unreachable or returns non-JSON is
skipped silently with a warning. The gateway still serves a
document covering the healthy services - partial is better than none.
"""

import logging;
import from typing { Any }
import from jac_scale.microservices.service_registry { ServiceRegistry, ServiceStatus }

glob _agg_logger = logging.getLogger(__name__);

"""Prefix every key in `paths` with `prefix`.

Handles the common service-side convention of paths starting with `/`;
we strip a leading slash from `prefix` before concatenation so the
output is always exactly one slash between prefix and tail.
"""
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

"""Fetch + merge healthy services' OpenAPI schemas into one document.

Returns a complete OpenAPI 3.0.x dict ready to serve at /openapi.json.
If no services are reachable, returns a minimal document with just
the gateway's own paths.
"""
async def aggregate_openapi(registry: ServiceRegistry) -> dict {
    import json;
    import urllib.request;
    import from urllib.error { URLError }

    merged_paths: dict = {};
    merged_schemas: dict = {};

    # Sequential urllib fetch inside the async handler. /openapi.json
    # is a rare admin endpoint (not hit per user request), so a 3-service
    # stack takes ~150ms total and doesn't justify the async-client
    # type-stub pain. If services proliferate, swap to asyncio.gather +
    # thread-executor later.
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

    # Always-present gateway-level paths (not proxied to a service).
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

"""Minimal fallback document when no services are reachable."""
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
