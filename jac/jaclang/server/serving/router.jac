import bisect;


obj RouteSegment {
    has kind: str = 'lit',
        value: str = '';
}

obj CompiledRoute {
    has endpoint: (JEndPoint | None) = None,
        ws_endpoint: (WSEndPoint | None) = None,
        segments: list[RouteSegment] = [],
        catchall: (str | None) = None,
        param_count: int = 0,
        trailing_slash: bool = False;

    def `match(
        path_segments: list[str], trailing_slash: bool = False
    ) -> (dict[(str, str)] | None);
}

def path_param_names(path: (str | None)) -> list[str];


def compile_route(path: str) -> CompiledRoute;

def route_sort_key(route: CompiledRoute) -> tuple[int, int, int, int, str];

obj Router {
    has routes: dict[(str, list[CompiledRoute])] = {},
        ws_routes: list[CompiledRoute] = [];

    def add(endpoint: JEndPoint);
    def add_ws(endpoint: WSEndPoint);
    def clear;
    def resolve(
        method: str, path: str
    ) -> tuple[(JEndPoint | None), dict[(str, str)], list[str]];

    def resolve_ws(path: str) -> tuple[(WSEndPoint | None), dict[(str, str)]];
    def all_endpoints -> list[JEndPoint];
}
