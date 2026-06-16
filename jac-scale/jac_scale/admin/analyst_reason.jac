"""A-07 REASON stage: the single small-model call over the bounded digest.

The one place a model runs (A07_DESIGN sections 5.4, 7, 14). It is handed the
pre-aggregated `IncidentDigest` - never raw logs/spans/metrics - and asked to
rank the most likely performance root cause and explain it. The model RANKS
and EXPLAINS; it must not invent metric values, file paths, or commits.

BYO token: the api_key + model_name come from the caller (the admin UI, per
request) and are used to build a throwaway byLLM `Model`; the key is never
stored. We call `Model.model_call_no_stream` (byLLM's provider abstraction +
error mapping) rather than the `by llm()` sugar, because that binds the model
globally at definition while our model + key vary per request.

Cost: one cheap call over a <=4K-token digest (~1 cent on a small model). The
digest's `trim_to` ceiling is what keeps this bounded.
"""
import json;
import logging;
import from byllm.lib { Model }

glob logger = logging.getLogger(__name__);

glob ANALYST_SYSTEM_PROMPT = (
    "You are an APPLICATION-performance analyst. You are given a deterministic "
    "report as JSON with these parts: `health` (overall status + error_rate + "
    "p95_ms over a trace sample), `endpoints` (per-API: route, calls, p95_ms, "
    "error_rate, db_calls_per_req, db_ms_per_req - which APIs are having issues), "
    "`db_hotspots` (route + DB operation with calls_per_req, ms_per_req and an "
    "n_plus_one flag - heavy/repeated DB calls), `slow_traces` (each with "
    "`critical_path`: the hops that consumed the latency, ranked by `self_ms`), "
    "and `errors` (grouped error signatures with counts). Diagnose the SINGLE "
    "most likely application performance problem AND reason through what it "
    "leads to, using ONLY the report.\n"
    "\nProduce a cause -> effect -> symptom chain:\n"
    "1. ROOT CAUSE - the specific slow/DB-heavy thing. Cite exact evidence: the "
    "endpoint (p95_ms / error_rate), the DB hotspot (operation + calls_per_req, "
    "especially if n_plus_one), or the critical-path span (self_ms). A high "
    "db_calls_per_req or an n_plus_one hotspot means the endpoint is DB-bound "
    "(likely an N+1 pattern); the highest-self_ms span is the latency bottleneck.\n"
    "2. IMPACT - what this CAUSES or risks as it gets worse. Reason about the "
    "failure modes a slow/DB-bound endpoint produces: gateway/proxy 504 timeouts "
    "(when p95 approaches the request timeout), DB connection-pool exhaustion and "
    "queueing under load, retries amplifying the load, and cascading slowdowns in "
    "callers. Frame these as the likely/at-risk consequence, tied to the cited "
    "numbers - not as confirmed events.\n"
    "3. TOP ERROR - the single most frequent error from `errors` (quote its "
    "signature + count) and state whether it is plausibly caused by the root "
    "cause (e.g. a timeout/connection error downstream of the slow DB calls). If "
    "`errors` is empty, say 'no errors observed yet' - do NOT invent one.\n"
    "\nRules: be specific and quote numbers; this is APPLICATION analysis (no "
    "pods/CPU/memory/infra); do NOT invent routes, spans, metrics, errors, files, "
    "or commits not in the report; if the report is thin (no endpoints, healthy, "
    "no hotspots or errors) say so and set confidence <= 0.3.\n"
    "\nRespond with ONLY a JSON object of this shape: "
    "{\"root_cause\": str (cite the endpoint/hotspot/span), "
    "\"confidence\": float between 0 and 1, "
    "\"impact\": str (likely failure modes this causes/risks, e.g. 504 timeouts, "
    "pool exhaustion - tied to the cited numbers), "
    "\"top_error\": str (most frequent error from `errors` with its count + "
    "whether it is linked; 'no errors observed yet' if none), "
    "\"ranked_suspects\": [{\"service\": str, \"why\": str (cite the evidence)}], "
    "\"recommended_action\": str}."
);


obj Suspect {
    """One ranked suspected location with the model's one-line reasoning."""
    has service: str = "",
        why: str = "";

    def to_dict -> dict {
        return {"service": self.service, "why": self.why};
    }
}


obj Analysis {
    """The model's structured verdict over a digest. `error` is set (and the
    other fields left empty) when the call or parse fails, so the endpoint can
    always return a well-formed object."""
    has root_cause: str = "",
        confidence: float = 0.0,
        impact: str = "",
        top_error: str = "",
        ranked_suspects: list = [],
        recommended_action: str = "",
        error: str | None = None;

    def to_dict -> dict {
        return {
            "root_cause": self.root_cause,
            "confidence": self.confidence,
            "impact": self.impact,
            "top_error": self.top_error,
            "ranked_suspects": [s.to_dict() for s in self.ranked_suspects],
            "recommended_action": self.recommended_action,
            "error": self.error
        };
    }
}


"""Build the chat messages for one diagnosis: stable system prompt + the
digest JSON as the user turn. Keeping the digest last keeps the system prompt
cacheable (A07_DESIGN section 14)."""
def build_messages(digest_json: str) -> list {
    return [
        {"role": "system", "content": ANALYST_SYSTEM_PROMPT},
        {
            "role": "user",
            "content": f"Incident digest:\n{digest_json}\n\nReturn only the JSON object."
        }
    ];
}


"""Parse the model's JSON content into an Analysis (defensive: any malformed
field degrades to a default rather than raising)."""
def parse_analysis(content: str) -> Analysis {
    try {
        data = json.loads(content);
    } except Exception as e {
        return Analysis(error=f"unparseable model output: {e}");
    }
    suspects: list = [];
    for s in (data.get("ranked_suspects", []) or []) {
        suspects.append(
            Suspect(service=str(s.get("service", "")), why=str(s.get("why", "")))
        );
    }
    return Analysis(
        root_cause=str(data.get("root_cause", "")),
        confidence=float(data.get("confidence", 0.0) or 0.0),
        impact=str(data.get("impact", "")),
        top_error=str(data.get("top_error", "")),
        ranked_suspects=suspects,
        recommended_action=str(data.get("recommended_action", ""))
    );
}


"""Run one diagnosis: build a throwaway Model from the BYO key, call it over
the digest, parse the result. Synchronous (the litellm call is sync) - the
endpoint runs it off the event loop. Never raises: provider/parse failures
come back as an Analysis with `error` set.
"""
def diagnose(digest_dict: dict, model_name: str, api_key: str) -> Analysis {
    digest_json = json.dumps(digest_dict);
    m = Model(model_name=model_name, api_key=api_key);
    params = {
        "model": model_name,
        "messages": build_messages(digest_json),
        "max_tokens": 1024,
        "response_format": {"type": "json_object"}
    };
    try {
        resp: any = m.model_call_no_stream(params);
    } except Exception as e {
        logger.warning(f"analyst diagnose call failed: {e}");
        return Analysis(error=str(e));
    }
    content = "";
    try {
        content = str(resp.choices[0].message.content or "");
    } except Exception as e {
        logger.warning(f"analyst diagnose: unexpected response shape: {e}");
        return Analysis(error="unexpected model response shape");
    }
    if not content {
        return Analysis(error="empty model response");
    }
    return parse_analysis(content);
}
