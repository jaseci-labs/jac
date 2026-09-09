import logging;
import from jaclang.scale.runtime.gateway.service_registry {
    ServiceRegistry,
    ServiceEntry
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

obj SpecFetch {
    has status: int = 0,
        doc: dict | None = None;

    def answered -> bool;
}


impl SpecFetch.answered -> bool {
    return self.status > 0 and self.status < 500;
}


async def fetch_service_spec(
    service_entry: ServiceEntry, timeout: float = 5.0
) -> SpecFetch {
    import json;
    import from jaclang.scale.runtime.transport.http_forward { raw_forward }

    result = await raw_forward(
        "GET", f"{service_entry.url}/openapi.json", {}, b"", timeout=int(timeout)
    );
    if result is None {
        return SpecFetch();
    }
    (status, _headers, body) = result;
    if status != 200 {
        return SpecFetch(status=status);
    }
    try {
        doc = json.loads(body.decode("utf-8"));
    } except Exception as e {
        _agg_logger.warning(f"openapi: unreadable spec from {service_entry.name}: {e}");
        return SpecFetch(status=status);
    }
    return SpecFetch(status=status, doc=doc if isinstance(doc, dict) else None);
}


async def aggregate_openapi(registry: ServiceRegistry) -> dict {
    import asyncio;

    candidates: list[tuple[str, ServiceEntry]] = [
        (name, `entry)
        for (name, `entry) in registry.entries.items()
        if `entry.is_routable()
    ];
    answers: dict[str, SpecFetch] = {};

    async def ask(name: str, service_entry: ServiceEntry) {
        try {
            answers[name] = await fetch_service_spec(service_entry);
        } except BaseException as task_err {
            _agg_logger.warning(f"openapi aggregate: {name} failed: {task_err}");
        }
    }
    await asyncio.gather(
        *[ask(name, service_entry) for (name, service_entry) in candidates],
        return_exceptions=True
    );

    merged_paths: dict = {};
    merged_schemas: dict = {};
    for (name, `entry) in candidates {
        got: SpecFetch | None = answers.get(name);
        doc: any = got.doc if got is not None else None;
        if not isinstance(doc, dict) {
            _agg_logger.warning(f"openapi aggregate: skipping {name}");
            continue;
        }

        raw_paths = doc.get("paths");
        paths: dict = raw_paths if isinstance(raw_paths, dict) else {};
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

        raw_comps = doc.get("components");
        comps: dict = raw_comps if isinstance(raw_comps, dict) else {};
        raw_schemas = comps.get("schemas");
        schemas: dict = raw_schemas if isinstance(raw_schemas, dict) else {};
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
            "title": "Jac Gateway",
            "version": "1.0.0",
            "description": "Aggregated OpenAPI across every healthy app in the fleet."
        },
        "paths": merged_paths,
        "components": {"schemas": merged_schemas}
    };
}
