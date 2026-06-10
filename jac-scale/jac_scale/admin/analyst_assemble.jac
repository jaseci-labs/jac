"""A-07 Performance Analyst - the REDUCE / assemble stage.

Runs the three collectors, assembles the IncidentDigest, and applies the
deterministic size gate (`trim_to`) so the artifact handed to the model is
bounded before any LLM call (A07_DESIGN sections 3, 5.2). This is the last
fully-deterministic stage: everything here is code, no model.

`build_digest()` is async because the trace + log collectors are async (their
Tempo/Loki clients are). The metric collector is sync. All three are
best-effort, so a partial digest (e.g. metrics only, off-K8s) is normal and
still useful.
"""
import logging;
import time;
import from jac_scale.admin.analyst { IncidentDigest, TimeWindow, Trigger }
import from jac_scale.admin.analyst_collect {
    collect_metric_symptoms,
    collect_trace_exemplars,
    collect_error_signatures
}

glob logger = logging.getLogger(__name__);


"""Assemble a bounded IncidentDigest from all three observability sources.

Collects metric symptoms (sync), then trace exemplars + error signatures
(async), stamps the window/trigger, and trims to `digest_max_tokens` before
returning. The trim is logged (never silent). The top symptom seeds the
trigger's human label so the digest is self-describing.
"""
async def build_digest(
    baseline_offset: str = "1h",
    digest_max_tokens: int = 4096,
    trigger_kind: str = "on_demand"
) -> IncidentDigest {
    now = time.time();

    symptoms = collect_metric_symptoms(baseline_offset=baseline_offset);
    exemplars = await collect_trace_exemplars();
    errors = await collect_error_signatures();

    window = TimeWindow(
        start_ts=now - 300.0,
        end_ts=now,
        baseline_start_ts=now - 3900.0,
        baseline_end_ts=now - 3600.0
    );

    top_name = symptoms[0].name if symptoms else "";
    top_observed = symptoms[0].current if symptoms else 0.0;
    trigger = Trigger(
        kind=trigger_kind,
        symptom=top_name,
        threshold=0.0,
        observed=top_observed
    );

    digest = IncidentDigest(
        window=window,
        trigger=trigger,
        symptoms=symptoms,
        exemplar_traces=exemplars,
        error_signatures=errors
    );

    dropped = digest.trim_to(digest_max_tokens);
    if dropped {
        logger.info(
            f"analyst: digest trimmed to <= {digest_max_tokens} tokens, "
            + f"dropped {len(dropped)} item(s): {dropped}"
        );
    }
    return digest;
}
