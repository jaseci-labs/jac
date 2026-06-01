"""Implementation of JacAPIServerLogs - A-05a pod-log query endpoints.

Three endpoints, all admin-auth-gated, all GET. They proxy Loki's HTTP
API and reshape the response into the flat `{ts, level, service,
trace_id, pod, msg, extras}` shape the React LogsPage expects.

Loki URL discovery (checked in order):
  1. LOKI_URL env var (dev / debugging override)
  2. http://<app_name>-loki-service:3100 (K8s service DNS when our
     M-14.a observability stack is deployed in the same namespace)
  3. http://localhost:3100 (last-resort dev fallback)

The handlers parse log line bodies as JSON (M-14.b format) and fall back
to a plain-text shape `{msg: line}` for non-JSON lines (pods that
predate M-14.b, third-party libraries, etc.). UI renders both.
"""
import os;
import json as json_module;
import logging;
import time;
import re;
import from fastapi { Request }
import from fastapi.responses { JSONResponse }
import from jaclang.runtimelib.transport { TransportResponse }
import from jac_scale.jserver.jserver {
    HTTPMethod,
    JEndPoint,
    APIParameter,
    ParameterType
}
import from jac_scale.config_loader { get_scale_config }

# Match the [trace=abc12345] prefix `TraceIdLogFilter` adds to plain
# text logs - lets us recover a short trace id from pre-M-14.b lines.
glob _TRACE_PREFIX_RE: any = re.compile(r"^\[trace=([0-9a-fA-F-]+)\]\s*"),
     logger = logging.getLogger(__name__);


"""Loki base URL with the env override / K8s DNS / localhost fallback.

Resolution order:
  1. `LOKI_URL` env var (full URL; dev / debugging override).
  2. `K8S_APP_NAME` env var (injected by K-track on every microservice
     pod) -> `http://<app>-loki-service:3100`. This is the runtime path
     in K8s; we read it directly because jac.toml's `${K8S_APP_NAME}`
     placeholder isn't expanded by the config loader.
  3. `kubernetes.app_name` from jac.toml, expanded against os.environ
     (it may carry a literal `${VAR}` placeholder). Un-expanded
     placeholders are treated as missing so we never build a bogus
     `http://${K8S_APP_NAME}-loki-service:3100` DNS name.
  4. Last-resort `http://localhost:3100` for dev runs.
"""
def _loki_base_url -> str {
    env = os.getenv("LOKI_URL", "").strip();
    if env {
        return env.rstrip("/");
    }
    app_name = os.getenv("K8S_APP_NAME", "").strip();
    if not app_name {
        try {
            k8s_cfg = get_scale_config().get_kubernetes_config();
            raw = str(k8s_cfg.get("app_name", "") or "").strip();
            expanded = os.path.expandvars(raw);
            if expanded and "${" not in expanded {
                app_name = expanded;
            }
        } except Exception {
            app_name = "";
        }
    }
    if not app_name {
        return "http://localhost:3100";
    }
    return f"http://{app_name}-loki-service:3100";
}


"""Read [plugins.scale.kubernetes].namespace; '' on lookup failure."""
def _app_namespace -> str {
    try {
        return get_scale_config().get_kubernetes_config().get("namespace", "");
    } except Exception {
        return "";
    }
}


"""Configured microservice route keys + '__gateway__' (becomes the
'gateway' service name in K-track). Empty list off-K8s."""
def _microservice_services -> list[str] {
    try {
        ms = get_scale_config().get_microservices_config();
        routes: dict = ms.get("routes", {});
        names: list[str] = list(routes.keys());
        # Order: gateway first, then declared services. Matches what
        # users see in `kubectl get pods` for a microservice deploy.
        return ["gateway"] + sorted(names);
    } except Exception {
        return [];
    }
}


"""Translate a service name into the pod-name regex Loki labels use.
K-track names pod templates `<svc>-deployment-*` (gateway, builder-sv,
jac-coder-sv); applied via `pod=~"<svc>-deployment-.*"` in LogQL."""
def _service_to_pod_regex(service: str) -> str {
    safe = service.lower().replace("_", "-");
    return f"{safe}-deployment-.*";
}


