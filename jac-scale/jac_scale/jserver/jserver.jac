import from abc { ABC, abstractmethod }
import from collections.abc { Callable }
import from dataclasses { dataclass }
import from enum { Enum }
import from typing { Any, Generic, TypeVar }
import from pydantic { BaseModel }
with entry {
    T = TypeVar('T');
}

class HTTPMethod(str , Enum) {
    with entry {
        GET = 'GET';
        POST = 'POST';
        PUT = 'PUT';
        PATCH = 'PATCH';
        DELETE = 'DELETE';
    }
}

class ParameterType(str , Enum) {
    with entry {
        QUERY = 'query';
        PATH = 'path';
        BODY = 'body';
        HEADER = 'header';
    }
}

@dataclass
class APIParameter {
    with entry {
        name: str;
        <>type: ParameterType = ParameterType.QUERY;
        data_type: str = 'str';
        required: bool = True;
        <>default: Any = None;
        description: str = '';
    }
}

"""\n    Data class representing a single API endpoint.\n\n    This class provides a clean representation of an endpoint configuration,\n    including its method, path, callback function, parameters, and response model.\n\n    Attributes:\n        method (HTTPMethod): The HTTP method for this endpoint\n        path (str): The URL path for this endpoint\n        callback (Callable): The function to call when this endpoint is hit\n        parameters (Optional[List[Dict[str, Any]]]): List of parameter configurations\n        response_model (Optional[Type[BaseModel]]): Pydantic model for response validation\n        tags (Optional[List[str]]): Tags for API documentation\n        summary (Optional[str]): Short summary for API documentation\n        description (Optional[str]): Detailed description for API documentation\n    """
@dataclass
class JEndPoint {
    with entry {
        method: HTTPMethod;
        path: str;
        callback: Callable[(..., Any)];
        parameters: (list[APIParameter] | None) = None;
        response_model: (type[BaseModel] | None) = None;
        tags: (list[str] | None) = None;
        summary: (str | None) = None;
        description: (str | None) = None;
    }
}

"""\n    Abstract base class for server implementations.\n    """
class JServer(ABC , Generic[T]) {
    def __init__(self: JServer, end_points: list[JEndPoint]) -> None {
        super.init();
        self._endpoints = end_points;
    }

    """\n        Return the list of registered endpoints.\n\n        This method should return only the endpoints that have been registered\n        with this server implementation, not create new ones.\n\n        Returns:\n            List[JEndPoint]: List of registered endpoint definitions\n        """
    def get_endpoints(self: JServer) -> list[JEndPoint] {
        return self._endpoints;
    }

    """\n        Add a single endpoint to the server implementation.\n\n        Args:\n            endpoint (JEndPoint): The endpoint to add\n        """
    def add_endpoint(self: JServer, endpoint: JEndPoint) -> None {
        self._endpoints.append(endpoint);
    }

    """\n        Execute the provided endpoints by calling the appropriate HTTP method handlers.\n\n        This method iterates through the endpoint list and calls the appropriate\n        method (get, post, put, patch, delete) based on each endpoint's HTTP method.\n        """
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

    """\n        Handle execution of a GET endpoint.\n        """
    @abstractmethod
    def _get(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
        ;
    }

    """\n        Handle execution of a POST endpoint.\n        """
    @abstractmethod
    def _post(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
        ;
    }

    """\n        Handle execution of a PUT endpoint.\n        """
    @abstractmethod
    def _put(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
        ;
    }

    """\n        Handle execution of a PATCH endpoint.\n        """
    @abstractmethod
    def _patch(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
        ;
    }

    """\n        Handle execution of a DELETE endpoint.\n        """
    @abstractmethod
    def _delete(self: JServer, endpoint: JEndPoint) -> 'JServer[T]' {
        ;
    }

    """\n        Create a complete server with all endpoints registered.\n\n        This is a convenience method that gets all endpoints and executes them\n        to create a fully configured server. The return type depends on the\n        concrete implementation.\n\n        Args:\n            app (Optional[FastAPI]): Optional FastAPI instance to use (ignored in base implementation)\n\n        Returns:\n            Any: Implementation-specific configured server\n        """
    @abstractmethod
    def create_server(self: JServer) -> T {
        ;
    }

    """\n        Run the server on the specified host and port.\n\n        Args:\n            host (str): The host address to bind the server to\n            port (int): The port number to bind the server to\n        """
    @abstractmethod
    def run_server(self: JServer, host: str = 'localhost', port: int = 8000) -> None {
        ;
    }
}
