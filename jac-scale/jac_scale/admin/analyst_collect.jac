"""A-07 Performance Analyst - the COLLECT stage.

Deterministic, bounded collection from the three observability sources A-07
reasons over (A07_DESIGN section 5.1). Each collector returns *pre-aggregated*
digest sub-objects - never raw series, spans, or log lines - so the funnel is
already narrowing before the reduce stage runs:

  - metrics  (this commit)  -> Symptom[]        via prometheus_client (K-13 + PR #6186)
  - traces   (next commit)  -> ExemplarTrace[]   via Tempo / O-02 (_tempo_request)
  - logs     (next commit)  -> ErrorSignature[]  via Loki / A-05a (_loki_request)

All collectors are best-effort: on an unreachable backend they return an
empty list (prometheus_client already returns None -> scalar() falls back),
so a missing signal degrades the digest rather than failing the analysis.

Pure-ish: the only I/O is read-only metric queries. No model, no mutation.
"""
import logging;
import os;
import time;
import from jac_scale.utilities.metrics.prometheus_client { query, scalar }
import from jac_scale.admin.analyst {
    Symptom, ExemplarTrace, ErrorSignature, CriticalPathSpan
}

glob logger = logging.getLogger(__name__);


"""Percentage change of `current` vs `baseline`, guarding divide-by-zero.

Returns 0.0 when there is no baseline to compare against (a brand-new signal
is not, by itself, an anomaly). The sign is preserved so the reduce stage can
tell a regression (positive on latency/errors) from a recovery.
"""
def pct_delta(baseline: float, current: float) -> float {
    if baseline == 0.0 {
        return 0.0;
    }
    diff = current - baseline;
    denom = baseline;
    if denom < 0.0 {
        denom = -denom;
    }
    return diff / denom * 100.0;
}


"""One metric probe: a human label + the current and baseline PromQL.

The baseline query is the same expression with an `offset`, so both are cheap
instant queries (Prometheus does the windowing). `signal` is always "metric".
"""
obj MetricProbe {
    has name: str,
        current_promql: str,
        baseline_promql: str;
}


"""Build the default K-13 / PR-#6186 probe set for the given baseline offset.

These target the gateway RED metrics (request rate, error rate, p95 latency)
that K-13 emits under the `jac_scale` namespace. `baseline_offset` is a PromQL
duration (e.g. "1h", "24h") naming the window to compare 'now' against.
"""
def default_probes(baseline_offset: str = "1h") -> list[MetricProbe] {
    dur = "[5m]";
    p95 = f"histogram_quantile(0.95, sum(rate(jac_scale_gateway_request_duration_seconds_bucket{dur})) by (le))";
    err = f"sum(rate(jac_scale_gateway_requests_total{{outcome=\"5xx\"}}{dur})) / clamp_min(sum(rate(jac_scale_gateway_requests_total{dur})), 1)";
    rps = f"sum(rate(jac_scale_gateway_requests_total{dur}))";
    return [
        MetricProbe(
            name="gateway p95 latency (s)",
            current_promql=p95,
            baseline_promql=f"{p95} offset {baseline_offset}"
        ),
        MetricProbe(
            name="gateway 5xx error ratio",
            current_promql=err,
            baseline_promql=f"{err} offset {baseline_offset}"
        ),
        MetricProbe(
            name="gateway request rate (req/s)",
            current_promql=rps,
            baseline_promql=f"{rps} offset {baseline_offset}"
        )
    ];
}


"""Magnitude rank key for a Symptom (squared delta avoids abs()).

Typed so `delta_pct` resolves to float - an `any`-typed lambda param leaves it
Unknown and the checker rejects arithmetic on it.
"""
def symptom_rank(s: Symptom) -> float {
    return s.delta_pct * s.delta_pct;
}


