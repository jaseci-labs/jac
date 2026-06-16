"""A-07 Performance Report - the deterministic, APPLICATION-level report.

This is the core deliverable: an application-performance report answering
"which APIs are having issues, and why" - built entirely from Tempo traces
(+ Loki errors). NO model produces any number here; an LLM has no business
generating metrics. The AI layer is a separate, optional "Analysis &
Recommendations" section that *reads* this report (analyst_reason.diagnose).

Scope is deliberately APPLICATION-level, not infra. Pod / node / CPU / memory
saturation is infrastructure performance and is already owned by the admin
Workloads / Usage view (#6186); duplicating it here just conflates two
concerns. This report is about the app's request/DB behaviour:

  - health      : app-level top-line derived from the trace sample (status +
                  error rate + overall p95).
  - endpoints   : per-API RED (calls, p95, error rate) + how much DB work each
                  request does - "which endpoints are having issues".
  - db_hotspots : operations doing heavy DB work, with calls-per-request and an
                  N+1 flag - "which calls are hammering the database".
  - slow_traces : the worst traces with their critical paths (where the time
                  went in the code path).
  - errors      : grouped error signatures.

These are pure data objects (no I/O). analyst_report_collect builds them.
"""
import from jac_scale.admin.analyst { ExemplarTrace, ErrorSignature }


obj ReportHealth {
    """App-level executive summary, derived from the trace sample (not infra).
    `status` is Healthy / Degraded based on error rate + p95."""
    has status: str = "unknown",
        sampled_traces: int = 0,
        error_rate: float = 0.0,        # 0..1 over the sampled traces
        p95_ms: float = 0.0;            # overall p95 across the sample

    def to_dict -> dict {
        return {
            "status": self.status,
            "sampled_traces": self.sampled_traces,
            "error_rate": self.error_rate,
            "p95_ms": self.p95_ms
        };
    }
}


obj EndpointStat {
    """Per-API RED + DB load: which endpoints are having issues.

    Aggregated across the trace sample, keyed by route (root span name).
    `db_calls_per_req` / `db_ms_per_req` expose how DB-heavy each endpoint is -
    the bridge to the db_hotspots section.
    """
    has route: str = "",
        calls: int = 0,
        error_rate: float = 0.0,        # 0..1
        p95_ms: float = 0.0,
        avg_ms: float = 0.0,
        db_calls_per_req: float = 0.0,
        db_ms_per_req: float = 0.0;

    def to_dict -> dict {
        return {
            "route": self.route,
            "calls": self.calls,
            "error_rate": self.error_rate,
            "p95_ms": self.p95_ms,
            "avg_ms": self.avg_ms,
            "db_calls_per_req": self.db_calls_per_req,
            "db_ms_per_req": self.db_ms_per_req
        };
    }
}


obj DbHotspot {
    """Heavy-DB-call analysis: an operation issued by an endpoint that does a
    lot of DB work. `calls_per_req` >= the N+1 threshold sets `n_plus_one` -
    the classic "this handler hammers the DB in a loop" signal."""
    has route: str = "",                # the endpoint that issues it
        operation: str = "",            # e.g. "memory.get mongodb"
        db_system: str = "",            # mongodb | redis | ...
        calls_per_req: float = 0.0,
        ms_per_req: float = 0.0,        # time in this op per request
        n_plus_one: bool = False;

    def to_dict -> dict {
        return {
            "route": self.route,
            "operation": self.operation,
            "db_system": self.db_system,
            "calls_per_req": self.calls_per_req,
            "ms_per_req": self.ms_per_req,
            "n_plus_one": self.n_plus_one
        };
    }
}


obj PerformanceReport {
    """The full deterministic application-performance report. `analysis` is not
    stored here; the AI Analysis & Recommendations section is filled in
    separately by the reason stage so the report stands on its own."""
    has generated_at: float = 0.0,
        window: str = "15m",
        sampled_traces: int = 0,
        health: ReportHealth | None = None,
        endpoints: list = [],           # list[EndpointStat]
        db_hotspots: list = [],         # list[DbHotspot]
        slow_traces: list = [],         # list[ExemplarTrace]
        errors: list = [];              # list[ErrorSignature]

    def to_dict -> dict {
        return {
            "generated_at": self.generated_at,
            "window": self.window,
            "sampled_traces": self.sampled_traces,
            "health": self.health.to_dict() if self.health else None,
            "endpoints": [e.to_dict() for e in self.endpoints],
            "db_hotspots": [d.to_dict() for d in self.db_hotspots],
            "slow_traces": [t.to_dict() for t in self.slow_traces],
            "errors": [e.to_dict() for e in self.errors]
        };
    }
}
