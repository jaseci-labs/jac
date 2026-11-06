"""Iterating a union with an `any` member yields `any`, so subscripting
the loop target stays unchecked."""

def fmt(ms: float) -> str {
    return str(ms);
}

def comprehension(trace: dict[str, any]) -> list[str] {
    return [fmt(call["latency_ms"] or 0) for call in (trace["llm_calls"] or [])];
}

def loop(trace: dict[str, any]) -> list[str] {
    out: list[str] = [];
    for call in trace["llm_calls"] or [] {
        out.append(fmt(call["latency_ms"] or 0));
    }
    return out;
}
