import os;
import logging;
import time;
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jaclang.scale.jserver.jserver {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.admin.service_urls { service_base_url }

glob logger = logging.getLogger(__name__);


def _tempo_base_url -> str {
    return service_base_url("TEMPO_URL", "tempo-service", 3200);
}


def _trace_services -> list[str] {
    try {
        ms = get_scale_config().get_microservices_config();
        routes: dict = ms.get("routes", {});
        names: list[str] = list(routes.keys());
        return ["gateway"] + sorted(names);
    } except Exception {
        return [];
    }
}


def _normalize_trace_id(raw: str) -> str {
    hex_str = (raw or "").replace("-", "").strip().lower();
    if not hex_str {
        return "";
    }
    try {
        int(hex_str, 16);
    } except ValueError {
        return "";
    }
    return hex_str;
}


def _build_traceql(service: str, status: str, min_duration_ms: int) -> str {
    clauses: list[str] = [];
    if service {
        safe = service.replace("\"", "");
        clauses.append(f"resource.service.name = \"{safe}\"");
    }
    if status == "error" {
        clauses.append("status = error");
    }
    if min_duration_ms > 0 {
        clauses.append(f"duration > {min_duration_ms}ms");
    }
    if not clauses {
        return "{ }";
    }
    return "{ " + " && ".join(clauses) + " }";
}


async def _tempo_request(path: str, params: dict, accept_json: bool = False) -> dict {
    import httpx;
    base = _tempo_base_url();
    url = base + path;
    headers: dict = {};
    if accept_json {
        headers["Accept"] = "application/json";
    }
    try {
        async with httpx.AsyncClient(timeout=httpx.Timeout(8.0, connect=3.0)) as cl {
            resp = await cl.get(url, params=params, headers=headers);
            resp.raise_for_status();
            return resp.json();
        }
    } except httpx.TimeoutException as e {
        raise ConnectionError(f"Tempo timed out: {e}");
    } except httpx.HTTPStatusError as e {
        raise ConnectionError(f"Tempo returned {e.response.status_code}");
    } except httpx.RequestError as e {
        raise ConnectionError(f"Tempo unreachable: {e}");
    }
}


def _otlp_value(value: dict) -> any {
    if "stringValue" in value {
        return value["stringValue"];
    }
    if "intValue" in value {
        return value["intValue"];
    }
    if "boolValue" in value {
        return value["boolValue"];
    }
    if "doubleValue" in value {
        return value["doubleValue"];
    }
    return "";
}


def _otlp_attrs(attrs: list) -> dict {
    out: dict = {};
    for a in (attrs or []) {
        k = a.get("key", "");
        if k {
            out[k] = _otlp_value(a.get("value", {}));
        }
    }
    return out;
}


def _flatten_tempo_trace(payload: dict) -> dict {
    spans: list[dict] = [];
    min_start: int = 0;
    max_end: int = 0;
    batches = payload.get("batches", []) or [];
    for batch in batches {
        resource = batch.get("resource", {}) or {};
        res_attrs = _otlp_attrs(resource.get("attributes", []));
        service = str(res_attrs.get("service.name", "unknown"));
        scope_spans = batch.get("scopeSpans", []) or [];
        for scope in scope_spans {
            for span in (scope.get("spans", []) or []) {
                start_ns = int(span.get("startTimeUnixNano", 0) or 0);
                end_ns = int(span.get("endTimeUnixNano", 0) or 0);
                if start_ns and (min_start == 0 or start_ns < min_start) {
                    min_start = start_ns;
                }
                if end_ns > max_end {
                    max_end = end_ns;
                }
                status = span.get("status", {}) or {};
                spans.append(
                    {
                        "span_id": span.get("spanId", ""),
                        "parent_span_id": span.get("parentSpanId", ""),
                        "name": span.get("name", ""),
                        "service": service,
                        "kind": span.get("kind", ""),
                        "start_ns": start_ns,
                        "duration_ms": (end_ns - start_ns) / 1_000_000.0
                            if end_ns >= start_ns
                            else 0,
                        "status": str(status.get("code", "")),
                        "attributes": _otlp_attrs(span.get("attributes", []))
                    }
                );
            }
        }
    }

    spans.sort(key=lambda s : s.get("start_ns", 0));
    total_ms = (max_end - min_start) / 1_000_000.0 if (max_end and min_start) else 0;
    return {
        "spans": spans,
        "count": len(spans),
        "start_ns": min_start,
        "total_ms": total_ms
    };
}


impl JacAPIServerTraces.register_traces_endpoints -> None {
    async def services_handler(request: Request) -> JSONResponse {
        guard = self.require_admin_json(request.headers.get("Authorization"));
        if guard {
            return guard;
        }
        return JSONResponse(
            content={"ok": True, "data": {"services": _trace_services()}}
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/traces/services",
            callback=services_handler,
            parameters=[],
            response_model=None,
            tags=["Traces"],
            summary="Service dropdown options",
            description=(
                "Microservices declared in [scale.microservices.routes] "
                "+ 'gateway'. Used by the admin TracesPage service filter."
            )
        )
    );

    async def search_handler(request: Request) -> JSONResponse {
        guard = self.require_admin_json(request.headers.get("Authorization"));
        if guard {
            return guard;
        }
        qp = request.query_params;
        service = (qp.get("service") or "").strip();
        status = (qp.get("status") or "").strip();
        since = (qp.get("since") or "1h").strip();
        try {
            min_dur = int(qp.get("min_duration_ms", "0"));
        } except (ValueError, TypeError) {
            min_dur = 0;
        }
        try {
            limit = int(qp.get("limit", "20"));
        } except (ValueError, TypeError) {
            limit = 20;
        }
        if limit < 1 {
            limit = 1;
        }
        if limit > 100 {
            limit = 100;
        }

        now_s = int(time.time());
        unit = since[-1] if since else "h";
        try {
            magnitude = int(since[:-1]) if len(since) > 1 else 1;
        } except (ValueError, TypeError) {
            magnitude = 1;
        }
        multiplier_s = {"s": 1, "m": 60, "h": 3600, "d": 86400}.get(unit, 3600);
        start_s = now_s - (magnitude * multiplier_s);

        traceql = _build_traceql(service, status, min_dur);
        try {
            payload = await _tempo_request(
                "/api/search",
                {
                    "q": traceql,
                    "limit": str(limit),
                    "start": str(start_s),
                    "end": str(now_s)
                }
            );
        } except ConnectionError as e {
            logger.warning(f"Tempo search failed: {e}");
            return JSONResponse(
                status_code=502,
                content={
                    "ok": False,
                    "error": {"message": "Trace backend unavailable", "detail": str(e)}
                }
            );
        }

        raw_traces = payload.get("traces", []) or [];
        traces: list[dict] = [];
        for t in raw_traces {
            traces.append(
                {
                    "trace_id": t.get("traceID", ""),
                    "root_service": t.get("rootServiceName", ""),
                    "root_name": t.get("rootTraceName", ""),
                    "start_ns": int(t.get("startTimeUnixNano", 0) or 0),
                    "duration_ms": int(t.get("durationMs", 0) or 0)
                }
            );
        }

        traces.sort(key=lambda x : x.get("start_ns", 0), reverse=True);
        return JSONResponse(
            content={
                "ok": True,
                "data": {"traces": traces, "count": len(traces), "query": traceql}
            }
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/traces",
            callback=search_handler,
            parameters=[],
            response_model=None,
            tags=["Traces"],
            summary="TraceQL search",
            description=(
                "Query params: service, status (error), min_duration_ms, "
                "since (1h/30m/2d), limit (default 20, max 100). Returns a "
                "list of matching traces (id, root service/name, duration)."
            )
        )
    );

    async def trace_handler(request: Request, trace_id: str) -> JSONResponse {
        guard = self.require_admin_json(request.headers.get("Authorization"));
        if guard {
            return guard;
        }
        norm = _normalize_trace_id(trace_id);
        if not norm {
            return JSONResponse(
                status_code=400,
                content={"ok": False, "error": {"message": "Invalid trace id"}}
            );
        }
        try {
            payload = await _tempo_request(f"/api/traces/{norm}", {}, accept_json=True);
        } except ConnectionError as e {
            logger.warning(f"Tempo trace fetch failed: {e}");
            return JSONResponse(
                status_code=502,
                content={
                    "ok": False,
                    "error": {"message": "Trace backend unavailable", "detail": str(e)}
                }
            );
        }
        flat = _flatten_tempo_trace(payload);
        flat["trace_id"] = norm;
        return JSONResponse(content={"ok": True, "data": flat});
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/traces/{trace_id}",
            callback=trace_handler,
            parameters=[
                APIParameter(
                    name="trace_id",
                    data_type="string",
                    required=True,
                    default=None,
                    description="Trace id (dashed UUID or 32-hex Tempo form)",
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=["Traces"],
            summary="One trace's spans (flame graph)",
            description=(
                "Returns the trace's spans flattened to {span_id, "
                "parent_span_id, name, service, start_ns, duration_ms, "
                "status, attributes} plus the trace start + total duration - "
                "the data the React waterfall needs."
            )
        )
    );

    logger.info("Trace query endpoints registered: /admin/traces/{,services,{id}}");
}