"""Collect ranked metric Symptoms: current vs baseline for each probe.

Runs each probe's two instant queries through prometheus_client, computes the
signed pct delta, and returns the top-N by absolute deviation (the cheap
MAD/z-score-style ranking from section 13; refined in the reduce stage). A
probe whose current value is unavailable is skipped, not faked.
"""
def collect_metric_symptoms(
    baseline_offset: str = "1h", top_n: int = 5
) -> list[Symptom] {
    symptoms: list[Symptom] = [];
    for probe in default_probes(baseline_offset) {
        cur_raw = query(probe.current_promql);
        if cur_raw is None {
            continue;
        }
        current = scalar(cur_raw);
        baseline = scalar(query(probe.baseline_promql));
        symptoms.append(
            Symptom(
                signal="metric",
                name=probe.name,
                baseline=baseline,
                current=current,
                delta_pct=pct_delta(baseline, current)
            )
        );
    }
    symptoms.sort(key=symptom_rank, reverse=True);
    return symptoms[:top_n];
}


# --- Traces (Tempo / O-02) -> ExemplarTrace[] --------------------------------
# Self-contained (mirrors prometheus_client's pattern) rather than importing
# the admin traces proxy's impl-private _tempo_* helpers, which only its own
# module can resolve. Surfaces slow-trace exemplars AND each one's critical
# path (the hops that actually consumed the latency) so the model can reason
# about WHERE the time went, not just which trace was slow.


"""Pull a scalar from an OTLP attribute value object (string/int/bool/double)."""
def otlp_value(value: any) -> any {
    if "stringValue" in value { return value["stringValue"]; }
    if "intValue" in value { return value["intValue"]; }
    if "boolValue" in value { return value["boolValue"]; }
    if "doubleValue" in value { return value["doubleValue"]; }
    return "";
}


"""Flatten an OTLP attribute list `[{key, value}]` into a plain dict."""
def otlp_attrs(attrs: any) -> dict {
    out: dict = {};
    for a in (attrs or []) {
        k = a.get("key", "");
        if k {
            out[k] = otlp_value(a.get("value", {}));
        }
    }
    return out;
}


"""Flatten Tempo's OTLP-JSON trace into a flat span list. Each span:
{span_id, parent_span_id, name, service, duration_ms, attributes}. service.name
is lifted from each batch's resource onto its spans."""
def flatten_spans(payload: any) -> list {
    spans: list = [];
    for batch in (payload.get("batches", []) or []) {
        resource = batch.get("resource", {}) or {};
        service = str(otlp_attrs(resource.get("attributes", [])).get("service.name", "unknown"));
        for scope in (batch.get("scopeSpans", []) or []) {
            for span in (scope.get("spans", []) or []) {
                start_ns = int(span.get("startTimeUnixNano", 0) or 0);
                end_ns = int(span.get("endTimeUnixNano", 0) or 0);
                dur = (end_ns - start_ns) / 1000000.0 if end_ns >= start_ns else 0.0;
                spans.append(
                    {
                        "span_id": str(span.get("spanId", "") or ""),
                        "parent_span_id": str(span.get("parentSpanId", "") or ""),
                        "name": str(span.get("name", "") or ""),
                        "service": service,
                        "duration_ms": dur,
                        "attributes": otlp_attrs(span.get("attributes", []))
                    }
                );
            }
        }
    }
    return spans;
}


"""Self-time rank key for a CriticalPathSpan (typed so self_ms is float)."""
def cpspan_rank(h: CriticalPathSpan) -> float {
    return h.self_ms;
}


"""Reduce a flat span list to its critical path: the top hops by self-time
(span duration minus its direct children's durations). Approximates the longest
dependent path (A07_DESIGN section 13) - surfaces the hops that actually
consumed the latency, which is what the model needs to localise the problem."""
def critical_path(spans: list, top_hops: int = 6) -> list[CriticalPathSpan] {
    child_ms: dict = {};
    for sp in spans {
        pid = str(sp.get("parent_span_id", "") or "");
        if pid {
            child_ms[pid] = float(child_ms.get(pid, 0.0)) + float(sp.get("duration_ms", 0) or 0);
        }
    }
    hops: list[CriticalPathSpan] = [];
    for sp in spans {
        sid = str(sp.get("span_id", "") or "");
        self_ms = float(sp.get("duration_ms", 0) or 0) - float(child_ms.get(sid, 0.0));
        if self_ms < 0.0 {
            self_ms = 0.0;
        }
        hops.append(
            CriticalPathSpan(
                service=str(sp.get("service", "") or ""),
                span_name=str(sp.get("name", "") or ""),
                attrs=dict(sp.get("attributes", {}) or {}),
                self_ms=self_ms
            )
        );
    }
    hops.sort(key=cpspan_rank, reverse=True);
    return hops[:top_hops];
}


