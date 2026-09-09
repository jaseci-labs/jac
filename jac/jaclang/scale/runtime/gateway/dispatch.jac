import from jaclang.scale.runtime.routing {
    GATEWAY_API_SEGMENTS,
    GATEWAY_LISTING_SEGMENTS,
    GATEWAY_PAGE_SEGMENTS,
    GATEWAY_WELLKNOWN_SEGMENTS
}

glob _BUILTIN_EXACT: set[str] = (
         {"/healthz/live", "/healthz/ready"}
         | {f"/{seg}" for seg in GATEWAY_WELLKNOWN_SEGMENTS}
     );

glob _PAGE_PATHS: set[str] = {f"/{seg}" for seg in GATEWAY_PAGE_SEGMENTS};

glob _PASSTHROUGH_SEGMENTS: set[str] = set(GATEWAY_API_SEGMENTS);

glob _SERVICE_MEMBER_SEGMENTS: set[str] = (
         _PASSTHROUGH_SEGMENTS
         | set(GATEWAY_WELLKNOWN_SEGMENTS)
         | set(GATEWAY_LISTING_SEGMENTS)
     );

glob ROUTE_BUILTIN: str = "builtin",
     ROUTE_ADMIN: str = "admin",
     ROUTE_IDENTITY: str = "identity",
     ROUTE_PROXY: str = "proxy",
     ROUTE_PASSTHROUGH: str = "passthrough",
     ROUTE_STATIC: str = "static",
     ROUTE_CLIENT_PAGE: str = "client_page";


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


def classify_route(
    path: str, service_prefixes: list[str], client_pages: bool = False
) -> RouteDecision {
    norm = _normalize(path);
    if client_pages and norm in _PAGE_PATHS {
        return RouteDecision(kind=ROUTE_CLIENT_PAGE);
    }
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
