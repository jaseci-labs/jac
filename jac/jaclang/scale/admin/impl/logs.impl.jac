import os;
import json as json_module;
import logging;
import time;
import re;
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jaclang.runtimelib.transport { TransportResponse }
import from jaclang.scale.jserver.jserver {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}
import from jaclang.scale.config.config_loader { get_scale_config }
import from jaclang.scale.admin.service_urls { service_base_url }

glob _TRACE_PREFIX_RE: any = re.compile(r"^\[trace=([0-9a-fA-F-]+)\]\s*"),
     logger = logging.getLogger(__name__);


def _loki_base_url -> str {
    return service_base_url("LOKI_URL", "loki-service", 3100);
}


def _app_namespace -> str {
    try {
        return get_scale_config().get_kubernetes_config().get("namespace", "");
    } except Exception {
        return "";
    }
}


def _app_name -> str {
    try {
        return get_scale_config().get_kubernetes_config().get("app_name", "");
    } except Exception {
        return "";
    }
}


def _is_microservice_mode -> bool {
    try {
        routes: dict = get_scale_config().get_microservices_config().get("routes", {});
        return bool(routes);
    } except Exception {
        return False;
    }
}


def _services_for_mode(microservice: bool, routes: dict, app_name: str) -> list[str] {
    if microservice {
        names: list[str] = list(routes.keys());
        return ["gateway"] + sorted(names);
    }
    return [app_name] if app_name else [];
}


def _microservice_services -> list[str] {
    try {
        ms = get_scale_config().get_microservices_config();
        routes: dict = ms.get("routes", {});
        return _services_for_mode(bool(routes), routes, _app_name());
    } except Exception {
        return [];
    }
}


def _service_to_pod_regex_for_mode(service: str, microservice: bool) -> str {
    safe = service.lower().replace("_", "-");
    if microservice {
        return f"{safe}-deployment-.*";
    }
    return f"{safe}-.*";
}


def _service_to_pod_regex(service: str) -> str {
    return _service_to_pod_regex_for_mode(service, _is_microservice_mode());
}


def _parse_log_body(body: str, pod_labels: dict, ts_nanos: str) -> dict {
    try {
        ns = int(ts_nanos);
        ts_iso = time.strftime("%Y-%m-%dT%H:%M:%S", time.gmtime(ns / 1_000_000_000)) + f".{(
            ns % 1_000_000_000
        ):09d}Z";
    } except (ValueError, TypeError) {
        ts_iso = "";
    }

    out: dict = {
        "ts": ts_iso,
        "ts_ns": ts_nanos,
        "level": pod_labels.get("level") or "INFO",
        "service": (
            pod_labels.get("service")
            or pod_labels.get("container")
            or pod_labels.get("pod", "")
        ),
        "trace_id": None,
        "pod": pod_labels.get("pod", ""),
        "msg": body,
        "extras": {}
    };

    stripped = body.lstrip();
    if stripped.startswith("{") and stripped.endswith("}") {
        parse_ok: bool = False;
        parsed: any = None;
        try {
            parsed = json_module.loads(stripped);
            parse_ok = isinstance(parsed, dict);
        } except (ValueError, TypeError) {
            parse_ok = False;
        }
        if parse_ok {
            out["ts"] = parsed.get("ts") or ts_iso;
            out["level"] = parsed.get("level") or out["level"];
            out["service"] = parsed.get("service") or out["service"];
            out["trace_id"] = parsed.get("trace_id");
            out["msg"] = parsed.get("msg") or body;
            out["extras"] = parsed.get("extras") or {};
            if parsed.get("exc") {
                out["extras"]["exc"] = parsed["exc"];
            }
            return out;
        }
    }

    trace_match = _TRACE_PREFIX_RE.match(body);
    if trace_match {
        out["trace_id"] = trace_match.group(1);
    }
    return out;
}


