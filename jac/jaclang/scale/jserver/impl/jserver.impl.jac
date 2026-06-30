"""Handle execution of a DELETE endpoint."""

impl JServer._delete(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
    ;
}

"""Handle execution of a PATCH endpoint."""
impl JServer._patch(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
    ;
}

"""Handle execution of a PUT endpoint."""
impl JServer._put(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
    ;
}

"""Handle execution of a POST endpoint."""
impl JServer._post(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
    ;
}

"""Handle execution of a GET endpoint."""
impl JServer._get(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
    ;
}

"""
Execute the provided endpoints by calling the appropriate HTTP method handlers.

This method iterates through the endpoint list and calls the appropriate
method (get, post, put, patch, delete) based on each endpoint's HTTP method.
"""
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

"""
Add a single endpoint to the server implementation.

Args:
endpoint (JEndPoint): The endpoint to add
"""
impl JServer.add_endpoint(self: JServer, endpoint: JEndPoint) -> None {
    self._endpoints.append(endpoint);
}

"""
Return the list of registered endpoints.
This method should return only the endpoints that have been registered
with this server implementation, not create new ones.

Returns:
List[JEndPoint]: List of registered endpoint definitions
"""
impl JServer.get_endpoints(self: JServer) -> list[JEndPoint] {
    return self._endpoints;
}

"""
Initialize the server with a list of endpoints.
Args:
end_points (list[JEndPoint]): List of endpoint definitions to register
"""
impl JServer.init(self: JServer, end_points: list[JEndPoint]) -> None {
    super.init();
    self._endpoints = end_points;
}