"""Parse a single Loki log line body. Returns the flat shape the UI
expects. Detects M-14.b JSON and pre-M-14.b plain-text + [trace=...]
prefix automatically."""
def _parse_log_body(body: str, pod_labels: dict, ts_nanos: str) -> dict {
    # Default ts: Loki's wall-clock for the line, as RFC3339.
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
        # Raw Loki nanosecond timestamp - kept as a string to avoid
        # JSON-side precision loss (>53 bits) and used by the
        # listing endpoint's `before` cursor for older-page paging.
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
        # Jac doesn't support a bare `pass` in except blocks; we model
        # "ignore the parse failure and fall through" by setting a flag
        # the regular flow below checks for. Cleaner than wrapping the
        # whole post-try body in an else clause.
        parse_ok: bool = False;
        parsed: any = None;
        try {
            parsed = json_module.loads(stripped);
            parse_ok = isinstance(parsed, dict);
        } except (ValueError, TypeError) {
            parse_ok = False;
        }
        if parse_ok {
            # Lift M-14.b stable schema; fall back to Loki labels for
            # any missing key.
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

    # Non-JSON line. Recover trace id from the [trace=...] prefix if
    # present (the TraceIdLogFilter format). Renamed to `trace_match`
    # because `match` is a Jac keyword.
    trace_match = _TRACE_PREFIX_RE.match(body);
    if trace_match {
        out["trace_id"] = trace_match.group(1);
    }
    return out;
}


"""Build a LogQL `query_range` selector. Always namespace-scoped to
avoid all-cluster firehose; adds optional service/level/search filters.
"""
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

    # Pipeline stages: parse JSON first so | level / trace_id are
    # available as label-filters (M-14.b labels lift service + level
    # to Loki labels, so we use label-match for level; trace_id is a
    # parsed field).
    pipeline: list[str] = [];
    if level {
        # Level may be a Loki label (post-M-14.b) OR only inside JSON
        # body (pre-M-14.b). Match both with a regex search.
        escaped = level.upper().replace('"', '\\"');
        pipeline.append(f'|~ "\\"level\\":\\"{escaped}\\"|{escaped}"');
    }
    if trace_id {
        # The K-12 trace id is exactly 8 hex chars for the short form
        # we put in the [trace=...] prefix; full UUID elsewhere. Match
        # both shapes. The literal brackets need `\\[` / `\\]` in the
        # LogQL string so the parser unescapes them to `\[` / `\]` for
        # the regex engine - a bare `\[` is rejected as "invalid char
        # escape" by Go's strconv.Unquote inside Loki's parser.
        # Backslashes are doubled first so quotes inserted next don't
        # get re-doubled (replace order matters here).
        escaped_tid = trace_id.replace("\\", "\\\\").replace('"', '\\"');
        pipeline.append(
            f'|~ "trace_id\\":\\"{escaped_tid}|\\\\[trace={escaped_tid[:8]}\\\\]"'
        );
    }
    if search {
        # Free-text contains-match. `|=` is case-sensitive substring.
        # Backslashes MUST be doubled before quotes are escaped,
        # otherwise the `\"` we just inserted gets re-mangled into
        # `\\"` which delivers a stray backslash to the substring
        # match.
        escaped_search = search.replace("\\", "\\\\").replace('"', '\\"');
        pipeline.append(f'|= "{escaped_search}"');
    }

    if pipeline {
        return selector + " " + " ".join(pipeline);
    }
    return selector;
}


"""HTTP GET to Loki with a short timeout, returning the parsed JSON
body. Raises ConnectionError on transport failure for the caller to
turn into a 502 response."""
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


"""Flatten a Loki query_range response into the UI-shaped log line list.

`ascending=True` (default) sorts oldest-first so trace timelines render
in causal order in the React component. `ascending=False` sorts
newest-first, which is what the main /admin/logs listing wants (matches
`kubectl logs --tail`'s feel; users expect the most recent line at the
top of the panel).
"""
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
    # Sort by the raw nanosecond ts (string-compare is safe: both
    # sides are zero-padded same-length nanosecond integers from Loki).
    out.sort(key=lambda line : line.get("ts_ns", ""), reverse=not ascending);
    return out;
}


"""Register the three log query endpoints. Called once at server start
from JacAPIServerCore._register_endpoints."""
impl JacAPIServerLogs.register_logs_endpoints -> None {
    # GET /admin/logs/services - dropdown options for the UI's service
    # filter. Reads [plugins.scale.microservices.routes]; never touches
    # the cluster. Cheap, no auth deferral on startup races.
    async def services_handler(request: Request) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get("http_status", 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
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
                "Microservices declared in [plugins.scale.microservices.routes] "
                "+ 'gateway'. Used by the admin LogsPage service filter."
            )
        )
    );

    # GET /admin/logs - paginated query (LogQL query_range under the
    # hood). Query params: service, level, search, trace, since
    # (default 15m), limit (default 200, max 1000).
    async def query_handler(request: Request) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get("http_status", 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
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
        # Loki rejects limits over its `max_entries_limit_per_query`
        # (default 5000); cap at 1000 to keep responses fast.
        if limit < 1 {
            limit = 1;
        }
        if limit > 1000 {
            limit = 1000;
        }

        # Translate `since` into ns timestamps. Supports m/h/d suffix
        # via Loki's relative-time syntax; we compute it server-side
        # so we control the window.
        now_ns = int(time.time() * 1_000_000_000);
        unit = since[-1] if since else "m";
        try {
            magnitude = int(since[:-1]) if len(since) > 1 else 15;
        } except (ValueError, TypeError) {
            magnitude = 15;
        }
        multiplier_s = {"s": 1, "m": 60, "h": 3600, "d": 86400}.get(unit, 60);
        start_ns = now_ns - (magnitude * multiplier_s * 1_000_000_000);

        # `before` is the cursor for "load older": a nanosecond ts
        # (the oldest entry's ts_ns from the previous page). We
        # subtract 1 so Loki excludes the boundary entry, otherwise
        # the same line would re-appear at the top of the next page.
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

        # Listing wants newest-first - matches `kubectl logs --tail` UX
        # so the latest line sits at the top of the panel.
        lines = _flatten_loki_response(payload, ascending=False);
        # Cursor for the next page: the oldest (last) entry's ts_ns.
        # `null` when the page is short of `limit` so the UI hides
        # the "Load older" button.
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

    # GET /admin/logs/trace/{trace_id} - all lines for a single trace.
    # Uses a wider time window (24h) because trace_ids often surface
    # in incident reports hours after the request.
    async def trace_handler(request: Request, trace_id: str) -> JSONResponse {
        auth_error = self.require_admin(request.headers.get("Authorization"));
        if auth_error {
            return JSONResponse(
                status_code=auth_error.meta.extra.get("http_status", 403),
                content={"ok": False, "error": {"message": "Unauthorized"}}
            );
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
