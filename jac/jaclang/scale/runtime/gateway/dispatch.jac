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


def _normalize(path: str) -> str;


def _first_segment(norm_path: str) -> str;


def _longest_prefix_match(norm_path: str, service_prefixes: list[str]) -> str;


def classify_route(
    path: str, service_prefixes: list[str], client_pages: bool = False
) -> RouteDecision;
