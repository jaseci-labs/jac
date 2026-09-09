import from jaclang.server.serving.endpoint { HTTPMethod, JEndPoint, WSEndPoint }


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
    ) -> (dict[(str, str)] | None) {
        if self.catchall is None and self.trailing_slash != trailing_slash {
            return None;
        }
        fixed = self.segments;
        if self.catchall is None and len(path_segments) != len(fixed) {
            return None;
        }
        if self.catchall is not None and len(path_segments) < len(fixed) {
            return None;
        }
        params: dict[(str, str)] = {};
        for (i, seg) in enumerate(fixed) {
            part = path_segments[i];
            if seg.kind == 'lit' {
                if seg.value != part {
                    return None;
                }
            } else {
                params[seg.value] = part;
            }
        }
        if self.catchall is not None {
            params[self.catchall] = '/'.join(path_segments[len(fixed):]);
        }
        return params;
    }
}

def path_param_names(path: (str | None)) -> list[str] {
    if not path {
        return [];
    }
    names: list[str] = [];
    for segment in path.split('/') {
        if segment.startswith('{') and segment.endswith('}') and len(segment) > 2 {
            raw = segment[1:-1].strip();
            if raw {
                name = raw.split(':', 1)[0].strip();
                if name and name not in names {
                    names.append(name);
                }
            }
        }
    }
    return names;
}


def compile_route(path: str) -> CompiledRoute {
    route = CompiledRoute();
    route.trailing_slash = len(path) > 1 and path.endswith('/');
    parts = [
        p
        for p in path.strip('/').split('/')
        if p != ''
    ];
    for part in parts {
        if part.startswith('{') and part.endswith('}') {
            inner = part[1:-1];
            if inner.endswith(':path') {
                route.catchall = inner[:-5];
            } else {
                name = inner.split(':')[0];
                route.segments.append(RouteSegment(kind='param', value=name));
                route.param_count += 1;
            }
        } else {
            route.segments.append(RouteSegment(kind='lit', value=part));
        }
    }
    return route;
}

def route_sort_key(route: CompiledRoute) -> tuple {
    path = '';
    if route.endpoint is not None {
        path = route.endpoint.path;
    } elif route.ws_endpoint is not None {
        path = route.ws_endpoint.path;
    }
    return (
        1 if route.catchall is not None else 0,
        route.param_count,
        -len(route.segments),
        path
    );
}

obj Router {
    has routes: dict[(str, list[CompiledRoute])] = {},
        ws_routes: list[CompiledRoute] = [];

    def add(endpoint: JEndPoint) {
        route = compile_route(endpoint.path);
        route.endpoint = endpoint;
        method = str(endpoint.method.value)
            if isinstance(endpoint.method, HTTPMethod)
            else str(endpoint.method);
        bucket = self.routes.setdefault(method.upper(), []);
        bucket.append(route);
        bucket.sort(key=route_sort_key);
    }

    def add_ws(endpoint: WSEndPoint) {
        route = compile_route(endpoint.path);
        route.ws_endpoint = endpoint;
        self.ws_routes.append(route);
        self.ws_routes.sort(key=route_sort_key);
    }

    def clear {
        self.routes = {};
        self.ws_routes = [];
    }

    def resolve(
        method: str, path: str
    ) -> tuple[(JEndPoint | None), dict[(str, str)], list[str]] {
        segments = [
            p
            for p in path.strip('/').split('/')
            if p != ''
        ];
        trailing = len(path) > 1 and path.endswith('/');
        lookup = 'GET' if method.upper() == 'HEAD' else method.upper();
        for route in self.routes.get(lookup, []) {
            params = route.`match(segments, trailing);
            if params is not None and route.endpoint is not None {
                return (route.endpoint, params, []);
            }
        }
        allowed: list[str] = [];
        for (other_method, bucket) in self.routes.items() {
            if other_method == lookup {
                continue;
            }
            for route in bucket {
                if route.`match(segments, trailing) is not None {
                    allowed.append(other_method);
                    break;
                }
            }
        }
        return (None, {}, allowed);
    }

    def resolve_ws(path: str) -> tuple[(WSEndPoint | None), dict[(str, str)]] {
        segments = [
            p
            for p in path.strip('/').split('/')
            if p != ''
        ];
        trailing = len(path) > 1 and path.endswith('/');
        for route in self.ws_routes {
            params = route.`match(segments, trailing);
            if params is not None and route.ws_endpoint is not None {
                return (route.ws_endpoint, params);
            }
        }
        return (None, {});
    }

    def all_endpoints -> list[JEndPoint] {
        result: list[JEndPoint] = [];
        for bucket in self.routes.values() {
            for route in bucket {
                if route.endpoint is not None {
                    result.append(route.endpoint);
                }
            }
        }
        return result;
    }
}
