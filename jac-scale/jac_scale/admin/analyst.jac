"""A-07 Performance Analyst - the IncidentDigest data contracts.

Self-contained contracts module (no endpoints yet). The collect / reduce /
reason / localize / github stages land in sibling modules
(`impl/analyst_collect.impl.jac`, ...) and import the objects defined here;
the admin endpoint mixin (`obj JacAPIServerAnalyst`) gets added to this file
with its impl in `impl/analyst.impl.jac` once the pipeline produces something
to serve. See `.local-docs/A07_DESIGN.md` (section 5.3 + section 10).

The pipeline is a funnel:

    TRIGGER -> COLLECT -> REDUCE -> [IncidentDigest] -> REASON (LLM)
                                         ^
                          this file: the contract the small model
                          is prompted against, and the ONLY thing it
                          ever sees - never raw logs/spans/metrics.

These are pure, side-effect-free data objects (no I/O). The collect stage
populates them from the in-cluster Prometheus via
`jac_scale.utilities.metrics.prometheus_client`, Tempo (O-02), Loki (A-05a),
and A-03 telemetry; the reduce stage ranks/dedupes/caps them; the result is
handed to `diagnose()`.

Design invariant: the digest has a HARD token ceiling (default ~4K, the
`digest_max_tokens` config knob). `estimate_tokens()` + `trim_to()` enforce
it deterministically BEFORE any model call - the whole reason A-07 is a
performance analyst and not a token burner.
"""


obj TimeWindow {
    """The incident window plus the baseline window it is compared against.

    Unix timestamps (seconds). The *delta* between window and baseline is the
    signal (see Symptom), not the absolute value.
    """
    has start_ts: float = 0.0,
        end_ts: float = 0.0,
        baseline_start_ts: float = 0.0,
        baseline_end_ts: float = 0.0;

    def to_dict -> dict {
        return {
            "start_ts": self.start_ts,
            "end_ts": self.end_ts,
            "baseline_start_ts": self.baseline_start_ts,
            "baseline_end_ts": self.baseline_end_ts
        };
    }
}


obj Trigger {
    """Why this analysis ran. Set deterministically by the trigger stage -
    never by the model (section 4)."""
    has kind: str = "on_demand",        # on_demand | alert | scheduled
        symptom: str = "",              # human label, e.g. "p95 latency"
        threshold: float = 0.0,
        observed: float = 0.0;

    def to_dict -> dict {
        return {
            "kind": self.kind,
            "symptom": self.symptom,
            "threshold": self.threshold,
            "observed": self.observed
        };
    }
}


obj Symptom {
    """One ranked anomaly: a metric's current value vs its baseline.

    `delta_pct` is the normalized deviation the reduce stage ranks on
    (MAD / z-score / pct-change - section 13). Top-N only (default 5).
    """
    has signal: str = "metric",         # metric | trace | log | cost
        name: str = "",                 # e.g. "gateway p95 /api/checkout"
        baseline: float = 0.0,
        current: float = 0.0,
        delta_pct: float = 0.0;

    def to_dict -> dict {
        return {
            "signal": self.signal,
            "name": self.name,
            "baseline": self.baseline,
            "current": self.current,
            "delta_pct": round(self.delta_pct, 2)
        };
    }
}


obj CriticalPathSpan {
    """One hop on an exemplar trace's critical path (the longest dependent
    path - section 13). `span_name`/`attrs` are the keys the LOCALIZE stage
    maps back to code, e.g. "memory.get mongodb" + {mem.tier: L3}."""
    has service: str = "",
        span_name: str = "",
        attrs: dict = {},
        self_ms: float = 0.0;

    def to_dict -> dict {
        return {
            "service": self.service,
            "span_name": self.span_name,
            "attrs": self.attrs,
            "self_ms": round(self.self_ms, 2)
        };
    }
}


obj ExemplarTrace {
    """One representative trace for the symptom - NOT the full set (1-3 max).
    Pre-reduced to its critical path so the model sees structure, not spans."""
    has trace_id: str = "",
        total_ms: float = 0.0,
        critical_path: list = [];

    def to_dict -> dict {
        return {
            "trace_id": self.trace_id,
            "total_ms": round(self.total_ms, 2),
            "critical_path": [s.to_dict() for s in self.critical_path]
        };
    }
}


