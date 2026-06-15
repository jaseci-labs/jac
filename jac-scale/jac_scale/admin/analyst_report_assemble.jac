"""A-07 Performance Report - the assembler.

Runs the deterministic collectors and assembles the PerformanceReport: health
(sync Prometheus) + per-pod USE (sync) + slow-trace exemplars with critical
paths (async Tempo) + grouped error signatures (async Loki). No model is
involved - this is the full deterministic report. The AI Analysis &
Recommendations section is layered on separately (analyst_reason.diagnose),
reading this report's dict.
"""
import time;
import logging;
import from jac_scale.admin.analyst_report { PerformanceReport }
import from jac_scale.admin.analyst_report_collect { collect_health, collect_pod_usage }
import from jac_scale.admin.analyst_collect {
    collect_trace_exemplars, collect_error_signatures
}

glob logger = logging.getLogger(__name__);


"""Assemble the full deterministic PerformanceReport from all signals.

Best-effort throughout: any collector that finds nothing (or whose backend is
unreachable / off-cluster) contributes an empty section rather than failing
the report. Async because the trace + log collectors are async.
"""
async def build_report(window: str = "5m", top_pods: int = 20) -> PerformanceReport {
    health = collect_health();
    pods = collect_pod_usage(top_n=top_pods);
    slow = await collect_trace_exemplars();
    errors = await collect_error_signatures();
    return PerformanceReport(
        generated_at=time.time(),
        window=window,
        health=health,
        pods=pods,
        slow_traces=slow,
        errors=errors
    );
}
