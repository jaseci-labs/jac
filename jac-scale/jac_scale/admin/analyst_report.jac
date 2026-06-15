"""A-07 Performance Report - the deterministic, industry-standard report.

This is the core deliverable: a comprehensive system-performance report
(health + RED + USE + slow traces + errors), built entirely from the
in-cluster Prometheus / Tempo / Loki. NO model is involved in producing any
number here - an LLM has no business generating metrics. The AI layer is a
separate, optional "Analysis & Recommendations" section that *reads* this
report (see analyst_reason.diagnose); it adds judgement, not facts.

Structure follows the standard observability methodology:
  - health  : overall status + pod/node counts + top-line RED (req/s, error
              rate, p95) - the executive summary.
  - pods    : per-pod USE (CPU / memory / restarts) - resource saturation.
  - slow_traces / errors : the worst latency + error clusters (reused from
              the digest collectors, incl. trace critical paths).

These are pure data objects (no I/O). analyst_report_collect builds them.
"""
import from jac_scale.admin.analyst { ExemplarTrace, ErrorSignature }


obj ReportHealth {
    """Executive summary: cluster/workload health + top-line RED metrics."""
    has status: str = "unknown",        # Healthy | Degraded | Unknown
        pods_running: int = 0,
        pods_pending: int = 0,
        pods_failed: int = 0,
        nodes_ready: int = 0,
        req_per_s: float = 0.0,
        error_rate: float = 0.0,        # 0..1 (5xx / total)
        p95_latency_s: float = 0.0;

    def to_dict -> dict {
        return {
            "status": self.status,
            "pods_running": self.pods_running,
            "pods_pending": self.pods_pending,
            "pods_failed": self.pods_failed,
            "nodes_ready": self.nodes_ready,
            "req_per_s": self.req_per_s,
            "error_rate": self.error_rate,
            "p95_latency_s": self.p95_latency_s
        };
    }
}


obj PodUsage {
    """Per-pod USE: utilization (CPU/mem) + a coarse saturation signal
    (restarts). Mirrors the columns of the admin Workloads view (#6186)."""
    has pod: str = "",
        status: str = "",
        cpu_cores: float = 0.0,
        mem_mb: float = 0.0,
        restarts: int = 0;

    def to_dict -> dict {
        return {
            "pod": self.pod,
            "status": self.status,
            "cpu_cores": self.cpu_cores,
            "mem_mb": self.mem_mb,
            "restarts": self.restarts
        };
    }
}


obj PerformanceReport {
    """The full deterministic performance report. `analysis` is left None here;
    the AI Analysis & Recommendations section is filled in separately by the
    reason stage so the report stands on its own without any model call."""
    has generated_at: float = 0.0,
        window: str = "5m",
        health: ReportHealth | None = None,
        pods: list = [],                # list[PodUsage]
        slow_traces: list = [],         # list[ExemplarTrace]
        errors: list = [];              # list[ErrorSignature]

    def to_dict -> dict {
        return {
            "generated_at": self.generated_at,
            "window": self.window,
            "health": self.health.to_dict() if self.health else None,
            "pods": [p.to_dict() for p in self.pods],
            "slow_traces": [t.to_dict() for t in self.slow_traces],
            "errors": [e.to_dict() for e in self.errors]
        };
    }
}