def _build_logql(
    namespace: str, service: str, level: str, search: str, trace_id: str
) -> str {
    parts: list[str] = [];
    if namespace {
        parts.append(f'namespace="{namespace}"');
    }
    if service {
        parts.append(f'pod=~"{_service_to_pod_regex(service)}"');
    }
    selector = "{" + ",".join(parts) + "}" if parts else "{namespace=~\".+\"}";

    pipeline: list[str] = [];
    if level {
        escaped = level.upper().replace('"', '\\"');
        pipeline.append(f'|~ "\\"level\\":\\"{escaped}\\"|{escaped}"');
    }
    if trace_id {
        escaped_tid = trace_id.replace("\\", "\\\\").replace('"', '\\"');
        pipeline.append(
            f'|~ "trace_id\\":\\"{escaped_tid}|\\\\[trace={escaped_tid[:8]}\\\\]"'
        );
    }
    if search {
        escaped_search = search.replace("\\", "\\\\").replace('"', '\\"');
        pipeline.append(f'|= "{escaped_search}"');
    }

    if pipeline {
        return selector + " " + " ".join(pipeline);
    }
    return selector;
}


async def _loki_request(path: str, params: dict) -> dict {
    import httpx;
    base = _loki_base_url();
    url = f"{base}{path}";
    try {
        async with httpx.AsyncClient(
            timeout=httpx.Timeout(8.0, connect=3.0)
        ) as client {
            response = await client.get(url, params=params);
            response.raise_for_status();
            return response.json();
        }
    } except httpx.TimeoutException as e {
        raise ConnectionError(f"Loki timeout at {url}: {e}");
    } except httpx.RequestError as e {
        raise ConnectionError(f"Loki request failed at {url}: {e}");
    } except httpx.HTTPStatusError as e {
        body = e.response.text[:200] if e.response else "";
        raise ConnectionError(
            f"Loki returned HTTP {e.response.status_code} at {url}: {body}"
        );
    }
}


def _flatten_loki_response(payload: dict, ascending: bool = True) -> list[dict] {
    out: list[dict] = [];
    data = payload.get("data") or {};
    for stream in (data.get("result") or []) {
        labels: dict = stream.get("stream") or {};
        for entry in (stream.get("values") or []) {
            if len(entry) < 2 {
                continue;
            }
            ts_nanos = str(entry[0]);
            body = str(entry[1]);
            out.append(_parse_log_body(body, labels, ts_nanos));
        }
    }

    out.sort(key=lambda (line) { line.get("ts_ns", ""); }, reverse=not ascending);
    return out;
}


impl JacAPIServerLogs.register_logs_endpoints -> None {
    async def services_handler(request: Request) -> JSONResponse {
        guard = self.require_admin_json(request.headers.get("Authorization"));
        if guard {
            return guard;
        }
        return JSONResponse(
            content={"ok": True, "data": {"services": _microservice_services()}}
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/logs/services",
            callback=services_handler,
            parameters=[],
            response_model=None,
            tags=["Logs"],
            summary="Service dropdown options",
            description=(
                "Microservices declared in [scale.microservices.routes] "
                "+ 'gateway'. Used by the admin LogsPage service filter."
            )
        )
    );

