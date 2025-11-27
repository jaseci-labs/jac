from abc import ABC, abstractmethod
from collections.abc import Callable
from dataclasses import dataclass
from enum import Enum
from typing import Any, Generic, TypeVar

from pydantic import BaseModel

T = TypeVar("T")


class HTTPMethod(str, Enum):
    GET = "GET"
    POST = "POST"
    PUT = "PUT"
    PATCH = "PATCH"
    DELETE = "DELETE"


class ParameterType(str, Enum):
    QUERY = "query"
    PATH = "path"
    BODY = "body"
    HEADER = "header"


@dataclass
class APIParameter:
    name: str
    type: ParameterType = ParameterType.QUERY
    data_type: str = "str"
    required: bool = True
    default: Any = None
    description: str = ""


@dataclass
class JEndPoint:
    """
    Data class representing a single API endpoint.

    This class provides a clean representation of an endpoint configuration,
    including its method, path, callback function, parameters, and response model.

    Attributes:
        method (HTTPMethod): The HTTP method for this endpoint
        path (str): The URL path for this endpoint
        callback (Callable): The function to call when this endpoint is hit
        parameters (Optional[List[Dict[str, Any]]]): List of parameter configurations
        response_model (Optional[Type[BaseModel]]): Pydantic model for response validation
        tags (Optional[List[str]]): Tags for API documentation
        summary (Optional[str]): Short summary for API documentation
        description (Optional[str]): Detailed description for API documentation
    """

    method: HTTPMethod
    path: str
    callback: Callable[..., Any]
    parameters: list[APIParameter] | None = None
    response_model: type[BaseModel] | None = None
    tags: list[str] | None = None
    summary: str | None = None
    description: str | None = None


class JServer(ABC, Generic[T]):
    """
    Abstract base class for server implementations.
    """

    def __init__(self, end_points: list[JEndPoint]) -> None:
        super().__init__()
        self._endpoints = end_points

    def get_endpoints(self) -> list[JEndPoint]:
        """
        Return the list of registered endpoints.

        This method should return only the endpoints that have been registered
        with this server implementation, not create new ones.

        Returns:
            List[JEndPoint]: List of registered endpoint definitions
        """
        return self._endpoints

    def add_endpoint(self, endpoint: JEndPoint) -> None:
        """
        Add a single endpoint to the server implementation.

        Args:
            endpoint (JEndPoint): The endpoint to add
        """
        self._endpoints.append(endpoint)

    def execute(self) -> None:
        """
        Execute the provided endpoints by calling the appropriate HTTP method handlers.

        This method iterates through the endpoint list and calls the appropriate
        method (get, post, put, patch, delete) based on each endpoint's HTTP method.
        """
        for endpoint in self._endpoints:
            if endpoint.method == HTTPMethod.GET:
                self._get(endpoint)
            elif endpoint.method == HTTPMethod.POST:
                self._post(endpoint)
            elif endpoint.method == HTTPMethod.PUT:
                self._put(endpoint)
            elif endpoint.method == HTTPMethod.PATCH:
                self._patch(endpoint)
            elif endpoint.method == HTTPMethod.DELETE:
                self._delete(endpoint)

    @abstractmethod
    def _get(self, endpoint: JEndPoint) -> "JServer[T]":
        """
        Handle execution of a GET endpoint.
        """
        pass

    @abstractmethod
    def _post(self, endpoint: JEndPoint) -> "JServer[T]":
        """
        Handle execution of a POST endpoint.
        """
        pass

    @abstractmethod
    def _put(self, endpoint: JEndPoint) -> "JServer[T]":
        """
        Handle execution of a PUT endpoint.
        """
        pass

    @abstractmethod
    def _patch(self, endpoint: JEndPoint) -> "JServer[T]":
        """
        Handle execution of a PATCH endpoint.
        """
        pass

    @abstractmethod
    def _delete(self, endpoint: JEndPoint) -> "JServer[T]":
        """
        Handle execution of a DELETE endpoint.
        """
        pass

    @abstractmethod
    def create_server(self) -> T:
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
        pass

    @abstractmethod
    def run_server(self, host: str = "localhost", port: int = 8000) -> None:
        """
        Run the server on the specified host and port.

        Args:
            host (str): The host address to bind the server to
            port (int): The port number to bind the server to
        """
        pass
