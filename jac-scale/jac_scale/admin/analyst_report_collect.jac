"""A-07 Performance Report - APPLICATION-level span aggregation.

Samples recent Tempo traces and aggregates their spans into the per-endpoint
RED + DB-hotspot picture the report is about: "which APIs are having issues,
and which calls are hammering the database." Infra (pods/CPU/mem) lives in the
Workloads view (#6186), not here.

Method: search Tempo for recent traces (excluding operator/admin traffic),
fetch + flatten each, then aggregate:
  - per ENDPOINT (root span name): calls, p95/avg latency, error rate, and how
    much DB work each request does (db_calls_per_req, db_ms_per_req).
  - per (endpoint, DB operation): calls-per-request + time-per-request, with an
    N+1 flag when a single request issues the same DB op many times.

A DB span is any span carrying an OTel `db.system` attribute (covers the O-03
memory-hierarchy spans: db.system=redis/mongodb). Best-effort + async: an
unreachable Tempo yields an empty report. Read-only; no model.
"""
import time;
import logging;
import from jac_scale.admin.analyst_report { ReportHealth, EndpointStat, DbHotspot }
import from jac_scale.admin.analyst_collect { tempo_base_url, flatten_spans }

glob logger = logging.getLogger(__name__);

glob _OP_PREFIXES = ["/admin/", "/metrics", "/healthz", "/readyz", "/livez"];
glob _NPLUSONE_THRESHOLD = 5.0;


"""True if a root trace name is operator/infra traffic (admin UI, the analyst's
own calls, health/metrics probes) - excluded from an app report."""
def is_operational(root_name: str) -> bool {
    n = root_name.lower();
    for p in _OP_PREFIXES {
        if p in n {
            return True;
        }
    }
    return False;
}


"""Index-based percentile of a list of floats (0.0 on empty)."""
def percentile(values: list, pct: float) -> float {
    if not values {
        return 0.0;
    }
    s = sorted(values);
    idx = int(pct * (len(s) - 1));
    return float(s[idx]);
}


"""The trace's root span: the one whose parent is absent or not in the trace."""
def root_span(spans: list) -> dict {
    ids: dict = {};
    for sp in spans {
        ids[str(sp.get("span_id", "") or "")] = True;
    }
    for sp in spans {
        pid = str(sp.get("parent_span_id", "") or "");
        if (not pid) or (pid not in ids) {
            return dict(sp);
        }
    }
    return dict(spans[0]) if spans else {};
}


"""Fetch one trace from Tempo and return its flattened spans ([] on failure)."""
async def fetch_trace_spans(base: str, trace_id: str) -> list {
    import httpx;
    try {
        async with httpx.AsyncClient(timeout=httpx.Timeout(5.0, connect=3.0)) as cl {
            resp = await cl.get(
                base + "/api/traces/" + trace_id,
                headers={"Accept": "application/json"}
            );
            resp.raise_for_status();
            payload = resp.json();
        }
    } except Exception as ex {
        logger.warning(f"analyst report: trace fetch failed for {trace_id}: {ex}");
        return [];
    }
    return flatten_spans(payload);
}


