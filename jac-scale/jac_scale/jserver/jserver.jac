import from abc { ABC, abstractmethod }
import from collections.abc { Callable }
import from dataclasses { dataclass }
import from typing { Any, Generic, TypeVar }
import from pydantic { BaseModel }
import from enum { StrEnum }

glob T = TypeVar('T');

class HTTPMethod(StrEnum) {
    has GET: str = 'GET',
        POST: str = 'POST',
        PUT: str = 'PUT',
        PATCH: str = 'PATCH',
        DELETE: str = 'DELETE';
}

class ParameterType(StrEnum) {
    has QUERY: str = 'query',
        PATH: str = 'path',
        BODY: str = 'body',
        HEADER: str = 'header',
        FILE: str = 'file';
}

obj APIParameter {
    has name: str,
        <>type: ParameterType = ParameterType.QUERY,
        data_type: str = 'str',
        required: bool = True,
        <>default: Any = None,
        description: str = '';
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
    has method: HTTPMethod,
        path: str,
        callback: Callable[(..., Any)],
        parameters: (list[APIParameter] | None) = None,
        response_model: (type[BaseModel] | None) = None,
        tags: (list[str] | None) = None,
        summary: (str | None) = None,
        description: (str | None) = None;
}

"""Abstract base class for server implementations."""
class JServer(ABC, Generic[T]) {
    def init(self: JServer, end_points: list[JEndPoint]) -> None;
    def get_endpoints(self: JServer) -> list[JEndPoint];
    def add_endpoint(self: JServer, endpoint: JEndPoint) -> None;
    def execute(self: JServer) -> None;
    @abstractmethod
    def _get(self: JServer, endpoint: JEndPoint) -> 'JServer[T]';

    @abstractmethod
    def _post(self: JServer, endpoint: JEndPoint) -> 'JServer[T]';

    @abstractmethod
    def _put(self: JServer, endpoint: JEndPoint) -> 'JServer[T]';

    @abstractmethod
    def _patch(self: JServer, endpoint: JEndPoint) -> 'JServer[T]';

    @abstractmethod
    def _delete(self: JServer, endpoint: JEndPoint) -> 'JServer[T]';

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
