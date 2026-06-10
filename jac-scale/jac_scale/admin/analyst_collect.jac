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
import from jac_scale.utilities.metrics.prometheus_client { query, scalar }
import from jac_scale.admin.analyst { Symptom }

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