"""Aggregate a sample of recent traces into (health, endpoints, db_hotspots).

`window_s` is the lookback; `sample_limit` caps how many traces are fetched
(each is one Tempo round-trip). `top_n` bounds each output list.
"""
async def collect_app_report(
    window_s: int = 900, sample_limit: int = 20, top_n: int = 10
) -> tuple {
    base = tempo_base_url();
    if base is None {
        return (ReportHealth(status="unknown"), [], []);
    }
    now_s = int(time.time());
    import httpx;
    try {
        async with httpx.AsyncClient(timeout=httpx.Timeout(5.0, connect=3.0)) as cl {
            resp = await cl.get(
                base + "/api/search",
                params={
                    "q": "{ }",
                    "limit": str(sample_limit),
                    "start": str(now_s - window_s),
                    "end": str(now_s)
                }
            );
            resp.raise_for_status();
            search = resp.json();
        }
    } except Exception as ex {
        logger.warning(f"analyst report: Tempo search unavailable: {ex}");
        return (ReportHealth(status="unknown"), [], []);
    }

    ep: dict = {};      # route -> {durs, errs, calls, db_calls, db_ms}
    hot: dict = {};     # "route||op" -> {route, operation, db_system, count, ms}
    sampled = 0;
    for t in (search.get("traces", []) or []) {
        root_name = str(t.get("rootTraceName", "") or "");
        if is_operational(root_name) {
            continue;
        }
        tid = str(t.get("traceID", "") or "");
        if not tid {
            continue;
        }
        spans = await fetch_trace_spans(base, tid);
        if not spans {
            continue;
        }
        sampled += 1;
        rootsp = root_span(spans);
        route = str(rootsp.get("name", "") or root_name or "unknown");
        total_ms = float(rootsp.get("duration_ms", 0) or 0);
        rattrs = rootsp.get("attributes", {}) or {};
        is_err = int(rattrs.get("http.status_code", 0) or 0) >= 500;

        db_count = 0;
        db_ms = 0.0;
        for sp in spans {
            attrs = sp.get("attributes", {}) or {};
            dbsys = str(attrs.get("db.system", "") or "");
            if not dbsys {
                continue;
            }
            spms = float(sp.get("duration_ms", 0) or 0);
            db_count += 1;
            db_ms += spms;
            op = str(sp.get("name", "") or "db op");
            key = route + "||" + op;
            h = hot.get(
                key,
                {"route": route, "operation": op, "db_system": dbsys, "count": 0, "ms": 0.0}
            );
            h["count"] = int(h["count"]) + 1;
            h["ms"] = float(h["ms"]) + spms;
            hot[key] = h;
        }

        agg = ep.get(
            route, {"durs": [], "errs": 0, "calls": 0, "db_calls": 0, "db_ms": 0.0}
        );
        agg["durs"].append(total_ms);
        agg["calls"] = int(agg["calls"]) + 1;
        if is_err {
            agg["errs"] = int(agg["errs"]) + 1;
        }
        agg["db_calls"] = int(agg["db_calls"]) + db_count;
        agg["db_ms"] = float(agg["db_ms"]) + db_ms;
        ep[route] = agg;
    }

    endpoints: list[EndpointStat] = [];
    all_durs: list = [];
    total_calls = 0;
    total_errs = 0;
    for route in ep.keys() {
        agg = ep[route];
        calls = int(agg["calls"]);
        durs = agg["durs"];
        all_durs = all_durs + list(durs);
        total_calls += calls;
        total_errs += int(agg["errs"]);
        endpoints.append(
            EndpointStat(
                route=str(route),
                calls=calls,
                error_rate=(float(agg["errs"]) / calls) if calls else 0.0,
                p95_ms=percentile(durs, 0.95),
                avg_ms=(float(sum(durs)) / len(durs)) if durs else 0.0,
                db_calls_per_req=(float(agg["db_calls"]) / calls) if calls else 0.0,
                db_ms_per_req=(float(agg["db_ms"]) / calls) if calls else 0.0
            )
        );
    }
    endpoints.sort(key=lambda e: any : e.p95_ms, reverse=True);

    hotspots: list[DbHotspot] = [];
    for key in hot.keys() {
        h = hot[key];
        route = str(h["route"]);
        route_calls = int(ep.get(route, {"calls": 1}).get("calls", 1)) or 1;
        cpr = float(h["count"]) / route_calls;
        hotspots.append(
            DbHotspot(
                route=route,
                operation=str(h["operation"]),
                db_system=str(h["db_system"]),
                calls_per_req=cpr,
                ms_per_req=float(h["ms"]) / route_calls,
                n_plus_one=(cpr >= _NPLUSONE_THRESHOLD)
            )
        );
    }
    hotspots.sort(key=lambda d: any : d.ms_per_req, reverse=True);

    overall_p95 = percentile(all_durs, 0.95);
    overall_err = (float(total_errs) / total_calls) if total_calls else 0.0;
    if sampled == 0 {
        status = "unknown";
    } elif overall_err > 0.05 or overall_p95 > 2000.0 {
        status = "Degraded";
    } else {
        status = "Healthy";
    }
    health = ReportHealth(
        status=status,
        sampled_traces=sampled,
        error_rate=overall_err,
        p95_ms=overall_p95
    );
    return (health, endpoints[:top_n], hotspots[:top_n]);
}