"""Fetch one trace's spans from Tempo and reduce to its critical path.
Best-effort: [] on any failure (the exemplar still carries id + total_ms)."""
async def fetch_critical_path(
    base: str, trace_id: str, top_hops: int = 6
) -> list[CriticalPathSpan] {
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
    } except Exception as e {
        logger.warning(f"analyst: Tempo trace fetch failed for {trace_id}: {e}");
        return [];
    }
    return critical_path(flatten_spans(payload), top_hops);
}


"""Resolve the in-cluster Tempo base URL, or None off-K8s.

Honors TEMPO_URL, else the K8S_APP_NAME-derived service DNS - same resolution
the admin traces proxy uses, kept local so collect has no cross-module coupling.
"""
def tempo_base_url -> str | None {
    env = os.getenv("TEMPO_URL", "").strip();
    if env {
        return env.rstrip("/");
    }
    app = os.getenv("K8S_APP_NAME", "").strip();
    if not app {
        return None;
    }
    return f"http://{app}-tempo-service:3200";
}


"""Collect slow-trace exemplars from Tempo (TraceQL `duration > Nms`).

Returns the `top_traces` slowest traces in the last hour as ExemplarTrace
(trace_id + total_ms + critical path, each fetched + flattened + self-timed).
Best-effort + async: an unreachable backend or off-K8s deploy yields [] so the
analysis degrades rather than fails. Only reduced summaries reach the model -
never raw spans.
"""
async def collect_trace_exemplars(
    min_duration_ms: int = 500, top_traces: int = 3
) -> list[ExemplarTrace] {
    import httpx;
    out: list[ExemplarTrace] = [];
    base = tempo_base_url();
    if base is None {
        return out;
    }
    now_s = int(time.time());
    traceql = f"{{ duration > {min_duration_ms}ms }}";
    try {
        async with httpx.AsyncClient(timeout=httpx.Timeout(5.0, connect=3.0)) as cl {
            resp = await cl.get(
                base + "/api/search",
                params={
                    "q": traceql,
                    "limit": "20",
                    "start": str(now_s - 3600),
                    "end": str(now_s)
                }
            );
            resp.raise_for_status();
            payload = resp.json();
        }
    } except Exception as e {
        logger.warning(f"analyst: Tempo search unavailable: {e}");
        return out;
    }
    summaries: list = list(payload.get("traces", []) or []);
    summaries.sort(key=lambda t : int(t.get("durationMs", 0) or 0), reverse=True);
    # Drop operator/infra traffic (admin UI, the analyst's OWN /analyze call,
    # health/metrics probes) - a *performance* report is about the app's
    # workload, not the tooling observing it. Without this the analyst's own
    # multi-second LLM call is the slowest trace and it diagnoses itself.
    app_traces: list = [];
    for t in summaries {
        root_name = str(t.get("rootTraceName", "") or "").lower();
        is_op = False;
        for p in ["/admin/", "/metrics", "/healthz", "/readyz", "/livez"] {
            if p in root_name {
                is_op = True;
            }
        }
        if not is_op {
            app_traces.append(t);
        }
    }
    for t in app_traces[:top_traces] {
        tid = str(t.get("traceID", "") or "");
        if not tid {
            continue;
        }
        cpath = await fetch_critical_path(base, tid);
        out.append(
            ExemplarTrace(
                trace_id=tid,
                total_ms=float(t.get("durationMs", 0) or 0),
                critical_path=cpath
            )
        );
    }
    return out;
}


# --- Logs (Loki / A-05a) -> ErrorSignature[] ---------------------------------
# Self-contained (same rationale as the Tempo collector). Groups error lines by
# a Drain-lite signature so the digest carries counts + one sample trace_id per
# cluster, never raw log lines (A07_DESIGN section 5.2 + 13).


