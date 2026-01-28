"""
JFastApiServer: A FastAPI Implementation of JServer

This module provides a FastAPI-specific implementation of the JServer abstract base class.
It handles endpoint registration with FastAPI applications and provides all the FastAPI-specific
functionality like parameter injection, response model generation, and route creation.

Key Components:
- JFastApiServer: FastAPI implementation of JServer
- create_app(): Creates a basic FastAPI application for demonstration

Advanced Features:
- Parameter injection with type conversion
- Response model generation from JSON schema
- Support for async/sync callback functions
- Automatic OpenAPI documentation generation
- Integration with JAC pass execution patterns
"""

import inspect;
import logging;
import uvicorn;
import from collections.abc { Callable }
import from typing { Any, Optional, TypeAlias, get_type_hints }
import from fastapi {
    Body,
    FastAPI,
    File,
    Form,
    Header,
    HTTPException,
    Path,
    Query,
    Request,
    UploadFile
}
import from fastapi.responses { Response, JSONResponse }
import from pydantic { BaseModel, Field, create_model }
import from .jserver { APIParameter, HTTPMethod, JEndPoint, JServer, ParameterType }
import from jaclang.runtimelib.transport { TransportResponse }

glob EndpointResponse: TypeAlias = Response | BaseModel | <>dict[(str, object)] | <>list[
         object
     ] | str | <>bytes | None;

"""Base protocol for parameter handlers."""
obj ParameterHandler {
    has type_converter: JFastApiServer;

    """Generate parameter string for FastAPI function signature."""
    def generate_param_string(param: APIParameter) -> str;

    """Get the actual Python type from parameter type string."""
    def get_type(param: APIParameter) -> type[Any] {
        return self.type_converter._get_python_type(param.data_type);
    }

    """Get the type name for code generation."""
    def get_type_name(param: APIParameter) -> str {
        return self.get_type(param).__name__;
    }
}

"""Handler for PATH parameters."""
obj PathParameterHandler(ParameterHandler) {
    def generate_param_string(param: APIParameter) -> str;
}

"""Handler for QUERY parameters."""
obj QueryParameterHandler(ParameterHandler) {
    def generate_param_string(param: APIParameter) -> str;
}

"""Handler for HEADER parameters."""
obj HeaderParameterHandler(ParameterHandler) {
    def generate_param_string(param: APIParameter) -> str;
}

"""Handler for FILE parameters."""
obj FileParameterHandler(ParameterHandler) {
    def generate_param_string(param: APIParameter) -> str;
}

"""Handler for BODY parameters with files (multipart/form-data)."""
obj FormBodyParameterHandler(ParameterHandler) {
    def generate_param_string(param: APIParameter) -> str;
}

"""Handler for BODY parameters without files (JSON)."""
obj JSONBodyParameterHandler(ParameterHandler) {
    has body_params: list[APIParameter];

    """Generate Pydantic model for JSON body."""
    def generate_body_model -> (type[BaseModel] | None);
}

"""
JFastApiServer: FastAPI implementation of JServer for programmatic endpoint creation.

JFastApiServer provides FastAPI-specific implementation of the JServer interface,
handling endpoint registration with FastAPI applications.

This class implements the JServer interface by:
- Storing registered endpoints internally
- Implementing HTTP method handlers (_get, _post, _put, _patch, _delete)
- Providing FastAPI app instance for server execution

    Example:
        >>> # Create server with endpoints
        >>> endpoints = [
        ...     JEndPoint(HTTPMethod.GET, "/users", get_users_callback),
        ...     JEndPoint(HTTPMethod.POST, "/users", create_user_callback)
        ... ]
        >>> server = JFastApiServer(endpoints)
        >>>
        >>> # Execute to create FastAPI routes
        >>> server.execute()
        >>> app = server.create_server()

    Attributes:
        app (FastAPI): The underlying FastAPI application instance
"""
class JFastApiServer(JServer[FastAPI]) {
    def init(
        self: JFastApiServer,
        endpoints: (list[JEndPoint] | None) = None,
        app: (FastAPI | None) = None
    ) -> None;

    def _get(self: JFastApiServer, endpoint: JEndPoint) -> 'JFastApiServer';
    def _post(self: JFastApiServer, endpoint: JEndPoint) -> 'JFastApiServer';
    def _put(self: JFastApiServer, endpoint: JEndPoint) -> 'JFastApiServer';
    def _patch(self: JFastApiServer, endpoint: JEndPoint) -> 'JFastApiServer';
    def _delete(self: JFastApiServer, endpoint: JEndPoint) -> 'JFastApiServer';
    def _route_priority(
        self: JFastApiServer, endpoint: JEndPoint
    ) -> tuple[int, int, int, str];

    def execute(self: JFastApiServer) -> None;
    def create_server(self: JFastApiServer) -> FastAPI;
    def _create_fastapi_route(
        self: JFastApiServer, method: HTTPMethod, endpoint: JEndPoint
    ) -> None;

    def _get_default_status_code(self: JFastApiServer, method: HTTPMethod) -> int;
    def _create_endpoint_function(
        self: JFastApiServer,
        callback: Callable[(..., Any)],
        parameters: list[APIParameter],
        dependencies: list[Any]
    ) -> Callable[..., Any];

    def _get_python_type(self: JFastApiServer, type_string: str) -> type[Any];
    def _create_response_model(
        self: JFastApiServer, response_config: (dict[(str, Any)] | None) = None
    ) -> (type[BaseModel] | None);

    def get_app(self: JFastApiServer) -> FastAPI;
    def run_server(
        self: JFastApiServer, host: str = '0.0.0.0', port: int = 8000
    ) -> None;
}
