import from abc { ABC, abstractmethod }
import from collections.abc { Callable }
import from dataclasses { dataclass }
import from typing { Any, Generic, TypeVar }
import from pydantic { BaseModel }
import from enum { StrEnum }

glob T = TypeVar('T');

class HTTPMethod(StrEnum) {
    has GET: str = 'GET';
    has POST: str = 'POST';
    has PUT: str = 'PUT';
    has PATCH: str = 'PATCH';
    has DELETE: str = 'DELETE';
}

class ParameterType(StrEnum) {
    has QUERY: str = 'query';
    has PATH: str = 'path';
    has BODY: str = 'body';
    has HEADER: str = 'header';
}

obj APIParameter {
    has name: str;
    has <>type: ParameterType = ParameterType.QUERY;
    has data_type: str = 'str';
    has required: bool = True;
    has <>default: Any = None;
    has description: str = '';
}

"""
Data class representing a single API endpoint.
This class provides a clean representation of an endpoint configuration,
including its method, path, callback function, parameters, and response model.

Attributes:
    method (HTTPMethod): The HTTP method for the endpoint (GET, POST, etc.)
    path (str): The URL path for the endpoint
    callback (Callable): The function to be called when the endpoint is accessed
    parameters (list[APIParameter] | None): List of parameters for the endpoint
    response_model (type[BaseModel] | None): Pydantic model for the response
    tags (list[str] | None): Tags for categorizing the endpoint
    summary (str | None): Short summary of the endpoint
    description (str | None): Detailed description of the endpoint
"""
obj JEndPoint {
    has method: HTTPMethod;
    has path: str;
    has callback: Callable[(..., Any)];
    has parameters: (list[APIParameter] | None) = None;
    has response_model: (type[BaseModel] | None) = None;
    has tags: (list[str] | None) = None;
    has summary: (str | None) = None;
    has description: (str | None) = None;
}

"""Abstract base class for server implementations."""
class JServer(ABC , Generic[T]) {
    """
    Initialize the server with a list of endpoints.
    Args:
        end_points (list[JEndPoint]): List of endpoint definitions to register
    """
    def __init__(self: JServer, end_points: list[JEndPoint]) -> None {
        super.init();
        self._endpoints = end_points;
    }

    """
    Return the list of registered endpoints.
    This method should return only the endpoints that have been registered
    with this server implementation, not create new ones.

    Returns:
        List[JEndPoint]: List of registered endpoint definitions
    """
    def get_endpoints(self: JServer) -> list[JEndPoint] {
        return self._endpoints;
    }

    """
    Add a single endpoint to the server implementation.

    Args:
    endpoint (JEndPoint): The endpoint to add
    """
    def add_endpoint(self: JServer, endpoint: JEndPoint) -> None {
        self._endpoints.append(endpoint);
    }

    """
    Execute the provided endpoints by calling the appropriate HTTP method handlers.

    This method iterates through the endpoint list and calls the appropriate
    method (get, post, put, patch, delete) based on each endpoint's HTTP method.
    """
    def execute(self: JServer) -> None {
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

    """Handle execution of a GET endpoint."""
    @abstractmethod
    def _get(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
        ;
    }

    """Handle execution of a POST endpoint."""
    @abstractmethod
    def _post(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
        ;
    }

    """Handle execution of a PUT endpoint."""
    @abstractmethod
    def _put(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
        ;
    }

    """Handle execution of a PATCH endpoint."""
    @abstractmethod
    def _patch(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
        ;
    }

    """Handle execution of a DELETE endpoint."""
    @abstractmethod
    def _delete(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
        ;
    }

    """
    Create a complete server with all endpoints registered.

    This is a convenience method that gets all endpoints and executes them
    to create a fully configured server. The return type depends on the
    concrete implementation.

    Args:
        app (Optional[FastAPI]): Optional FastAPI instance to use (ignored in base implementation)

    Returns:
        Any: Implementation-specific configured server
    """
    @abstractmethod
    def create_server(self: JServer) -> T { }

    """Run the server on the specified host and port."""
    @abstractmethod
    def run_server(self: JServer, host: str = 'localhost', port: int = 8000) -> None { }
}