obj Suspect {
    """A ranked suspected location, with the evidence that put it on the list.
    The model ranks/explains these; it does not invent them."""
    has service: str = "",
        evidence: list = [],            # list[str], human-readable bullets
        exemplar_trace_id: str | None = None;

    def to_dict -> dict {
        return {
            "service": self.service,
            "evidence": self.evidence,
            "exemplar_trace_id": self.exemplar_trace_id
        };
    }
}


obj ErrorSignature {
    """A cluster of error logs grouped by signature (Drain - section 13),
    with a count and ONE sample trace_id. Never raw log lines."""
    has signature: str = "",
        count: int = 0,
        services: list = [],            # list[str]
        sample_trace_id: str | None = None;

    def to_dict -> dict {
        return {
            "signature": self.signature,
            "count": self.count,
            "services": self.services,
            "sample_trace_id": self.sample_trace_id
        };
    }
}


obj CostOutlier {
    """A token/cost spike from A-03 telemetry, as a delta vs baseline."""
    has service: str = "",
        model: str = "",
        tokens_delta: int = 0,
        cost_delta_usd: float = 0.0;

    def to_dict -> dict {
        return {
            "service": self.service,
            "model": self.model,
            "tokens_delta": self.tokens_delta,
            "cost_delta_usd": round(self.cost_delta_usd, 6)
        };
    }
}


obj RecentDeploy {
    """A recent image_tag change per service - the git-correlation seed the
    LOCALIZE stage matches a suspect commit against (section 5.6)."""
    has service: str = "",
        image_tag: str = "",
        commit_sha: str | None = None,
        at: float = 0.0;                # unix ts of the rollout

    def to_dict -> dict {
        return {
            "service": self.service,
            "image_tag": self.image_tag,
            "commit_sha": self.commit_sha,
            "at": self.at
        };
    }
}


obj IncidentDigest {
    """The bounded artifact handed to the model. Stable schema = the prompt
    contract. Every list is ranked + capped by the reduce stage; the whole
    object is size-bounded by `trim_to()` before any model call."""
    has window: TimeWindow | None = None,
        trigger: Trigger | None = None,
        symptoms: list = [],            # list[Symptom], <=5
        suspects: list = [],            # list[Suspect], <=5
        exemplar_traces: list = [],     # list[ExemplarTrace], <=3
        error_signatures: list = [],    # list[ErrorSignature], <=5
        cost_outliers: list = [],       # list[CostOutlier], <=5
        recent_deploys: list = [];      # list[RecentDeploy]

    def to_dict -> dict {
        return {
            "window": self.window.to_dict() if self.window else None,
            "trigger": self.trigger.to_dict() if self.trigger else None,
            "symptoms": [s.to_dict() for s in self.symptoms],
            "suspects": [s.to_dict() for s in self.suspects],
            "exemplar_traces": [t.to_dict() for t in self.exemplar_traces],
            "error_signatures": [e.to_dict() for e in self.error_signatures],
            "cost_outliers": [c.to_dict() for c in self.cost_outliers],
            "recent_deploys": [d.to_dict() for d in self.recent_deploys]
        };
    }

    """Cheap, deterministic token estimate of the rendered digest.

    Uses the chars/4 heuristic on the JSON form (section 3: for hard limits
    the real tokenizer is used at the call site, but this is enough for the
    reduce-stage size gate). No model, no I/O.
    """
    def estimate_tokens -> int {
        import json;
        rendered = json.dumps(self.to_dict());
        return len(rendered) // 4;
    }

    """Drop lowest-ranked items until the digest fits `max_tokens`.

    Returns a list of human-readable strings describing what was dropped,
    so the caller can `log()` it - no silent truncation (section 5.2).
    Sheds the cheapest-signal lists first; assumes each list is already
    ranked best-first by the reduce stage.
    """
    def trim_to(max_tokens: int) -> list {
        dropped: list = [];
        # Order in which we shed load: deploys (context) -> cost -> errors ->
        # exemplars -> suspects -> symptoms (symptoms are the core signal).
        order = [
            ("recent_deploys", self.recent_deploys),
            ("cost_outliers", self.cost_outliers),
            ("error_signatures", self.error_signatures),
            ("exemplar_traces", self.exemplar_traces),
            ("suspects", self.suspects),
            ("symptoms", self.symptoms)
        ];
        for (label, items) in order {
            while self.estimate_tokens() > max_tokens and items {
                items.pop();
                dropped.append(label);
            }
            if self.estimate_tokens() <= max_tokens {
                break;
            }
        }
        return dropped;
    }
}
