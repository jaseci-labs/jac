glob _BUILTIN_EXACT: set[str] = {
         "/healthz/live",
         "/healthz/ready",
         "/health",
         "/healthz",
         "/metrics",
         "/openapi.json",
         "/docs"
     };

glob _PASSTHROUGH_SEGMENTS: set[str] = {
         "walker",
         "function",
         "user",
         "sso",
         "api-key",
         "webhook",
         "ws",
         "jobs",
         "graph"
     };

glob _SERVICE_MEMBER_SEGMENTS: set[str] = _PASSTHROUGH_SEGMENTS | {
         "healthz",
         "health",
         "metrics",
         "openapi.json",
         "docs"
     };

glob ROUTE_BUILTIN: str = "builtin",
     ROUTE_ADMIN: str = "admin",
     ROUTE_IDENTITY: str = "identity",
     ROUTE_PROXY: str = "proxy",
     ROUTE_PASSTHROUGH: str = "passthrough",
     ROUTE_STATIC: str = "static";


obj RouteDecision {
    has kind: str,
        service: str = "";
}


def _normalize(path: str) -> str {
    trimmed = path.strip("/");
    if trimmed == "" {
        return "/";
    }
    return "/" + trimmed;
}


def _first_segment(norm_path: str) -> str {
    trimmed = norm_path.strip("/");
    if trimmed == "" {
        return "";
    }
    return trimmed.split("/")[0];
}


def _longest_prefix_match(norm_path: str, service_prefixes: list[str]) -> str {
    best = "";
    for prefix in service_prefixes {
        if norm_path.startswith(prefix + "/") {
            remainder = norm_path[len(prefix) + 1:];
            first_member = remainder.split("/")[0];
            if first_member in _SERVICE_MEMBER_SEGMENTS and len(prefix) > len(best) {
                best = prefix;
            }
        }
    }
    return best;
}


def classify_route(path: str, service_prefixes: list[str]) -> RouteDecision {
    norm = _normalize(path);
    if norm in _BUILTIN_EXACT {
        return RouteDecision(kind=ROUTE_BUILTIN);
    }
    if norm == "/admin" or norm.startswith("/admin/") {
        return RouteDecision(kind=ROUTE_ADMIN);
    }
    matched = _longest_prefix_match(norm, service_prefixes);
    if matched != "" {
        return RouteDecision(kind=ROUTE_PROXY, service=matched);
    }
    if _first_segment(norm) == "user" {
        return RouteDecision(kind=ROUTE_IDENTITY);
    }
    if _first_segment(norm) in _PASSTHROUGH_SEGMENTS {
        return RouteDecision(kind=ROUTE_PASSTHROUGH);
    }
    return RouteDecision(kind=ROUTE_STATIC);
}