"""Resolve the in-cluster Loki base URL, or None off-K8s."""
def loki_base_url -> str | None {
    env = os.getenv("LOKI_URL", "").strip();
    if env {
        return env.rstrip("/");
    }
    app = os.getenv("K8S_APP_NAME", "").strip();
    if not app {
        return None;
    }
    return f"http://{app}-loki-service:3100";
}


"""Drain-lite log-message template: long hex/uuid runs -> <id>, digit runs ->
<n>, trimmed. Collapses near-identical errors into one signature so the digest
counts them instead of repeating them. Uses char-class patterns (no r-strings).
"""
def log_signature(msg: str) -> str {
    import re;
    s = re.sub("[0-9a-fA-F-]{16,}", "<id>", msg);
    s = re.sub("[0-9]+", "<n>", s);
    return s.strip()[:120];
}


"""Count rank key for an ErrorSignature (typed so count resolves to int)."""
def esig_rank(e: ErrorSignature) -> int {
    return e.count;
}


"""Collect error-log signatures from Loki (namespace-scoped, level=ERROR).

Pulls the last hour of ERROR lines, parses M-14 structured-JSON bodies for
msg / service / trace_id, groups by Drain-lite signature, and returns the
top-N clusters by count. Best-effort + async: unreachable Loki or off-K8s
(no namespace) yields []. Only grouped counts + one sample trace_id per
signature reach the model - never raw lines.
"""
async def collect_error_signatures(
    top_n: int = 5, max_lines: int = 1000
) -> list[ErrorSignature] {
    import httpx;
    import json;
    out: list[ErrorSignature] = [];
    base = loki_base_url();
    namespace = os.getenv("K8S_NAMESPACE", "").strip();
    if base is None or not namespace {
        return out;
    }
    now_ns = int(time.time() * 1_000_000_000);
    start_ns = now_ns - 3600 * 1_000_000_000;
    logql = "{namespace=\"" + namespace + "\"} | json | level=\"ERROR\"";
    try {
        async with httpx.AsyncClient(timeout=httpx.Timeout(5.0, connect=3.0)) as cl {
            resp = await cl.get(
                base + "/loki/api/v1/query_range",
                params={
                    "query": logql,
                    "start": str(start_ns),
                    "end": str(now_ns),
                    "limit": str(max_lines),
                    "direction": "backward"
                }
            );
            resp.raise_for_status();
            payload = resp.json();
        }
    } except Exception as e {
        logger.warning(f"analyst: Loki query unavailable: {e}");
        return out;
    }

    counts: dict[str, int] = {};
    svcs: dict[str, set] = {};
    samples: dict[str, str] = {};
    data = payload.get("data", {}) or {};
    result = data.get("result", []) or [];
    for stream in result {
        labels = stream.get("stream", {}) or {};
        svc_label = str(labels.get("service", "") or labels.get("app", "") or "");
        for v in (stream.get("values", []) or []) {
            line = str(v[1]) if len(v) > 1 else "";
            msg = line;
            trace_id = "";
            svc = svc_label;
            try {
                rec = json.loads(line);
                if isinstance(rec, dict) {
                    msg = str(rec.get("msg", "") or rec.get("message", "") or line);
                    trace_id = str(rec.get("trace_id", "") or "");
                    svc = str(rec.get("service", "") or svc_label);
                }
            } except Exception {
                msg = line;
            }
            sig = log_signature(msg);
            counts[sig] = int(counts.get(sig, 0)) + 1;
            if sig not in svcs {
                svcs[sig] = set();
            }
            if svc {
                svcs[sig].add(svc);
            }
            if sig not in samples and trace_id {
                samples[sig] = trace_id;
            }
        }
    }

    items: list[ErrorSignature] = [];
    for sig in list(counts.keys()) {
        items.append(
            ErrorSignature(
                signature=sig,
                count=int(counts.get(sig, 0)),
                services=list(svcs.get(sig, set())),
                sample_trace_id=samples.get(sig, None)
            )
        );
    }
    items.sort(key=esig_rank, reverse=True);
    return items[:top_n];
}
