"""Shared helpers for diagnostic-code token normalization."""

def resolve_diagnostic_tokens(tokens: list) -> tuple[list[str], list[str]] {
    import from jaclang.jac0core.diagnostics { DIAGNOSTICS, LINT_ALIASES }
    resolved: list[str] = [];
    unknown: list[str] = [];
    seen: set[str] = set();
    unknown_seen: set[str] = set();
    if not tokens {
        return (resolved, unknown);
    }
    for raw_item in tokens {
        if not isinstance(raw_item, str) {
            continue;
        }
        for part in raw_item.split(",") {
            token = part.strip();
            if not token {
                continue;
            }
            canonical = token.upper();
            if canonical in DIAGNOSTICS {
                if canonical not in seen {
                    seen.add(canonical);
                    resolved.append(canonical);
                }
                continue;
            }
            alias_code = LINT_ALIASES.get(token.lower());
            if alias_code and alias_code in DIAGNOSTICS {
                if alias_code not in seen {
                    seen.add(alias_code);
                    resolved.append(alias_code);
                }
                continue;
            }
            if canonical not in unknown_seen {
                unknown_seen.add(canonical);
                unknown.append(canonical);
            }
        }
    }
    return (resolved, unknown);
}