    async def query_handler(request: Request) -> JSONResponse {
        guard = self.require_admin_json(request.headers.get("Authorization"));
        if guard {
            return guard;
        }
        qp = request.query_params;
        service = (qp.get("service") or "").strip();
        level = (qp.get("level") or "").strip();
        search = (qp.get("search") or "").strip();
        trace = (qp.get("trace") or "").strip();
        since = (qp.get("since") or "15m").strip();

        try {
            limit = int(qp.get("limit", "200"));
        } except (ValueError, TypeError) {
            limit = 200;
        }

        if limit < 1 {
            limit = 1;
        }
        if limit > 1000 {
            limit = 1000;
        }

        now_ns = int(time.time() * 1_000_000_000);
        unit = since[-1] if since else "m";
        try {
            magnitude = int(since[:-1]) if len(since) > 1 else 15;
        } except (ValueError, TypeError) {
            magnitude = 15;
        }
        multiplier_s = {"s": 1, "m": 60, "h": 3600, "d": 86400}.get(unit, 60);
        start_ns = now_ns - (magnitude * multiplier_s * 1_000_000_000);

        before = (qp.get("before") or "").strip();
        end_ns = now_ns;
        if before {
            try {
                end_ns = int(before) - 1;
            } except (ValueError, TypeError) {
                end_ns = now_ns;
            }
        }

        namespace = _app_namespace();
        logql = _build_logql(namespace, service, level, search, trace);

        try {
            payload = await _loki_request(
                "/loki/api/v1/query_range",
                {
                    "query": logql,
                    "limit": str(limit),
                    "start": str(start_ns),
                    "end": str(end_ns),
                    "direction": "backward"
                }
            );
        } except ConnectionError as e {
            logger.warning(f"Loki query failed: {e}");
            return JSONResponse(
                status_code=502,
                content={
                    "ok": False,
                    "error": {"message": "Log backend unavailable", "detail": str(e)}
                }
            );
        }

        lines = _flatten_loki_response(payload, ascending=False);

        next_before = None;
        if len(lines) >= limit and lines {
            next_before = lines[-1].get("ts_ns");
        }
        return JSONResponse(
            content={
                "ok": True,
                "data": {
                    "lines": lines,
                    "count": len(lines),
                    "query": logql,
                    "namespace": namespace,
                    "next_before": next_before
                }
            }
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/logs",
            callback=query_handler,
            parameters=[],
            response_model=None,
            tags=["Logs"],
            summary="Paginated log query",
            description=(
                "Query params: service, level, search, trace, since (15m/1h/2d), "
                "limit (default 200, max 1000), before (nanosecond ts cursor "
                "from the previous page's `next_before`). Returns lines sorted "
                "newest-first; cursor-paginate by passing the response's "
                "`next_before` back as `before` on the next call."
            )
        )
    );

    async def trace_handler(request: Request, trace_id: str) -> JSONResponse {
        guard = self.require_admin_json(request.headers.get("Authorization"));
        if guard {
            return guard;
        }

        now_ns = int(time.time() * 1_000_000_000);
        start_ns = now_ns - (24 * 3600 * 1_000_000_000);
        namespace = _app_namespace();
        logql = _build_logql(namespace, "", "", "", trace_id);

        try {
            payload = await _loki_request(
                "/loki/api/v1/query_range",
                {
                    "query": logql,
                    "limit": "500",
                    "start": str(start_ns),
                    "end": str(now_ns),
                    "direction": "forward"
                }
            );
        } except ConnectionError as e {
            logger.warning(f"Loki trace query failed: {e}");
            return JSONResponse(
                status_code=502,
                content={
                    "ok": False,
                    "error": {"message": "Log backend unavailable", "detail": str(e)}
                }
            );
        }

        lines = _flatten_loki_response(payload);
        services_touched = sorted(
            {
                line["service"]
                for line in lines
                if line.get("service")
            }
        );
        first_ts = lines[0]["ts"] if lines else "";
        last_ts = lines[-1]["ts"] if lines else "";

        return JSONResponse(
            content={
                "ok": True,
                "data": {
                    "lines": lines,
                    "count": len(lines),
                    "trace_id": trace_id,
                    "services_touched": services_touched,
                    "first_ts": first_ts,
                    "last_ts": last_ts
                }
            }
        );
    }
    self.server.add_endpoint(
        JEndPoint(
            method=HTTPMethod.GET,
            path="/admin/logs/trace/{trace_id}",
            callback=trace_handler,
            parameters=[
                APIParameter(
                    name="trace_id",
                    data_type="string",
                    required=True,
                    default=None,
                    description="K-12 trace id (full UUID or 8-char short form)",
                    type=ParameterType.PATH
                )
            ],
            response_model=None,
            tags=["Logs"],
            summary="All log lines for one trace",
            description=(
                "Returns every log line in the last 24h matching the given "
                "trace_id, plus the services touched and the first/last "
                "timestamps - the data the React Trace Explorer needs."
            )
        )
    );

    logger.info("Log query endpoints registered: /admin/logs/{,services,trace/{id}}");
}
