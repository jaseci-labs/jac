"""Gateway request-dispatch decision: pure classification of a request path.

Both the embedded and the process gateway run the same decision to pick where a
request goes, in this order:

  1. builtin exact paths   (/healthz/*, /health, /healthz, /metrics,
                            /openapi.json, /docs)
  2. admin                 (/admin, /admin/*)
  3. service proxy         longest service-prefix match -> that service
  4. builtin passthrough   (/walker, /function, /user, ... fan-out)
  5. static                SPA fallback for everything else

Keeping this pure (path + the registered service prefixes in, a decision out)
makes the order testable in isolation. With the no-/api/ scheme, a service claims
only its member subpaths (`/<svc>/walker/...`, `/<svc>/function/...`, ...): the
bare `/<svc>` and any non-member subpath fall through to static, so an SPA route
that shares a service's name still renders the SPA instead of hitting the proxy.
"""

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

# A service pod (JacAPIServer) exposes exactly these first-segments under its
# gateway prefix: the sv-call surface (_PASSTHROUGH_SEGMENTS) plus its own
# builtins. A request matches the proxy only when its first post-prefix segment
# is one of these; everything else under the prefix is the SPA's to own.
glob _SERVICE_MEMBER_SEGMENTS: set[str] = _PASSTHROUGH_SEGMENTS | {
         "healthz",
         "health",
         "metrics",
         "openapi.json",
         "docs"
     };

glob ROUTE_BUILTIN: str = "builtin",
     ROUTE_ADMIN: str = "admin",
     ROUTE_PROXY: str = "proxy",
     ROUTE_PASSTHROUGH: str = "passthrough",
     ROUTE_STATIC: str = "static";


"""Where a request path is dispatched. `service` is the matched service prefix
when kind is proxy, empty otherwise."""
obj RouteDecision {
    has kind: str,
        service: str = "";
}


"""Normalize a path to a single leading slash and no trailing slash (root stays
'/')."""
def _normalize(path: str) -> str {
    trimmed = path.strip("/");
    if trimmed == "" {
        return "/";
    }
    return "/" + trimmed;
}


"""The first path segment ('' for root)."""
def _first_segment(norm_path: str) -> str {
    trimmed = norm_path.strip("/");
    if trimmed == "" {
        return "";
    }
    return trimmed.split("/")[0];
}


"""Longest service prefix whose member subpath owns `norm_path`, or '' when none
match. A prefix owns `norm_path` only when the first segment after it is a service
member (`/<prefix>/walker/...`); the bare prefix and non-member subpaths are left
to the SPA, so a service and a same-named SPA route coexist."""
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


"""Classify a request path against the registered service prefixes."""
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
    if _first_segment(norm) in _PASSTHROUGH_SEGMENTS {
        return RouteDecision(kind=ROUTE_PASSTHROUGH);
    }
    return RouteDecision(kind=ROUTE_STATIC);
}
