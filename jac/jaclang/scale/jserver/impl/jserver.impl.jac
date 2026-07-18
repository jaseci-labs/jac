impl JServer._delete(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
    ;
}

impl JServer._patch(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
    ;
}

impl JServer._put(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
    ;
}

impl JServer._post(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
    ;
}

impl JServer._get(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
    ;
}

impl JServer.execute(self: JServer) -> None {
    for endpoint in self._endpoints {
        if (endpoint.method == HTTPMethod.GET) {
            self._get(endpoint);
        } elif (endpoint.method == HTTPMethod.POST) {
            self._post(endpoint);
        } elif (endpoint.method == HTTPMethod.PUT) {
            self._put(endpoint);
        } elif (endpoint.method == HTTPMethod.PATCH) {
            self._patch(endpoint);
        } elif (endpoint.method == HTTPMethod.DELETE) {
            self._delete(endpoint);
        }
    }
}

impl JServer.add_endpoint(self: JServer, endpoint: JEndPoint) -> None {
    self._endpoints.append(endpoint);
}

impl JServer.init(self: JServer, end_points: list[JEndPoint]) -> None {
    self._endpoints = end_points;
}
