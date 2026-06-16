"""A-07 Performance Report - the assembler.

Runs the deterministic collectors and assembles the application-level
PerformanceReport: a sampled span aggregation (health + per-endpoint RED +
DB hotspots, async Tempo) + slow-trace exemplars with critical paths (async
Tempo) + grouped error signatures (async Loki). No model is involved - this is
the full deterministic report. The AI Analysis & Recommendations section is
layered on separately (analyst_reason.diagnose), reading this report's dict.
"""
import time;
import logging;
import from jac_scale.admin.analyst_report { PerformanceReport }
import from jac_scale.admin.analyst_report_collect { collect_app_report }
import from jac_scale.admin.analyst_collect {
    collect_trace_exemplars, collect_error_signatures
}

glob logger = logging.getLogger(__name__);


"""Assemble the full deterministic PerformanceReport from all signals.

Best-effort throughout: any collector whose backend is unreachable / off-
cluster contributes an empty section rather than failing the report. Async
because every collector here is async (Tempo + Loki). `sample_limit` caps how
many traces the per-endpoint aggregation fetches.
"""
async def build_report(window: str = "15m", sample_limit: int = 20) -> PerformanceReport {
    (health, endpoints, db_hotspots) = await collect_app_report(sample_limit=sample_limit);
    slow = await collect_trace_exemplars();
    errors = await collect_error_signatures();
    return PerformanceReport(
        generated_at=time.time(),
        window=window,
        sampled_traces=health.sampled_traces,
        health=health,
        endpoints=endpoints,
        db_hotspots=db_hotspots,
        slow_traces=slow,
        errors=errors
    );
}
